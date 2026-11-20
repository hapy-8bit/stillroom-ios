import Foundation
import MetricKit
import OSLog
import UIKit

/// Local bounded evidence for unexpected exits. A missing willTerminate marker
/// alone is not classified as a crash: iOS can legitimately reclaim a background app.
@MainActor
final class PlaybackDiagnostics: NSObject, MXMetricManagerSubscriber {
    static let shared = PlaybackDiagnostics()
    private let archive: PlaybackDiagnosticArchive
    private let session = UUID().uuidString
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    private let logger = Logger(subsystem: "com.liuhang.stillroom", category: "PlaybackDiagnostics")
    private var tokens: [NSObjectProtocol] = []
    private var started = false

    private override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        archive = PlaybackDiagnosticArchive(directory: support.appendingPathComponent("Stillroom/Diagnostics"))
        super.init()
    }

    init(archive: PlaybackDiagnosticArchive) {
        self.archive = archive
        super.init()
    }

    deinit { tokens.forEach(NotificationCenter.default.removeObserver) }

    func start() {
        guard !started else { return }
        started = true
        MXMetricManager.shared.add(self)
        record(.launch)
        let notifications: [(Notification.Name, PlaybackDiagnosticEvent)] = [
            (UIApplication.didBecomeActiveNotification, .foreground),
            (UIApplication.didEnterBackgroundNotification, .background),
            (UIApplication.didReceiveMemoryWarningNotification, .memoryWarning)
        ]
        for (name, event) in notifications {
            tokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in Task { @MainActor in self?.record(event) }
            })
        }
    }

    func stop() {
        guard started else { return }
        started = false
        MXMetricManager.shared.remove(self)
        tokens.forEach(NotificationCenter.default.removeObserver)
        tokens.removeAll()
    }

    @discardableResult
    func record(_ event: PlaybackDiagnosticEvent, position: Double? = nil,
                playing: Bool? = nil, preparing: Bool? = nil, error: NSError? = nil) -> Task<Void, Never> {
        let seconds = position.flatMap { $0.isFinite ? max(0, $0) : nil }
        // Error domains are identifiers; descriptions/userInfo may contain an
        // authenticated URL and are intentionally never serialized here.
        let domain = error.map { String($0.domain.prefix(100).filter { $0.isLetter || $0.isNumber || "._-".contains($0) }) }
        let entry = PlaybackDiagnosticEntry(timestamp: Date().timeIntervalSince1970,
            session: session, processID: ProcessInfo.processInfo.processIdentifier,
            build: build, event: event, position: seconds, playing: playing,
            preparing: preparing, errorDomain: domain, errorCode: error?.code)
        let archive = self.archive
        let logger = self.logger
        logger.notice("Playback event: \(event.rawValue, privacy: .public)")
        return Task {
            do { try await archive.append(entry) }
            catch { logger.error("Local playback diagnostic could not be written") }
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // MetricKit delivers on a background queue. Convert immutable system
        // payloads there, then pass only Data to the archive actor.
        for payload in payloads {
            let data = payload.jsonRepresentation()
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    try await self.archive.storeSystemDiagnostic(data)
                    self.record(.diagnosticPayload)
                } catch { self.logger.error("System diagnostic could not be retained locally") }
            }
        }
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {}
}
