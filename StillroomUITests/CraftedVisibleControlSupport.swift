import XCTest

extension XCTestCase {
    /// SwiftUI may report an offscreen descendant as hittable behind a safe-area inset. Require
    /// a visible 44-point hit neighborhood, excluding the real toolbar/keyboard/sticky frames.
    @MainActor func revealCraftedControl(_ element: XCUIElement, app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        if element.exists, [.textField, .textView, .secureTextField].contains(element.elementType) {
            // Multiline fields can exceed the viewport. Native tap scrolls the insertion point
            // into view, and focus removes the production footer; a centered 44pt box cannot fit.
            return
        }
        for _ in 0..<10 {
            let area = craftedVisibleControlArea(app)
            if element.exists {
                let frame = element.frame
                if validCraftedFrame(frame) {
                    let hit = CGRect(x: frame.midX - 22, y: frame.midY - 22, width: 44, height: 44)
                    if area.contains(hit), element.isHittable { return }
                    scrollCraftedContent(app, upward: hit.maxY > area.maxY || hit.midY >= area.midY)
                    continue
                }
            }
            scrollCraftedContent(app, upward: true)
        }
        XCTFail("Control is not visibly clear of toolbar and sticky actions: " + element.identifier,
                file: file, line: line)
    }

    @MainActor func craftedVisibleControlArea(_ app: XCUIApplication) -> CGRect {
        let window = app.frame
        let crop = app.buttons["craft.photo.crop.cancel"]
        let memory = app.buttons["memory.close"]
        let cropIsFront = crop.exists && crop.isHittable
        let memoryIsFront = !cropIsFront && memory.exists && memory.isHittable
        let overlayID = cropIsFront ? "craft.photo.crop" : memoryIsFront ? "memory.page" : nil
        let overlay = overlayID.map { app.otherElements[$0] }
        let overlayScrolls = overlay?.scrollViews.allElementsBoundByIndex ?? []
        // Modal sheets can leave their covered ancestors in the accessibility tree. Restrict
        // geometry to the active sheet; the last scroll view is its fallback on this native stack.
        let scrolls = overlayID == nil ? app.scrollViews.allElementsBoundByIndex :
            overlayScrolls.isEmpty ? Array(app.scrollViews.allElementsBoundByIndex.suffix(1)) : overlayScrolls
        let scrollFrames = scrolls.map(\.frame)
            .filter(validCraftedFrame).map { $0.intersection(window) }.filter { !$0.isNull }
        var area = scrollFrames.max { $0.width * $0.height < $1.width * $1.height } ?? window
        var top = max(window.minY, area.minY)
        var bottom = min(window.maxY, area.maxY)
        let bars = overlayID == nil ? app.navigationBars.allElementsBoundByIndex :
            Array(app.navigationBars.allElementsBoundByIndex.suffix(1))
        for bar in bars where validCraftedFrame(bar.frame) {
            top = max(top, bar.frame.maxY)
        }
        for id in overlayID == nil ? ["craft.composer.close", "craft.composer.step.2", "craft.cabinet.close", "sleeve.close"] : [] {
            let control = app.buttons[id]
            if control.exists, validCraftedFrame(control.frame), control.frame.intersects(window) {
                top = max(top, control.frame.maxY)
            }
        }
        for id in overlayID == nil ? ["sleeve.play", "craft.composer.saveDraft", "craft.composer.saveReady", "craft.composer.play"] : [] {
            let control = app.buttons[id]
            if control.exists, validCraftedFrame(control.frame), control.frame.intersects(window) {
                // The inset's paper/material and explanatory line extend above its first button.
                bottom = min(bottom, control.frame.minY - 24)
            }
        }
        if let keyboard = app.keyboards.allElementsBoundByIndex.first, validCraftedFrame(keyboard.frame) {
            bottom = min(bottom, keyboard.frame.minY)
        }
        area = CGRect(x: max(window.minX, area.minX) + 4, y: top + 8,
                      width: max(0, min(window.maxX, area.maxX) - max(window.minX, area.minX) - 8),
                      height: max(0, bottom - top - 16))
        return area
    }

    @MainActor func scrollCraftedContent(_ app: XCUIApplication, upward: Bool) {
        let area = craftedVisibleControlArea(app)
        guard area.width > 12, area.height > 60 else {
            XCTFail("The scrollable form has no visible area clear of its fixed controls.")
            return
        }
        // The trailing gutter is outside the photo crop's pan surface. Both endpoints remain
        // inside the actual scroll viewport, so a swipe cannot start on a sticky action.
        let x = area.maxX - 4
        let upper = area.minY + area.height * 0.2
        let lower = area.minY + area.height * 0.8
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: x - app.frame.minX, dy: (upward ? lower : upper) - app.frame.minY))
        let end = origin.withOffset(CGVector(dx: x - app.frame.minX, dy: (upward ? upper : lower) - app.frame.minY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func validCraftedFrame(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite && frame.origin.x.isFinite && frame.origin.y.isFinite &&
            frame.width.isFinite && frame.height.isFinite && frame.width > 0 && frame.height > 0
    }
}
