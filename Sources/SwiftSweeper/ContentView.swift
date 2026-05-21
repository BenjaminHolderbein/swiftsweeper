import AppKit
import SwiftSweeperKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel(
        difficulty: GameViewModel.Difficulty(
            rawValue: UserDefaults.standard.string(forKey: "difficulty") ?? "easy"
        ) ?? .easy
    )
    @AppStorage("muted") private var muted: Bool = false
    @AppStorage("difficulty") private var difficultyRaw: String = GameViewModel.Difficulty.easy.rawValue
    @AppStorage("bestTime") private var bestTime: Int = 0
    @AppStorage("totalWins") private var totalWins: Int = 0
    @State private var isNewBest: Bool = false
    @State private var showingCustomSheet = false
    @State private var focusedRow: Int = 0
    @State private var focusedCol: Int = 0
    @FocusState private var boardFocused: Bool
    @AppStorage("customRows")  private var storedCustomRows: Int = 12
    @AppStorage("customCols")  private var storedCustomCols: Int = 12
    @AppStorage("customMines") private var storedCustomMines: Int = 20
    private let cellSize: CGFloat = 28
    private let outerPadding: CGFloat = 12
    private let topBarHeight: CGFloat = 32
    private let hudHeight: CGFloat = 40

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
        .focusable()
        .focusEffectDisabled()
        .focused($boardFocused)
        .onAppear {
            viewModel.customRows = storedCustomRows
            viewModel.customCols = storedCustomCols
            viewModel.customMines = storedCustomMines
            if viewModel.difficulty == .custom {
                viewModel.setCustom(rows: storedCustomRows,
                                    cols: storedCustomCols,
                                    mines: storedCustomMines)
            }
            // Center the keyboard cursor and grab focus.
            focusedRow = viewModel.rows / 2
            focusedCol = viewModel.cols / 2
            boardFocused = true
        }
        .onChange(of: viewModel.difficulty) { _, _ in
            // Clamp focus when board size changes (e.g. new difficulty).
            focusedRow = min(focusedRow, viewModel.rows - 1)
            focusedCol = min(focusedCol, viewModel.cols - 1)
        }
        .onKeyPress(.upArrow)    { focusedRow = max(0, focusedRow - 1); return .handled }
        .onKeyPress(.downArrow)  { focusedRow = min(viewModel.rows - 1, focusedRow + 1); return .handled }
        .onKeyPress(.leftArrow)  { focusedCol = max(0, focusedCol - 1); return .handled }
        .onKeyPress(.rightArrow) { focusedCol = min(viewModel.cols - 1, focusedCol + 1); return .handled }
        .onKeyPress(.space)      {
            viewModel.cellTapped(row: focusedRow, col: focusedCol); return .handled
        }
        .onKeyPress("f")         {
            viewModel.cellFlagged(row: focusedRow, col: focusedCol); return .handled
        }
        .onKeyPress(.return)     {
            if viewModel.gameState == .playing {
                viewModel.chord(row: focusedRow, col: focusedCol)
            } else {
                viewModel.resetGame()
            }
            return .handled
        }
        .onKeyPress("r")         { viewModel.resetGame(); return .handled }
        .sheet(isPresented: $showingCustomSheet) {
            CustomBoardSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.difficulty) { _, d in
            difficultyRaw = d.rawValue
        }
        .onChange(of: viewModel.customRows)  { _, v in storedCustomRows  = v }
        .onChange(of: viewModel.customCols)  { _, v in storedCustomCols  = v }
        .onChange(of: viewModel.customMines) { _, v in storedCustomMines = v }
        .onChange(of: viewModel.gameState) { _, newState in
            switch newState {
            case .won:
                totalWins += 1
                let t = viewModel.elapsedTime
                if bestTime == 0 || t < bestTime {
                    bestTime = t
                    isNewBest = true
                } else {
                    isNewBest = false
                }
                if !muted { NSSound(named: "Funk")?.play() }
            case .lost:
                if !muted { NSSound(named: "Bottle")?.play() }
            case .playing:
                break
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach([GameViewModel.Difficulty.easy, .medium, .hard], id: \.self) { d in
                    Button(d.label) { viewModel.setDifficulty(d) }
                }
                Divider()
                Button("Custom…") { showingCustomSheet = true }
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
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
        }
    }

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
            .background(GeometryReader { proxy in
                WindowReader(
                    onChange: { window in
                        ClickDispatcher.shared.window = window
                        publishGridFrame(proxy.frame(in: .global), window: window)
                    }
                ) { _ in
                    Color.clear
                        .onAppear { publishGridFrame(proxy.frame(in: .global), window: nil) }
                        .onChange(of: proxy.frame(in: .global)) { _, new in
                            publishGridFrame(new, window: ClickDispatcher.shared.window)
                        }
                }
            })
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.28))
                    .padding(6)
            )
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    private func publishGridFrame(_ frameInGlobal: CGRect, window: NSWindow?) {
        ClickDispatcher.shared.viewModel = viewModel
        ClickDispatcher.shared.rows = viewModel.rows
        ClickDispatcher.shared.cols = viewModel.cols
        ClickDispatcher.shared.cellSize = cellSize
        ClickDispatcher.shared.cellSpacing = 2
        ClickDispatcher.shared.gridFrameInWindowTL = frameInGlobal
        ClickDispatcher.shared.window = window
    }

    private func cellView(row: Int, col: Int) -> some View {
        // Clicks are dispatched via ClickDispatcher in the app-level NSEvent
        // monitor — the view here is visual only.
        GlassCellView(
            cell: viewModel.grid[row][col],
            size: cellSize,
            isFocused: row == focusedRow && col == focusedCol && boardFocused
        )
        .frame(width: cellSize, height: cellSize)
    }
}

#Preview {
    ContentView().frame(width: 420, height: 600)
}
