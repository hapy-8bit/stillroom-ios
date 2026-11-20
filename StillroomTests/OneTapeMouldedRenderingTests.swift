import XCTest
import SwiftUI
@testable import Stillroom

final class OneTapeMouldedRenderingTests: XCTestCase {
    func testStrataKeepsItsShouldersInsideOneContinuousShell() {
        let outline = OneTapeMouldGeometry(style: .strata).outline
        for point in [CGPoint(x: 40, y: 40), CGPoint(x: 40, y: 100),
                      CGPoint(x: 540, y: 40), CGPoint(x: 540, y: 330)] {
            XCTAssertTrue(outline.contains(point), "Missing shell shoulder at \(point)")
        }
    }

    @MainActor
    func testEveryShellUsesTheSameVisibleBoundsAsClassic() throws {
        var reference: CGRect?
        for style in OneTapeAppearance.TapeStyle.allCases {
            let shell: AnyView
            if style.isSculpted {
                shell = AnyView(OneTapeMouldedCassette(style: style))
            } else if style == .bronze {
                shell = AnyView(OneTapeBronzeCassette())
            } else {
                shell = AnyView(Image("OneTapeClassicShell").resizable())
            }
            let renderer = ImageRenderer(content: shell.frame(width: 376.33, height: 576))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage?.cgImage)
            let rgba = try pixels(image)
            var minX = image.width, minY = image.height, maxX = 0, maxY = 0
            for y in 0..<image.height {
                for x in 0..<image.width where rgba[(y * image.width + x) * 4 + 3] >= 240 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
            XCTAssertLessThan(minX, maxX, "Missing shell: \(style.rawValue)")
            let bounds = CGRect(x: CGFloat(minX) / 2, y: CGFloat(minY) / 2,
                width: CGFloat(maxX - minX + 1) / 2, height: CGFloat(maxY - minY + 1) / 2)
            if let reference {
                for (edge, expected) in zip([bounds.minX, bounds.minY, bounds.maxX, bounds.maxY],
                    [reference.minX, reference.minY, reference.maxX, reference.maxY]) {
                    XCTAssertEqual(edge, expected, accuracy: 1.5,
                        "Shell position/size changed: \(style.rawValue), \(bounds), expected \(reference)")
                }
            } else {
                reference = bounds
            }
            let attachment = XCTAttachment(image: UIImage(cgImage: image))
            attachment.name = "aligned-shell-\(style.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testMeasuredDrivePortsStayInsideTheApprovedShell() {
        for style in OneTapeAppearance.TapeStyle.sculpted {
            let geometry = OneTapeMouldGeometry(style: style)
            XCTAssertEqual(geometry.axles.count, 2)
            XCTAssertLessThan(abs(geometry.axles[0].y - geometry.axles[1].y), 8,
                "Small photographic perspective is allowed, not a displaced mechanism")
            for point in geometry.axles {
                XCTAssertTrue(geometry.outline.contains(point), style.rawValue)
                XCTAssertTrue(geometry.windows.contains(point), style.rawValue)
            }
        }
    }

    func testAllSixStylesRoundTripWithoutChangingLegacyChoices() throws {
        XCTAssertEqual(OneTapeAppearance.TapeStyle.sculpted.count, 6)
        for style in OneTapeAppearance.TapeStyle.allCases {
            var appearance = OneTapeAppearance()
            appearance.tapeStyle = style
            appearance.glassOpen = false
            let decoded = try JSONDecoder().decode(OneTapeAppearance.self,
                from: JSONEncoder().encode(appearance))
            XCTAssertEqual(decoded, appearance)
        }
    }

    @MainActor
    func testAllStylesAnimateOnlyTheirMechanismsAndHaveResources() throws {
        for style in OneTapeAppearance.TapeStyle.sculpted {
            let geometry = OneTapeMouldGeometry(style: style)
            XCTAssertNotNil(UIImage(named: geometry.asset))
            XCTAssertNotNil(UIImage(named: geometry.asset + "Drive0"))
            XCTAssertNotNil(UIImage(named: geometry.asset + "Shaft0"))
            let still = try render(style, angle: .zero, progress: 0.35)
            let rotating = try render(style, angle: .degrees(31), progress: 0.35)
            let hub = geometry.axles[0]
            let radius = geometry.hubRadii[0] - 3
            let hubRect = portraitRect(CGRect(x: hub.x - radius, y: hub.y - radius,
                                              width: radius * 2, height: radius * 2))
            XCTAssertGreaterThan(try differences(still, rotating, rect: hubRect), 30, style.rawValue)
            XCTAssertEqual(try differences(still, rotating, rect: portraitRect(geometry.wordRect)), 0,
                           "The molded face must remain stationary: \(style.rawValue)")
            let wound = try render(style, angle: .zero, progress: 0.9)
            if geometry.hasTapeWindow {
                XCTAssertGreaterThan(try differences(still, wound, rect: CGRect(x: 0, y: 0, width: 376, height: 576)),
                                     0, "Molded packs dynamically reflect queue progress: \(style.rawValue)")
            } else {
                XCTAssertEqual(try differences(still, wound, rect: CGRect(x: 0, y: 0, width: 376, height: 576)),
                               0, "Molded face remains clean: \(style.rawValue)")
            }
            let attachment = XCTAttachment(image: UIImage(cgImage: still))
            attachment.name = "mould-\(style.rawValue)-native-layers"
            attachment.lifetime = .keepAlways
            add(attachment)
            var appearance = OneTapeAppearance()
            appearance.tapeStyle = style
            let printed = ImageRenderer(content: OneTapeCassetteArtwork(appearance: appearance))
            printed.scale = 2
            let preview = XCTAttachment(image: try XCTUnwrap(printed.uiImage))
            preview.name = "mould-\(style.rawValue)-complete-artwork"
            preview.lifetime = .keepAlways
            add(preview)
            let compact = ImageRenderer(content: OneTapeMouldedThumbnail(style: style)
                .frame(width: 98, height: 64))
            compact.scale = 3
            let thumbnail = XCTAttachment(image: try XCTUnwrap(compact.uiImage))
            thumbnail.name = "mould-\(style.rawValue)-compact-preview"
            thumbnail.lifetime = .keepAlways
            add(thumbnail)
            if style == .ribs {
                for degrees in [0.0, 31, 93] {
                    let image = try render(style, angle: .degrees(degrees), progress: 0.35, scale: 3)
                    let detail = XCTAttachment(image: UIImage(cgImage: image))
                    detail.name = "ribs-edge-3x-phase-\(Int(degrees))"
                    detail.lifetime = .keepAlways
                    add(detail)
                }
            }
        }
    }

    @MainActor
    func testPrintableLandingsAreOpaqueAndLowerMechanismsStayUnprinted() throws {
        let printMask = try renderSharedPrintMask()
        for style in OneTapeAppearance.TapeStyle.sculpted {
            let geometry = OneTapeMouldGeometry(style: style)
            let image = try render(style, angle: .zero, progress: 0.35)
            for rect in [geometry.wordRect, geometry.durationRect, geometry.countRect] {
                let sample = portraitRect(CGRect(x: rect.midX - 1, y: rect.midY - 1, width: 2, height: 2))
                let values = try pixels(try XCTUnwrap(image.cropping(to: sample.integral)))
                XCTAssertGreaterThanOrEqual(stride(from: 3, to: values.count, by: 4)
                    .map { values[$0] }.min() ?? 0, 250, style.rawValue)
            }
            for x in [158.0, 212.5, 365.5, 417.0] {
                XCTAssertLessThan(try maskAlpha(printMask, at: CGPoint(x: x, y: 342)), 16, style.rawValue)
            }
        }
    }

    @MainActor
    func testStationaryShaftIsVisibleThroughEachTurningDrive() throws {
        for style in OneTapeAppearance.TapeStyle.sculpted {
            let geometry = OneTapeMouldGeometry(style: style)
            let still = try render(style, angle: .zero, progress: 0)
            let moving = try render(style, angle: .degrees(31), progress: 1)
            for center in geometry.axles {
                let shaft = portraitRect(CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3))
                XCTAssertEqual(try differences(still, moving, rect: shaft), 0,
                    "The steel shaft must not rotate with the drive: \(style.rawValue)")
                let values = try pixels(try XCTUnwrap(still.cropping(to: shaft.integral)))
                XCTAssertGreaterThan(stride(from: 0, to: values.count, by: 4)
                    .map { Int(values[$0]) }.max() ?? 0, 60, style.rawValue)
            }
        }
    }

    @MainActor
    func testOnlyDriveCoresMoveWhileTapeAndFlangesStayFixed() throws {
        for style in OneTapeAppearance.TapeStyle.sculpted {
            let geometry = OneTapeMouldGeometry(style: style)
            let still = try render(style, angle: .zero, progress: 0.35)
            for exposure in [0.0, 24.0] {
                let moving = try render(style, angle: .degrees(31), progress: 0.35,
                                        exposure: exposure)
                XCTAssertEqual(try differencesOutsideHubs(still, moving, geometry: geometry), 0,
                    "Black tape, aperture edges and shell must stay fixed: \(style.rawValue)")
                for index in 0..<2 {
                    let axle = geometry.axles[index]
                    let radius = geometry.hubRadii[index] - 3
                    let core = CGRect(x: axle.x - radius, y: axle.y - radius,
                                      width: radius * 2, height: radius * 2)
                    XCTAssertGreaterThan(try differences(still, moving, rect: portraitRect(core)),
                        30, "Both drive cores must turn: \(style.rawValue), \(index)")
                }
            }
        }
    }

    @MainActor
    func testFastWindExposureChangesOnlyMovingPartsInAllSixShells() throws {
        for style in OneTapeAppearance.TapeStyle.sculpted {
            let geometry = OneTapeMouldGeometry(style: style)
            let sharp = try render(style, angle: .degrees(12), progress: 0.5)
            let fast = try render(style, angle: .degrees(12), progress: 0.5, exposure: 24)
            let hub = geometry.axles[0]
            let radius = geometry.hubRadii[0] - 3
            XCTAssertGreaterThan(try differences(sharp, fast, rect: portraitRect(
                CGRect(x: hub.x - radius, y: hub.y - radius, width: radius * 2, height: radius * 2))),
                30, style.rawValue)
            XCTAssertEqual(try differences(sharp, fast, rect: portraitRect(geometry.wordRect)), 0,
                "Fast-wind shutter must leave the molded shell sharp: \(style.rawValue)")
            let attachment = XCTAttachment(image: UIImage(cgImage: fast))
            attachment.name = "reel-fast-shutter-\(style.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testSharedDoodleMaskKeepsMechanismsAndTheReadoutLaneClear() throws {
        let image = try renderSharedPrintMask()
        XCTAssertGreaterThan(try maskAlpha(image, at: CGPoint(x: 100, y: 80)), 240)
        for style in OneTapeAppearance.TapeStyle.sculpted {
            let geometry = OneTapeMouldGeometry(style: style)
            for point in geometry.axles {
                XCTAssertLessThan(try maskAlpha(image, at: point), 16, style.rawValue)
            }
            for rect in [OneTapeMouldGeometry.illustrationDurationRect,
                         OneTapeMouldGeometry.illustrationCountRect] {
                XCTAssertLessThan(try maskAlpha(image, at: CGPoint(x: rect.midX, y: rect.midY)),
                    16, style.rawValue)
            }
        }
    }

    @MainActor
    func testTheSameIllustrationDoesNotChangeWhenSwitchingMoulds() throws {
        let supported = Set(OneTapeAppearance.TapeStyle.sculpted.flatMap {
            OneTapeDoodleCatalog.supportedStyles(for: $0)
        })
        for illustration in OneTapeAppearance.DoodleStyle.allCases
        where illustration != .none && supported.contains(illustration) {
            var appearance = OneTapeAppearance()
            appearance.selectIllustration(illustration)
            var reference: [UInt8]?
            for style in OneTapeAppearance.TapeStyle.sculpted {
                appearance.tapeStyle = style
                let renderer = ImageRenderer(content: OneTapeDoodleArtwork(appearance: appearance))
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.uiImage?.cgImage)
                let actual = try pixels(image)
                if let reference {
                    XCTAssertTrue(actual == reference, "Illustration changed: \(illustration.rawValue), \(style.rawValue)")
                } else {
                    XCTAssertTrue(stride(from: 3, to: actual.count, by: 4).contains { actual[$0] > 24 },
                        "Missing illustration: \(illustration.rawValue)")
                    reference = actual
                }
            }
        }
    }

    @MainActor
    func testSculptedPrintMatchesClassicBrandPositioning() throws {
        var classic = OneTapeAppearance()
        classic.tapeStyle = .classic
        classic.printStyle = .brand
        let reference = ImageRenderer(content: OneTapeBrandPrint(appearance: classic))
        reference.scale = 1
        let classicImage = try XCTUnwrap(reference.uiImage?.cgImage)
        for style in OneTapeAppearance.TapeStyle.sculpted {
            var appearance = OneTapeAppearance()
            appearance.tapeStyle = style
            appearance.printStyle = .brand
            let candidate = ImageRenderer(content: OneTapeBrandPrint(appearance: appearance))
            candidate.scale = 1
            let candidateImage = try XCTUnwrap(candidate.uiImage?.cgImage)
            XCTAssertEqual(try differences(classicImage, candidateImage, rect: CGRect(x: 0, y: 0, width: 376, height: 576)), 0, style.rawValue)
        }
    }

    @MainActor
    private func render(_ style: OneTapeAppearance.TapeStyle, angle: Angle, progress: Double,
                        exposure: Double = 0, scale: CGFloat = 1) throws -> CGImage {
        let renderer = ImageRenderer(content: OneTapeMouldedCassette(style: style,
            supplyAngle: angle, takeupAngle: angle, tapeProgress: progress, reelExposureDegrees: exposure))
        renderer.scale = scale
        return try XCTUnwrap(renderer.uiImage?.cgImage)
    }

    @MainActor
    private func renderSharedPrintMask() throws -> CGImage {
        let renderer = ImageRenderer(content: OneTapeMouldPrintMask())
        renderer.scale = 2
        return try XCTUnwrap(renderer.uiImage?.cgImage)
    }

    private func maskAlpha(_ image: CGImage, at point: CGPoint) throws -> UInt8 {
        let scale = CGFloat(image.height) / 576
        let sample = CGRect(x: floor((376.33 - point.y) * scale),
            y: floor(point.x * scale), width: 1, height: 1)
        return try pixels(XCTUnwrap(image.cropping(to: sample)))[3]
    }

    private func portraitRect(_ rect: CGRect) -> CGRect {
        CGRect(x: 376.33 - rect.maxY, y: rect.minX, width: rect.height, height: rect.width)
    }

    private func differencesOutsideHubs(_ first: CGImage, _ second: CGImage,
                                       geometry: OneTapeMouldGeometry) throws -> Int {
        let a = try pixels(first), b = try pixels(second)
        XCTAssertEqual(first.width, second.width)
        XCTAssertEqual(first.height, second.height)
        let centers = geometry.axles.map { CGPoint(x: 376.33 - $0.y, y: $0.x) }
        let radii = geometry.hubRadii
        let stretch = geometry.driveStretch
        var changed = 0
        for y in 0..<first.height {
            for x in 0..<first.width {
                // One logical point per pixel in these renders. The allowance
                // covers antialiasing at the pale core boundary, not the pack.
                let insideCore = centers.indices.contains { index in
                    let radius = radii[index]
                    let dx = (CGFloat(x) + 0.5 - centers[index].x)
                        / (radius * stretch.height + 1)
                    let dy = (CGFloat(y) + 0.5 - centers[index].y)
                        / (radius * stretch.width + 1)
                    return dx * dx + dy * dy <= 1
                }
                guard !insideCore else { continue }
                let offset = (y * first.width + x) * 4
                if (0..<4).contains(where: { abs(Int(a[offset + $0]) - Int(b[offset + $0])) > 3 }) {
                    changed += 1
                }
            }
        }
        return changed
    }

    private func differences(_ first: CGImage, _ second: CGImage, rect: CGRect) throws -> Int {
        let a = try pixels(try XCTUnwrap(first.cropping(to: rect.integral)))
        let b = try pixels(try XCTUnwrap(second.cropping(to: rect.integral)))
        XCTAssertEqual(a.count, b.count)
        return stride(from: 0, to: min(a.count, b.count), by: 4).filter { offset in
            (0..<4).contains { abs(Int(a[offset + $0]) - Int(b[offset + $0])) > 3 }
        }.count
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = result.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(drawn)
        return result
    }
}
