import XCTest
import SwiftUI
@testable import Stillroom

final class OneTapeAppearanceTests: XCTestCase {
    func testBrandControlMatchesVisibleLegacyStateAndPreservesOtherAppearanceChoices() {
        var appearance = OneTapeAppearance()
        appearance.tapeStyle = .strata
        appearance.bodyColor = .green
        appearance.screenStyle = .trails
        appearance.glassOpen = false
        // Old readable records can contain this hidden combination. Reading
        // its effective state must not migrate or overwrite either field.
        appearance.doodleStyle = .city
        appearance.printStyle = .brand
        XCTAssertFalse(appearance.isBrandPrintVisible)
        XCTAssertEqual(appearance.printStyle, .brand)
        appearance.setBrandPrintVisible(false)
        XCTAssertEqual(appearance.doodleStyle, .city)
        XCTAssertEqual(appearance.printStyle, .blank)
        appearance.setBrandPrintVisible(true)
        XCTAssertTrue(appearance.isBrandPrintVisible)
        XCTAssertEqual(appearance.doodleStyle, .none)
        appearance.selectIllustration(.wild)
        XCTAssertFalse(appearance.isBrandPrintVisible)
        XCTAssertEqual(appearance.printStyle, .blank)
        appearance.selectIllustration(.none)
        XCTAssertTrue(appearance.isBrandPrintVisible)
        XCTAssertEqual(appearance.tapeStyle, .strata)
        XCTAssertEqual(appearance.bodyColor, .green)
        XCTAssertEqual(appearance.screenStyle, .trails)
        XCTAssertFalse(appearance.glassOpen)
    }

    @MainActor
    func testRedrawnPrintsKeepTransparentPaperInsteadOfFillingTheCassette() throws {
        let cases: [(OneTapeAppearance.DoodleStyle, Double)] = [
            (.dog, 0.15), (.caterpillar, 0.06), (.seesaw, 0.15),
            (.city, 0.55), (.wild, 0.70)
        ]
        for (style, maximumCoverage) in cases {
            var appearance = OneTapeAppearance()
            appearance.doodleStyle = style
            let renderer = ImageRenderer(content: OneTapeDoodleArtwork(appearance: appearance))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage?.cgImage, style.rawValue)
            let width = image.width
            let height = image.height
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            XCTAssertTrue(drawn)
            let inkPixels = stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] > 24 }.count
            let coverage = Double(inkPixels) / Double(width * height)
            // Broad art-specific limits catch an opaque full-cassette mask and
            // missing assets without imposing a pixel-perfect illustration test.
            XCTAssertGreaterThan(coverage, 0.0001, "Missing ink: \(style.rawValue)")
            XCTAssertLessThan(coverage, maximumCoverage, "Opaque paper: \(style.rawValue)")
        }
    }

    func testBuild37GlassRecordRemainsReadableAsThePhysicalCoverState() throws {
        let data = Data("""
        {"tapeStyle":"clear","printStyle":"brand","bodyStyle":"graphite",
         "screenStyle":"water","doodleStyle":"dog","bodyColor":"green","glassEnabled":false}
        """.utf8)
        let appearance = try JSONDecoder().decode(OneTapeAppearance.self, from: data)
        XCTAssertFalse(appearance.glassOpen)
        XCTAssertEqual(appearance.tapeStyle, .clear)
        XCTAssertEqual(appearance.screenStyle, .water)
        XCTAssertEqual(appearance.doodleStyle, .dog)
        let encoded = try JSONEncoder().encode(appearance)
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(record["glassEnabled"] as? Bool, false)
    }

    func testAppearanceRoundTripPreservesIndependentChoices() throws {
        let suite = "OneTapeAppearanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = OneTapeAppearancePreferences(defaults: defaults)
        XCTAssertEqual(try preferences.load(), OneTapeAppearance())
        var appearance = OneTapeAppearance()
        appearance.tapeStyle = .clear
        appearance.printStyle = .blank
        appearance.bodyStyle = .graphite
        appearance.bodyColor = .green
        appearance.screenStyle = .water
        appearance.doodleStyle = .dog
        appearance.glassOpen = false
        try preferences.save(appearance)
        XCTAssertEqual(try OneTapeAppearancePreferences(defaults: defaults).load(), appearance)
    }

    func testUnreadableAppearanceIsPreservedWhenAnotherStyleIsSelected() throws {
        let suite = "OneTapeAppearanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupted = Data("unreadable preference".utf8)
        defaults.set(corrupted, forKey: "oneTape.appearance.v1")
        let preferences = OneTapeAppearancePreferences(defaults: defaults)
        XCTAssertThrowsError(try preferences.load())
        XCTAssertThrowsError(try preferences.save(OneTapeAppearance()))
        XCTAssertEqual(defaults.data(forKey: "oneTape.appearance.v1"), corrupted)
    }

    func testCustomizationKeepsNavigationVisibleThroughStudioAndBackground() {
        var model = OneTapePresentation()
        model.toggleCustomization()
        XCTAssertTrue(model.customizationVisible)
        XCTAssertTrue(model.menuVisible)
        model.expireMenu(generation: model.menuGeneration)
        XCTAssertTrue(model.menuVisible)
        model.present(.studio)
        XCTAssertTrue(model.customizationVisible)
        model.panel = nil
        model.suspend()
        XCTAssertTrue(model.customizationVisible)
        XCTAssertTrue(model.menuVisible)
        model.closeCustomization()
        model.expireMenu(generation: model.menuGeneration)
        XCTAssertFalse(model.menuVisible)
        model.navigate(to: .library)
        XCTAssertFalse(model.customizationVisible)
    }

    func testTapeStyleGroupsAndDefaultOrdering() {
        XCTAssertEqual(OneTapeAppearance().tapeStyle, .classic)
        XCTAssertEqual(OneTapeAppearance.TapeStyle.classic.customizationTitle, "白色")
        XCTAssertEqual(OneTapeAppearance.TapeStyle.graphite.customizationTitle, "黑色")
        XCTAssertEqual(OneTapeAppearance.TapeStyle.classicGroup, [.classic, .graphite])
        XCTAssertEqual(OneTapeAppearance.TapeStyle.bespoke, [.armature, .fieldNotes, .silverOval, .twinArc])
        XCTAssertEqual(OneTapeAppearance.TapeStyle.sculpted, [.strata, .facet, .islands, .ribs, .stream, .eclipse])
        XCTAssertEqual(OneTapeAppearance.TapeStyle.retroGroup, [.clear, .window, .memphis, .bronze])
        let combined = OneTapeAppearance.TapeStyle.classicGroup
            + OneTapeAppearance.TapeStyle.bespoke
            + OneTapeAppearance.TapeStyle.sculpted
            + OneTapeAppearance.TapeStyle.retroGroup
        XCTAssertEqual(combined, OneTapeAppearance.TapeStyle.allCases)
        XCTAssertEqual(Set(combined).count, OneTapeAppearance.TapeStyle.allCases.count)
    }

    func testDoodleCatalogCoversAll81StylesAndOriginalShellOrdering() throws {
        XCTAssertEqual(OneTapeAppearance.DoodleStyle.allCases.count, 81)
        XCTAssertEqual(OneTapeDoodleCatalog.title(for: .circuitGarden), "电路板")
        XCTAssertEqual(OneTapeDoodleCatalog.title(for: .soundMaze), "迷宫")
        XCTAssertEqual(OneTapeDoodleCatalog.title(for: .orbitDoodles), "轨道")
        XCTAssertEqual(OneTapeDoodleCatalog.title(for: .littleMachines), "小机器")
        XCTAssertEqual(OneTapeDoodleCatalog.title(for: .wild), "野生")

        let classic = OneTapeDoodleCatalog.supportedStyles(for: .classic)
        XCTAssertEqual(classic.count, 24)
        XCTAssertEqual(Array(classic.prefix(8)), [.none, .dog, .caterpillar, .seesaw, .city, .wild, .climber, .smile])
        XCTAssertEqual(Array(classic.suffix(4)), [.littleMachines, .soundMaze, .circuitGarden, .orbitDoodles])
        XCTAssertEqual(OneTapeDoodleCatalog.supportedStyles(for: .clear), [.none, .ants, .peek, .snail, .pilgrims])
        XCTAssertEqual(OneTapeDoodleCatalog.supportedStyles(for: .window), [.none, .napper, .cleaner, .theatre])

        let decodedOvergrown = try JSONDecoder().decode(
            OneTapeAppearance.DoodleStyle.self,
            from: Data(#""overgrown""#.utf8)
        )
        XCTAssertEqual(decodedOvergrown, .wild)

        for style in OneTapeAppearance.DoodleStyle.allCases where style != .none {
            let thumb = OneTapeDoodleCatalog.thumbnailAsset(for: style)
            XCTAssertFalse(thumb.isEmpty, style.rawValue)
            XCTAssertNotNil(UIImage(named: thumb), "Missing thumbnail asset: \(thumb)")
            let ink = try XCTUnwrap(OneTapeDoodleCatalog.inkAsset(for: style))
            XCTAssertNotNil(UIImage(named: ink.name), "Missing ink asset: \(ink.name)")
        }
    }
}
