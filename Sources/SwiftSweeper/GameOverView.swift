import SwiftUI

struct GameOverView: View {
    let didWin: Bool
    let elapsedTime: Int
    let bestTime: Int
    let totalWins: Int
    let totalGames: Int
    let isNewBest: Bool
    let resetAction: () -> Void

    private var winPctText: String {
        guard totalGames > 0 else { return "—" }
        let pct = Double(totalWins) / Double(totalGames) * 100
        return String(format: "%.0f%%", pct)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(didWin ? "🎉" : "💥").font(.system(size: 36))
            Text(didWin ? "You won" : "Boom")
                .font(.system(.title3, design: .rounded).weight(.bold))

            if didWin {
                VStack(spacing: 6) {
                    statRow(label: "Time", value: formatTime(elapsedTime))
                    statRow(label: "Best", value: bestTime > 0 ? formatTime(bestTime) : "—")
                    statRow(label: "Total wins", value: "\(totalWins) / \(totalGames)")
                    statRow(label: "Win rate", value: winPctText)
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

            Button(action: resetAction) {
                Text(didWin ? "Play again" : "Try again")
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive().tint(didWin ? .green : .red), in: Capsule())
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
        let m = s / 60, r = s % 60
        return m > 0 ? String(format: "%d:%02d", m, r) : "\(r)s"
    }
}
