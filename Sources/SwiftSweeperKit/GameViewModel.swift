import Combine
import Foundation

@MainActor
public final class GameViewModel: ObservableObject {
    public enum Difficulty: String, CaseIterable {
        case easy, medium, hard, custom
        public var label: String {
            switch self {
            case .easy: "Easy"
            case .medium: "Medium"
            case .hard: "Hard"
            case .custom: "Custom"
            }
        }
        /// Built-in preset dimensions. `.custom` returns nil — caller must
        /// supply dimensions from elsewhere (the view model's custom* props).
        public var preset: (rows: Int, cols: Int, mines: Int)? {
            switch self {
            case .easy:   (9, 9, 10)
            case .medium: (13, 13, 25)
            case .hard:   (16, 16, 45)
            case .custom: nil
            }
        }
    }

    public static let minBoardSide = 5
    public static let maxBoardSide = 30

    @Published public var difficulty: Difficulty = .easy
    @Published public var customRows: Int = 12
    @Published public var customCols: Int = 12
    @Published public var customMines: Int = 20

    public var rows: Int { difficulty.preset?.rows ?? customRows }
    public var cols: Int { difficulty.preset?.cols ?? customCols }
    public var mineCount: Int { difficulty.preset?.mines ?? customMines }

    /// Largest mine count that still leaves room for the first-tap safe zone
    /// (the clicked cell + its 8 neighbors).
    public static func maxMines(rows: Int, cols: Int) -> Int {
        max(1, rows * cols - 9)
    }

    @Published public var grid: [[Cell]] = []
    @Published public var gameState: GameState = .playing
    @Published public var flagsPlaced: Int = 0
    @Published public var elapsedTime: Int = 0

    private var timer: Timer?
    private var isFirstTap: Bool = true

    public var isTimerRunning: Bool { timer != nil }

    isolated deinit {
        timer?.invalidate()
    }

    public init(difficulty: Difficulty = .easy) {
        self.difficulty = difficulty
        resetGame()
    }

    public func setDifficulty(_ d: Difficulty) {
        guard d != difficulty else { return }
        difficulty = d
        resetGame()
    }

    public func setCustom(rows: Int, cols: Int, mines: Int) {
        let r = min(max(rows, Self.minBoardSide), Self.maxBoardSide)
        let c = min(max(cols, Self.minBoardSide), Self.maxBoardSide)
        let m = min(max(mines, 1), Self.maxMines(rows: r, cols: c))
        customRows = r
        customCols = c
        customMines = m
        if difficulty != .custom { difficulty = .custom }
        resetGame()
    }

    public func resetGame() {
        stopGameTimer()
        gameState = .playing
        flagsPlaced = 0
        elapsedTime = 0
        isFirstTap = true
        grid = Array(repeating: Array(repeating: Cell(), count: cols), count: rows)
    }

    public func cellTapped(row: Int, col: Int) {
        guard gameState == .playing, isValid(row: row, col: col) else { return }
        if isFirstTap {
            isFirstTap = false
            placeMines(avoidRow: row, avoidCol: col)
            calculateNeighborCounts()
            startGameTimer()
        }
        guard !grid[row][col].isRevealed && !grid[row][col].isFlagged else { return }
        grid[row][col].isRevealed = true
        if grid[row][col].isMine {
            grid[row][col].isExploded = true
            triggerGameOver(won: false)
            return
        }
        if grid[row][col].neighboringMines == 0 { revealAdjacentCells(row: row, col: col) }
        checkWinCondition()
    }

    public func cellFlagged(row: Int, col: Int) {
        guard gameState == .playing, isValid(row: row, col: col) else { return }
        guard !grid[row][col].isRevealed else { return }
        let prev = grid[row][col].mark
        switch prev {
        case .none:     grid[row][col].mark = .flag
        case .flag:     grid[row][col].mark = .question
        case .question: grid[row][col].mark = .none
        }
        if prev == .flag { flagsPlaced -= 1 }
        if grid[row][col].mark == .flag { flagsPlaced += 1 }
    }

    /// Classic chord: when the user presses left+right on a revealed numbered
    /// cell whose adjacent flag count matches its mine count, reveal every
    /// adjacent un-flagged, un-revealed cell. Misflagging (a non-mine flagged
    /// as a mine) causes the chord to step on a real mine — game over.
    public func chord(row: Int, col: Int) {
        guard gameState == .playing, isValid(row: row, col: col) else { return }
        let cell = grid[row][col]
        guard cell.isRevealed, cell.neighboringMines > 0 else { return }
        var adjacentFlags = 0
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let nr = row + dr, nc = col + dc
                if isValid(row: nr, col: nc), grid[nr][nc].isFlagged { adjacentFlags += 1 }
            }
        }
        guard adjacentFlags == cell.neighboringMines else { return }
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let nr = row + dr, nc = col + dc
                guard isValid(row: nr, col: nc) else { continue }
                let n = grid[nr][nc]
                if !n.isFlagged && !n.isRevealed {
                    cellTapped(row: nr, col: nc)
                    if gameState != .playing { return }
                }
            }
        }
    }

    private func placeMines(avoidRow: Int, avoidCol: Int) {
        var safeCells = Set<Int>()
        for dr in -1...1 {
            for dc in -1...1 {
                let nr = avoidRow + dr, nc = avoidCol + dc
                if isValid(row: nr, col: nc) { safeCells.insert(nr * cols + nc) }
            }
        }
        var locations = (0..<rows).flatMap { r in (0..<cols).map { c in (r, c) } }
            .filter { !safeCells.contains($0.0 * cols + $0.1) }
        locations.shuffle()
        for (r, c) in locations.prefix(mineCount) { grid[r][c].isMine = true }
    }

    private func calculateNeighborCounts() {
        for r in 0..<rows {
            for c in 0..<cols {
                guard !grid[r][c].isMine else { continue }
                var count = 0
                for dr in -1...1 {
                    for dc in -1...1 where !(dr == 0 && dc == 0) {
                        let nr = r + dr, nc = c + dc
                        if isValid(row: nr, col: nc) && grid[nr][nc].isMine { count += 1 }
                    }
                }
                grid[r][c].neighboringMines = count
            }
        }
    }

    private func revealAdjacentCells(row: Int, col: Int) {
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let nr = row + dr, nc = col + dc
                if isValid(row: nr, col: nc) && !grid[nr][nc].isRevealed && !grid[nr][nc].isFlagged {
                    grid[nr][nc].isRevealed = true
                    if grid[nr][nc].neighboringMines == 0 { revealAdjacentCells(row: nr, col: nc) }
                }
            }
        }
    }

    private func checkWinCondition() {
        guard gameState == .playing else { return }
        let revealedCount = grid.flatMap { $0 }.filter { $0.isRevealed && !$0.isMine }.count
        if revealedCount == (rows * cols) - mineCount { triggerGameOver(won: true) }
    }

    private func triggerGameOver(won: Bool) {
        guard gameState == .playing else { return }
        gameState = won ? .won : .lost
        stopGameTimer()
        if !won { revealAllMines() } else { autoFlagRemainingMines() }
    }

    private func revealAllMines() {
        for r in 0..<rows {
            for c in 0..<cols where grid[r][c].isMine { grid[r][c].isRevealed = true }
        }
    }

    private func autoFlagRemainingMines() {
        var newFlags = 0
        for r in 0..<rows {
            for c in 0..<cols where grid[r][c].isMine && !grid[r][c].isFlagged {
                grid[r][c].mark = .flag
                newFlags += 1
            }
        }
        flagsPlaced += newFlags
    }

    private func startGameTimer() {
        stopGameTimer()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.gameState == .playing { self.elapsedTime += 1 } else { self.stopGameTimer() }
            }
        }
    }

    private func stopGameTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func isValid(row: Int, col: Int) -> Bool {
        row >= 0 && row < rows && col >= 0 && col < cols
    }
}
