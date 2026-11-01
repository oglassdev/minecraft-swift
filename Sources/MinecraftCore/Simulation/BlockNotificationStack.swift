struct BlockNotificationStack<Continuation: Sendable>: Sendable {
    enum Step: Sendable {
        case removed(BlockPosition, BlockState)
        case added(BlockPosition, BlockState)
        case neighbor(BlockPosition, changedKind: BlockKind)
        case continuation(Continuation)
    }

    private enum Frame: Sendable {
        case step(Step)
        case neighbors(BlockPosition, BlockKind, Int)
    }

    private var frames: [Frame] = []
    static var offsets: [BlockPosition] {
        [
            BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0),
            BlockPosition(0, -1, 0), BlockPosition(0, 1, 0),
            BlockPosition(0, 0, -1), BlockPosition(0, 0, 1),
        ]
    }

    mutating func push(_ continuation: Continuation) {
        frames.append(.step(.continuation(continuation)))
    }

    mutating func notify(at p: BlockPosition, changedKind: BlockKind) {
        frames.append(.neighbors(p, changedKind, 0))
    }

    mutating func changed(at p: BlockPosition, previous: BlockState?, current: BlockState?) {
        guard previous != current else { return }
        notify(at: p, changedKind: current?.kind ?? .air)
        if let current { frames.append(.step(.added(p, current))) }
        if let previous { frames.append(.step(.removed(p, previous))) }
    }

    mutating func added(at p: BlockPosition, state: BlockState?) {
        notify(at: p, changedKind: state?.kind ?? .air)
        if let state { frames.append(.step(.added(p, state))) }
    }

    mutating func next() -> Step? {
        guard let frame = frames.popLast() else { return nil }
        switch frame {
        case .step(let step): return step
        case .neighbors(let p, let kind, let index):
            if index < 5 { frames.append(.neighbors(p, kind, index + 1)) }
            return .neighbor(p.adding(Self.offsets[index]), changedKind: kind)
        }
    }
}
