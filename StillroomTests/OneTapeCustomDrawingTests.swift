import PencilKit
import UIKit
import XCTest
@testable import Stillroom

final class OneTapeCustomDrawingTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneTapeCustomDrawingTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testAppearanceCustomDrawingMutualExclusionAndCodableCompatibility() throws {
        // Legacy records written before customDrawingID must continue decoding seamlessly.
        let legacyJSON = """
        {"tapeStyle":"classic","printStyle":"brand","bodyStyle":"black","screenStyle":"lcd","doodleStyle":"none","bodyColor":"black","glassEnabled":true}
        """.data(using: .utf8)!
        var appearance = try JSONDecoder().decode(OneTapeAppearance.self, from: legacyJSON)
        XCTAssertNil(appearance.customDrawingID)
        XCTAssertTrue(appearance.isBrandPrintVisible)

        let id = UUID()
        appearance.selectCustomDrawing(id)
        XCTAssertEqual(appearance.customDrawingID, id)
        XCTAssertEqual(appearance.doodleStyle, .none)
        XCTAssertEqual(appearance.printStyle, .blank)
        XCTAssertFalse(appearance.isBrandPrintVisible)

        // Switching to a built-in illustration or brand print clears customDrawingID.
        appearance.selectIllustration(.dog)
        XCTAssertNil(appearance.customDrawingID)
        XCTAssertEqual(appearance.doodleStyle, .dog)

        appearance.selectCustomDrawing(id)
        appearance.setBrandPrintVisible(true)
        XCTAssertNil(appearance.customDrawingID)
        XCTAssertTrue(appearance.isBrandPrintVisible)

        appearance.selectCustomDrawing(id)
        appearance.clearCustomDrawingSelection()
        XCTAssertNil(appearance.customDrawingID)
        XCTAssertTrue(appearance.isBrandPrintVisible)
    }

    @MainActor
    func testDrawingStoreSaveReloadDeleteAndCorruptedIndexPreservation() throws {
        let store = OneTapeDrawingStore(directory: tempDirectory)
        let stroke = makeSampleStroke(from: CGPoint(x: 120, y: 70), to: CGPoint(x: 240, y: 70), color: .systemOrange)
        let drawing = PKDrawing(strokes: [stroke])

        let saved = try store.saveCanvasDrawing(pkDrawing: drawing, shell: .classic, inkMode: .originalColors)
        XCTAssertEqual(store.drawings.count, 1)
        XCTAssertEqual(store.displayTitle(for: saved), "画作 1")
        XCTAssertNotNil(store.thumbnail(for: saved))
        XCTAssertNotNil(store.portraitImage(for: saved))
        XCTAssertEqual(store.portraitImage(for: saved)?.cgImage?.width, 1129)
        XCTAssertEqual(store.portraitImage(for: saved)?.cgImage?.height, 1728)
        XCTAssertEqual(store.thumbnail(for: saved)?.cgImage?.width, 360)
        XCTAssertEqual(store.thumbnail(for: saved)?.cgImage?.height, 235)

        // Reload from fresh store instance.
        let reloaded = OneTapeDrawingStore(directory: tempDirectory)
        XCTAssertEqual(reloaded.drawings.count, 1)
        XCTAssertEqual(reloaded.drawings.first?.id, saved.id)
        XCTAssertEqual(reloaded.loadPKDrawing(for: saved)?.strokes.count, 1)

        reloaded.updateInkMode(id: saved.id, inkMode: .tapeInk)
        XCTAssertEqual(reloaded.drawings.first?.inkMode, .tapeInk)

        // Verify stroke orientation: top area of portrait (y=70) renders near left edge of landscape thumbnail.
        let thumbImage = try XCTUnwrap(reloaded.thumbnail(for: saved))
        XCTAssertTrue(hasInkPixels(in: thumbImage, normalizedRect: CGRect(x: 0.0, y: 0.0, width: 0.35, height: 1.0)))
        XCTAssertFalse(hasInkPixels(in: thumbImage, normalizedRect: CGRect(x: 0.65, y: 0.0, width: 0.35, height: 1.0)))

        reloaded.deleteDrawing(id: saved.id)
        XCTAssertTrue(reloaded.drawings.isEmpty)

        // Corrupted index handling: preserve malformed index.json on load and back it up before later writes.
        let corruptedDir = tempDirectory.appendingPathComponent("corrupted", isDirectory: true)
        try FileManager.default.createDirectory(at: corruptedDir, withIntermediateDirectories: true)
        let indexURL = corruptedDir.appendingPathComponent("index.json")
        let malformedData = Data("{ not valid json".utf8)
        try malformedData.write(to: indexURL)

        let corruptedStore = OneTapeDrawingStore(directory: corruptedDir)
        XCTAssertTrue(corruptedStore.hasCorruptedIndex)
        XCTAssertTrue(corruptedStore.drawings.isEmpty)
        XCTAssertEqual(try Data(contentsOf: indexURL), malformedData)

        _ = try corruptedStore.saveCanvasDrawing(pkDrawing: drawing, shell: .bronze, inkMode: .tapeInk)
        let backups = try FileManager.default.contentsOfDirectory(at: corruptedDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("index.corrupted.") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: backups[0]), malformedData)
    }

    func testPaperGenerationAndInkExtraction() throws {
        // Synthetic portrait mask (1129x1728): printable white perimeter, non-printable transparent center cutout.
        let maskW = 1129
        let maskH = 1728
        var maskRGBA = [UInt8](repeating: 255, count: maskW * maskH * 4)
        for y in 650..<1050 {
            for x in 350..<780 {
                let offset = (y * maskW + x) * 4
                maskRGBA[offset] = 0
                maskRGBA[offset + 1] = 0
                maskRGBA[offset + 2] = 0
                maskRGBA[offset + 3] = 0
            }
        }

        let blankPaper = try XCTUnwrap(
            OneTapeDrawingPaperService.generatePaperImage(fromPortraitMaskRGBA: maskRGBA, width: maskW, height: maskH)
        )
        XCTAssertEqual(blankPaper.cgImage?.width, 2604)
        XCTAssertEqual(blankPaper.cgImage?.height, 1836)

        // Blank paper must throw .noDrawing.
        XCTAssertThrowsError(try OneTapeDrawingPaperService.extractImportedDrawing(from: blankPaper)) { error in
            XCTAssertEqual(error as? OneTapeDrawingPaperError, .noDrawing)
        }

        // Draw dark black ink in printable area of generated paper and verify template recognition + blue stripping.
        let drawnDark = renderStroke(onto: blankPaper, color: .black, rect: CGRect(x: 420, y: 360, width: 280, height: 180))
        let importedDark = try OneTapeDrawingPaperService.extractImportedDrawing(from: drawnDark)
        XCTAssertTrue(importedDark.recognizedPaper)
        XCTAssertEqual(OneTapeDrawingPaperService.suggestedInkMode(for: importedDark.image), .tapeInk)
        XCTAssertEqual(importedDark.image.cgImage?.width, 1129)
        XCTAssertEqual(importedDark.image.cgImage?.height, 1728)
        XCTAssertTrue(hasInkPixels(in: importedDark.image, normalizedRect: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)))

        // Draw vivid saturated color ink and verify suggested ink mode switches to .originalColors.
        let drawnColor = renderStroke(onto: blankPaper, color: UIColor(red: 0.92, green: 0.30, blue: 0.06, alpha: 1),
                                      rect: CGRect(x: 420, y: 360, width: 320, height: 220))
        let importedColor = try OneTapeDrawingPaperService.extractImportedDrawing(from: drawnColor)
        XCTAssertEqual(OneTapeDrawingPaperService.suggestedInkMode(for: importedColor.image), .originalColors)
    }

    // MARK: - Helpers

    private func makeSampleStroke(from start: CGPoint, to end: CGPoint, color: UIColor) -> PKStroke {
        let ink = PKInk(.pen, color: color)
        let points = [
            PKStrokePoint(location: start, timeOffset: 0, size: CGSize(width: 14, height: 14),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2),
            PKStrokePoint(location: end, timeOffset: 0.1, size: CGSize(width: 14, height: 14),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        ]
        return PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    private func renderStroke(onto image: UIImage, color: UIColor, rect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: image.size.width, height: image.size.height)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
            color.setFill()
            ctx.cgContext.fillEllipse(in: rect)
        }
    }

    private func hasInkPixels(in image: UIImage, normalizedRect: CGRect) -> Bool {
        guard let cg = image.cgImage,
              let rgba = OneTapeDrawingPaperInkExtractor.extractRGBA(from: cg, targetSize: CGSize(width: cg.width, height: cg.height)) else {
            return false
        }
        let minX = max(0, Int(floor(normalizedRect.minX * CGFloat(cg.width))))
        let maxX = min(cg.width, Int(ceil(normalizedRect.maxX * CGFloat(cg.width))))
        let minY = max(0, Int(floor(normalizedRect.minY * CGFloat(cg.height))))
        let maxY = min(cg.height, Int(ceil(normalizedRect.maxY * CGFloat(cg.height))))
        for y in minY..<maxY {
            for x in minX..<maxX {
                if rgba[(y * cg.width + x) * 4 + 3] > 32 {
                    return true
                }
            }
        }
        return false
    }
}
