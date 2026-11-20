/// Visual presentation only. Audio, queue selection and record progress do not live here.
struct TurntableChromeState: Equatable {
    enum Mode: Equatable { case collapsed, tools, appearance }

    private(set) var mode: Mode = .collapsed
    private(set) var revision = 0

    var showsTools: Bool { mode == .tools }
    var showsAppearance: Bool { mode == .appearance }

    mutating func reveal() {
        mode = .tools
        revision += 1
    }

    mutating func editAppearance() {
        mode = .appearance
        revision += 1
    }

    mutating func collapse() {
        mode = .collapsed
        revision += 1
    }

    /// A late idle job must not fold a newer interaction or the appearance editor.
    mutating func finishIdle(revision expected: Int) {
        guard expected == revision, mode == .tools else { return }
        collapse()
    }
}
