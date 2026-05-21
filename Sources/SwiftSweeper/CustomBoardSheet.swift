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

    private func startGame() {
        viewModel.setCustom(rows: rows, cols: cols, mines: mines)
        dismiss()
    }

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
                .keyboardShortcut(.cancelAction)

                Button(action: startGame) {
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
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            Spacer()
            TextField("", value: value, formatter: clampFormatter(range))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 60)
                .onSubmit { clamp(value, to: range); startGame() }
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
    }

    private func clamp(_ value: Binding<Int>, to range: ClosedRange<Int>) {
        value.wrappedValue = min(max(value.wrappedValue, range.lowerBound), range.upperBound)
    }

    private func clampFormatter(_ range: ClosedRange<Int>) -> NumberFormatter {
        let f = NumberFormatter()
        f.allowsFloats = false
        f.minimum = NSNumber(value: range.lowerBound)
        f.maximum = NSNumber(value: range.upperBound)
        return f
    }
}
