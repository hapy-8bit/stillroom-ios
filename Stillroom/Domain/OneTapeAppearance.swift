import Foundation

/// Appearance is presentation data only. Persistence and the single audio engine
/// remain outside this value, so changing a material never resets playback time.
struct OneTapeAppearance: Codable, Equatable, Sendable {
    var tapeStyle: TapeStyle = .classic
    var printStyle: PrintStyle = .brand
    var bodyStyle: BodyStyle = .black
    var screenStyle: ScreenStyle = .lcd
    var doodleStyle: DoodleStyle = .none
    var bodyColor: BodyColor = .black
    // nil is the legacy surface. Optional decoding keeps all existing
    // appearance records readable without migrating or overwriting them.
    var bodyMaterial: OneTapeBodyMaterial? = nil
    var reelColor: ReelColor? = nil
    var reelStyle: ReelStyle = .classic
    var reelFinish: ReelFinish = .silver
    var glassOpen = true
    var customDrawingID: UUID? = nil
    var customArtworkID: UUID? = nil
    // Optional / default-backed surface effects added in build 100.
    // Custom decoding below keeps all earlier preference records readable.
    var tapeFoilStyle: TapeFoilStyle? = nil
    var trackListEnabled = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTape = try container.decodeIfPresent(TapeStyle.self, forKey: .tapeStyle) ?? .classic
        // The six sculpted moulds and .window were retired from the tape catalog; map any
        // legacy preference cleanly to .classic without overwriting other fields.
        tapeStyle = (decodedTape.isSculpted || decodedTape == .window) ? .classic : decodedTape
        printStyle = try container.decodeIfPresent(PrintStyle.self, forKey: .printStyle) ?? .brand
        bodyStyle = try container.decodeIfPresent(BodyStyle.self, forKey: .bodyStyle) ?? .black
        screenStyle = try container.decodeIfPresent(ScreenStyle.self, forKey: .screenStyle) ?? .lcd
        doodleStyle = try container.decodeIfPresent(DoodleStyle.self, forKey: .doodleStyle) ?? .none
        bodyColor = try container.decodeIfPresent(BodyColor.self, forKey: .bodyColor) ?? .black
        let decodedMaterial = try container.decodeIfPresent(OneTapeBodyMaterial.self, forKey: .bodyMaterial)
        // Legacy non-Cassette glass/metal placeholders were retired; map cleanly
        // back to the classic shell without discarding any other saved choices.
        bodyMaterial = decodedMaterial?.isRetiredLegacy == true ? nil : decodedMaterial
        reelColor = try container.decodeIfPresent(ReelColor.self, forKey: .reelColor)
        reelStyle = try container.decodeIfPresent(ReelStyle.self, forKey: .reelStyle) ?? .classic
        reelFinish = try container.decodeIfPresent(ReelFinish.self, forKey: .reelFinish) ?? .silver
        glassOpen = try container.decodeIfPresent(Bool.self, forKey: .glassOpen) ?? true
        customDrawingID = try container.decodeIfPresent(UUID.self, forKey: .customDrawingID)
        customArtworkID = try container.decodeIfPresent(UUID.self, forKey: .customArtworkID)
        tapeFoilStyle = try container.decodeIfPresent(TapeFoilStyle.self, forKey: .tapeFoilStyle)
        trackListEnabled = try container.decodeIfPresent(Bool.self, forKey: .trackListEnabled) ?? false
        if doodleStyle != .none && !OneTapeDoodleCatalog.supports(doodleStyle, on: tapeStyle) {
            doodleStyle = .none
            if customDrawingID == nil && customArtworkID == nil && !trackListEnabled && printStyle == .blank {
                printStyle = .brand
            }
        }
    }

    mutating func selectTapeStyle(_ style: TapeStyle) {
        tapeStyle = style
        // Match Cassette 1.0.5 `TapeDoodle.fits(skin:)`: a built-in illustration
        // drawn for another aperture cutout does not carry over clipped onto a new shell.
        if doodleStyle != .none && !OneTapeDoodleCatalog.supports(doodleStyle, on: style) {
            doodleStyle = .none
            if customDrawingID == nil && customArtworkID == nil && !trackListEnabled && printStyle == .blank {
                printStyle = .brand
            }
        }
    }

    mutating func selectBodyStyle(_ style: BodyStyle) {
        bodyStyle = style
        bodyMaterial = nil
        // A newly chosen material must not remain hidden beneath a color
        // override from the previously selected material.
        bodyColor = .black
    }

    mutating func selectBodyMaterial(_ material: OneTapeBodyMaterial) {
        bodyMaterial = material
        bodyColor = .black
    }

    mutating func selectBodyColor(_ color: BodyColor) {
        // Match Cassette 1.0.5 `PhoneBodyPaint`: paint swatches coat the classic
        // chassis rather than muddying signature foil, circuit, or camo finishes.
        bodyMaterial = nil
        bodyStyle = .black
        bodyColor = color
    }

    var isBrandPrintVisible: Bool {
        printStyle == .brand
            && doodleStyle == .none
            && customDrawingID == nil
            && customArtworkID == nil
            && !trackListEnabled
    }

    var needsMotionTilt: Bool {
        let graphiteMetal = bodyMaterial == nil && bodyStyle == .graphite && bodyColor == .black
        return tapeFoilStyle != nil || graphiteMetal || (bodyMaterial?.usesTilt ?? false)
    }

    mutating func selectIllustration(_ style: DoodleStyle) {
        doodleStyle = style
        customDrawingID = nil
        customArtworkID = nil
        if style != .none {
            trackListEnabled = false
        }
        printStyle = style == .none && !trackListEnabled ? .brand : .blank
    }

    mutating func selectCustomDrawing(_ id: UUID) {
        customDrawingID = id
        customArtworkID = nil
        doodleStyle = .none
        trackListEnabled = false
        printStyle = .blank
    }

    mutating func clearCustomDrawingSelection() {
        guard customDrawingID != nil else { return }
        customDrawingID = nil
        if customArtworkID == nil && doodleStyle == .none && !trackListEnabled && printStyle == .blank {
            printStyle = .brand
        }
    }

    mutating func selectCustomArtwork(_ id: UUID) {
        customArtworkID = id
        customDrawingID = nil
        doodleStyle = .none
        trackListEnabled = false
        printStyle = .blank
    }

    mutating func clearCustomArtworkSelection() {
        guard customArtworkID != nil else { return }
        customArtworkID = nil
        if customDrawingID == nil && doodleStyle == .none && !trackListEnabled && printStyle == .blank {
            printStyle = .brand
        }
    }

    mutating func setBrandPrintVisible(_ visible: Bool) {
        printStyle = visible ? .brand : .blank
        // Keep the existing replacement rule instead of inventing overlapping
        // lettering on illustrations, track lists or custom drawings.
        if visible {
            doodleStyle = .none
            customDrawingID = nil
            customArtworkID = nil
            trackListEnabled = false
        } else {
            customDrawingID = nil
            customArtworkID = nil
        }
    }

    mutating func setTrackListEnabled(_ enabled: Bool) {
        trackListEnabled = enabled
        if enabled {
            doodleStyle = .none
            customDrawingID = nil
            customArtworkID = nil
            printStyle = .blank
        } else if doodleStyle == .none && customDrawingID == nil && customArtworkID == nil && printStyle == .blank {
            printStyle = .brand
        }
    }

    // Build37 used this key for a cosmetic switch. Keep its stored identity
    // while making the picker and physical sliding cover one authoritative value.
    private enum CodingKeys: String, CodingKey {
        case tapeStyle, printStyle, bodyStyle, screenStyle, doodleStyle, bodyColor, bodyMaterial, reelColor, reelStyle, reelFinish, customDrawingID, customArtworkID
        case tapeFoilStyle, trackListEnabled
        case glassOpen = "glassEnabled"
    }

    enum TapeFoilStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case holo, silver
        var id: String { rawValue }
    }

    enum TapeStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case classic, graphite
        case armature, fieldNotes, silverOval, twinArc
        case strata, facet, islands, ribs, stream, eclipse
        case clear, window, memphis, bronze
        var id: String { rawValue }

        static let classicGroup: [Self] = [.classic, .graphite]
        static let bespoke: [Self] = [.armature, .fieldNotes, .silverOval, .twinArc]
        static let sculpted: [Self] = [.strata, .facet, .islands, .ribs, .stream, .eclipse]
        static let retroGroup: [Self] = [.clear, .memphis, .bronze]
        var isSculpted: Bool { Self.sculpted.contains(self) }
        var isBespoke: Bool { Self.bespoke.contains(self) }
        var usesLightInk: Bool { self == .graphite || self == .clear || self == .armature || self == .twinArc }
        var showsExposedMetalReels: Bool { self == .clear || self == .window }
    }

    enum PrintStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case brand, blank
        var id: String { rawValue }
    }

    enum BodyStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case black, graphite, adaptive, cover
        var id: String { rawValue }
    }

    enum ScreenStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case lcd, fluid, oscilloscope, sand, dunes, meters, water, iron, name, fox
        case ink, smoke, growth, harmonograph, cover, waterfall
        case rain, trails
        var id: String { rawValue }
    }

    /// Stored illustration identities stay separate from lettering preferences.
    /// The current selection rules show an illustration in place of branding.
    enum DoodleStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case none
        case climber, smile, bicycle, cat, fishing, tightrope, swing, sleeper
        case creatures, people, shapes, plants, daydream, faces, littleMachines, soundMaze, circuitGarden, orbitDoodles
        case dog, ants, slide, megaphone, skier, owl, bus, lifter, runners
        case aquarium, sunglasses, headphones, submarine, moon, tv, cone, spotlight
        case caterpillar, seesaw, peek, snail, birds, abseil, sledge, surfer
        case astronaut, panda, boat, sofa, frog, tandem, hammock, skipping
        case hotdog, pool, cinema, table, binoculars, robot, heart, umbrella
        case blimp, dachshund, napper, cleaner, mountain, lighthouse, pilgrims, frame
        case chalet, observatory, train, diver, circus, stadium, picturehouse, aviator
        case city, wild, hills, zeppelin, theatre

        var id: String { rawValue }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if raw == "overgrown" {
                self = .wild
                return
            }
            guard let style = Self(rawValue: raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown DoodleStyle rawValue: \(raw)"
                )
            }
            self = style
        }
    }

    enum BodyColor: String, Codable, CaseIterable, Identifiable, Sendable {
        case black, navy, green, slate, dove, cognac, white, garden
        var id: String { rawValue }
    }

    enum ReelColor: String, Codable, CaseIterable, Identifiable, Sendable {
        case white, black, orange, crimson, blue
        var id: String { rawValue }
    }

    /// Exposed metallic reel flange cutout geometries matching Cassette 1.0.5 (`ReelStyle`).
    enum ReelStyle: String, Codable, CaseIterable, Identifiable, Sendable {
        case classic, rounded, solid
        var id: String { rawValue }
    }

    /// Anodized aluminum flange finishes matching Cassette 1.0.5 (`ReelColour`).
    enum ReelFinish: String, Codable, CaseIterable, Identifiable, Sendable {
        case silver, ruby, gold, cobalt, graphite, orange, emerald
        var id: String { rawValue }
    }
}
