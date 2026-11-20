/// Normal-record drag acceptance, recovered from the reference's 3.8.5 normal scene:
/// actual global translation chooses an axis; predicted global x beyond ±100 logical
/// points requests a skip. The audio queue remains the authority on availability.
struct OrbitRecordDrag {
    enum Axis { case horizontal, vertical }
    private(set) var axis: Axis?
    private(set) var translationX: Double = 0
    private var owner: String?
    private var blocked = false

    mutating func update(owner key: String, x: Double, y: Double) {
        guard !blocked, x.isFinite, y.isFinite else { return }
        if owner == nil { owner = key }
        guard owner == key else { cancel(blockUntilRelease: true); return }
        if axis == nil { axis = abs(x) > abs(y) ? .horizontal : .vertical }
        translationX = axis == .horizontal ? x : 0
    }

    mutating func finish(owner key: String, predictedX: Double, active: Bool,
                         canSkipNext: Bool, canSkipPrevious: Bool) -> Int? {
        defer { cancel() }
        guard !blocked, active, owner == key, axis == .horizontal, predictedX.isFinite else { return nil }
        if predictedX < -100, canSkipNext { return 1 }
        if predictedX > 100, canSkipPrevious { return -1 }
        return nil
    }

    mutating func cancel(blockUntilRelease: Bool = false) {
        owner = nil
        axis = nil
        translationX = 0
        blocked = blockUntilRelease
    }
}
