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
    var glassOpen = true
    var customDrawingID: UUID? = nil
    var customArtworkID: UUID? = nil

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

    var isBrandPrintVisible: Bool {
        printStyle == .brand && doodleStyle == .none && customDrawingID == nil && customArtworkID == nil
    }

    mutating func selectIllustration(_ style: DoodleStyle) {
        doodleStyle = style
        customDrawingID = nil
        customArtworkID = nil
        printStyle = style == .none ? .brand : .blank
    }

    mutating func selectCustomDrawing(_ id: UUID) {
        customDrawingID = id
        customArtworkID = nil
        doodleStyle = .none
        printStyle = .blank
    }

    mutating func clearCustomDrawingSelection() {
        guard customDrawingID != nil else { return }
        customDrawingID = nil
        if customArtworkID == nil && doodleStyle == .none && printStyle == .blank {
            printStyle = .brand
        }
    }

    mutating func selectCustomArtwork(_ id: UUID) {
        customArtworkID = id
        customDrawingID = nil
        doodleStyle = .none
        printStyle = .blank
    }

    mutating func clearCustomArtworkSelection() {
        guard customArtworkID != nil else { return }
        customArtworkID = nil
        if customDrawingID == nil && doodleStyle == .none && printStyle == .blank {
            printStyle = .brand
        }
    }

    mutating func setBrandPrintVisible(_ visible: Bool) {
        printStyle = visible ? .brand : .blank
        // Keep the existing replacement rule instead of inventing overlapping
        // lettering on illustrations or custom drawings. A single value write persists both fields.
        if visible {
            doodleStyle = .none
            customDrawingID = nil
            customArtworkID = nil
        } else {
            customDrawingID = nil
            customArtworkID = nil
        }
    }

    // Build37 used this key for a cosmetic switch. Keep its stored identity
    // while making the picker and physical sliding cover one authoritative value.
    private enum CodingKeys: String, CodingKey {
        case tapeStyle, printStyle, bodyStyle, screenStyle, doodleStyle, bodyColor, bodyMaterial, reelColor, customDrawingID, customArtworkID
        case glassOpen = "glassEnabled"
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
        static let retroGroup: [Self] = [.clear, .window, .memphis, .bronze]
        var isSculpted: Bool { Self.sculpted.contains(self) }
        var isBespoke: Bool { Self.bespoke.contains(self) }
        var usesLightInk: Bool { self == .graphite || self == .clear || self == .armature || self == .twinArc }
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
        case ink, rain, trails, waterfall
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
}
