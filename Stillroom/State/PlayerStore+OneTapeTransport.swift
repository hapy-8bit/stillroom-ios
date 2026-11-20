import Foundation

extension PlayerStore {
    func beginWinding(direction: Int) {
        trackWindupController.cancel()
        do { try windingController.begin(direction: direction) }
        catch { notice("暂时无法快进或快退，请检查音乐连接后重试。") }
    }

    func endWinding(resume: Bool = true) {
        windingController.end(resume: resume)
        checkpoint()
    }

    func cancelWinding() {
        windingController.cancel()
        trackWindupController.cancel()
    }

    var isTapeTrackChanging: Bool { tapeTrackMotionRate != nil }

    /// Repeated track keys retain the original playing intent while each new
    /// target invalidates the previous delayed resume. Paused navigation stays
    /// immediate and crafted-side boundaries keep their existing semantics.
    func stepForTape(_ direction: Int, withMechanicalDelay: Bool = true) {
        guard direction != 0, currentTrack != nil else { return }
        PlaybackDiagnostics.shared.record(direction < 0 ? .previous : .next, position: position)
        let shouldResume = isPlaying || snapshot.isPreparing || trackWindupController.isActive
        let winds = withMechanicalDelay && shouldResume && craftedSession == nil
        cancelWinding()
        if winds { pause() }
        let revision = selectionRevision
        if direction < 0 { previousForTape() } else { skip(1) }
        guard winds, selectionRevision != revision else { return }
        do { try trackWindupController.begin(direction: direction) }
        catch { notice("无法播放：" + error.localizedDescription) }
    }

    /// One Tape's previous key differs from the legacy turntable control.
    /// Restarting retains the engine's current play/pause intent.
    func previousForTape() {
        cancelWinding()
        guard currentTrack != nil else { return }
        switch OneTapeTransportRules.previousAction(position: position) {
        case .restart: seek(0)
        case .previous: skip(-1)
        }
    }
}
