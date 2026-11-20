import AVFoundation

/// Serial system work stays off the main actor; activating an audio route can block for hundreds of milliseconds.
actor AudioSessionActivation {
    static let shared = AudioSessionActivation()

    func activate() throws {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback { try session.setCategory(.playback, mode: .default) }
        try session.setActive(true)
    }
}
