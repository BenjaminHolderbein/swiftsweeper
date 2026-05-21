import SwiftSweeperKit
import SwiftUI

struct GlassCellView: View {
    let cell: Cell
    let size: CGFloat
    var isFocused: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    private let contentScale: CGFloat = 0.55

    var body: some View {
        let r = RoundedRectangle(cornerRadius: 6)
        Group {
            if cell.isRevealed {
                content
                    .frame(width: size, height: size)
                    .background(
                        cell.isExploded ? AnyShapeStyle(Color.red.opacity(0.6))
                                        : AnyShapeStyle(revealedFill),
                        in: r
                    )
            } else {
                content
                    .frame(width: size, height: size)
                    .glassEffect(.regular.interactive().tint(.white.opacity(0.18)), in: r)
            }
        }
        .font(.system(size: size * contentScale))
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.tint, lineWidth: 2)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if cell.isFlagged && !cell.isRevealed {
            // 🚩's visible mass sits in the upper-left of its bounding box, so
            // a small right/up nudge — matched to the offset in make_icon.swift —
            // makes it read as centered next to the "?" glyph.
            Text("🚩")
                .font(.system(size: size * 0.55))
                .offset(x: size * 0.043, y: -size * 0.052)
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

    private var revealedFill: Color {
        // Dark mode keeps the dark glass cell; light mode lightens to a
        // near-classic-Minesweeper gray so the classic palette reads correctly.
        colorScheme == .dark ? Color.black.opacity(0.45)
                             : Color(red: 0.75, green: 0.75, blue: 0.76)
    }

    private var numberColor: Color {
        if colorScheme == .light {
            switch cell.neighboringMines {
            case 1: Color(red: 0.00, green: 0.00, blue: 1.00)
            case 2: Color(red: 0.00, green: 0.50, blue: 0.00)
            case 3: Color(red: 1.00, green: 0.00, blue: 0.00)
            case 4: Color(red: 0.00, green: 0.00, blue: 0.50)
            case 5: Color(red: 0.50, green: 0.00, blue: 0.00)
            case 6: Color(red: 0.00, green: 0.50, blue: 0.50)
            case 7: Color(red: 0.00, green: 0.00, blue: 0.00)
            case 8: Color(red: 0.50, green: 0.50, blue: 0.50)
            default: .clear
            }
        } else {
            // Pairs 1/4 and 3/5 share hue and differ only in lightness — the
            // classic relationship, compressed into the legible range on a
            // dark cell.
            switch cell.neighboringMines {
            case 1: Color(red: 0.40, green: 0.64, blue: 1.00)
            case 2: Color(red: 0.30, green: 0.82, blue: 0.35)
            case 3: Color(red: 1.00, green: 0.30, blue: 0.30)
            case 4: Color(red: 0.20, green: 0.40, blue: 0.85)
            case 5: Color(red: 0.67, green: 0.27, blue: 0.27)
            case 6: Color(red: 0.30, green: 0.82, blue: 0.82)
            case 7: Color(red: 1.00, green: 1.00, blue: 1.00)
            case 8: Color(red: 0.55, green: 0.55, blue: 0.55)
            default: .clear
            }
        }
    }
}
