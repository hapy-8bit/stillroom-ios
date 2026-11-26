import Foundation

/// Runtime-compiled Metal Shading Language source for the unified iPhone body
/// rendering pipeline. Compiling via `MTLDevice.makeLibrary(source:options:)`
/// runs natively on both Apple Silicon iOS Simulator and physical iPhone GPUs
/// without requiring Xcode's optional offline MetalToolchain component.
enum OneTapeBodyShaderSource {
    static let msl: String = """
    #include <metal_stdlib>
    using namespace metal;

    struct BodyUniforms {
        float2 designSize;
        float2 uvOffset;
        float2 uvScale;
        float2 tilt;
        float phase;
        float energy;
        float grain;
        float reserved;
    };

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex VertexOut bodyFullscreenVertex(uint vertexID [[vertex_id]]) {
        const float2 pos[3] = {
            float2(-1.0, -1.0),
            float2( 3.0, -1.0),
            float2(-1.0,  3.0)
        };
        VertexOut out;
        out.position = float4(pos[vertexID], 0.0, 1.0);
        float2 ndc = pos[vertexID];
        out.uv = float2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
        return out;
    }

    static inline float hash21(float2 p) {
        p = fract(p * float2(123.34, 456.21));
        p += dot(p, p + 45.32);
        return fract(p.x * p.y);
    }

    static inline float valueNoise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        float2 u = f * f * (3.0 - 2.0 * f);
        float a = hash21(i);
        float b = hash21(i + float2(1.0, 0.0));
        float c = hash21(i + float2(0.0, 1.0));
        float d = hash21(i + float2(1.0, 1.0));
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    static inline float fbm2(float2 p) {
        float sum = 0.0;
        float amp = 0.55;
        for (int i = 0; i < 3; i++) {
            sum += amp * valueNoise(p);
            p = p * 2.03 + float2(13.7, 7.3);
            amp *= 0.48;
        }
        return sum;
    }

    static inline float stealthCamoHeight(float2 p) {
        float2 q = p * 0.0155;
        float2 warp = float2(
            fbm2(q + float2(1.4, 5.2)),
            fbm2(q + float2(8.7, 2.1))
        );
        float mainField = fbm2(q * 1.18 + (warp - 0.5) * 1.65);
        float smallDots = valueNoise(p * 0.036 + warp * 1.4);
        float combined = max(mainField, smallDots * 0.88);
        return smoothstep(0.555, 0.595, combined);
    }

    // 1. Classic Prototype: Satin Brushed Titanium-Graphite
    fragment half4 graphiteFragment(
        VertexOut in [[stage_in]],
        constant BodyUniforms& u [[buffer(0)]]
    ) {
        float2 uv = u.uvOffset + in.uv * u.uvScale;
        float2 pos = uv * u.designSize;

        float fineBrush = valueNoise(float2(pos.x * 0.045, pos.y * 2.65));
        float microBrush = valueNoise(float2(pos.x * 0.12 + 19.0, pos.y * 6.2));
        float bead = hash21(floor(pos * 1.5)) - 0.5;
        float brushed = (fineBrush - 0.5) * 0.042 + (microBrush - 0.5) * 0.024 + bead * 0.014;

        float2 lightCenter = float2(0.32 + u.tilt.x * 0.34, 0.16 + u.tilt.y * 0.24);
        float dist = length((uv - lightCenter) * float2(1.0, 1.55));
        float dome = exp(-dist * dist * 1.35) * 0.145;

        float bandPos = uv.x * 0.82 + uv.y * 0.26 - u.tilt.x * 0.28 - u.tilt.y * 0.14;
        float sheen = exp(-pow((bandPos - 0.52) * 3.1, 2.0)) * 0.095
                    + exp(-pow((bandPos - 0.22) * 5.2, 2.0)) * 0.042;

        float verticalFalloff = mix(0.055, -0.065, uv.y);

        float3 basePewter = float3(0.555, 0.568, 0.578);
        float3 rgb = clamp(basePewter + float3(dome + sheen + verticalFalloff + brushed), 0.0, 1.0);
        return half4(half3(rgb), 1.0h);
    }

    // 2. Foil Prototype: Seamless Diagonal Micro-Brushed Pearlescent Holo Foil
    fragment half4 holoFoilFragment(
        VertexOut in [[stage_in]],
        constant BodyUniforms& u [[buffer(0)]]
    ) {
        float2 uv = u.uvOffset + in.uv * u.uvScale;
        float2 pos = uv * u.designSize;

        // Continuous ~38-degree diagonal brushed aluminum coordinates (zero seam anywhere).
        float diagAcross = pos.x * 0.788 + pos.y * 0.616;
        float diagAlong  = -pos.x * 0.616 + pos.y * 0.788;

        // Fine silk-brushed anisotropic metallic streaks.
        float streakCoarse = valueNoise(float2(diagAcross * 0.42, diagAlong * 0.012)) - 0.5;
        float streakFine   = valueNoise(float2(diagAcross * 1.35 + 11.0, diagAlong * 0.022)) - 0.5;
        float streakMicro  = valueNoise(float2(diagAcross * 3.10 + 27.0, diagAlong * 0.045)) - 0.5;
        float brush = streakCoarse * 0.48 + streakFine * 0.65 + streakMicro * 0.35;

        // Smooth studio light direction driven by device tilt.
        float2 lightDir = normalize(float2(0.45 + u.tilt.x * 0.85, -0.52 + u.tilt.y * 0.78));
        float sweepCoord = uv.x * 0.62 + uv.y * 0.48 - u.tilt.x * 0.42 - u.tilt.y * 0.30;

        // Continuous wide-wavelength thin-film interference phase (pearlescent silver -> ice cyan -> violet -> champagne gold).
        float phase = uv.x * 0.48
                    + uv.y * 0.42
                    + brush * 0.045
                    + u.tilt.x * 0.38
                    + u.tilt.y * 0.28;

        // Refined pastel-metallic spectral palette (restrained saturation so metal reads authentic, not neon).
        float3 spectrum = 0.62 + 0.38 * cos(6.2831853 * (phase + float3(0.06, 0.28, 0.56)));
        // Pull back harsh greens toward silver-cyan pearl, matching Cassette's real foil calibration.
        float lum = dot(spectrum, float3(0.28, 0.58, 0.14));
        spectrum = mix(spectrum, float3(lum * 1.02, lum * 1.03, lum * 1.06), 0.30);

        // Luminous brushed silver aluminum carrier.
        float metallicShade = 0.78 + brush * 0.11 + dot(uv - 0.5, lightDir) * 0.08;
        float3 silverBase = float3(metallicShade * 0.98, metallicShade * 0.99, metallicShade * 1.02);

        // Soft anisotropic specular reflection gliding across the brushed grooves.
        float broadSheen = exp(-pow((sweepCoord - 0.52) * 2.5, 2.0)) * 0.20;
        float crispGlint = exp(-pow((sweepCoord - 0.55) * 8.2, 2.0)) * (0.14 + max(0.0, brush) * 0.22);

        // Iridescent sheen is strongest around the studio highlight band and softly metallic elsewhere.
        float iridMix = clamp(0.32 + broadSheen * 1.15 + abs(brush) * 0.14, 0.28, 0.56);
        float3 rgb = mix(silverBase, spectrum * (0.95 + brush * 0.12), iridMix);
        rgb += float3(broadSheen * 0.52 + crispGlint);
        rgb += (hash21(floor(pos * 1.4)) - 0.5) * 0.016;

        return half4(half3(clamp(rgb, 0.0, 1.0)), 1.0h);
    }

    // 3. Tactile Prototype: Carbon Matte + Raised Glossy Clear-Coat Stealth Camo
    fragment half4 stealthCamoFragment(
        VertexOut in [[stage_in]],
        constant BodyUniforms& u [[buffer(0)]]
    ) {
        float2 uv = u.uvOffset + in.uv * u.uvScale;
        float2 pos = uv * u.designSize;

        float twillA = sin((pos.x + pos.y) * 1.85);
        float twillB = sin((pos.x - pos.y) * 1.85);
        float carbonWeave = (twillA * twillB) * 0.0085 + (hash21(floor(pos)) - 0.5) * 0.009;

        float2 lightDir = normalize(float2(-0.52 + u.tilt.x * 0.92, -0.68 + u.tilt.y * 0.82));
        float hCenter = stealthCamoHeight(pos);
        float hLight = stealthCamoHeight(pos + lightDir * 1.35);
        float hShadow = stealthCamoHeight(pos - lightDir * 1.35);

        float edgeHighlight = clamp(hCenter - hLight, 0.0, 1.0);
        float edgeShadow = clamp(hCenter - hShadow, 0.0, 1.0);

        float matteGrad = (0.5 - uv.y) * 0.022 + (0.5 - uv.x) * 0.012;
        float3 matteBase = float3(0.112, 0.116, 0.122) + float3(matteGrad + carbonWeave);

        float specCoord = uv.x * 0.68 + uv.y * 0.54 - u.tilt.x * 0.45 - u.tilt.y * 0.36;
        float glossSweep = exp(-pow((specCoord - 0.46) * 2.9, 2.0)) * 0.088
                         + exp(-pow((specCoord - 0.72) * 5.4, 2.0)) * 0.042;
        float3 glossSurface = float3(0.148, 0.153, 0.162) + float3(glossSweep) + float3(carbonWeave * 0.25);

        float3 rgb = mix(matteBase, glossSurface, hCenter);
        rgb += float3(0.24, 0.25, 0.27) * edgeHighlight * (0.58 + glossSweep * 4.5);
        rgb -= float3(0.085, 0.088, 0.092) * edgeShadow;

        return half4(half3(clamp(rgb, 0.0, 1.0)), 1.0h);
    }

    // 4. Tech Prototype: Dark Satin PCB + SMD Components + Quiet Traveling Warm Amber Pulses
    fragment half4 circuitBodyFragment(
        VertexOut in [[stage_in]],
        constant BodyUniforms& u [[buffer(0)]],
        texture2d<half> smdTex [[texture(0)]],
        texture2d<half> traceTex [[texture(1)]]
    ) {
        constexpr sampler linearSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
        float2 uv = u.uvOffset + in.uv * u.uvScale;
        float2 pos = uv * u.designSize;

        // Matte black FR-4 solder mask micro-texture + quiet studio tilt sheen.
        float weave = (valueNoise(pos * 0.62) - 0.5) * 0.011
                    + (hash21(floor(pos)) - 0.5) * 0.007;
        float2 lightCenter = float2(0.42 + u.tilt.x * 0.36, 0.28 + u.tilt.y * 0.30);
        float d = length((uv - lightCenter) * float2(1.0, 1.45));
        float satinGlow = exp(-d * d * 2.2) * 0.032;
        float3 rgb = float3(0.060, 0.061, 0.066) + float3(satinGlow + weave);

        // Tone-on-tone matte dark SMD chips & passive components.
        half4 smd = smdTex.sample(linearSampler, uv);
        rgb = mix(rgb, float3(smd.rgb) + float3(satinGlow * 0.45), float(smd.a));

        // Restrained warm copper-amber perimeter traces with traveling audio-boosted pulses.
        half4 trace = traceTex.sample(linearSampler, uv);
        if (trace.a > 0.002h) {
            float2 centered = uv - float2(0.5, 0.48);
            float angle = atan2(centered.y, centered.x) / 6.2831853 + 0.5;

            float waveA = fract(angle - u.phase * 0.18);
            float pulseA = exp(-pow(min(waveA, 1.0 - waveA) * 8.5, 2.0));

            float waveB = fract(angle + 0.48 - u.phase * 0.13);
            float pulseB = exp(-pow(min(waveB, 1.0 - waveB) * 10.0, 2.0)) * 0.65;

            float tiltCatch = clamp(0.84 + dot(normalize(centered + 1e-4), u.tilt) * 0.24, 0.68, 1.14);
            // Quiet warm resting glow; brightens smoothly as pulses pass or music peaks.
            float boost = (0.38 + u.energy * 0.45) * tiltCatch + (pulseA + pulseB) * (0.48 + u.energy * 0.90);
            float hotspot = clamp((pulseA + pulseB * 0.6) * (0.30 + u.energy * 0.62), 0.0, 1.0);

            float3 glow = float3(trace.rgb) * boost + float3(0.36, 0.20, 0.05) * hotspot * float(trace.a);
            rgb += glow;
        }

        return half4(half3(clamp(rgb, 0.0, 1.0)), 1.0h);
    }

    // 5. Industrial / Tactile Directional Studio Relief over Baked Precision Shell Texture
    fragment half4 directionalReliefFragment(
        VertexOut in [[stage_in]],
        constant BodyUniforms& u [[buffer(0)]],
        texture2d<half> baseTex [[texture(0)]]
    ) {
        constexpr sampler linearSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
        float2 uv = u.uvOffset + in.uv * u.uvScale;
        float2 pos = uv * u.designSize;

        half4 baseSample = baseTex.sample(linearSampler, uv);
        float dirLight = (0.5 - uv.x) * (0.038 + u.tilt.x * 0.080)
                       + (0.45 - uv.y) * (0.050 + u.tilt.y * 0.070);
        float grain = (hash21(floor(pos * 1.25)) - 0.5) * u.grain;

        float3 rgb = clamp(float3(baseSample.rgb) + float3(dirLight + grain), 0.0, 1.0);
        return half4(half3(rgb), 1.0h);
    }

    // 6. Foil: Seamless Diagonal Bright Brushed Platinum-Silver Foil
    fragment half4 silverFoilFragment(
        VertexOut in [[stage_in]],
        constant BodyUniforms& u [[buffer(0)]]
    ) {
        float2 uv = u.uvOffset + in.uv * u.uvScale;
        float2 pos = uv * u.designSize;

        // Seamless ~38-degree diagonal brushed platinum-silver coordinates.
        float diagAcross = pos.x * 0.788 + pos.y * 0.616;
        float diagAlong  = -pos.x * 0.616 + pos.y * 0.788;

        // Crisp high-definition anisotropic metallic brush grooves & bright ridge crests.
        float streakCoarse = valueNoise(float2(diagAcross * 0.48, diagAlong * 0.010)) - 0.5;
        float streakFine   = valueNoise(float2(diagAcross * 1.55 + 7.3, diagAlong * 0.018)) - 0.5;
        float streakMicro  = valueNoise(float2(diagAcross * 3.60 + 19.1, diagAlong * 0.036)) - 0.5;
        float brush = streakCoarse * 0.52 + streakFine * 0.82 + streakMicro * 0.44;
        float ridgeSpark = pow(clamp(0.5 + brush * 1.45, 0.0, 1.0), 2.4) * 0.14;

        float2 lightDir = normalize(float2(0.45 + u.tilt.x * 0.85, -0.52 + u.tilt.y * 0.76));
        float sweepCoord = uv.x * 0.62 + uv.y * 0.44 - u.tilt.x * 0.42 - u.tilt.y * 0.30;

        // Luminous brushed platinum-silver carrier (bright metallic silver even at rest).
        float brightTone = 0.775 + brush * 0.175 + dot(uv - 0.5, lightDir) * 0.095 + ridgeSpark;
        float3 platinumBase = float3(brightTone * 0.975, brightTone * 0.990, brightTone * 1.015);

        // Two overlapping studio reflection lobes so silver gleams across both top & lower deck.
        float primarySheen   = exp(-pow((sweepCoord - 0.46) * 2.4, 2.0)) * 0.185;
        float secondarySheen = exp(-pow((sweepCoord - 0.84) * 3.6, 2.0)) * 0.115;
        float crispSpec      = exp(-pow((sweepCoord - 0.50) * 8.5, 2.0)) * (0.12 + max(0.0, brush) * 0.24);

        // Whisper-quiet cool ice / pale champagne thin-film sheen only on grazing highlights.
        float phase = uv.x * 0.56 + uv.y * 0.46 + brush * 0.07 + u.tilt.x * 0.34 + u.tilt.y * 0.24;
        float3 spectrum = 0.76 + 0.24 * cos(6.2831853 * (phase + float3(0.12, 0.34, 0.60)));
        float lum = dot(spectrum, float3(0.30, 0.55, 0.15));
        spectrum = mix(spectrum, float3(lum * 0.985, lum * 1.00, lum * 1.025), 0.58);

        float iridMix = clamp(0.09 + (primarySheen + secondarySheen) * 0.45 + max(0.0, brush) * 0.08, 0.08, 0.22);
        float3 rgb = mix(platinumBase, spectrum * (0.96 + brush * 0.12), iridMix);
        rgb += float3(primarySheen * 0.62 + secondarySheen * 0.52 + crispSpec);
        rgb += (hash21(floor(pos * 1.5)) - 0.5) * 0.014;

        return half4(half3(clamp(rgb, 0.0, 1.0)), 1.0h);
    }

    // 7. Foil: High-Density Micro-Mirror Disco Ball Mosaic (6.4pt beveled silver tiles)
    fragment half4 discoFragment(
        VertexOut in [[stage_in]],
        constant BodyUniforms& u [[buffer(0)]]
    ) {
        float2 uv = u.uvOffset + in.uv * u.uvScale;
        float2 pos = uv * u.designSize;

        const float pitch = 6.4;
        float2 grid = pos / pitch;
        float2 tileID = floor(grid);
        float2 f = fract(grid);

        // Crisp recessed dark charcoal grout seams between individual mirror squares.
        float groutX = smoothstep(0.055, 0.125, f.x) * smoothstep(0.055, 0.125, 1.0 - f.x);
        float groutY = smoothstep(0.055, 0.125, f.y) * smoothstep(0.055, 0.125, 1.0 - f.y);
        float tileMask = groutX * groutY;

        // Deterministic per-tile 3D mirror facet orientation & reflectivity class.
        float r0 = hash21(tileID + float2(1.7, 9.2));
        float r1 = hash21(tileID + float2(23.1, 4.8));
        float r2 = hash21(tileID + float2(51.3, 17.6));

        float2 tileNormal = float2(r0 - 0.5, r1 - 0.5) * 1.75;
        float2 envDir = float2(
            u.tilt.x * 1.35 + (uv.x - 0.5) * 0.85 + sin(u.phase * 0.65) * 0.18,
            u.tilt.y * 1.35 + (uv.y - 0.5) * 0.85 + cos(u.phase * 0.52) * 0.14
        );

        // Studio environment reflection brightness across neighboring tilted glass facets.
        float align = dot(normalize(tileNormal + float2(0.001, 0.001)), normalize(envDir + float2(0.02, -0.03)));
        float baseReflect = mix(0.14, 0.78, clamp(0.46 + align * 0.42 + (r2 - 0.5) * 0.34, 0.0, 1.0));

        // Subtle curved reflection sweep across each individual mirror face.
        float innerGrad = (1.0 - f.x) * 0.10 + (1.0 - f.y) * 0.12 - 0.10;
        float topLeftBevel = (smoothstep(0.24, 0.08, f.x) + smoothstep(0.24, 0.08, f.y)) * 0.14;
        float botRightBevel = (smoothstep(0.76, 0.92, f.x) + smoothstep(0.76, 0.92, f.y)) * 0.15;

        // Occasional dazzling spotlight specular catches, softly twinkling on phase & audio peaks.
        float twinkleWave = 0.5 + 0.5 * sin(u.phase * (1.2 + r1 * 1.9) + r0 * 25.0);
        float hotCatch = pow(clamp(align * 0.5 + 0.5, 0.0, 1.0), 6.0) * (0.45 + twinkleWave * 0.55);
        float sparkle = smoothstep(0.78, 0.98, r2 * 0.52 + hotCatch * 0.62) * (0.52 + u.energy * 0.48);

        float mirrorLum = clamp(baseReflect + innerGrad + topLeftBevel - botRightBevel + sparkle * 0.68, 0.08, 1.0);

        // Mostly silver-chrome monochrome with rare cold-cyan or warm-champagne stage glints.
        float3 tint = float3(0.96, 0.98, 1.01);
        if (r2 > 0.84) {
            tint = float3(0.84, 0.95, 1.06);
        } else if (r2 < 0.13) {
            tint = float3(1.04, 0.96, 0.86);
        }

        float3 tileColor = clamp(tint * mirrorLum + float3(sparkle * 0.36), 0.0, 1.0);
        float3 groutColor = float3(0.065, 0.068, 0.075);
        float3 rgb = mix(groutColor, tileColor, tileMask);

        return half4(half3(rgb), 1.0h);
    }

    // 8. Tactile: Cool Urban-Slate Multi-Scale Digital Pixel Camouflage
    fragment half4 digitalCamoFragment(
        VertexOut in [[stage_in]],
        constant BodyUniforms& u [[buffer(0)]]
    ) {
        float2 uv = u.uvOffset + in.uv * u.uvScale;
        float2 pos = uv * u.designSize;

        // Three integer-aligned digital pixel scales (14pt macro, 7pt mid, 3.5pt fine).
        float2 macroCell = floor(pos / 14.0);
        float2 midCell   = floor(pos / 7.0);
        float2 fineCell  = floor(pos / 3.5);

        float macroField = valueNoise(macroCell * 0.42 + float2(3.1, 7.4));
        float midField   = valueNoise(midCell * 0.55 + float2(14.2, 2.9));
        float fineNoise  = hash21(fineCell + float2(9.5, 4.1));
        float accentDark = valueNoise(midCell * 0.48 + float2(29.7, 18.3));

        // Combine quantized fields to produce crisp blocky stair-stepped digital islands.
        float v = macroField * 0.56 + midField * 0.30 + fineNoise * 0.14;
        float3 slate;
        if (v < 0.36 || (accentDark > 0.77 && fineNoise > 0.40)) {
            slate = float3(0.165, 0.188, 0.214); // Deep charcoal tactical slate
        } else if (v < 0.51) {
            slate = float3(0.315, 0.348, 0.382); // Gunmetal blue-slate
        } else if (v < 0.67) {
            slate = float3(0.505, 0.538, 0.572); // Medium cool urban slate
        } else {
            slate = float3(0.675, 0.705, 0.730); // Crisp light silver-slate
        }

        // Tactile matte polymer grain + subtle directional studio tilt light.
        float dirLight = (0.5 - uv.x) * (0.036 + u.tilt.x * 0.075)
                       + (0.45 - uv.y) * (0.044 + u.tilt.y * 0.065);
        float grain = (hash21(floor(pos * 1.4)) - 0.5) * 0.022;

        float3 rgb = clamp(slate + float3(dirLight + grain), 0.0, 1.0);
        return half4(half3(rgb), 1.0h);
    }

    // Helpers for Transparent Mechanical (See-Through) live GPU mechanisms & clear acrylic walls.
    static inline float sdRoundedBox(float2 p, float2 halfSize, float radius) {
        float2 q = abs(p) - halfSize + radius;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    }

    static inline float3 compositeSpurGear(
        float3 dst,
        float2 pos,
        float2 center,
        float pitchR,
        float teeth,
        float theta,
        float3 metalTint,
        float2 lightDir
    ) {
        float2 d = pos - center;
        float r = length(d);
        float outerR = pitchR + 1.45;
        if (r > outerR + 4.5) { return dst; }

        // Cast drop shadow onto recessed gearbox cavity floor.
        float2 ds = pos - (center + float2(1.1, 2.0));
        float rs = length(ds);
        float aS = atan2(ds.y, ds.x) - theta;
        float toothS = clamp(cos(aS * teeth) * 2.1, -1.0, 1.0);
        float edgeS = pitchR + toothS * 1.42;
        float shadowAlpha = (1.0 - smoothstep(edgeS - 1.2, edgeS + 2.4, rs)) * 0.62;
        dst *= (1.0 - shadowAlpha);

        // Flat-topped trapezoidal involute-style gear teeth silhouette.
        float angle = atan2(d.y, d.x) - theta;
        float toothWave = clamp(cos(angle * teeth) * 2.2, -1.0, 1.0);
        float gearEdge = pitchR + toothWave * 1.45;
        float mask = 1.0 - smoothstep(gearEdge - 0.55, gearEdge + 0.45, r);
        if (mask <= 0.001) { return dst; }

        // Rotating 3 circular lightening ports milled through the recessed gear web.
        float webOuter = pitchR - 2.6;
        float webInner = pitchR * 0.34;
        float holeMask = 0.0;
        if (pitchR >= 10.5) {
            float holeOrbit = pitchR * 0.56;
            float holeR = pitchR * 0.165;
            for (int i = 0; i < 3; i++) {
                float ha = theta + float(i) * 2.0943951;
                float2 hc = center + float2(cos(ha), sin(ha)) * holeOrbit;
                holeMask = max(holeMask, 1.0 - smoothstep(holeR - 0.45, holeR + 0.35, length(pos - hc)));
            }
        }
        float effectiveMask = mask * (1.0 - holeMask * 0.92);

        // Anisotropic radial-turned brushed metal shading + directional top-left studio light.
        float2 n = d / max(r, 0.001);
        float dirLit = dot(n, lightDir) * 0.22;
        float spunSheen = pow(abs(sin(angle * 2.0 + 0.6)), 1.6) * 0.14;
        float fineTurn = sin(r * 5.2) * 0.035;
        float rimBevel = smoothstep(gearEdge - 2.0, gearEdge - 0.5, r) * 0.14;

        // Recessed inner web ring vs raised outer tooth rim.
        float inWeb = smoothstep(webOuter + 0.5, webOuter - 0.6, r) * smoothstep(webInner - 0.5, webInner + 0.6, r);
        float webDarken = inWeb * 0.22;
        float rimLip = exp(-pow((r - webOuter) * 1.7, 2.0)) * 0.16;

        float lum = clamp(0.68 + dirLit + spunSheen + fineTurn + rimBevel - webDarken + rimLip, 0.18, 1.0);
        float3 col = metalTint * lum;

        // Turned stainless steel central axle boss & tiny dark bore.
        float axle = 1.0 - smoothstep(webInner - 0.4, webInner + 0.35, r);
        float3 steelBoss = float3(0.76, 0.78, 0.80) * (0.78 + dot(n, lightDir) * 0.25);
        col = mix(col, steelBoss, axle);
        float bore = 1.0 - smoothstep(1.35, 1.85, r);
        col = mix(col, float3(0.12, 0.13, 0.14), bore);

        return mix(dst, clamp(col, 0.0, 1.0), effectiveMask);
    }

    static inline float3 compositeFlywheel(
        float3 dst,
        float2 pos,
        float2 center,
        float radius,
        float theta,
        float2 lightDir
    ) {
        float2 d = pos - center;
        float r = length(d);
        if (r > radius + 5.0) { return dst; }

        // Soft cast shadow under full-scale stainless flywheel.
        float rs = length(pos - (center + float2(1.2, 2.2)));
        float shadow = (1.0 - smoothstep(radius - 1.5, radius + 3.2, rs)) * 0.68;
        dst *= (1.0 - shadow);

        float mask = 1.0 - smoothstep(radius - 0.5, radius + 0.45, r);
        if (mask <= 0.001) { return dst; }

        float2 n = d / max(r, 0.001);
        float angle = atan2(d.y, d.x) - theta;
        float spun = 0.5 + 0.5 * sin(angle * 2.0 + 0.4);
        float lathe = sin(r * 4.5) * 0.03;

        // Bright chamfered outer steel rim + satin recessed inner dish.
        float outerRim = smoothstep(radius - 3.6, radius - 2.6, r);
        float dishTone = 0.34 + spun * 0.22 + dot(n, lightDir) * 0.16 + lathe;
        float rimTone  = 0.66 + spun * 0.24 + dot(n, lightDir) * 0.22;
        float3 col = float3(0.84, 0.86, 0.89) * mix(dishTone, rimTone, outerRim);

        // Three rotating machined balance holes in the flywheel dish.
        for (int i = 0; i < 3; i++) {
            float ha = theta + float(i) * 2.0943951;
            float2 hc = center + float2(cos(ha), sin(ha)) * (radius * 0.56);
            float hd = length(pos - hc);
            float port = 1.0 - smoothstep(2.6, 3.2, hd);
            float portRim = exp(-pow((hd - 3.3) * 1.9, 2.0)) * 0.26;
            col += float3(portRim);
            col = mix(col, float3(0.06, 0.065, 0.072), port);
        }

        // Raised center collar & turned gold-brass capstan shaft.
        float collar = 1.0 - smoothstep(5.2, 5.9, r);
        col = mix(col, float3(0.56, 0.58, 0.60) * (0.76 + dot(n, lightDir) * 0.24), collar);
        float brassCap = 1.0 - smoothstep(2.9, 3.5, r);
        col = mix(col, float3(0.92, 0.78, 0.44) * (0.80 + dot(n, lightDir) * 0.24), brassCap);
        float centerPin = 1.0 - smoothstep(1.1, 1.5, r);
        col = mix(col, float3(0.16, 0.16, 0.17), centerPin);

        return mix(dst, clamp(col, 0.0, 1.0), mask);
    }

    static inline float3 compositePulley(
        float3 dst,
        float2 pos,
        float2 center,
        float radius,
        float theta,
        float2 lightDir
    ) {
        float2 d = pos - center;
        float r = length(d);
        if (r > radius + 3.5) { return dst; }

        float rs = length(pos - (center + float2(0.8, 1.6)));
        dst *= (1.0 - (1.0 - smoothstep(radius - 1.0, radius + 2.2, rs)) * 0.58);

        float mask = 1.0 - smoothstep(radius - 0.5, radius + 0.45, r);
        if (mask <= 0.001) { return dst; }

        float2 n = d / max(r, 0.001);
        float angle = atan2(d.y, d.x) - theta;
        float groove = exp(-pow((r - radius * 0.66) * 2.2, 2.0)) * 0.24;
        float spoke = 0.5 + 0.5 * cos(angle * 2.0);
        float lum = clamp(0.68 + dot(n, lightDir) * 0.24 + spoke * 0.14 - groove, 0.24, 1.0);
        float3 col = float3(0.94, 0.79, 0.42) * lum;

        // Two rotating micro alignment dimples so pulley spin is visibly readable.
        for (int i = 0; i < 2; i++) {
            float ha = theta + float(i) * 3.1415926;
            float2 hc = center + float2(cos(ha), sin(ha)) * (radius * 0.52);
            float dimple = 1.0 - smoothstep(0.95, 1.35, length(pos - hc));
            col = mix(col, float3(0.24, 0.18, 0.08), dimple);
        }
        float shaft = 1.0 - smoothstep(1.9, 2.4, r);
        col = mix(col, float3(0.28, 0.30, 0.32), shaft);
        return mix(dst, clamp(col, 0.0, 1.0), mask);
    }

    // 9. Tech: Transparent Mechanical Smoked-Polycarbonate Shell + Live Meshing Gears & Flywheel
    fragment half4 seeThroughFragment(
        VertexOut in [[stage_in]],
        constant BodyUniforms& u [[buffer(0)]],
        texture2d<half> baseTex [[texture(0)]]
    ) {
        constexpr sampler linearSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
        float2 uv = u.uvOffset + in.uv * u.uvScale;
        float2 pos = uv * u.designSize;
        float2 lightDir = normalize(float2(-0.55 + u.tilt.x * 0.75, -0.72 + u.tilt.y * 0.65));

        // 1. Sample static baked internal aluminum sub-chassis, batteries, PCBs, wires, tape head & motor.
        float3 col = float3(baseTex.sample(linearSampler, uv).rgb);

        // 2. Live 60fps mathematically meshed brass & stainless gear train in the central bridge (y: 622..651).
        // Constant angular velocity avoids phase jitter when audio energy fluctuates.
        float omega = u.phase * 6.8;
        float3 warmBrass   = float3(0.93, 0.80, 0.52);
        float3 brightSteel = float3(0.84, 0.87, 0.90);
        float3 goldBrass   = float3(0.95, 0.84, 0.58);
        float3 satinSteel  = float3(0.72, 0.76, 0.80);

        col = compositeSpurGear(col, pos, float2(114.00, 637.50), 14.0, 14.0,  omega / 14.0 + 0.00000, warmBrass,   lightDir);
        col = compositeSpurGear(col, pos, float2(138.87, 635.00), 11.0, 11.0, -omega / 11.0 + 2.62834, brightSteel, lightDir);
        col = compositeSpurGear(col, pos, float2(162.69, 638.00), 13.0, 13.0,  omega / 13.0 + 0.90733, goldBrass,   lightDir);
        col = compositeSpurGear(col, pos, float2(184.54, 635.50),  9.0,  9.0, -omega /  9.0 + 1.20357, satinSteel,  lightDir);

        // 3. Full-scale live rotating machined steel flywheel & fast-spinning brass motor pulley in bottom bay.
        col = compositeFlywheel(col, pos, float2(134.0, 838.5), 20.5, u.phase * 1.15, lightDir);
        col = compositePulley  (col, pos, float2(212.0, 835.0),  8.4, u.phase * 2.80, lightDir);

        // 4. Translucent smoked polycarbonate optical walls: real wall-thickness light-piping & cast cavity shadows!
        float dOuter  = -sdRoundedBox(pos - float2(196.5, 426.0), float2(196.5, 426.0), 59.0);
        float dPocket =  sdRoundedBox(pos - float2(196.505, 345.20), float2(176.955, 276.90), 19.12);
        float dLCD    =  sdRoundedBox(pos - float2(232.525, 733.935), float2(132.195, 82.815), 2.5);
        float dWall   = min(dOuter, min(dPocket, dLCD));

        // Elevated plastic housing walls cast realistic depth shadow onto gears/flywheel/PCB beneath.
        float wallShadow = smoothstep(10.0, 2.0, dWall) * 0.44;
        col *= (1.0 - wallShadow);

        // Milky-cool light-piping glowing inside the 3.6pt transparent polycarbonate wall thickness!
        float wallThickness = smoothstep(5.4, 3.0, dWall) * smoothstep(0.0, 1.6, dWall);
        float innerEdgeLine = exp(-pow((dWall - 3.6) * 1.45, 2.0));
        float3 acrylicEdgeTint = float3(0.76, 0.82, 0.87);
        col = mix(col, col * 0.75 + acrylicEdgeTint * 0.34, wallThickness * 0.62);
        col += acrylicEdgeTint * innerEdgeLine * 0.22;

        // 5. Smoked clear polycarbonate cover glaze & tilt-driven curved acrylic specular reflection sweep.
        float3 smoked = col * 0.96 + float3(0.020, 0.024, 0.028);
        float glossCoord = uv.x * 0.68 + uv.y * 0.44 - u.tilt.x * 0.48 - u.tilt.y * 0.34;
        float primaryGlass   = exp(-pow((glossCoord - 0.38) * 4.2, 2.0)) * 0.14;
        float crispGlassEdge = exp(-pow((glossCoord - 0.36) * 14.0, 2.0)) * 0.11;
        float secondaryGlass = exp(-pow((glossCoord - 0.76) * 6.0, 2.0)) * 0.075;

        float3 specColor = float3(0.90, 0.95, 1.00);
        float grain = (hash21(floor(pos * 1.5)) - 0.5) * 0.008;
        float3 rgb = clamp(smoked + specColor * (primaryGlass + crispGlassEdge + secondaryGlass) + float3(grain), 0.0, 1.0);
        return half4(half3(rgb), 1.0h);
    }
    """
}
