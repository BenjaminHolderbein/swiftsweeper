// Needed for Timer, ObservableObject etc.
import Combine
// The main UI framework
import SwiftUI

// Needed for NSViewRepresentable and mouse events on macOS
#if os(macOS)
    import AppKit
#endif

// MARK: - Supporting Data Structures

enum GameState {
    case playing, won, lost
}

// Added Equatable conformance for potentially better ForEach performance
enum CellMark: Equatable {
    case none, flag, question
}

struct Cell: Identifiable, Equatable {
    let id = UUID()
    var isMine: Bool = false
    var isRevealed: Bool = false
    var mark: CellMark = .none
    var neighboringMines: Int = 0

    var isFlagged: Bool { mark == .flag }
    var isQuestioned: Bool { mark == .question }

    static func == (lhs: Cell, rhs: Cell) -> Bool {
        return lhs.id == rhs.id
            && lhs.isRevealed == rhs.isRevealed && lhs.mark == rhs.mark
            && lhs.isMine == rhs.isMine
            && lhs.neighboringMines == rhs.neighboringMines
    }
}

// MARK: - Game View Model (Logic - Unchanged)

class GameViewModel: ObservableObject {
    enum Difficulty: String, CaseIterable {
        case easy, medium, hard
        var label: String {
            switch self {
            case .easy: "Easy"
            case .medium: "Medium"
            case .hard: "Hard"
            }
        }
        var rows: Int {
            switch self { case .easy: 9; case .medium: 13; case .hard: 16 }
        }
        var cols: Int {
            switch self { case .easy: 9; case .medium: 13; case .hard: 16 }
        }
        var mineCount: Int {
            switch self { case .easy: 10; case .medium: 25; case .hard: 45 }
        }
    }

    @Published var difficulty: Difficulty = .easy
    var rows: Int { difficulty.rows }
    var cols: Int { difficulty.cols }
    var mineCount: Int { difficulty.mineCount }

    @Published var grid: [[Cell]] = []
    @Published var gameState: GameState = .playing
    @Published var flagsPlaced: Int = 0
    @Published var elapsedTime: Int = 0

    private var timer: Timer?
    private var isFirstTap: Bool = true

    init(difficulty: Difficulty = .easy) {
        self.difficulty = difficulty
        resetGame()
    }

    func setDifficulty(_ d: Difficulty) {
        guard d != difficulty else { return }
        difficulty = d
        resetGame()
    }

    // --- Game Logic Methods (Identical to previous version) ---
    func resetGame() {
        stopGameTimer()
        gameState = .playing
        flagsPlaced = 0
        elapsedTime = 0
        isFirstTap = true
        grid = createNewGrid()
    }
    private func createNewGrid() -> [[Cell]] {
        Array(repeating: Array(repeating: Cell(), count: cols), count: rows)
    }
    private func setupBoard(firstTapRow: Int, firstTapCol: Int) {
        placeMines(avoidRow: firstTapRow, avoidCol: firstTapCol)
        calculateNeighborCounts()
    }
    private func placeMines(avoidRow: Int, avoidCol: Int) {
        var safeCells = Set<Int>()
        for dr in -1...1 {
            for dc in -1...1 {
                let nr = avoidRow + dr
                let nc = avoidCol + dc
                if isValid(row: nr, col: nc) {
                    safeCells.insert(nr * cols + nc)
                }
            }
        }
        var potentialMineLocations = (0..<rows).flatMap { r in (0..<cols).map { c in (r, c) } }
            .filter { !safeCells.contains($0.0 * cols + $0.1) }
        potentialMineLocations.shuffle()
        var placedMines = 0
        for (r, c) in potentialMineLocations.prefix(mineCount) {
            grid[r][c].isMine = true
            placedMines += 1
            if placedMines >= mineCount { break }
        }
        if placedMines < mineCount {
            print("Warning: Could only place \(placedMines)/\(mineCount) mines.")
        }
    }
    private func calculateNeighborCounts() {
        for r in 0..<rows {
            for c in 0..<cols {
                guard !grid[r][c].isMine else { continue }
                var count = 0
                for dr in -1...1 {
                    for dc in -1...1 {
                        if dr == 0 && dc == 0 { continue }
                        let nr = r + dr
                        let nc = c + dc
                        if isValid(row: nr, col: nc) && grid[nr][nc].isMine { count += 1 }
                    }
                }
                grid[r][c].neighboringMines = count
            }
        }
    }
    func cellTapped(row: Int, col: Int) {
        guard gameState == .playing, isValid(row: row, col: col) else { return }
        if isFirstTap {
            isFirstTap = false
            setupBoard(firstTapRow: row, firstTapCol: col)
            if timer == nil { startGameTimer() }
        } else if timer == nil && gameState == .playing {
            startGameTimer()
        }
        guard !grid[row][col].isRevealed && !grid[row][col].isFlagged else { return }
        grid[row][col].isRevealed = true
        if grid[row][col].isMine {
            triggerGameOver(won: false)
            return
        }
        if grid[row][col].neighboringMines == 0 { revealAdjacentCells(row: row, col: col) }
        checkWinCondition()
    }
    func cellFlagged(row: Int, col: Int) {
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
    private func revealAdjacentCells(row: Int, col: Int) {
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr
                let nc = col + dc
                if isValid(row: nr, col: nc) && !grid[nr][nc].isRevealed && !grid[nr][nc].isFlagged
                {
                    grid[nr][nc].isRevealed = true
                    if grid[nr][nc].neighboringMines == 0 { revealAdjacentCells(row: nr, col: nc) }
                }
            }
        }
    }
    private func checkWinCondition() {
        guard gameState == .playing else { return }
        let revealedCount = grid.flatMap { $0 }.filter { $0.isRevealed && !$0.isMine }.count
        let totalNonMineCells = (rows * cols) - mineCount
        if revealedCount == totalNonMineCells { triggerGameOver(won: true) }
    }
    private func triggerGameOver(won: Bool) {
        guard gameState == .playing else { return }
        gameState = won ? .won : .lost
        stopGameTimer()
        if !won { revealAllMines() } else { autoFlagRemainingMines() }
    }
    private func revealAllMines() {
        for r in 0..<rows {
            for c in 0..<cols { if grid[r][c].isMine { grid[r][c].isRevealed = true } }
        }
    }
    private func autoFlagRemainingMines() {
        var newFlags = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if grid[r][c].isMine && !grid[r][c].isFlagged {
                    grid[r][c].mark = .flag
                    newFlags += 1
                }
            }
        }
        flagsPlaced += newFlags
    }
    private func startGameTimer() {
        stopGameTimer()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.gameState == .playing { self.elapsedTime += 1 } else { self.stopGameTimer() }
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

// MARK: - Right Click Handling (macOS - Unchanged)

#if os(macOS)
    struct RightClickableView<Content: View>: NSViewRepresentable {
        var content: Content
        var onLeftClick: () -> Void
        var onRightClick: () -> Void

        func makeNSView(context: Context) -> RightClickHostingView<Content> {
            let hostingView = RightClickHostingView(rootView: content)
            hostingView.onLeftClick = onLeftClick
            hostingView.onRightClick = onRightClick
            return hostingView
        }
        func updateNSView(_ nsView: RightClickHostingView<Content>, context: Context) {
            nsView.rootView = content
        }
    }
    class RightClickHostingView<Content: View>: NSHostingView<Content> {
        var onLeftClick: (() -> Void)?
        var onRightClick: (() -> Void)?
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 1 { onLeftClick?() }
            super.mouseDown(with: event)
        }
        override func rightMouseDown(with event: NSEvent) { onRightClick?() /* Omit super */ }
    }
#endif  // os(macOS)

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var viewModel = GameViewModel(
        difficulty: GameViewModel.Difficulty(
            rawValue: UserDefaults.standard.string(forKey: "difficulty") ?? "easy"
        ) ?? .easy
    )
    @AppStorage("muted") private var muted: Bool = false
    @AppStorage("difficulty") private var difficultyRaw: String = "easy"
    @AppStorage("bestTime") private var bestTime: Int = 0
    @AppStorage("totalWins") private var totalWins: Int = 0
    @State private var isNewBest: Bool = false
    private let cellSize: CGFloat = 28
    private let outerPadding: CGFloat = 12

    var body: some View {
        ZStack {
            VStack(spacing: outerPadding) {
                topBar
                hudPanel
                gridPanel
            }
            .padding(outerPadding)
            .fixedSize()

            if viewModel.gameState != .playing {
                GameOverView(
                    didWin: viewModel.gameState == .won,
                    elapsedTime: viewModel.elapsedTime,
                    bestTime: bestTime,
                    totalWins: totalWins,
                    isNewBest: isNewBest,
                    resetAction: viewModel.resetGame
                )
                .transition(.opacity.combined(with: .scale))
                .zIndex(1)
            }
        }
        .onChange(of: viewModel.gameState) { _, newState in
            guard newState == .won else { return }
            totalWins += 1
            let t = viewModel.elapsedTime
            if bestTime == 0 || t < bestTime {
                bestTime = t
                isNewBest = true
            } else {
                isNewBest = false
            }
        }
    }

    private let topBarHeight: CGFloat = 32

    private var topBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(GameViewModel.Difficulty.allCases, id: \.self) { d in
                    Button(d.label) {
                        difficultyRaw = d.rawValue
                        viewModel.setDifficulty(d)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.difficulty.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: topBarHeight)
                .contentShape(Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .glassEffect(.regular.interactive(), in: Capsule())

            Spacer()

            Button {
                muted.toggle()
            } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: topBarHeight, height: topBarHeight)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
        }
    }

    private let hudHeight: CGFloat = 40

    private var hudPanel: some View {
        HStack(spacing: 10) {
            counter(
                icon: "flag.fill",
                tint: Color(red: 0.95, green: 0.36, blue: 0.36),
                value: max(0, viewModel.mineCount - viewModel.flagsPlaced)
            )
            .glassEffect(.regular, in: Capsule())
            Spacer(minLength: 0)
            Button(action: viewModel.resetGame) {
                Text(faceEmoji)
                    .font(.system(size: 22))
                    .frame(width: hudHeight, height: hudHeight)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            Spacer(minLength: 0)
            counter(
                icon: "timer",
                tint: Color(red: 0.45, green: 0.78, blue: 1.0),
                value: viewModel.elapsedTime
            )
            .glassEffect(.regular, in: Capsule())
        }
    }

    private func counter(icon: String, tint: Color, value: Int) -> some View {
        let clamped = max(0, min(999, value))
        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(String(format: "%03d", clamped))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .frame(height: hudHeight)
    }

    private var faceEmoji: String {
        switch viewModel.gameState {
        case .playing: "🙂"
        case .won:     "😎"
        case .lost:    "😵"
        }
    }

    private var gridPanel: some View {
        GlassEffectContainer(spacing: 2) {
            VStack(spacing: 2) {
                ForEach(0..<viewModel.grid.count, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<viewModel.grid[row].count, id: \.self) { col in
                            cellView(row: row, col: col)
                        }
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.28))
                    .padding(6)
            )
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func cellView(row: Int, col: Int) -> some View {
        let cell = viewModel.grid[row][col]
        let view = GlassCellView(cell: cell, size: cellSize)
        #if os(macOS)
        RightClickableView(
            content: view,
            onLeftClick:  { viewModel.cellTapped(row: row, col: col) },
            onRightClick: { viewModel.cellFlagged(row: row, col: col) }
        )
        .frame(width: cellSize, height: cellSize)
        #else
        view.frame(width: cellSize, height: cellSize)
            .onTapGesture { viewModel.cellTapped(row: row, col: col) }
            .onLongPressGesture(minimumDuration: 0.3) {
                viewModel.cellFlagged(row: row, col: col)
            }
        #endif
    }
}

// MARK: - Glass Cell

struct GlassCellView: View {
    let cell: Cell
    let size: CGFloat
    private let contentScale: CGFloat = 0.55

    var body: some View {
        let r = RoundedRectangle(cornerRadius: 6)
        Group {
            if cell.isRevealed {
                content
                    .frame(width: size, height: size)
                    .background(
                        cell.isMine ? AnyShapeStyle(Color.red.opacity(0.6))
                                    : AnyShapeStyle(Color.black.opacity(0.45)),
                        in: r
                    )
            } else {
                content
                    .frame(width: size, height: size)
                    .glassEffect(.regular.interactive().tint(.white.opacity(0.18)), in: r)
            }
        }
        .font(.system(size: size * contentScale))
    }

    @ViewBuilder
    private var content: some View {
        if cell.isFlagged && !cell.isRevealed {
            Text("🚩").font(.system(size: size * 0.6))
        } else if cell.isQuestioned && !cell.isRevealed {
            Text("?")
                .font(.system(size: size * 0.6, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        } else if cell.isRevealed {
            if cell.isMine {
                Text("💣").font(.system(size: size * 0.62))
            } else if cell.neighboringMines > 0 {
                Text("\(cell.neighboringMines)").foregroundStyle(numberColor)
            } else {
                Color.clear
            }
        } else {
            Color.clear
        }
    }

    private var numberColor: Color {
        switch cell.neighboringMines {
        case 1: .blue
        case 2: Color(red: 0.0, green: 0.6, blue: 0.2)
        case 3: .red
        case 4: Color(red: 0.0, green: 0.0, blue: 0.6)
        case 5: Color(red: 0.6, green: 0.0, blue: 0.0)
        case 6: Color(red: 0.0, green: 0.55, blue: 0.55)
        case 7: .primary
        case 8: .secondary
        default: .clear
        }
    }
}

// MARK: - Game Over

struct GameOverView: View {
    let didWin: Bool
    let elapsedTime: Int
    let bestTime: Int
    let totalWins: Int
    let isNewBest: Bool
    let resetAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(didWin ? "🎉" : "💥")
                .font(.system(size: 36))
            Text(didWin ? "You won" : "Boom")
                .font(.system(.title3, design: .rounded).weight(.bold))

            if didWin {
                VStack(spacing: 6) {
                    statRow(label: "Time", value: formatTime(elapsedTime))
                    statRow(label: "Best", value: bestTime > 0 ? formatTime(bestTime) : "—")
                    statRow(label: "Total wins", value: "\(totalWins)")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))

                if isNewBest {
                    Label("New best time", systemImage: "trophy.fill")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.yellow)
                }
            }

            Button(didWin ? "Play again" : "Try again", action: resetAction)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive().tint(didWin ? .green : .red),
                             in: Capsule())
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 26)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit().fontWeight(.semibold)
        }
        .font(.system(.subheadline, design: .rounded))
        .frame(width: 150)
    }

    private func formatTime(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return m > 0 ? String(format: "%d:%02d", m, r) : "\(r)s"
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 420, height: 600)
    }
}
