import CoreGraphics
import Foundation

/// These are the recovered local scheduling inputs, not a measured end-to-end duration.
/// The two player delays begin when the finished-opening branch appears, after openingFinishDelay.
enum RecordOpeningTiming {
    static let selectionPublishDelay: TimeInterval = 0.24
    static let openingSpringResponse: TimeInterval = 0.5
    static let openingSpringDamping = 1.0
    static let openingFinishDelay: TimeInterval = 1.0
    static let extractionDuration: TimeInterval = 0.4
    static let landscapeFinishDelay: TimeInterval = 0.2
    static let playerModeDelay: TimeInterval = 0.5
    static let playerSpringResponse: TimeInterval = 0.4
    static let playerSpringDamping = 1.0
    static let playbackIntentDelay: TimeInterval = 0.5
}

/// A presentation journey and cancellable intent tickets. Audio remains owned by PlayerStore.
/// The coordinating layer schedules work, forwards milestones and cancels on background/exit.
struct RecordOpeningJourney {
    enum Stage: Equatable, Sendable {
        case list
        case openVinyl
        case ready
    }

    enum PresentationStage: Equatable, Sendable {
        case list
        case openVinyl
        case ready
        case playing
    }

    struct Token: Equatable, Sendable {
        let trackID: String
        fileprivate let selectionRevision: UInt64
    }

    struct PlaybackRequest: Equatable, Sendable {
        let trackID: String
        fileprivate let token: Token
        fileprivate let playbackRevision: UInt64
    }

    private(set) var stage: Stage = .list
    private(set) var openingFinished = false
    private(set) var landscapeFinished = false
    private(set) var currentToken: Token?
    var selectedTrackID: String? { currentToken?.trackID }
    private var selectionRevision: UInt64 = 0
    private var playbackRevision: UInt64 = 0
    private var pendingPlayback: PlaybackRequest?

    @discardableResult
    mutating func select(trackID: String) -> Token? {
        guard !trackID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        selectionRevision &+= 1
        cancelPendingPlayback()
        let token = Token(trackID: trackID, selectionRevision: selectionRevision)
        currentToken = token
        stage = .openVinyl
        openingFinished = false
        landscapeFinished = false
        return token
    }

    func isCurrent(_ token: Token) -> Bool {
        currentToken == token
    }

    /// Call for the delayed finish marker, independently of spring settling or frame callbacks.
    @discardableResult
    mutating func finishOpening(token: Token) -> Bool {
        guard isCurrent(token), stage == .openVinyl, !openingFinished else { return false }
        openingFinished = true
        return true
    }

    @discardableResult
    mutating func finishLandscapeTransition(token: Token) -> Bool {
        guard isCurrent(token), stage == .openVinyl, openingFinished,
              !landscapeFinished else { return false }
        landscapeFinished = true
        return true
    }

    @discardableResult
    mutating func enterPlayer(token: Token) -> Bool {
        guard isCurrent(token), stage == .openVinyl, openingFinished, landscapeFinished else { return false }
        stage = .ready
        return true
    }

    /// Previewing another sleeve does not replace the engine's current track. Match identity
    /// as well as its play flag so an older song cannot make the preview record appear playing.
    func presentationStage(isPlaying: Bool, playingTrackID: String?) -> PresentationStage {
        switch stage {
        case .list: return .list
        case .openVinyl: return .openVinyl
        case .ready: return isPlaying && playingTrackID == selectedTrackID ? .playing : .ready
        }
    }

    /// Issue on an explicit play/needle action, never just because an animation completed.
    mutating func requestPlayback(token: Token) -> PlaybackRequest? {
        guard isCurrent(token), stage == .ready, pendingPlayback == nil else { return nil }
        playbackRevision &+= 1
        let request = PlaybackRequest(trackID: token.trackID, token: token,
                                      playbackRevision: playbackRevision)
        pendingPlayback = request
        return request
    }

    func isCurrent(_ request: PlaybackRequest) -> Bool {
        stage == .ready && isCurrent(request.token) && pendingPlayback == request
    }

    /// The coordinator consumes immediately before committing to the authoritative audio engine.
    /// Duplicated, cancelled or superseded delayed callbacks receive nil and cannot start old audio.
    mutating func consumePlayback(_ request: PlaybackRequest) -> String? {
        guard isCurrent(request) else { return nil }
        pendingPlayback = nil
        return request.trackID
    }

    /// Pause can cancel a pending needle/play intent without resetting the visible ready record.
    mutating func cancelPendingPlayback() {
        playbackRevision &+= 1
        pendingPlayback = nil
    }

    /// Use on scene exit/background; no delayed callback from this selection remains valid.
    mutating func cancel() {
        selectionRevision &+= 1
        currentToken = nil
        stage = .list
        openingFinished = false
        landscapeFinished = false
        cancelPendingPlayback()
    }
}

/// Rectangles are logical points in the caller's declared coordinate space.
/// Endpoints come from measured cells and the destination layout: no guessed 3D hinge is encoded.
enum RecordOpeningGeometry {
    static func clampedProgress(_ progress: Double) -> Double {
        progress.isFinite ? min(1, max(0, progress)) : 0
    }

    static func progress(elapsed: TimeInterval, duration: TimeInterval) -> Double {
        guard elapsed.isFinite, duration.isFinite, duration > 0 else { return 0 }
        return clampedProgress(elapsed / duration)
    }

    static func localFrame(_ frame: CGRect, in viewport: CGRect) -> CGRect {
        let value = sanitized(frame)
        let bounds = sanitized(viewport)
        return value.offsetBy(dx: -bounds.minX, dy: -bounds.minY)
    }

    static func interpolatedFrame(from source: CGRect, to destination: CGRect, progress: Double) -> CGRect {
        let source = sanitized(source)
        let destination = sanitized(destination)
        let phase = CGFloat(clampedProgress(progress))
        return CGRect(x: source.minX + (destination.minX - source.minX) * phase,
                      y: source.minY + (destination.minY - source.minY) * phase,
                      width: source.width + (destination.width - source.width) * phase,
                      height: source.height + (destination.height - source.height) * phase)
    }

    /// The recovered phone-only scale uses the complete container in logical points.
    /// This helper is independent of the separately recovered two-face sleeve projection.
    static func referencePhoneScale(container: CGSize) -> CGFloat? {
        guard container.width.isFinite, container.height.isFinite,
              container.width > 0, container.height > 0 else { return nil }
        return container.width / container.height <= 0.5 ? container.width / 375 : container.height / 750
    }

    private static func sanitized(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.origin.x.isFinite ? rect.origin.x : 0,
               y: rect.origin.y.isFinite ? rect.origin.y : 0,
               width: rect.size.width.isFinite ? max(0, rect.size.width) : 0,
               height: rect.size.height.isFinite ? max(0, rect.size.height) : 0)
    }
}
