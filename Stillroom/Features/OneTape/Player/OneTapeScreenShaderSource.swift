import Foundation

/// Runtime-compiled Metal Shading Language source for the unified 60fps reflective
/// monochrome LCD screen pipeline:
/// - `scopeScreenFragment`: Cassette-style minimalist oscilloscope trace on reflective LCD.
/// - `liquidScreenFragment`: physics-driven glossy obsidian ferrofluid droplets.
/// - `waterScreenFragment`: directional-lit 2D shallow-water ripple heightfield.
/// - `lcdBackdropFragment` + `sandParticleVertex`/`sandParticleFragment`: hardware point-sprite
///   sand renderer powering Chladni `sand`, wind `dunes`, and `name` typography.
/// - `ironFilingVertex`/`ironFilingFragment`: instanced anti-aliased magnetic dipole iron needles.
enum OneTapeScreenShaderSource {
    static let msl: String = """
    #include <metal_stdlib>
    using namespace metal;

    struct ScreenUniforms {
        float4 bgColor;     // rgb = reflective LCD substrate
        float4 inkColor;    // rgb = deep monochrome LCD ink, a = playing state
        float2 size;        // logical point size (264.39x165.63 or rotated 165.63x264.39)
        float time;         // monotonic visual phase in seconds
        float scopeGain;    // gentle real-PCM auto-gain [1.0..2.2]
        float bass;         // smoothed low-frequency energy [0..1]
        float mid;          // smoothed mid/vocal energy [0..1]
        float high;         // smoothed high-frequency shimmer [0..1]
        float kick;         // punchy beat-onset envelope [0..1]
        float rms;          // overall loudness [0..1]
        float hasSignal;    // 1.0 when real PCM audio is active, else 0.0
        int pieceCount;     // active ferrofluid physics droplet count
        float pixelScale;   // drawable pixels per logical point (typically 2.0)
        int gridW;          // shallow-water heightfield width
        int gridH;          // shallow-water heightfield height
        float pad0;
        float pad1;
    };

    struct GPUGrain {
        float2 uv;
        float sizePx;
        float shade;
    };

    struct GPUFiling {
        float2 uv;
        float angle;
        float lengthAndShade;
    };

    struct ScreenVertexOut {
        float4 position [[position]];
        float2 uv;
    };

    struct SandVertexOut {
        float4 position [[position]];
        float pointSize [[point_size]];
        float shade;
    };

    struct FilingVertexOut {
        float4 position [[position]];
        float2 localPt;     // local needle coordinates in logical points
        float halfLen;      // half length in logical points
        float shade;
    };

    vertex ScreenVertexOut screenFullscreenVertex(uint vertexID [[vertex_id]]) {
        const float2 pos[3] = {
            float2(-1.0, -1.0),
            float2( 3.0, -1.0),
            float2(-1.0,  3.0)
        };
        ScreenVertexOut out;
        out.position = float4(pos[vertexID], 0.0, 1.0);
        float2 ndc = pos[vertexID];
        out.uv = float2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
        return out;
    }

    // Non-periodic 32-bit PCG integer hash (zero rational modular grid artifacts).
    static inline float pcgHash21(uint2 p) {
        uint h = p.x * 747796405u + p.y * 2891336453u + 277803737u;
        h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
        h = (h >> 22u) ^ h;
        return float(h & 0x00FFFFFFu) / 16777216.0;
    }

    // Shared reflective monochrome LCD glass micro-grain & subtle recessed bezel optics.
    static inline half4 finalizeLCD(float3 col, float2 uv, float2 pos, constant ScreenUniforms& u) {
        uint2 px = uint2(max(float2(0.0), floor(pos * u.pixelScale)));
        float grain = (pcgHash21(px) - 0.5) * 0.015;
        float topShadow  = smoothstep(9.0, 0.0, pos.y) * 0.050;
        float leftShadow = smoothstep(7.0, 0.0, pos.x) * 0.036;
        float botLift    = smoothstep(u.size.y - 6.0, u.size.y, pos.y) * 0.014;
        float sheen      = (0.5 - uv.x * 0.45 - uv.y * 0.55) * 0.018;

        float3 outRgb = col + float3(grain + sheen + botLift - topShadow - leftShadow);
        return half4(half3(clamp(outRgb, 0.0, 1.0)), 1.0h);
    }

    // Shared reflective LCD background pass for particle & needle screens.
    fragment half4 lcdBackdropFragment(
        ScreenVertexOut in [[stage_in]],
        constant ScreenUniforms& u [[buffer(0)]]
    ) {
        float2 pos = in.uv * u.size;
        return finalizeLCD(u.bgColor.rgb, in.uv, pos, u);
    }

    // Smooth Catmull-Rom interpolation across the 48-sample zero-crossing-stabilized PCM trace.
    static inline float sampleWaveCubic(constant float* wave, float xNorm) {
        float idx = clamp(xNorm, 0.0, 1.0) * 47.0;
        int i1 = clamp(int(floor(idx)), 0, 47);
        int i0 = max(0, i1 - 1);
        int i2 = min(47, i1 + 1);
        int i3 = min(47, i1 + 2);
        float t = idx - float(i1);

        float p0 = wave[i0];
        float p1 = wave[i1];
        float p2 = wave[i2];
        float p3 = wave[i3];

        float t2 = t * t;
        float t3 = t2 * t;
        return 0.5 * ((2.0 * p1)
                    + (-p0 + p2) * t
                    + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
                    + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3);
    }

    // 1. Minimalist Monochrome LCD Oscilloscope (matching Cassette 1.0.5 single baseline + crisp wave)
    fragment half4 scopeScreenFragment(
        ScreenVertexOut in [[stage_in]],
        constant ScreenUniforms& u [[buffer(0)]],
        constant float* wave [[buffer(1)]]
    ) {
        float2 uv = in.uv;
        float2 pos = uv * u.size;
        float3 bg  = u.bgColor.rgb;
        float3 ink = u.inkColor.rgb;

        float insetX = 12.0;
        float plotW = max(1.0, u.size.x - insetX * 2.0);
        float plotH = max(1.0, u.size.y - 20.0);

        // Single ultra-delicate horizontal center zero-line (no graph-paper clutter).
        float baseDist = abs(pos.y - u.size.y * 0.5);
        float inSpan = step(insetX, pos.x) * step(pos.x, u.size.x - insetX);
        float baseline = (1.0 - smoothstep(0.0, 0.65, baseDist)) * 0.085 * inSpan;
        float3 col = mix(bg, ink, baseline);

        if (pos.x >= insetX - 1.5 && pos.x <= u.size.x - insetX + 1.5) {
            float xN = clamp((pos.x - insetX) / plotW, 0.0, 1.0);
            float amp = plotH * 0.43 * u.hasSignal * u.scopeGain;
            float sC = clamp(sampleWaveCubic(wave, xN) * amp, -plotH * 0.46, plotH * 0.46);
            float eps = 1.0 / max(plotW, 32.0);
            float sL = clamp(sampleWaveCubic(wave, clamp(xN - eps, 0.0, 1.0)) * amp, -plotH * 0.46, plotH * 0.46);
            float sR = clamp(sampleWaveCubic(wave, clamp(xN + eps, 0.0, 1.0)) * amp, -plotH * 0.46, plotH * 0.46);

            float curveY = u.size.y * 0.5 - sC;
            float slope = (sR - sL) * 0.5;
            float invNorm = rsqrt(1.0 + slope * slope);
            float perpDist = abs(pos.y - curveY) * invNorm;
            float shadowDist = abs((pos.y - 1.4) - curveY) * invNorm;

            // Crisp dark ink stroke with delicate recessed drop shadow onto the LCD substrate.
            float dropShadow = exp(-pow(shadowDist / (2.5 + u.rms * 1.4), 2.0)) * 0.14;
            float coreWidth = 1.45 + u.kick * 0.35;
            float coreAlpha = 1.0 - smoothstep(coreWidth - 0.45, coreWidth + 0.45, perpDist);

            col = mix(col, ink, clamp(dropShadow + coreAlpha * 0.96, 0.0, 0.97));
        }

        return finalizeLCD(col, uv, pos, u);
    }

    // 2. Physics-Driven Glossy Obsidian Ferrofluid Droplets on Reflective LCD
    fragment half4 liquidScreenFragment(
        ScreenVertexOut in [[stage_in]],
        constant ScreenUniforms& u [[buffer(0)]],
        constant float4* pieces [[buffer(2)]]
    ) {
        float2 uv = in.uv;
        float2 pos = uv * u.size;
        float3 bg  = u.bgColor.rgb;
        float3 ink = u.inkColor.rgb;

        float minDim = max(1.0, min(u.size.x, u.size.y));
        float2 p = (pos - u.size * 0.5) / minDim;
        float2 pShadow = p - float2(0.011, 0.016);

        int count = clamp(u.pieceCount, 1, 16);
        float field = 0.0;
        float shadowField = 0.0;
        float2 grad = float2(0.0);

        for (int i = 0; i < count; i++) {
            float4 piece = pieces[i];
            float2 d = p - piece.xy;
            float r2 = piece.z * piece.z;
            float denom = dot(d, d) + 0.00075;
            float contrib = r2 / denom;
            field += contrib;
            grad += (-2.0 * contrib / denom) * d;

            float2 ds = pShadow - piece.xy;
            shadowField += r2 / (dot(ds, ds) + 0.0011);
        }

        float rippleAmp = 0.012 + u.high * 0.048 + u.bass * 0.022;
        float ripple = sin(p.x * 26.0 + u.time * 2.4) * cos(p.y * 26.0 - u.time * 2.1) * rippleAmp;
        float level = field + ripple;

        float gradMag = max(0.05, length(grad));
        float pixelWidth = gradMag * (1.20 / minDim);
        float bodyMask = smoothstep(1.0 - pixelWidth, 1.0 + pixelWidth, level);

        float dropShadow = smoothstep(0.84, 1.08, shadowField) * (1.0 - bodyMask) * 0.16;

        // Sharp liquid-mercury silver-white specular rim crescent along the top-left curve.
        float2 n2 = normalize(-grad + float2(1e-5, 1e-5));
        float lightFacing = clamp(dot(n2, normalize(float2(-0.62, -0.78))), 0.0, 1.0);
        float outerRim = smoothstep(1.01, 1.14, level) * smoothstep(1.52, 1.16, level);
        float broadSheen = smoothstep(1.04, 1.32, level) * smoothstep(2.10, 1.38, level);
        float specular = pow(lightFacing, 5.0) * outerRim * 0.52 + pow(lightFacing, 2.6) * broadSheen * 0.18;

        float3 liquidCol = mix(ink, float3(0.95, 0.97, 0.98), clamp(specular, 0.0, 0.72));
        float3 col = mix(bg, ink, dropShadow);
        col = mix(col, liquidCol, bodyMask * 0.98);

        return finalizeLCD(col, uv, pos, u);
    }

    // Bilinear sampler for the 2D shallow-water heightfield grid.
    static inline float sampleGridBilinear(constant float* grid, int w, int h, float2 uv) {
        float fx = clamp(uv.x, 0.0, 1.0) * float(w - 1);
        float fy = clamp(uv.y, 0.0, 1.0) * float(h - 1);
        int x0 = clamp(int(floor(fx)), 0, w - 1);
        int y0 = clamp(int(floor(fy)), 0, h - 1);
        int x1 = min(w - 1, x0 + 1);
        int y1 = min(h - 1, y0 + 1);
        float tx = fx - float(x0);
        float ty = fy - float(y0);

        float a = grid[y0 * w + x0];
        float b = grid[y0 * w + x1];
        float c = grid[y1 * w + x0];
        float d = grid[y1 * w + x1];
        return mix(mix(a, b, tx), mix(c, d, tx), ty);
    }

    // 3. Monochrome Reflective Shallow-Water Surface Ripples (Directional Lit Heightfield)
    fragment half4 waterScreenFragment(
        ScreenVertexOut in [[stage_in]],
        constant ScreenUniforms& u [[buffer(0)]],
        constant float* grid [[buffer(1)]]
    ) {
        float2 uv = in.uv;
        float2 pos = uv * u.size;
        float3 bg  = u.bgColor.rgb;
        float3 ink = u.inkColor.rgb;

        int gw = max(4, u.gridW);
        int gh = max(4, u.gridH);
        float2 eps = float2(1.0 / float(gw - 1), 1.0 / float(gh - 1));

        float hC = sampleGridBilinear(grid, gw, gh, uv);
        float hL = sampleGridBilinear(grid, gw, gh, uv - float2(eps.x, 0.0));
        float hR = sampleGridBilinear(grid, gw, gh, uv + float2(eps.x, 0.0));
        float hU = sampleGridBilinear(grid, gw, gh, uv - float2(0.0, eps.y));
        float hD = sampleGridBilinear(grid, gw, gh, uv + float2(0.0, eps.y));

        // Surface slope & 3D water normal lit from upper-left studio angle.
        float dhdx = (hR - hL) * 2.8;
        float dhdy = (hD - hU) * 2.8;
        float3 n = normalize(float3(-dhdx, -dhdy, 1.0));
        float3 lightDir = normalize(float3(-0.55, -0.62, 0.56));
        float3 halfVec  = normalize(lightDir + float3(0.0, 0.0, 1.0));

        float ndl = dot(n, lightDir);
        float flatNdl = lightDir.z;
        float slopeDelta = ndl - flatNdl;

        // Troughs facing away from light deepen cleanly into monochrome LCD ink;
        // crests facing light lift into crisp reflective silver-white liquid highlights.
        float shadowBand = clamp(-slopeDelta * 1.95 + max(0.0, -hC) * 0.28, 0.0, 0.88);
        float specHighlight = pow(max(0.0, dot(n, halfVec)), 18.0) * 0.42
                            + clamp(slopeDelta * 1.15, 0.0, 0.26);

        float3 col = mix(bg, ink, shadowBand);
        col = mix(col, float3(0.97, 0.98, 0.99), clamp(specHighlight, 0.0, 0.56));

        return finalizeLCD(col, uv, pos, u);
    }

    // 4. Hardware Point-Sprite Sand Renderer (Chladni Sand, Wind Dunes, & Sand Name)
    vertex SandVertexOut sandParticleVertex(
        uint vertexID [[vertex_id]],
        constant ScreenUniforms& u [[buffer(0)]],
        constant GPUGrain* grains [[buffer(1)]]
    ) {
        GPUGrain g = grains[vertexID];
        SandVertexOut out;
        out.position = float4(g.uv.x * 2.0 - 1.0, 1.0 - g.uv.y * 2.0, 0.0, 1.0);
        out.pointSize = max(1.5, g.sizePx * (u.pixelScale * 0.5));
        out.shade = g.shade;
        return out;
    }

    fragment half4 sandParticleFragment(
        SandVertexOut in [[stage_in]],
        float2 pointCoord [[point_coord]],
        constant ScreenUniforms& u [[buffer(0)]]
    ) {
        float d = length(pointCoord - 0.5);
        float alpha = (1.0 - smoothstep(0.28, 0.50, d)) * in.shade;
        if (alpha < 0.02) {
            discard_fragment();
        }
        return half4(half3(u.inkColor.rgb), half(alpha));
    }

    // 5. Instanced Oriented Magnetic Iron Filings (Anti-Aliased Metallic Micro-Needles)
    vertex FilingVertexOut ironFilingVertex(
        uint vertexID [[vertex_id]],
        uint instanceID [[instance_id]],
        constant ScreenUniforms& u [[buffer(0)]],
        constant GPUFiling* filings [[buffer(1)]]
    ) {
        const float2 corners[4] = {
            float2(-1.0, -1.0),
            float2( 1.0, -1.0),
            float2(-1.0,  1.0),
            float2( 1.0,  1.0)
        };
        GPUFiling f = filings[instanceID];
        float lenPt = max(3.0, floor(f.lengthAndShade) * 0.1);
        float shade = clamp(fract(f.lengthAndShade) / 0.99, 0.35, 1.0);
        float halfLen = lenPt * 0.5;
        float halfThick = 1.35; // padded quad half-height for smooth AA falloff

        float2 c = corners[vertexID];
        float2 localPt = float2(c.x * (halfLen + 1.0), c.y * halfThick);
        float ca = cos(f.angle);
        float sa = sin(f.angle);
        float2 rotPt = float2(localPt.x * ca - localPt.y * sa,
                              localPt.x * sa + localPt.y * ca);

        float2 centerPt = f.uv * u.size;
        float2 worldPt = centerPt + rotPt;
        float2 uv = worldPt / max(u.size, float2(1.0));

        FilingVertexOut out;
        out.position = float4(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, 0.0, 1.0);
        out.localPt = localPt;
        out.halfLen = halfLen;
        out.shade = shade;
        return out;
    }

    fragment half4 ironFilingFragment(
        FilingVertexOut in [[stage_in]],
        constant ScreenUniforms& u [[buffer(0)]]
    ) {
        // Tapered needle capsule SDF: crisp dark metallic sliver with fine pointed ends.
        float clampedX = clamp(in.localPt.x, -in.halfLen, in.halfLen);
        float endNorm = abs(in.localPt.x) / max(in.halfLen, 0.5);
        float needleRadius = mix(0.62, 0.24, smoothstep(0.35, 1.0, endNorm));
        float dist = length(float2(in.localPt.x - clampedX, in.localPt.y));
        float alpha = (1.0 - smoothstep(needleRadius - 0.22, needleRadius + 0.32, dist)) * in.shade;
        if (alpha < 0.02) {
            discard_fragment();
        }
        return half4(half3(u.inkColor.rgb), half(alpha));
    }
    """
}
