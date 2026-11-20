import Foundation

enum RepeatMode: String, Codable, CaseIterable {
    case off, all, one
    var symbol: String { self == .one ? "repeat.1" : "repeat" }
    var label: String { self == .off ? "顺序播放" : self == .all ? "列表循环" : "单曲循环" }
    var next: RepeatMode { self == .off ? .all : self == .all ? .one : .off }
}

struct PlaybackQueue {
    private(set) var ids: [String] = []
    private var original: [String] = []
    private(set) var shuffled = false
    var repeatMode: RepeatMode = .off
    var originalIDs: [String] { original }

    mutating func restore(ids: [String], original: [String], shuffled: Bool, repeatMode: RepeatMode) {
        self.ids = Array(NSOrderedSet(array: ids)) as? [String] ?? ids
        self.original = Array(NSOrderedSet(array: original)) as? [String] ?? original
        self.shuffled = shuffled; self.repeatMode = repeatMode
    }

    mutating func replace(with ids: [String], startingAt current: String) {
        self.original = Array(NSOrderedSet(array: ids)) as? [String] ?? ids
        self.ids = original
        if shuffled { shuffle(around: current) }
    }

    mutating func toggleShuffle(current: String) {
        shuffled.toggle()
        if shuffled { shuffle(around: current) } else { ids = original }
    }

    private mutating func shuffle(around current: String) {
        ids = (original.contains(current) ? [current] : []) + original.filter { $0 != current }.shuffled()
    }

    func adjacent(to current: String, delta: Int, automatic: Bool) -> String? {
        guard !ids.isEmpty, let index = ids.firstIndex(of: current) else { return nil }
        if automatic && repeatMode == .one { return current }
        let next = index + delta
        if automatic && !ids.indices.contains(next) && repeatMode == .off { return nil }
        return ids[(next % ids.count + ids.count) % ids.count]
    }
}

