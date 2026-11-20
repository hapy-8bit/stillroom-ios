import XCTest
import UIKit
@testable import Stillroom

final class OrbitPresentationTests: XCTestCase {
    func testAlbumStylesDoNotOwnOrChangeTheGlobalBackground() throws {
        var preferences = OrbitVisualPreferences()
        var album = OrbitRecordStyle(); album.material = .split
        preferences.setStyle(album, albumKey: "record-a")
        preferences.background = .lavender
        var global = OrbitRecordStyle(); global.material = .black
        preferences.setStyle(global, albumKey: nil)
        XCTAssertEqual(preferences.style(for: "record-a").material, .split)
        XCTAssertEqual(preferences.style(for: "record-b").material, .black)
        XCTAssertEqual(preferences.background, .lavender)
        let restored = try JSONDecoder().decode(OrbitVisualPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(restored, preferences)
    }

    func testStickerDraftIsIndependentAndCannotExceedTwelveUniqueStickers() {
        let saved = OrbitRecordStyle()
        var draft = saved
        for index in 0..<12 { XCTAssertNotNil(draft.addSticker(OrbitStickerKind.allCases[index % 4])) }
        XCTAssertNil(draft.addSticker(.star))
        XCTAssertEqual(draft.stickers.count, 12)
        XCTAssertEqual(Set(draft.stickers.map(\.id)).count, 12)
        XCTAssertEqual(saved.stickers, [], "Cancel discards the value draft without changing the saved style")
        XCTAssertTrue(draft.stickers.allSatisfy { hypot($0.x - 0.5, $0.y - 0.5) >= 0.27 })
    }

    func testStickerNormalizationKeepsItsFullFootprintInsideTheRecord() {
        for size in [0.01, 0.18, 0.9, .nan] {
            let sticker = OrbitRecordSticker(id: "one", kind: .heart, x: 1, y: 1, size: size, rotation: 720).normalized()
            XCTAssertGreaterThanOrEqual(sticker.size, 0.1)
            XCTAssertLessThanOrEqual(sticker.size, 0.34)
            XCTAssertLessThanOrEqual(hypot(sticker.x - 0.5, sticker.y - 0.5) + sticker.size / 2, 0.500_001)
            XCTAssertEqual(sticker.rotation, 0)
        }
        let invalid = OrbitRecordSticker(id: "two", kind: .vinyl, x: .nan, y: .infinity, rotation: .nan).normalized()
        XCTAssertEqual(invalid.x, 0.5); XCTAssertEqual(invalid.y, 0.5); XCTAssertEqual(invalid.rotation, 0)
    }

    func testWholeRecordPositionUsesCanonicalMediaDurationsRatherThanQueuePosition() {
        var first = Track.demos[0]; first.duration = 40
        var second = Track.demos[1]; second.duration = 60
        var third = Track.demos[2]; third.duration = 100
        let model = OrbitPlaybackPresentation(current: second, albums: [first], albumTracks: [first, second, third], position: 30, duration: 60)
        XCTAssertEqual(model.albumFraction ?? -1, 0.35, accuracy: 0.0001)
        XCTAssertEqual(model.fraction, 0.5, accuracy: 0.0001)
        var unknown = model; unknown.albumTracks[2].duration = 0
        XCTAssertNil(unknown.albumFraction, "Unknown future duration must not invent a whole-disc total")
        var duplicate = model; duplicate.albumTracks.append(first)
        XCTAssertNil(duplicate.albumFraction)
    }

    func testAlbumArtworkNeverFallsBackToTheSongOnlyOverride() {
        let track = Track.demos[0]
        let songImage = UIImage()
        var model = OrbitPlaybackPresentation(current: track, albums: [track], artworks: [track.id: songImage])
        XCTAssertTrue(model.currentArtwork === songImage)
        XCTAssertNil(model.albumArtwork)
        let albumImage = UIImage()
        model.albumArtworks[track.id] = albumImage
        XCTAssertTrue(model.albumArtwork === albumImage)
        XCTAssertTrue(model.currentArtwork === songImage)
    }

    func testCraftedNeedleUsesTheActiveSideAcrossSourceAlbums() {
        var first = Track.demos[0]; first.duration = 40
        var second = Track.demos[1]; second.duration = 60
        var third = Track.demos[2]; third.duration = 100
        let session = customSession(sideA: [first.id, second.id], sideB: [third.id])
        let model = OrbitPlaybackPresentation(current: second, albums: [first, second, third],
                                              albumTracks: [first, second, third], position: 30, duration: 60,
                                              craftedSession: session)
        XCTAssertEqual(model.needleFraction ?? -1, 0.7, accuracy: 0.0001)
        XCTAssertEqual(model.albumFraction ?? -1, 0.35, accuracy: 0.0001)
    }

    func testCustomArtworkNeverFallsBackToTheCurrentSong() {
        let track = Track.demos[0]
        let songImage = UIImage()
        let session = customSession(sideA: [track.id])
        var model = OrbitPlaybackPresentation(current: track, albums: [track], artworks: [track.id: songImage],
                                              craftedSession: session)
        XCTAssertTrue(model.currentArtwork === songImage)
        XCTAssertNil(model.displayArtwork, "A typographic custom sleeve must not borrow the source album's cover")
        let customImage = UIImage()
        model.craftedCover = customImage
        XCTAssertTrue(model.displayArtwork === customImage)
    }

    func testCustomRecordIdentityStaysAcrossSongsAndChangesAtTheFaceBoundary() {
        let first = Track.demos[0], second = Track.demos[1]
        var session = customSession(sideA: [first.id, second.id], sideB: [Track.demos[2].id])
        var model = OrbitPlaybackPresentation(current: first, albums: [first, second], craftedSession: session)
        let sideAIdentity = model.recordIdentity
        model.current = second
        XCTAssertEqual(model.recordIdentity, sideAIdentity)
        XCTAssertEqual(model.displayTrack.id, "craft:" + session.record.id)
        XCTAssertEqual(model.displayTrack.album, session.record.title)
        XCTAssertEqual(model.displayTrack.artist, "A 面")
        XCTAssertEqual(model.current.id, second.id, "The visual record identity cannot replace the actual audio track")
        session.side = .b
        model.craftedSession = session
        XCTAssertNotEqual(model.recordIdentity, sideAIdentity)
        XCTAssertEqual(model.displayTrack.artist, "B 面")
    }

    func testCustomStyleTargetStaysFrozenAcrossSongsAndFaces() {
        var session = customSession(sideA: [Track.demos[0].id], sideB: [Track.demos[1].id])
        var model = OrbitPlaybackPresentation(current: Track.demos[0], albums: Track.demos, craftedSession: session)
        let key = model.styleKey
        model.current = Track.demos[1]
        session.side = .b
        model.craftedSession = session
        XCTAssertEqual(model.styleKey, key)
        XCTAssertEqual(key, "craft:" + session.record.id)
        model.craftedSession = nil
        XCTAssertEqual(model.styleKey, model.current.albumKey)
    }

    func testFreshPreferencesOpenTheAtmosphericTurntable() {
        let preferences = OrbitVisualPreferences()
        XCTAssertEqual(preferences.selectedHome, .turntable)
        XCTAssertEqual(preferences.background, .atmosphere)
        XCTAssertEqual(preferences.globalStyle.material, .smoke)
        XCTAssertTrue(preferences.usesLightContent)
    }

    func testPreviouslySavedWheelAndSagePreferencesStayUnchanged() throws {
        let saved = #"{"selectedHome":"wheel","background":"sage","globalStyle":{"material":"black","primaryHex":"A7BCE8","secondaryHex":"F1F4FB","stickers":[]},"albumStyles":{}}"#
        let preferences = try JSONDecoder().decode(OrbitVisualPreferences.self, from: Data(saved.utf8))
        XCTAssertEqual(preferences.selectedHome, .wheel)
        XCTAssertEqual(preferences.background, .sage)
        XCTAssertEqual(preferences.globalStyle.material, .black)
        XCTAssertEqual(preferences.customBackgroundHex, "0B1420")
    }

    func testLegacySilverAndAlbumOverridesSurviveNewBackgroundFields() throws {
        let saved = #"{"selectedHome":"turntable","background":"silver","globalStyle":{"material":"black","primaryHex":"A7BCE8","secondaryHex":"F1F4FB","stickers":[]},"albumStyles":{"record-a":{"material":"split","primaryHex":"112233","secondaryHex":"DDEEFF","stickers":[]}}}"#
        let preferences = try JSONDecoder().decode(OrbitVisualPreferences.self, from: Data(saved.utf8))
        XCTAssertEqual(preferences.background, .silver)
        XCTAssertEqual(preferences.style(for: "record-a").material, .split)
        XCTAssertEqual(preferences.style(for: "record-a").primaryHex, "112233")
        XCTAssertEqual(preferences.style(for: "record-b").material, .black)
    }

    func testCustomBackgroundNormalizesRGBAndRejectsInvalidMutation() throws {
        var preferences = OrbitVisualPreferences()
        XCTAssertTrue(preferences.setCustomBackgroundHex("  #aBc123 \n"))
        XCTAssertEqual(preferences.customBackgroundHex, "ABC123")
        XCTAssertEqual(preferences.background, .custom)
        let saved = preferences
        for invalid in ["#fff", "11223344", "GG2233", "12 345", "##112233", ""] {
            XCTAssertFalse(preferences.setCustomBackgroundHex(invalid))
            XCTAssertEqual(preferences, saved)
        }
        let restored = try JSONDecoder().decode(OrbitVisualPreferences.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(restored, saved)
    }

    func testCustomBackgroundForegroundFollowsSavedColorWithoutChangingMaterial() {
        var preferences = OrbitVisualPreferences()
        let material = preferences.globalStyle.material
        XCTAssertTrue(preferences.setCustomBackgroundHex("000000"))
        XCTAssertTrue(preferences.usesLightContent)
        XCTAssertTrue(preferences.setCustomBackgroundHex("FFFFFF"))
        XCTAssertFalse(preferences.usesLightContent)
        XCTAssertTrue(preferences.setCustomBackgroundHex("808080"))
        XCTAssertFalse(preferences.usesLightContent, "Medium gray needs dark text for readable contrast")
        XCTAssertEqual(preferences.globalStyle.material, material)
    }

    func testArmLightCyclesAndRoundTripsWithoutChangingRecordOrBackground() throws {
        var preferences = OrbitVisualPreferences()
        let background = preferences.background
        let style = preferences.globalStyle
        for expected in [OrbitArmLight.red, .blue, .purple, .off] {
            preferences.armLight = preferences.armLight.next
            XCTAssertEqual(preferences.armLight, expected)
            let saved = try JSONEncoder().encode(preferences)
            XCTAssertEqual(try JSONDecoder().decode(OrbitVisualPreferences.self, from: saved), preferences)
            XCTAssertEqual(preferences.background, background)
            XCTAssertEqual(preferences.globalStyle, style)
        }
    }

    func testLegacyVisualPreferencesDefaultTheNewArmLightToOff() throws {
        let data = Data(#"{"background":"silver","selectedHome":"turntable"}"#.utf8)
        let preferences = try JSONDecoder().decode(OrbitVisualPreferences.self, from: data)
        XCTAssertEqual(preferences.armLight, .off)
        XCTAssertEqual(preferences.background, .silver)
    }

    private func customSession(sideA: [String], sideB: [String] = []) -> CraftListeningSession {
        CraftListeningSession(record: CraftedRecord(id: "test-custom", title: "给今天的唱片",
                                                     sideA: sideA, sideB: sideB, isDraft: false))
    }

}
