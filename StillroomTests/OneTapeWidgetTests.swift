import SwiftUI
import UIKit
import XCTest
@testable import Stillroom

final class OneTapeWidgetTests: XCTestCase {
    func testEmptySnapshotDefaultsAndFormatting() {
        let empty = OneTapeWidgetSnapshot.empty
        XCTAssertFalse(empty.hasTape)
        XCTAssertEqual(empty.cardTitle, "还没有磁带")
        XCTAssertEqual(empty.labelTitle, "无磁带")
        XCTAssertEqual(empty.sideIndexLabel, "01")
        XCTAssertEqual(empty.counterText, "000")
        XCTAssertEqual(empty.counterDigits, ["0", "0", "0"])
        XCTAssertEqual(empty.percent, 0)
        XCTAssertEqual(empty.hubStepIndex, 0)
        XCTAssertEqual(empty.smallStatusLabel, "已装入")
        XCTAssertEqual(empty.deckStatusLabel, "已装入")
    }

    func testCounterPercentAndClamping() {
        let now = Date(timeIntervalSince1970: 1_000)
        let mid = OneTapeWidgetSnapshot(
            title: "葡萄成熟时",
            artist: "陈奕迅",
            album: "U87",
            trackNumber: 5,
            isPlaying: true,
            progress: 0.501,
            tint: OneTapeWidgetTint(red: 0.8, green: 0.4, blue: 0.2),
            updated: now,
            artworkID: "cover-u87",
            albumDuration: 2400,
            playbackRemaining: 1200
        )
        XCTAssertTrue(mid.hasTape)
        XCTAssertEqual(mid.cardTitle, "葡萄成熟时")
        XCTAssertEqual(mid.labelTitle, "U87")
        XCTAssertEqual(mid.sideIndexLabel, "05")
        XCTAssertEqual(mid.counterText, "500")
        XCTAssertEqual(mid.counterDigits, ["5", "0", "0"])
        XCTAssertEqual(mid.percent, 50)
        XCTAssertEqual(mid.smallStatusLabel, "正在播放")
        XCTAssertEqual(mid.deckStatusLabel, "磁带转动中")

        let invalid = OneTapeWidgetSnapshot(
            title: "Test",
            artist: "",
            album: "",
            isPlaying: false,
            progress: .nan,
            tint: nil,
            updated: now,
            artworkID: "",
            albumDuration: -10,
            playbackRemaining: .infinity
        )
        XCTAssertEqual(invalid.clampedProgress, 0)
        XCTAssertEqual(invalid.counterText, "000")
        XCTAssertEqual(invalid.albumDuration, 0)
        XCTAssertEqual(invalid.playbackRemaining, 0)
    }

    func testTimelineProjectionAdvancesAndStopsAtPlaybackEnd() {
        let start = Date(timeIntervalSince1970: 10_000)
        let playing = OneTapeWidgetSnapshot(
            title: "Track 1",
            artist: "Artist",
            album: "Album",
            isPlaying: true,
            progress: 0.25,
            tint: nil,
            updated: start,
            artworkID: "art-1",
            albumDuration: 1000,
            playbackRemaining: 250
        )

        let midway = playing.projected(at: start.addingTimeInterval(100))
        XCTAssertTrue(midway.isPlaying)
        XCTAssertEqual(midway.clampedProgress, 0.35, accuracy: 0.0001)
        XCTAssertEqual(midway.counterText, "349")
        XCTAssertEqual(midway.percent, 35)

        let finished = playing.projected(at: start.addingTimeInterval(300))
        XCTAssertFalse(finished.isPlaying)
        XCTAssertEqual(finished.clampedProgress, 0.50, accuracy: 0.0001)
        XCTAssertEqual(finished.playbackRemaining, 0, accuracy: 0.0001)

        let dates = playing.timelineDates(from: start, maxEntries: 12)
        XCTAssertGreaterThan(dates.count, 2)
        XCTAssertLessThanOrEqual(dates.count, 12)
        XCTAssertEqual(dates.first, start)
        XCTAssertEqual(dates.last?.timeIntervalSince(start) ?? 0, 250, accuracy: 0.1)

        let paused = OneTapeWidgetSnapshot(
            title: "Track 1",
            artist: "Artist",
            album: "Album",
            isPlaying: false,
            progress: 0.25,
            tint: nil,
            updated: start,
            artworkID: "art-1",
            albumDuration: 1000,
            playbackRemaining: 250
        )
        XCTAssertEqual(paused.timelineDates(from: start), [start])
        XCTAssertEqual(paused.projected(at: start.addingTimeInterval(120)).clampedProgress, 0.25, accuracy: 0.0001)
    }

    func testDeviceWidgetMetricsMatchStandardIOSGridSizes() {
        let pro16 = OneTapeWidgetMetrics.forScreen(width: 402, height: 874)
        XCTAssertEqual(pro16.small, CGSize(width: 158, height: 158))
        XCTAssertEqual(pro16.medium, CGSize(width: 338, height: 158))
        XCTAssertEqual(pro16.large, CGSize(width: 338, height: 354))
        XCTAssertEqual(pro16.cornerRadius, 22)

        let proMax = OneTapeWidgetMetrics.forScreen(width: 440, height: 956)
        XCTAssertEqual(proMax.small, CGSize(width: 170, height: 170))
        XCTAssertEqual(proMax.medium, CGSize(width: 364, height: 170))
        XCTAssertEqual(proMax.large, CGSize(width: 364, height: 382))

        let mini = OneTapeWidgetMetrics.forScreen(width: 360, height: 780)
        XCTAssertEqual(mini.small, CGSize(width: 141, height: 141))
        XCTAssertEqual(mini.cornerRadius, 20)
    }

    func testSharedStoreRoundTripAndCorruptRecovery() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneTapeWidgetStoreTests-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = OneTapeWidgetSharedStore(directoryOverride: tempDir)
        XCTAssertEqual(store.loadSnapshot(), .empty)
        XCTAssertNil(store.loadArtwork())

        let cover = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600)).image { ctx in
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
        }
        let snapshot = OneTapeWidgetSnapshot(
            title: "Night Bus",
            artist: "Stillroom",
            album: "Late Tape",
            trackNumber: 3,
            isPlaying: true,
            progress: 0.42,
            tint: OneTapeWidgetTint(red: 0.9, green: 0.5, blue: 0.2),
            updated: Date(timeIntervalSince1970: 1_700_000_000),
            artworkID: "late-tape-art",
            albumDuration: 1800,
            playbackRemaining: 1044
        )
        XCTAssertTrue(store.save(snapshot: snapshot, artwork: cover, writeArtwork: true))

        let loaded = store.loadSnapshot()
        XCTAssertEqual(loaded, snapshot)
        let loadedArt = try XCTUnwrap(store.loadArtwork())
        XCTAssertLessThanOrEqual(max(loadedArt.size.width, loadedArt.size.height), 320.5)

        // Corrupt JSON must fall back cleanly to `.empty` without throwing.
        let snapshotURL = try XCTUnwrap(store.snapshotURL)
        try Data("not-valid-json".utf8).write(to: snapshotURL, options: .atomic)
        XCTAssertEqual(store.loadSnapshot(), .empty)
    }

    @MainActor
    func testAllThreeWidgetSizesRenderCleanlyInDarkAndLightMode() {
        let cover = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { ctx in
            UIColor(red: 0.72, green: 0.34, blue: 0.22, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
        }
        let snapshot = OneTapeWidgetSnapshot(
            title: "葡萄成熟时",
            artist: "陈奕迅",
            album: "U87",
            trackNumber: 2,
            isPlaying: true,
            progress: 0.38,
            tint: OneTapeWidgetTint(red: 0.72, green: 0.34, blue: 0.22),
            updated: Date(),
            artworkID: "u87",
            albumDuration: 2400,
            playbackRemaining: 1488
        )
        let metrics = OneTapeWidgetMetrics.forScreen(width: 402, height: 874)
        let states: [(String, OneTapeWidgetSnapshot, UIImage?)] = [
            ("empty", .empty, nil),
            ("playing", snapshot, cover)
        ]
        for (stateName, stateSnapshot, stateArtwork) in states {
            for scheme in [ColorScheme.dark, ColorScheme.light] {
                let schemeName = scheme == .dark ? "dark" : "light"
                for size in OneTapeWidgetSize.allCases {
                    let view = OneTapeWidgetPreview(
                        size: size,
                        snapshot: stateSnapshot,
                        artwork: stateArtwork,
                        metrics: metrics
                    )
                    .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 3
                    let rendered = renderer.uiImage
                    XCTAssertNotNil(rendered, "Failed rendering \(stateName)-\(size)-\(schemeName)")
                    XCTAssertGreaterThan(rendered?.size.width ?? 0, 100)
                    if let rendered {
                        let attachment = XCTAttachment(image: rendered)
                        attachment.name = "widget-\(stateName)-\(schemeName)-\(size.rawValue)"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                }
            }
        }
    }
}
