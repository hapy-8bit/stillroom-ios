import XCTest
import UIKit
import SwiftUI
@testable import Stillroom

final class OneTapePresentationTests: XCTestCase {
    @MainActor
    func testEveryNavigationGlyphPaintsVisiblePixels() throws {
        for kind in [OneTapeNavigationGlyph.Kind.player, .library, .insights] {
            let renderer = ImageRenderer(content: OneTapeNavigationGlyph(kind: kind, activation: 0)
                .frame(width: 36, height: 32).foregroundStyle(.white))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.cgImage)
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = try XCTUnwrap(CGContext(data: &pixels, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let painted = stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] > 32 }.count
            XCTAssertGreaterThan(painted, 32, "The navigation glyph must not be blank: \(kind)")
        }
    }

    func testOldTimeoutCannotDismissAReopenedMenu() {
        var model = OneTapePresentation()
        model.toggleMenu()
        let oldGeneration = model.menuGeneration
        model.toggleMenu()
        model.toggleMenu()
        model.expireMenu(generation: oldGeneration)
        XCTAssertTrue(model.menuVisible)
        model.expireMenu(generation: model.menuGeneration)
        XCTAssertFalse(model.menuVisible)
    }

    func testLibraryNavigationAndModalPreventPlayerIdleDismissal() {
        var model = OneTapePresentation()
        model.navigate(to: .library)
        model.expireMenu(generation: model.menuGeneration)
        XCTAssertTrue(model.menuVisible)
        model.navigate(to: .player)
        XCTAssertTrue(model.menuVisible)
        model.expireMenu(generation: model.menuGeneration)
        XCTAssertFalse(model.menuVisible)
        model.toggleMenu()
        model.present(.settings)
        model.expireMenu(generation: model.menuGeneration)
        XCTAssertTrue(model.menuVisible)
        model.panel = nil
        model.expireMenu(generation: model.menuGeneration)
        XCTAssertFalse(model.menuVisible)
    }

    func testBackgroundInvalidatesPendingIdleWork() {
        var model = OneTapePresentation()
        model.toggleMenu()
        let oldGeneration = model.menuGeneration
        model.suspend()
        model.toggleMenu()
        model.expireMenu(generation: oldGeneration)
        XCTAssertTrue(model.menuVisible)
    }
}
