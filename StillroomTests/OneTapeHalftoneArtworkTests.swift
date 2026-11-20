import UIKit
import XCTest
@testable import Stillroom

final class OneTapeHalftoneArtworkTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneTapeHalftoneArtworkTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testAppearanceCustomArtworkMutualExclusionAndCodableCompatibility() throws {
        let legacyJSON = """
        {"tapeStyle":"classic","printStyle":"brand","bodyStyle":"black","screenStyle":"lcd","doodleStyle":"none","bodyColor":"black","glassEnabled":true}
        """.data(using: .utf8)!
        var appearance = try JSONDecoder().decode(OneTapeAppearance.self, from: legacyJSON)
        XCTAssertNil(appearance.customArtworkID)
        XCTAssertTrue(appearance.isBrandPrintVisible)

        let artID = UUID()
        appearance.selectCustomArtwork(artID)
        XCTAssertEqual(appearance.customArtworkID, artID)
        XCTAssertNil(appearance.customDrawingID)
        XCTAssertEqual(appearance.doodleStyle, .none)
        XCTAssertEqual(appearance.printStyle, .blank)
        XCTAssertFalse(appearance.isBrandPrintVisible)

        let drawingID = UUID()
        appearance.selectCustomDrawing(drawingID)
        XCTAssertNil(appearance.customArtworkID)
        XCTAssertEqual(appearance.customDrawingID, drawingID)

        appearance.selectCustomArtwork(artID)
        appearance.selectIllustration(.city)
        XCTAssertNil(appearance.customArtworkID)
        XCTAssertEqual(appearance.doodleStyle, .city)

        appearance.selectCustomArtwork(artID)
        appearance.setBrandPrintVisible(true)
        XCTAssertNil(appearance.customArtworkID)
        XCTAssertTrue(appearance.isBrandPrintVisible)

        appearance.selectCustomArtwork(artID)
        appearance.clearCustomArtworkSelection()
        XCTAssertNil(appearance.customArtworkID)
        XCTAssertTrue(appearance.isBrandPrintVisible)
    }

    func testHalftoneEngineModesInkSeparationWearAndLineInk() throws {
        // Build 240x360 test photo: dark left half, bright right half, plus colorful botanical accents.
        let photo = makeGradientPhoto(size: CGSize(width: 240, height: 360))
        let targetSize = CGSize(width: 188, height: 288)

        // 1. Dark tape + tapeInk cream halftone prints highlights on the bright right side.
        var monoCreamRecipe = OneTapeArtworkRecipe()
        monoCreamRecipe.mode = .halftone
        monoCreamRecipe.halftoneStyle = .mono
        monoCreamRecipe.primaryInk = .tapeInk
        monoCreamRecipe.dotSize = 0.35
        monoCreamRecipe.inkWear = 0.25
        monoCreamRecipe.strength = 0.70

        let creamPrint = try OneTapeHalftoneEngine.renderArtworkPrint(
            sourceImage: photo,
            subjectMaskImage: nil,
            recipe: monoCreamRecipe,
            shell: .graphite,
            targetSize: targetSize
        )
        XCTAssertGreaterThan(visiblePixelCount(in: creamPrint), 150)

        // 2. Classic light shell + cobalt mono prints shadow dots on the dark left half.
        var monoCobalt = monoCreamRecipe
        monoCobalt.primaryInk = .cobalt
        let cobaltPrint = try OneTapeHalftoneEngine.renderArtworkPrint(
            sourceImage: photo,
            subjectMaskImage: nil,
            recipe: monoCobalt,
            shell: .classic,
            targetSize: targetSize
        )
        XCTAssertGreaterThan(visiblePixelCount(in: cobaltPrint), 150)

        // 3. Overprint ruby + cobalt dual-angle screens + Botanical tri-screen.
        var overprintRecipe = monoCobalt
        overprintRecipe.halftoneStyle = .overprint
        overprintRecipe.primaryInk = .ruby
        overprintRecipe.secondaryInk = .cobalt
        let overprintImage = try OneTapeHalftoneEngine.renderArtworkPrint(
            sourceImage: photo,
            subjectMaskImage: nil,
            recipe: overprintRecipe,
            shell: .classic,
            targetSize: targetSize
        )
        XCTAssertGreaterThan(visiblePixelCount(in: overprintImage), 150)

        var botanicalRecipe = monoCobalt
        botanicalRecipe.halftoneStyle = .botanical
        botanicalRecipe.primaryInk = .slate
        let botanicalImage = try OneTapeHalftoneEngine.renderArtworkPrint(
            sourceImage: photo,
            subjectMaskImage: nil,
            recipe: botanicalRecipe,
            shell: .classic,
            targetSize: targetSize
        )
        XCTAssertGreaterThan(visiblePixelCount(in: botanicalImage), 150)

        // 4. Line-ink extraction removes light paper while keeping dark pen stroke, and rejects blank paper.
        let blankCard = makeSolidPaperImage(size: CGSize(width: 240, height: 360), color: UIColor(white: 0.94, alpha: 1))
        var inkRecipe = OneTapeArtworkRecipe()
        inkRecipe.mode = .lineInk
        inkRecipe.cleanup = 0.30
        inkRecipe.strength = 0.75
        XCTAssertThrowsError(try OneTapeHalftoneEngine.renderArtworkPrint(
            sourceImage: blankCard,
            subjectMaskImage: nil,
            recipe: inkRecipe,
            shell: .classic,
            targetSize: targetSize
        )) { error in
            XCTAssertEqual(error as? OneTapeArtworkError, .noClearInk)
        }

        let drawnCard = drawDarkStroke(onto: blankCard, rect: CGRect(x: 60, y: 120, width: 120, height: 120))
        let linePrint = try OneTapeHalftoneEngine.renderArtworkPrint(
            sourceImage: drawnCard,
            subjectMaskImage: nil,
            recipe: inkRecipe,
            shell: .classic,
            targetSize: targetSize
        )
        let lineCount = visiblePixelCount(in: linePrint)
        XCTAssertGreaterThan(lineCount, 200)
        XCTAssertLessThan(lineCount, Int(targetSize.width * targetSize.height) / 2)

        // 5. Verify localized mirror titles and +90 deg orientation into portrait cassette coordinates.
        XCTAssertEqual(OneTapeArtworkMode.halftone.title, "网点照片")
        XCTAssertEqual(OneTapeArtworkMode.lineInk.title, "涂鸦")
        XCTAssertEqual(OneTapeHalftoneStyle.mono.title, "复古")
        let topDarkCard = drawDarkStroke(
            onto: makeSolidPaperImage(size: CGSize(width: 300, height: 200), color: .white),
            rect: CGRect(x: 0, y: 0, width: 300, height: 70)
        )
        let composed = OneTapeHalftoneEngine.renderComposedSource(
            sourceImage: topDarkCard,
            subjectMaskImage: nil,
            recipe: OneTapeArtworkRecipe(),
            targetSize: targetSize
        )
        let composedLine = try OneTapeHalftoneEngine.renderArtworkPrint(
            sourceImage: topDarkCard,
            subjectMaskImage: nil,
            recipe: inkRecipe,
            shell: .classic,
            targetSize: targetSize
        )
        XCTAssertNotNil(composed.cgImage)
        XCTAssertGreaterThan(visiblePixelCount(in: composedLine, normalizedRect: CGRect(x: 0.55, y: 0.0, width: 0.45, height: 1.0)), 100)
        XCTAssertEqual(visiblePixelCount(in: composedLine, normalizedRect: CGRect(x: 0.0, y: 0.0, width: 0.45, height: 1.0)), 0)
    }

    @MainActor
    func testArtworkStoreSaveReloadReprintAndCorruptedIndexPreservation() throws {
        let store = OneTapeArtworkStore(directory: tempDirectory)
        let source = makeGradientPhoto(size: CGSize(width: 240, height: 360))
        let recipe = OneTapeArtworkRecipe()
        let printImg = try OneTapeHalftoneEngine.renderArtworkPrint(
            sourceImage: source,
            subjectMaskImage: nil,
            recipe: recipe,
            shell: .classic,
            targetSize: CGSize(width: 376, height: 576)
        )

        let saved = try store.saveArtwork(
            sourceImage: source,
            subjectMaskImage: nil,
            renderedPrint: printImg,
            recipe: recipe,
            shell: .classic
        )
        XCTAssertEqual(store.artworks.count, 1)
        XCTAssertEqual(store.displayTitle(for: saved), "照片 1")
        XCTAssertEqual(store.printImage(for: saved)?.cgImage?.width, 1129)
        XCTAssertEqual(store.printImage(for: saved)?.cgImage?.height, 1728)
        XCTAssertEqual(store.thumbnail(for: saved)?.cgImage?.width, 360)
        XCTAssertEqual(store.thumbnail(for: saved)?.cgImage?.height, 235)

        let reloaded = OneTapeArtworkStore(directory: tempDirectory)
        XCTAssertEqual(reloaded.artworks.count, 1)
        XCTAssertEqual(reloaded.artworks.first?.id, saved.id)

        // Reprinting for a new shell updates shellRawValue and preserves item id.
        let reprinted = try reloaded.reprintArtwork(id: saved.id, for: .graphite)
        XCTAssertEqual(reprinted.id, saved.id)
        XCTAssertEqual(reprinted.shellRawValue, OneTapeAppearance.TapeStyle.graphite.rawValue)

        reloaded.deleteArtwork(id: saved.id)
        XCTAssertTrue(reloaded.artworks.isEmpty)

        // Capacity enforcement.
        for _ in 0..<OneTapeArtworkStore.maxArtworkCount {
            _ = try reloaded.saveArtwork(
                sourceImage: source,
                subjectMaskImage: nil,
                renderedPrint: printImg,
                recipe: recipe,
                shell: .classic
            )
        }
        XCTAssertTrue(reloaded.isAtCapacity)
        XCTAssertThrowsError(try reloaded.saveArtwork(
            sourceImage: source,
            subjectMaskImage: nil,
            renderedPrint: printImg,
            recipe: recipe,
            shell: .classic
        )) { error in
            XCTAssertEqual(error as? OneTapeArtworkError, .tooManyPhotos(OneTapeArtworkStore.maxArtworkCount))
        }

        // Corrupted index preservation.
        let corruptDir = tempDirectory.appendingPathComponent("corrupt_art", isDirectory: true)
        try FileManager.default.createDirectory(at: corruptDir, withIntermediateDirectories: true)
        let badBytes = Data("{ corrupted artwork json".utf8)
        let corruptIndex = corruptDir.appendingPathComponent("index.json")
        try badBytes.write(to: corruptIndex)

        let corruptStore = OneTapeArtworkStore(directory: corruptDir)
        XCTAssertTrue(corruptStore.hasCorruptedIndex)
        XCTAssertTrue(corruptStore.artworks.isEmpty)
        XCTAssertEqual(try Data(contentsOf: corruptIndex), badBytes)
    }

    // MARK: - Helpers

    private func makeGradientPhoto(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: size.width * 0.5, height: size.height))
            UIColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1).setFill()
            cg.fill(CGRect(x: size.width * 0.5, y: 0, width: size.width * 0.5, height: size.height))
            UIColor(red: 0.20, green: 0.68, blue: 0.26, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.15, y: size.height * 0.25, width: 70, height: 70))
            UIColor(red: 0.85, green: 0.35, blue: 0.15, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.55, y: size.height * 0.55, width: 70, height: 70))
        }
    }

    private func makeSolidPaperImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func drawDarkStroke(onto image: UIImage, rect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { ctx in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            UIColor.black.setFill()
            ctx.cgContext.fill(rect)
        }
    }

    private func visiblePixelCount(
        in image: UIImage,
        normalizedRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    ) -> Int {
        guard let cg = image.cgImage,
              let rgba = OneTapeDrawingPaperInkExtractor.extractRGBA(from: cg, targetSize: CGSize(width: cg.width, height: cg.height)) else {
            return 0
        }
        let minX = max(0, Int(floor(normalizedRect.minX * CGFloat(cg.width))))
        let maxX = min(cg.width, Int(ceil(normalizedRect.maxX * CGFloat(cg.width))))
        let minY = max(0, Int(floor(normalizedRect.minY * CGFloat(cg.height))))
        let maxY = min(cg.height, Int(ceil(normalizedRect.maxY * CGFloat(cg.height))))
        var count = 0
        for y in minY..<maxY {
            for x in minX..<maxX where rgba[(y * cg.width + x) * 4 + 3] >= 25 {
                count += 1
            }
        }
        return count
    }
}
