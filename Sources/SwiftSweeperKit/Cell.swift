public enum GameState {
    case playing, won, lost
}

public enum CellMark: Equatable {
    case none, flag, question
}

public struct Cell: Equatable {
    public var isMine: Bool = false
    public var isRevealed: Bool = false
    public var isExploded: Bool = false
    public var mark: CellMark = .none
    public var neighboringMines: Int = 0

    public init() {}

    public var isFlagged: Bool { mark == .flag }
    public var isQuestioned: Bool { mark == .question }
}
