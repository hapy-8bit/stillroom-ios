import XCTest
@testable import Stillroom

/// Release selection is distinct from persisted enum identity. These tests use
/// disposable defaults only; no normal appearance or music data is cleared.
final class OneTapeScreenAvailabilityTests: XCTestCase {
    private let unavailable: [OneTapeAppearance.ScreenStyle] = [
        .dunes, .iron, .ink, .water, .sand, .oscilloscope, .waterfall
    ]

    func testSelectableRingContainsOnlyApprovedArtAndRetainedLCDAndFox() {
        XCTAssertEqual(OneTapeScreenAvailability.selectableStyles.map(\.rawValue),
            ["lcd", "fluid", "rain", "trails", "name", "meters", "fox"])
        let styles = OneTapeScreenAvailability.selectableStyles
        XCTAssertEqual(Set(styles.map(\.rawValue)).count, styles.count)
        var current = OneTapeAppearance.ScreenStyle.lcd
        var visited: [OneTapeAppearance.ScreenStyle] = []
        for _ in styles.indices {
            visited.append(current)
            current = OneTapeScreenAvailability.nextStyle(after: current)
        }
        XCTAssertEqual(visited, styles)
        XCTAssertEqual(current, .lcd)
        for stored in unavailable {
            XCTAssertFalse(stored.isSelectable)
            XCTAssertEqual(stored.resolvedStyle, .lcd)
            XCTAssertEqual(OneTapeScreenAvailability.nextStyle(after: stored), .lcd)
        }
    }

    func testEveryLegacyRawIdentityStillRoundTripsWithoutBeingMigrated() throws {
        let expected = ["lcd", "fluid", "oscilloscope", "sand", "dunes", "meters", "water",
                        "iron", "name", "fox", "ink", "rain", "trails", "waterfall"]
        XCTAssertEqual(OneTapeAppearance.ScreenStyle.allCases.map(\.rawValue), expected)
        for value in expected {
            let encoded = Data(("\"" + value + "\"").utf8)
            let decoded = try JSONDecoder().decode(OneTapeAppearance.ScreenStyle.self, from: encoded)
            XCTAssertEqual(decoded.rawValue, value)
            XCTAssertEqual(try JSONDecoder().decode(String.self,
                from: JSONEncoder().encode(decoded)), value)
        }
    }

    @MainActor
    func testLegacyPreferencePreviewAndUnrelatedSavePreserveStoredScreenAndOtherChoices() throws {
        try withActorPreferences { defaults, preferences in
            for oldStyle in unavailable {
                var original = OneTapeAppearance()
                original.tapeStyle = .bronze
                original.doodleStyle = .wild
                original.bodyStyle = .graphite
                original.bodyColor = .cognac
                original.glassOpen = false
                original.screenStyle = oldStyle
                try preferences.save(original)
                let bytes = try XCTUnwrap(defaults.data(forKey: "oneTape.appearance.v1"))
                let store = OneTapeStore(appearancePreferences: preferences, behaviorDefaults: defaults)
                XCTAssertEqual(store.appearance.screenStyle, oldStyle)
                XCTAssertEqual(store.appearance.screenStyle.resolvedStyle, .lcd)
                XCTAssertEqual(defaults.data(forKey: "oneTape.appearance.v1"), bytes,
                    "Resolving a preview must not rewrite legacy preferences")
                store.setGlassOpen(true)
                var saved = try preferences.load()
                XCTAssertEqual(saved.screenStyle, oldStyle)
                XCTAssertEqual(saved.tapeStyle, .bronze)
                XCTAssertEqual(saved.doodleStyle, .wild)
                XCTAssertEqual(saved.bodyStyle, .graphite)
                XCTAssertEqual(saved.bodyColor, .cognac)
                XCTAssertTrue(saved.glassOpen)
                let object = try XCTUnwrap(JSONSerialization.jsonObject(
                    with: XCTUnwrap(defaults.data(forKey: "oneTape.appearance.v1"))) as? [String: Any])
                XCTAssertEqual(object["glassEnabled"] as? Bool, true)
                XCTAssertNil(object["glassOpen"])
                store.cycleScreen()
                saved = try preferences.load()
                XCTAssertEqual(saved.screenStyle, .lcd,
                    "An explicit cycle from an unavailable stored style first chooses LCD")
            }
        }
    }

    func testUnknownFuturePreferenceIsPreservedInsteadOfSilentlyTreatedAsAnAvailableStyle() throws {
        try withPreferences { defaults, preferences in
            let bytes = Data("""
                {"tapeStyle":"bronze","printStyle":"brand","bodyStyle":"black",
                 "screenStyle":"future-screen","doodleStyle":"wild","bodyColor":"cognac",
                 "glassEnabled":false}
                """.utf8)
            defaults.set(bytes, forKey: "oneTape.appearance.v1")
            XCTAssertThrowsError(try preferences.load())
            XCTAssertThrowsError(try preferences.save(OneTapeAppearance()))
            XCTAssertEqual(defaults.data(forKey: "oneTape.appearance.v1"), bytes)
        }
    }

    private func withPreferences(_ action: (UserDefaults, OneTapeAppearancePreferences) throws -> Void) throws {
        let suite = "OneTapeScreenAvailabilityTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try action(defaults, OneTapeAppearancePreferences(defaults: defaults))
    }

    @MainActor
    private func withActorPreferences(
        _ action: @MainActor (UserDefaults, OneTapeAppearancePreferences) throws -> Void
    ) throws {
        let suite = "OneTapeScreenAvailabilityTests.Actor." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try action(defaults, OneTapeAppearancePreferences(defaults: defaults))
    }
}

final class OneTapeScreenStateTests: XCTestCase {
    func testStatePriorityKeepsLiveMetadataDuringLoadingAndUsesEmptyFallbackOnlyWithoutTrack() {
        let empty = readout(title: "", artist: "", playing: true, preparing: true, count: 0, id: "")
        XCTAssertEqual(empty.screenState, .empty)
        XCTAssertEqual(empty.screenTitle, "还没有磁带")
        XCTAssertEqual(empty.screenArtist, "在音乐库添加音乐")
        XCTAssertEqual(empty.screenTrackLabel, "曲 --/--")
        XCTAssertEqual(empty.screenSideLabel, "面 A")
        XCTAssertEqual(empty.screenElapsedLabel, "--:--")
        XCTAssertEqual(empty.screenDurationLabel, "--:--")
        XCTAssertEqual(empty.screenRemainingLabel, "--:--")
        XCTAssertEqual(empty.screenTimeLabel, "--:-- --:--")
        let loading = readout(playing: true, preparing: true)
        XCTAssertEqual(loading.screenState, .loading)
        XCTAssertEqual(loading.screenStatusLabel, "LOADING")
        XCTAssertEqual(loading.screenTitle, "Night Signal")
        XCTAssertEqual(loading.screenArtist, "Actual Artist")
        XCTAssertFalse(loading.screenState.allowsMotion)
        XCTAssertEqual(readout(playing: true).screenState, .playing)
        XCTAssertEqual(readout().screenState, .paused)
        XCTAssertTrue(readout(playing: true).screenState.allowsMotion)
        let unknown = readout(title: " \n", artist: "\t ")
        XCTAssertEqual(unknown.screenTitle, "未命名歌曲")
        XCTAssertEqual(unknown.screenArtist, "未知艺人")
        XCTAssertEqual(unknown.screenTimeLabel, "1:05 -2:43")
        XCTAssertEqual(unknown.screenTrackLabel, "曲 03/09")
        XCTAssertEqual(unknown.screenSideLabel, "面 A")
    }

    func testUnknownDurationStaysUnknownWhileLoadingRetainsTheRealArtistAndLegacyClocks() {
        let value = OneTapePlaybackReadout(title: "Live Track", artist: "Actual Artist",
            positionSeconds: 7, durationSeconds: 0, isPlaying: false, isPreparing: true,
            trackIndex: 0, trackCount: 1, trackID: "live-track")
        XCTAssertEqual(value.screenState, .loading)
        XCTAssertEqual(value.screenArtist, "Actual Artist")
        XCTAssertEqual(value.screenElapsedLabel, "0:07")
        XCTAssertEqual(value.screenDurationLabel, "--:--")
        XCTAssertEqual(value.screenRemainingLabel, "--:--")
        XCTAssertEqual(value.screenTimeLabel, "0:07 --:--")
        XCTAssertEqual(value.positionLabel, "0:07")
        XCTAssertEqual(value.durationLabel, "0:00")
    }

    func testTrackIdentityDistinguishesTwoSongsWithTheSameVisibleMetadata() {
        let first = readout(id: "library-first")
        let second = readout(id: "library-second")
        XCTAssertEqual(first.title, second.title)
        XCTAssertEqual(first.artist, second.artist)
        XCTAssertNotEqual(first, second,
            "Same-name songs must still trigger meter/visual state resets")
        let oldCallSite = OneTapePlaybackReadout(title: "Legacy", artist: "Artist",
            positionSeconds: 0, durationSeconds: 1, isPlaying: false, isPreparing: false,
            trackIndex: 0, trackCount: 1)
        XCTAssertEqual(oldCallSite.trackID, "")
        let idOnly = readout(title: "", artist: "", count: 0, id: "real-track")
        XCTAssertTrue(idOnly.hasTrack)
    }

    func testClockFreezesAcrossPauseBufferingAndInactiveGapsThenResumesWithoutJump() {
        var clock = OneTapeScreenMotionClock()
        clock.setRunning(true, at: 100)
        XCTAssertEqual(clock.phase(at: 101.25), 1.25, accuracy: 0.000_001)
        clock.setRunning(false, at: 102)
        XCTAssertEqual(clock.phase(at: 500), 2, accuracy: 0.000_001)
        clock.setRunning(false, at: 700)
        clock.setRunning(true, at: 900)
        XCTAssertEqual(clock.phase(at: 901.5), 3.5, accuracy: 0.000_001)
        let buffering = readout(playing: false, preparing: true)
        clock.setRunning(buffering.screenState.allowsMotion, at: 902)
        XCTAssertEqual(clock.phase(at: 10_000), 4, accuracy: 0.000_001)
        clock.setRunning(true, at: 20_000)
        XCTAssertEqual(clock.phase(at: 20_000.5), 4.5, accuracy: 0.000_001)
        // Media seconds remain an independent projection, including seeks.
        XCTAssertEqual(buffering.positionSeconds, 65)
        XCTAssertEqual(buffering.durationSeconds, 228)
    }

    func testClockResetForNewTrackAndRepeatedSamplingDoNotConsumeTimeOrAcceptNonfiniteInputs() {
        var clock = OneTapeScreenMotionClock()
        clock.setRunning(true, at: 10)
        XCTAssertEqual(clock.phase(at: 12), clock.phase(at: 12))
        clock.setRunning(false, at: 12)
        clock.setRunning(true, at: .nan)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.phase(at: .infinity), 2)
        clock.reset(at: 30, running: true)
        XCTAssertEqual(clock.phase(at: 30), 0)
        XCTAssertEqual(clock.phase(at: 30.75), 0.75)
        clock.reset(at: .infinity, running: true)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.phase(at: 99), 0)
    }

    private func readout(title: String = "Night Signal", artist: String = "Actual Artist",
                         playing: Bool = false, preparing: Bool = false,
                         count: Int = 9, id: String = "library-track") -> OneTapePlaybackReadout {
        OneTapePlaybackReadout(title: title, artist: artist, positionSeconds: 65, durationSeconds: 228,
            isPlaying: playing, isPreparing: preparing, trackIndex: 2, trackCount: count, trackID: id)
    }
}

