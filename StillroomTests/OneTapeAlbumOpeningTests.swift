import XCTest
import CoreGraphics
import SwiftUI
@testable import Stillroom

final class OneTapeAlbumOpeningTests: XCTestCase {
    private let stages: [OneTapeAlbumOpeningStage] = [.folded, .standing, .docked, .revealing, .revealed]

    func testShelfTapeStandsBelowCenterThenDocksAboveTheList() {
        let viewport = CGSize(width: 393, height: 759)
        let origin = CGRect(x: 32, y: 395.5, width: 329, height: 89.5)
        let folded = pose(.folded, viewport: viewport, origin: origin, pitch: -36)
        let standing = pose(.standing, viewport: viewport, origin: origin)
        let docked = pose(.docked, viewport: viewport, origin: origin)
        let revealed = pose(.revealed, viewport: viewport, origin: origin)

        XCTAssertEqual(folded.frame.midX, origin.midX, accuracy: 0.001)
        XCTAssertEqual(folded.frame.minY, origin.midY - folded.frame.height * 0.25, accuracy: 0.001)
        XCTAssertLessThan(folded.angle, -25)
        XCTAssertEqual(standing.angle, 0)
        XCTAssertGreaterThan(standing.frame.midY, viewport.height / 2)
        XCTAssertLessThan(standing.frame.midY, viewport.height * 0.7)
        XCTAssertGreaterThan(standing.frame.midY, docked.frame.midY + 150)
        XCTAssertGreaterThan(standing.frame.width, docked.frame.width)

        // The 53-point safe-area anchor becomes y112 in the observed window
        // with a 59-point top inset. Resource pixels are not layout units.
        XCTAssertEqual(docked.frame.midX, viewport.width / 2, accuracy: 0.001)
        XCTAssertEqual(docked.frame.minY, 53, accuracy: 0.001)
        XCTAssertEqual(docked.frame.width, 329, accuracy: 0.001)
        XCTAssertEqual(docked.frame.height, 211.7, accuracy: 0.001)
        XCTAssertEqual(docked.frame.width / docked.frame.height, 329 / 211.7, accuracy: 0.000_001)
        XCTAssertEqual(revealed.frame, docked.frame,
                       "Revealing controls must not jump the already docked cover.")
        XCTAssertEqual(revealed.angle, 0)
    }

    func testAllStagesHaveFiniteNonnegativeSizeAcrossWindowWidths() {
        let viewports = [CGSize.zero, CGSize(width: 56, height: 100),
                         CGSize(width: 320, height: 568), CGSize(width: 393, height: 759),
                         CGSize(width: 520, height: 1000), CGSize(width: 834, height: 1194)]
        for viewport in viewports {
            for stage in stages {
                let value = pose(stage, viewport: viewport)
                for number in [value.frame.minX, value.frame.minY, value.frame.width, value.frame.height] {
                    XCTAssertTrue(number.isFinite, "\(stage), viewport\(viewport)")
                }
                XCTAssertTrue(value.angle.isFinite)
                XCTAssertGreaterThanOrEqual(value.frame.width, 0)
                XCTAssertGreaterThanOrEqual(value.frame.height, 0)
                if viewport.width >= 64 {
                    XCTAssertGreaterThanOrEqual(value.frame.minX, 0)
                    XCTAssertLessThanOrEqual(value.frame.maxX, viewport.width)
                }
            }
        }
    }

    func testScaledViewportsKeepUnifiedHorizontalDockForGrid() {
        let small = pose(.docked, viewport: CGSize(width: 320, height: 568), layout: .grid)
        let large = pose(.docked, viewport: CGSize(width: 520, height: 1000), layout: .grid)
        let ratio = large.frame.width / small.frame.width
        XCTAssertGreaterThan(ratio, 1)
        XCTAssertEqual(small.frame.midX, 160, accuracy: 0.001)
        XCTAssertEqual(large.frame.midX, 260, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(small.frame.minX, 32)
        XCTAssertGreaterThanOrEqual(large.frame.minX, 32)
        XCTAssertEqual(large.frame.height / small.frame.height, ratio, accuracy: 0.000_001)
        XCTAssertGreaterThan(large.frame.minY, small.frame.minY)
        XCTAssertEqual(large.frame.width / large.frame.height, 329 / 211.7, accuracy: 0.000_001)

        let wide = pose(.docked, viewport: CGSize(width: 834, height: 1194), layout: .grid)
        XCTAssertEqual(wide.frame.width, 470, accuracy: 0.001)
        XCTAssertEqual(wide.frame.midX, 417, accuracy: 0.001)
    }

    func testMissingOriginUsesFocalFanOutAndClampsShelfPitch() {
        let viewport = CGSize(width: 393, height: 759)
        let center = pose(.folded, viewport: viewport, pitch: 0)
        let positive = pose(.folded, viewport: viewport, pitch: 36)
        let negative = pose(.folded, viewport: viewport, pitch: -36)
        XCTAssertEqual(positive.frame, negative.frame)
        XCTAssertEqual(positive.frame.midX, viewport.width / 2, accuracy: 0.001)
        XCTAssertEqual(center.angle, -5, accuracy: 0.001)
        XCTAssertEqual(negative.angle, -34, accuracy: 0.001)
        XCTAssertEqual(positive.angle, -78, accuracy: 0.001)
    }

    func testFoldedShelfOpensFocalCaseAndTucksUpperAndLowerNeighbors() {
        let viewport = CGSize(width: 393, height: 759)
        let upper = CGRect(x: 32, y: 150, width: 329, height: 136)
        let middle = CGRect(x: 32, y: 330, width: 329, height: 136)
        let lower = CGRect(x: 32, y: 510, width: 329, height: 136)
        let topPose = pose(.folded, viewport: viewport, origin: upper, pitch: -0.75)
        let focalPose = pose(.folded, viewport: viewport, origin: middle, pitch: 0)
        let bottomPose = pose(.folded, viewport: viewport, origin: lower, pitch: 0.75)

        XCTAssertEqual(focalPose.angle, -5, accuracy: 0.001,
                       "The centered focal cassette stands nearly upright to display its full horizontal artwork.")
        XCTAssertLessThan(topPose.angle, focalPose.angle - 15)
        XCTAssertLessThan(bottomPose.angle, topPose.angle - 25,
                          "Lower foreground cassettes fold further forward than upper background cassettes.")
        XCTAssertGreaterThan(topPose.angle, -90, "Upper cases keep their front artwork visible.")
        XCTAssertGreaterThan(bottomPose.angle, -90, "Lower cases stay on their front face instead of flipping to the back.")
        XCTAssertEqual(OneTapeCaseGeometry.crateClearanceFraction(for: 0), 0, accuracy: 0.001)
        XCTAssertGreaterThan(OneTapeCaseGeometry.crateClearanceFraction(for: 0.5), 0.95)
    }


    func testProjectedFacesShareSeamsAndStayFiniteThroughTheFullRoll() {
        for width: CGFloat in [0, 256, 329, 470] {
            for angle in stride(from: -115.0, through: 0, by: 5) {
                let box = OneTapeCaseProjection(width: width, angle: angle)
                XCTAssertEqual(box.front[0], box.spine[3])
                XCTAssertEqual(box.front[1], box.spine[2])
                XCTAssertEqual(box.back[2], box.spine[1])
                XCTAssertEqual(box.back[3], box.spine[0])
                for face in [box.front, box.back, box.spine] {
                    for p in face { XCTAssertTrue(p.x.isFinite && p.y.isFinite) }
                    let transform = OneTapeCaseProjection.transform(size: CGSize(width: width,
                        height: face == box.spine ? box.thickness : box.height), corners: face)
                    for n in [transform.m11, transform.m12, transform.m13, transform.m21,
                              transform.m22, transform.m23, transform.m31, transform.m32, transform.m33] {
                        XCTAssertTrue(n.isFinite, "The edge-on plane must never divide by zero.")
                    }
                }
            }
        }
    }

    func testUprightProjectionExactlyMatchesTheFinalHeroAndShelfHasDepth() {
        let upright = OneTapeCaseProjection(width: 329, angle: 0)
        XCTAssertEqual(upright.front, [CGPoint(x: 0, y: 0), CGPoint(x: 329, y: 0),
                                      CGPoint(x: 329, y: 211.7), CGPoint(x: 0, y: 211.7)])
        let upper = OneTapeCaseProjection(width: 329, angle: -70)
        XCTAssertTrue(upper.showsFront)
        XCTAssertLessThan(upper.front[2].x - upper.front[3].x, 329,
                          "The far cover edge recedes; it is not a separate rectangular card.")
        let lower = OneTapeCaseProjection(width: 329, angle: -110)
        XCTAssertFalse(lower.showsFront)
        XCTAssertLessThan(lower.back[0].y, lower.spine[0].y)
    }

    @MainActor
    func testRenderedShelfAndOpeningContactSheet() throws {
        let collection = MusicCollection(id: "stack-render", kind: .album, title: "STACK STUDY",
            subtitle: "ONE TAPE QA", remoteID: "", trackIDs: [], coverArtID: nil, year: nil, duration: 0)
        let contact = VStack(spacing: 0) {
            ForEach([-112.0, -100, -90, -80, -68, -40, 0], id: \.self) { angle in
                OneTapeSpatialCase(collection: collection, artwork: nil, angle: angle)
                    .frame(width: 329, height: 211.7)
                    .frame(width: 393, height: angle == 0 ? 240 : 130, alignment: .top)
                    .padding(.top, 35)
            }
        }.background(Color.black)
        let image = try XCTUnwrap(ImageRenderer(content: contact).uiImage)
        XCTAssertGreaterThan(image.size.height, 1000)
        let attachment = XCTAttachment(image: image)
        attachment.name = "stack-native-projection-contact"
        attachment.lifetime = .keepAlways
        add(attachment)
    }


    @MainActor
    func testUprightRenderedBoxDoesNotLeaveAnUnrotatedSpineOverTheCover() throws {
        let collection = MusicCollection(id: "upright-render", kind: .album, title: "STACK STUDY",
            subtitle: "ONE TAPE QA", remoteID: "", trackIDs: [], coverArtID: nil, year: nil, duration: 0)
        let native = OneTapeCaseArtwork(collection: collection, artwork: nil, layout: .shelf)
            .frame(width: 329, height: 211.7).background(Color.black)
        let box = OneTapeSpatialCase(collection: collection, artwork: nil, angle: 0)
            .frame(width: 329, height: 211.7).background(Color.black)
        let reference = try XCTUnwrap(ImageRenderer(content: native).uiImage?.cgImage)
        let rendered = try XCTUnwrap(ImageRenderer(content: box).uiImage?.cgImage)
        let crop = CGRect(x: 20, y: 8, width: 280, height: 36)
        func pixels(_ image: CGImage) throws -> Data {
            let slice = try XCTUnwrap(image.cropping(to: crop))
            var bytes = [UInt8](repeating: 0, count: 280 * 36 * 4)
            let context = try XCTUnwrap(CGContext(data: &bytes, width: 280, height: 36,
                bitsPerComponent: 8, bytesPerRow: 280 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(slice, in: CGRect(x: 0, y: 0, width: 280, height: 36))
            return Data(bytes)
        }
        let a = try pixels(reference)
        let b = try pixels(rendered)
        XCTAssertEqual(a, b, "At a zero-area spine projection SwiftUI can fall back to drawing it untransformed.")
    }

    private func pose(_ stage: OneTapeAlbumOpeningStage, viewport: CGSize,
                      origin: CGRect = .zero, pitch: CGFloat = 0,
                      layout: OneTapeLibraryLayout = .shelf) -> OneTapeAlbumOpeningPose {
        OneTapeAlbumOpeningPose(stage: stage, viewport: viewport, origin: origin, pitch: pitch, layout: layout)
    }
}
