import Combine
import Foundation

@MainActor
public final class GameViewModel: ObservableObject {
    public enum Difficulty: String, CaseIterable {
        case easy, medium, hard
        public var label: String {
            switch self {
            case .easy: "Easy"
            case .medium: "Medium"
            case .hard: "Hard"
            }
        }
        public var rows: Int {
            switch self { case .easy: 9; case .medium: 13; case .hard: 16 }
        }
        public var cols: Int {
            switch self { case .easy: 9; case .medium: 13; case .hard: 16 }
        }
        public var mineCount: Int {
            switch self { case .easy: 10; case .medium: 25; case .hard: 45 }
        }
    }

    @Published public var difficulty: Difficulty = .easy
    public var rows: Int { difficulty.rows }
    public var cols: Int { difficulty.cols }
    public var mineCount: Int { difficulty.mineCount }

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
