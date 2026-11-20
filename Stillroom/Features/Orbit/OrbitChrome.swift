import SwiftUI

/// Playback time is supplied in seconds. Decorative views never schedule or infer audio progress.
struct OrbitPlaybackPresentation {
    var current: Track
    var albums: [Track]
    var albumTracks: [Track] = []
    var artworks: [String: UIImage] = [:]
    var albumArtworks: [String: UIImage] = [:]
    var playing = false
    var preparing = false
    var position: Double = 0
    var duration: Double = 0
    var selectionRevision = 0
    var transition: OrbitRecordTransition = .follow
    var reducedMotion = false
    var libraryReady = true
    var active = true
    var queueFinished = false
    var statusCaption: String? = nil
    var craftedSession: CraftListeningSession? = nil
    var craftedCover: UIImage? = nil
    var craftedCollected = false
    var archiveBusy = false
    var canSkipNext = true
    var canSkipPrevious = true

    var displayRecordTitle: String { craftedSession?.record.title ?? current.album }
    var styleKey: String { craftedSession.map { "craft:" + $0.record.id } ?? current.albumKey }
    var recordIdentity: String {
        craftedSession.map { "craft:" + $0.record.id + "|" + $0.side.rawValue } ?? "album:" + current.albumKey
    }

    /// A custom record owns its printed identity across songs. This copy is only for drawing;
    /// transport and system now-playing callbacks must continue to use the real current track.
    var displayTrack: Track {
        guard let session = craftedSession else { return current }
        return Track(id: "craft:" + session.record.id, title: session.record.title,
                     artist: session.side.label, album: session.record.title,
                     audioFile: "", palette: .local, duration: current.duration, lyrics: "",
                     isDemo: false, isLyricDemo: false)
    }
    var displayArtwork: UIImage? { craftedSession == nil ? currentArtwork : craftedCover }
    var needleFraction: Double? {
        guard let session = craftedSession else { return albumFraction }
        return session.fraction(currentID: current.id, position: position, duration: duration, tracks: albumTracks)
    }

    var fraction: Double { duration.isFinite && duration > 0 ? MediaTime.clamped(position, duration: duration) / duration : 0 }
    var currentArtwork: UIImage? { artworks[current.id] }
    var currentAlbum: Track { albums.first(where: { $0.albumKey == current.albumKey }) ?? current }
    var albumArtwork: UIImage? { albumArtworks[currentAlbum.id] }

    var albumFraction: Double? {
        guard let index = albumTracks.firstIndex(where: { $0.id == current.id }),
              Set(albumTracks.map(\.id)).count == albumTracks.count else { return nil }
        let durations = albumTracks.enumerated().map { offset, track in offset == index && duration > 0 ? duration : track.duration }
        guard durations.allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        let total = durations.reduce(0, +)
        guard total.isFinite && total > 0 else { return nil }
        return (durations.prefix(index).reduce(0, +) + MediaTime.clamped(position, duration: durations[index])) / total
    }
}

struct OrbitHomeActions {
    var selectAlbum: (String) -> Void = { _ in }
    var toggle: () -> Void = {}
    var skip: (Int) -> Void = { _ in }
    var seek: (Double) -> Void = { _ in }
    var library: () -> Void = {}
    var settings: () -> Void = {}
    var lyrics: () -> Void = {}
    var importMusic: () -> Void = {}
    var queue: () -> Void = {}
    var craftedRecords: () -> Void = {}
    var songMemories: () -> Void = {}
    var openCurrent: (() -> Void)? = nil
    var sleeve: () -> Void = {}
    var flip: () -> Void = {}
    var collect: () async -> Bool = { false }
    var endListening: () -> Void = {}
    var recordOpening: (() -> Void)? = nil
    var rotate: () -> Void = {}
}

enum OrbitInk {
    static let accent = Color(red: 0.31, green: 0.82, blue: 1)
    static let purple = Color(red: 0.83, green: 0.14, blue: 1)
    static let button = Color(white: 0.085)
    static func color(_ hex: String) -> Color {
        let value = UInt(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xA7BCE8
        return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}

struct OrbitCircleButton: View {
    var symbol: String
    var label: String
    var identifier: String
    var diameter: CGFloat = 42
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: diameter > 48 ? 22 : 17, weight: .semibold))
                .foregroundStyle(.white).frame(width: diameter, height: diameter)
                .background(OrbitInk.button.opacity(0.92), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.7))
                .frame(minWidth: 44, minHeight: 44)
        }.buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier(identifier)
    }
}

struct OrbitTransport: View {
    let presentation: OrbitPlaybackPresentation
    let actions: OrbitHomeActions
    var active: Bool
    var turntable = false
    var lightBackground = false
    var showsPhysicalControls = true
    var showsTurntableSecondaryInfo = true
    var horizontalInset: CGFloat = 24
    var openTurntable: () -> Void
    @State private var collectionOwner: String?
    @State private var collectionFailed = false

    private var ink: Color { lightBackground ? Color(hex: 0x252629) : .white }
    private var session: CraftListeningSession? { presentation.craftedSession }
    private var boundary: Bool { session.map { $0.phase != .listening } ?? false }
    private var collecting: Bool { collectionOwner != nil }
    private var collected: Bool { presentation.craftedCollected }
    private var metadataSubtitle: String {
        if turntable, session != nil { return presentation.current.artist }
        return presentation.statusCaption ?? (presentation.preparing ? "正在准备音乐" : presentation.current.artist)
    }
    private var playLabel: String {
        if session?.phase == .awaitingFlip { return "A 面已播放完，请翻面" }
        return presentation.queueFinished || session?.phase == .finished ? "从头重听" : presentation.playing ? "暂停" : "播放"
    }

    var body: some View {
        VStack(spacing: turntable ? 9 : 15) {
            metadata
            if turntable {
                if showsTurntableSecondaryInfo { turntableStatus }
                if showsPhysicalControls { physicalControls.padding(.top, 6) }
            } else {
                OrbitProgressWave(position: presentation.position, duration: presentation.duration, playing: presentation.playing,
                                  active: active, reducedMotion: presentation.reducedMotion, ink: ink,
                                  selectionKey: "\(presentation.current.id)|\(presentation.selectionRevision)", onSeek: actions.seek)
            }
        }.padding(.horizontal, horizontalInset).padding(.vertical, turntable ? 0 : 10)
            .accessibilityElement(children: .contain)
            .onChange(of: presentation.recordIdentity) { _, _ in
                collectionOwner = nil
                collectionFailed = false
            }
    }

    private var metadata: some View {
        HStack(spacing: 9) {
            Button(action: openTurntable) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(presentation.albums.isEmpty ? "还没有音乐" : presentation.current.title)
                        .font(.system(size: turntable ? 20 : 19, weight: turntable ? .bold : .semibold))
                        .lineLimit(turntable ? 2 : 1).minimumScaleFactor(0.85)
                    Text(metadataSubtitle)
                        .font(.system(size: turntable ? 13 : 10, weight: .medium))
                        .foregroundStyle(ink.opacity(0.6)).lineLimit(1)
                }.foregroundStyle(ink).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.buttonStyle(.plain).accessibilityIdentifier("orbit.openPlayer")
            if !turntable {
                HStack(spacing: 4) {
                    OrbitCircleButton(symbol: "backward.end.fill", label: "上一首", identifier: "orbit.previous", diameter: 38) { actions.skip(-1) }
                    OrbitCircleButton(symbol: presentation.playing ? "pause.fill" : "play.fill",
                                      label: playLabel, identifier: "orbit.play", diameter: 52, action: actions.toggle)
                    OrbitCircleButton(symbol: "forward.end.fill", label: "下一首", identifier: "orbit.next", diameter: 38) { actions.skip(1) }
                }.disabled(presentation.albums.isEmpty)
            }
        }
    }

    @ViewBuilder private var turntableStatus: some View {
        if session != nil { recordStatus }
        else {
            HStack(spacing: 12) {
                Text(presentation.displayRecordTitle).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Spacer(minLength: 4)
                Text(MediaTime.label(presentation.position))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                compactAction("封套与记忆", symbol: "square.on.square", id: "unified.sleeve", action: actions.sleeve)
            }.foregroundStyle(ink.opacity(0.55)).frame(minHeight: 44)
        }
    }

    @ViewBuilder private var recordStatus: some View {
        if let session {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.record.title).lineLimit(1)
                    Text(collectionFailed ? "收藏未完成，请重试" : session.phase == .awaitingFlip ? "A 面已播放完" : session.phase == .finished ? (session.allReachedEnd ? "这一张，听完了" : "本次播放已结束") : session.side.label)
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(ink.opacity(0.5))
                }.font(.system(size: 11, weight: .medium)).foregroundStyle(ink.opacity(0.75))
                Spacer(minLength: 4)
                if session.phase == .awaitingFlip {
                    compactAction("翻到 B 面", symbol: "arrow.triangle.2.circlepath", id: "unified.flip", action: actions.flip)
                } else if session.phase == .finished {
                    Button(action: collectRecord) {
                        Label(collected ? "已收藏" : collecting || presentation.archiveBusy ? "正在收藏" : "收藏这张唱片",
                              systemImage: collected ? "checkmark.seal" : "plus")
                            .font(.system(size: 11, weight: .medium)).frame(minHeight: 44)
                    }.buttonStyle(.plain).foregroundStyle(ink)
                        .disabled(collected || collecting || presentation.archiveBusy)
                        .accessibilityIdentifier("unified.collect")
                }
                compactAction("封套与记忆", symbol: "square.on.square", id: "unified.sleeve", action: actions.sleeve)
            }.accessibilityElement(children: .contain)
        }
    }

    private var physicalControls: some View {
        HStack(spacing: 14) {
            playerKey(presentation.playing ? "pause.fill" : "play.fill", label: playLabel, id: "orbit.play", action: actions.toggle)
                .disabled(session?.phase == .awaitingFlip)
            Spacer(minLength: 14)
            playerKey("backward.end.fill", label: "上一首", id: "orbit.previous") { actions.skip(-1) }
            playerKey("forward.end.fill", label: "下一首", id: "orbit.next") { actions.skip(1) }
                .disabled(boundary)
        }
    }

    private func compactAction(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 11, weight: .medium))
                .labelStyle(.titleOnly).frame(minWidth: 44, minHeight: 44)
        }.buttonStyle(.plain).foregroundStyle(ink).accessibilityIdentifier(id)
    }

    private func playerKey(_ symbol: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ink.opacity(0.9)).frame(width: 64, height: 44)
                .background {
                    // The shallow highlight reads as a physical key without moving the audio control's hit area.
                    Capsule().fill(LinearGradient(colors: lightBackground ? [.white.opacity(0.38), .white.opacity(0.08)] : [.white.opacity(0.15), .white.opacity(0.035)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(lightBackground ? 0.12 : 0.3), radius: 1.5, y: 1.5)
                }
                .overlay(Capsule().strokeBorder(ink.opacity(0.25), lineWidth: 0.7))
        }.buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier(id)
    }

    private func collectRecord() {
        guard !collecting, !presentation.archiveBusy, !collected else { return }
        collectionFailed = false
        let identity = presentation.recordIdentity
        collectionOwner = identity
        Task { @MainActor in
            // A completed archive write is the only source of the collection stamp; animation never commits data.
            let saved = await actions.collect()
            guard collectionOwner == identity else { return }
            collectionFailed = !saved
            collectionOwner = nil
        }
    }
}

struct OrbitProgressWave: View {
    let position: Double
    let duration: Double
    let playing: Bool
    let active: Bool
    let reducedMotion: Bool
    var showWave = true
    var ink: Color = .white
    var selectionKey = ""
    var onSeek: (Double) -> Void
    @GestureState private var preview: Double?
    @GestureState private var dragging = false
    @State private var dragOwner: String?

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width - 12)
            let value = MediaTime.clamped(dragOwner == selectionKey ? preview ?? position : position, duration: duration)
            let fraction = duration.isFinite && duration > 0 ? value / duration : 0
            TimelineView(.animation(minimumInterval: 1 / 24, paused: !playing || !active || reducedMotion)) { context in
                ZStack(alignment: .leading) {
                    Capsule().fill(ink.opacity(0.2)).frame(height: 2)
                    if playing && showWave {
                        Canvas { context2, size in
                            let time = reducedMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                            for row in 0..<5 {
                                var line = Path()
                                for step in 0...100 {
                                    let x = CGFloat(step) / 100 * size.width
                                    let envelope = sin(Double(step) / 100 * .pi)
                                    let y = size.height / 2 + sin(Double(step) * 0.15 + time * (1.6 + Double(row) * 0.2) + Double(row)) * 6 * envelope
                                    if step == 0 { line.move(to: CGPoint(x: x, y: y)) } else { line.addLine(to: CGPoint(x: x, y: y)) }
                                }
                                context2.stroke(line, with: .color(OrbitInk.accent.opacity(0.25 + Double(row) * 0.13)), lineWidth: 0.8)
                            }
                        }.frame(height: 26).shadow(color: OrbitInk.accent, radius: 6)
                            .accessibilityIdentifier("orbit.progress.wave")
                    }
                    Circle().fill(OrbitInk.accent).frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1)).shadow(color: OrbitInk.accent, radius: 4)
                        .offset(x: width * fraction)
                }.padding(.horizontal, 6).frame(height: 44).contentShape(Rectangle())
            }.gesture(DragGesture(minimumDistance: 0).updating($dragging) { _, state, _ in state = true }
                .updating($preview) { value, state, _ in
                state = MediaTime.clamped((value.location.x - 6) / width * duration, duration: duration)
            }.onChanged { _ in if active && dragOwner == nil { dragOwner = selectionKey } }
                .onEnded { value in
                    defer { dragOwner = nil }
                    guard active, dragOwner == selectionKey else { return }
                    onSeek(MediaTime.clamped((value.location.x - 6) / width * duration, duration: duration))
                })
        }.frame(height: 44).accessibilityElement(children: .ignore).accessibilityLabel("播放进度")
            .accessibilityValue("\(MediaTime.label(preview ?? position)) / \(MediaTime.label(duration))")
            .accessibilityAdjustableAction { direction in onSeek(MediaTime.clamped(position + (direction == .increment ? 5 : -5), duration: duration)) }
            .accessibilityIdentifier("orbit.progress")
            .onChange(of: active) { _, value in if !value && dragging { dragOwner = "cancelled" } }
            .onChange(of: selectionKey) { _, _ in dragOwner = dragging ? "cancelled" : nil }
            .task(id: dragging) {
                guard !dragging else { return }
                // GestureState can reset before onEnded. Let the release commit its owned seek
                // first; a system cancellation still clears the owner on the following actor turn.
                await Task.yield()
                guard !Task.isCancelled, !dragging else { return }
                dragOwner = nil
            }.onDisappear { dragOwner = nil }
    }
}
