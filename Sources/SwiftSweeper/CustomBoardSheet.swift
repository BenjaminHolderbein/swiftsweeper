import SwiftSweeperKit
import SwiftUI

struct CustomBoardSheet: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var rows: Int
    @State private var cols: Int
    @State private var mines: Int

    init(viewModel: GameViewModel) {
        self.viewModel = viewModel
        _rows = State(initialValue: viewModel.customRows)
        _cols = State(initialValue: viewModel.customCols)
        _mines = State(initialValue: viewModel.customMines)
    }

    private var maxMines: Int { GameViewModel.maxMines(rows: rows, cols: cols) }

    var body: some View {
        VStack(spacing: 16) {
            Text("Custom board")
                .font(.system(.title3, design: .rounded).weight(.bold))

            VStack(spacing: 10) {
                row("Rows", value: $rows, range: GameViewModel.minBoardSide...GameViewModel.maxBoardSide)
                row("Cols", value: $cols, range: GameViewModel.minBoardSide...GameViewModel.maxBoardSide)
                row("Mines", value: $mines, range: 1...maxMines)
            }
            .padding(14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Capsule())

                Button(action: {
                    viewModel.setCustom(rows: rows, cols: cols, mines: mines)
                    dismiss()
                }) {
                    Text("Start")
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive().tint(.blue), in: Capsule())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 280)
        .onChange(of: rows) { _, _ in clampMines() }
        .onChange(of: cols) { _, _ in clampMines() }
    }

    private func clampMines() {
        if mines > maxMines { mines = maxMines }
    }

    private func row(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .font(.system(.body, design: .monospaced))
                    .monospacedDigit()
                    .frame(minWidth: 40, alignment: .trailing)
            }
        }
    }
}
