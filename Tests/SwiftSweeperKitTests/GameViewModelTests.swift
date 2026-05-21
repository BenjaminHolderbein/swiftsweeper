import XCTest
@testable import SwiftSweeperKit

@MainActor
final class GameViewModelTests: XCTestCase {

    func testInitialState() {
        let vm = GameViewModel(difficulty: .easy)
        XCTAssertEqual(vm.gameState, .playing)
        XCTAssertEqual(vm.grid.count, 9)
        XCTAssertEqual(vm.grid[0].count, 9)
        XCTAssertEqual(vm.flagsPlaced, 0)
        XCTAssertEqual(vm.elapsedTime, 0)
        // Mines aren't placed until the first tap.
        XCTAssertEqual(totalMines(vm), 0)
    }

    func testFirstTapPlacesMinesAndSpareNeighbors() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 4, col: 4)
        XCTAssertEqual(totalMines(vm), 10)
        for dr in -1...1 {
            for dc in -1...1 {
                let r = 4 + dr, c = 4 + dc
                XCTAssertFalse(vm.grid[r][c].isMine,
                               "(\(r),\(c)) should be safe on first tap")
            }
        }
        XCTAssertEqual(vm.gameState, .playing)
        XCTAssertTrue(vm.grid[4][4].isRevealed)
    }

    func testFlagCycle() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 0, col: 0)
        guard let (r, c) = firstUnrevealed(vm) else { return XCTFail("no unrevealed cell") }

        XCTAssertEqual(vm.grid[r][c].mark, .none)
        vm.cellFlagged(row: r, col: c)
        XCTAssertEqual(vm.grid[r][c].mark, .flag)
        XCTAssertEqual(vm.flagsPlaced, 1)

        vm.cellFlagged(row: r, col: c)
        XCTAssertEqual(vm.grid[r][c].mark, .question)
        XCTAssertEqual(vm.flagsPlaced, 0)

        vm.cellFlagged(row: r, col: c)
        XCTAssertEqual(vm.grid[r][c].mark, .none)
        XCTAssertEqual(vm.flagsPlaced, 0)
    }

    func testFlaggedCellIsProtectedFromReveal() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 0, col: 0)
        guard let (r, c) = firstUnrevealed(vm) else { return XCTFail() }
        vm.cellFlagged(row: r, col: c)
        vm.cellTapped(row: r, col: c)
        XCTAssertFalse(vm.grid[r][c].isRevealed)
    }

    func testHittingMineLosesAndMarksOnlyOneExploded() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 0, col: 0)
        guard let (r, c) = firstMine(vm) else { return XCTFail("no mines placed") }
        vm.cellTapped(row: r, col: c)
        XCTAssertEqual(vm.gameState, .lost)
        XCTAssertTrue(vm.grid[r][c].isExploded)
        let exploded = vm.grid.flatMap { $0 }.filter(\.isExploded).count
        XCTAssertEqual(exploded, 1, "only the clicked mine should be exploded")
        // All mines should be revealed on loss.
        let unrevealedMines = vm.grid.flatMap { $0 }.filter { $0.isMine && !$0.isRevealed }.count
        XCTAssertEqual(unrevealedMines, 0)
    }

    func testRevealingAllNonMinesWins() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 4, col: 4)
        for r in 0..<9 {
            for c in 0..<9 where !vm.grid[r][c].isMine && !vm.grid[r][c].isRevealed {
                vm.cellTapped(row: r, col: c)
            }
        }
        XCTAssertEqual(vm.gameState, .won)
        // Remaining mines auto-flagged on win.
        let unflaggedMines = vm.grid.flatMap { $0 }.filter { $0.isMine && !$0.isFlagged }.count
        XCTAssertEqual(unflaggedMines, 0)
        XCTAssertEqual(vm.flagsPlaced, 10)
    }

    func testSetDifficultyResetsBoard() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 0, col: 0)
        vm.setDifficulty(.medium)
        XCTAssertEqual(vm.gameState, .playing)
        XCTAssertEqual(vm.grid.count, 13)
        XCTAssertEqual(vm.grid[0].count, 13)
        XCTAssertEqual(vm.flagsPlaced, 0)
        let revealed = vm.grid.flatMap { $0 }.filter(\.isRevealed).count
        XCTAssertEqual(revealed, 0)
    }

    func testMineCountMatchesDifficulty() {
        for (diff, expected): (GameViewModel.Difficulty, Int) in
            [(.easy, 10), (.medium, 25), (.hard, 45)] {
            let vm = GameViewModel(difficulty: diff)
            vm.cellTapped(row: 1, col: 1)
            XCTAssertEqual(totalMines(vm), expected, "mines for \(diff)")
        }
    }

    func testNeighborCountsMatchPlacedMines() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 4, col: 4)
        for r in 0..<vm.rows {
            for c in 0..<vm.cols where !vm.grid[r][c].isMine {
                var expected = 0
                for dr in -1...1 {
                    for dc in -1...1 where !(dr == 0 && dc == 0) {
                        let nr = r + dr, nc = c + dc
                        if nr >= 0, nr < vm.rows, nc >= 0, nc < vm.cols,
                           vm.grid[nr][nc].isMine { expected += 1 }
                    }
                }
                XCTAssertEqual(vm.grid[r][c].neighboringMines, expected,
                               "neighbor count wrong at (\(r),\(c))")
            }
        }
    }

    func testTimerStartsOnFirstTap() {
        let vm = GameViewModel(difficulty: .easy)
        XCTAssertFalse(vm.isTimerRunning, "timer should not run before first tap")
        vm.cellTapped(row: 4, col: 4)
        XCTAssertTrue(vm.isTimerRunning, "timer should run after first tap")
    }

    func testTimerStopsOnWin() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 4, col: 4)
        for r in 0..<9 {
            for c in 0..<9 where !vm.grid[r][c].isMine && !vm.grid[r][c].isRevealed {
                vm.cellTapped(row: r, col: c)
            }
        }
        XCTAssertEqual(vm.gameState, .won)
        XCTAssertFalse(vm.isTimerRunning, "timer must stop when game is won")
    }

    func testTimerStopsOnLoss() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 0, col: 0)
        guard let (r, c) = firstMine(vm) else { return XCTFail() }
        vm.cellTapped(row: r, col: c)
        XCTAssertEqual(vm.gameState, .lost)
        XCTAssertFalse(vm.isTimerRunning, "timer must stop when game is lost")
    }

    func testTimerStopsOnResetAndSetDifficulty() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 0, col: 0)
        XCTAssertTrue(vm.isTimerRunning)
        vm.resetGame()
        XCTAssertFalse(vm.isTimerRunning, "timer must stop on reset")

        vm.cellTapped(row: 0, col: 0)
        XCTAssertTrue(vm.isTimerRunning)
        vm.setDifficulty(.medium)
        XCTAssertFalse(vm.isTimerRunning, "timer must stop when difficulty changes")
    }

    func testChordRevealsAdjacentWhenFlagsMatch() {
        let vm = GameViewModel(difficulty: .easy)
        // Force a known layout: tap (4,4) to place mines (avoiding 3x3 around it).
        vm.cellTapped(row: 4, col: 4)
        // Find a revealed numbered cell at the cascade boundary.
        guard let (r, c) = numberedRevealed(vm) else { return XCTFail("no numbered revealed cell") }
        let n = vm.grid[r][c].neighboringMines
        // Flag exactly the adjacent mines.
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let nr = r + dr, nc = c + dc
                if nr >= 0, nr < vm.rows, nc >= 0, nc < vm.cols, vm.grid[nr][nc].isMine {
                    vm.cellFlagged(row: nr, col: nc)
                }
            }
        }
        var flags = 0
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let nr = r + dr, nc = c + dc
                if nr >= 0, nr < vm.rows, nc >= 0, nc < vm.cols, vm.grid[nr][nc].isFlagged {
                    flags += 1
                }
            }
        }
        XCTAssertEqual(flags, n, "test setup: flagged count should equal neighbor mine count")
        vm.chord(row: r, col: c)
        // After chord, every non-flagged adjacent cell should be revealed.
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let nr = r + dr, nc = c + dc
                guard nr >= 0, nr < vm.rows, nc >= 0, nc < vm.cols else { continue }
                if !vm.grid[nr][nc].isFlagged {
                    XCTAssertTrue(vm.grid[nr][nc].isRevealed, "(\(nr),\(nc)) should be revealed after chord")
                }
            }
        }
    }

    func testChordNoopWhenFlagsDontMatch() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 4, col: 4)
        guard let (r, c) = numberedRevealed(vm) else { return XCTFail() }
        // Don't place flags. Snapshot grid.
        let before = vm.grid
        vm.chord(row: r, col: c)
        XCTAssertEqual(vm.grid, before, "chord with wrong flag count must do nothing")
    }

    func testCustomBoardClampsAndPlays() {
        let vm = GameViewModel()
        vm.setCustom(rows: 5, cols: 5, mines: 3)
        XCTAssertEqual(vm.difficulty, .custom)
        XCTAssertEqual(vm.rows, 5)
        XCTAssertEqual(vm.cols, 5)
        XCTAssertEqual(vm.mineCount, 3)
        vm.cellTapped(row: 2, col: 2)
        XCTAssertEqual(totalMines(vm), 3)
        XCTAssertEqual(vm.gameState, .playing)
    }

    func testCustomBoardEnforcesMineUpperBound() {
        let vm = GameViewModel()
        // Way too many mines for 5x5
        vm.setCustom(rows: 5, cols: 5, mines: 100)
        XCTAssertEqual(vm.mineCount, GameViewModel.maxMines(rows: 5, cols: 5))
    }

    func testCustomBoardEnforcesSideLimits() {
        let vm = GameViewModel()
        vm.setCustom(rows: 1, cols: 999, mines: 1)
        XCTAssertEqual(vm.rows, GameViewModel.minBoardSide)
        XCTAssertEqual(vm.cols, GameViewModel.maxBoardSide)
    }

    func testResetGameClearsEverything() {
        let vm = GameViewModel(difficulty: .easy)
        vm.cellTapped(row: 0, col: 0)
        vm.cellFlagged(row: 8, col: 8)
        vm.resetGame()
        XCTAssertEqual(vm.gameState, .playing)
        XCTAssertEqual(vm.flagsPlaced, 0)
        XCTAssertEqual(vm.elapsedTime, 0)
        XCTAssertEqual(totalMines(vm), 0, "mines cleared until next first tap")
        let revealed = vm.grid.flatMap { $0 }.filter(\.isRevealed).count
        XCTAssertEqual(revealed, 0)
    }

    // MARK: helpers

    private func totalMines(_ vm: GameViewModel) -> Int {
        vm.grid.flatMap { $0 }.filter(\.isMine).count
    }

    private func firstUnrevealed(_ vm: GameViewModel) -> (Int, Int)? {
        for r in 0..<vm.rows {
            for c in 0..<vm.cols where !vm.grid[r][c].isRevealed { return (r, c) }
        }
        return nil
    }

    private func firstMine(_ vm: GameViewModel) -> (Int, Int)? {
        for r in 0..<vm.rows {
            for c in 0..<vm.cols where vm.grid[r][c].isMine { return (r, c) }
        }
        return nil
    }

    private func numberedRevealed(_ vm: GameViewModel) -> (Int, Int)? {
        for r in 0..<vm.rows {
            for c in 0..<vm.cols {
                let cell = vm.grid[r][c]
                if cell.isRevealed && cell.neighboringMines > 0 { return (r, c) }
            }
        }
        return nil
    }
}
