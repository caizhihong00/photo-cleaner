import SwiftUI

struct BoardView: View {
    let snakes: [Snake]
    let onSnakeTap: (String) -> Void
    let shakePhases: [String: CGFloat]

    private var totalSize: CGFloat {
        CGFloat(GameConfig.gridSize) * GameConfig.cellSize + CGFloat(GameConfig.gridSize - 1) * GameConfig.gap
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.12, green: 0.14, blue: 0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 10)

            ZStack(alignment: .topLeading) {
                // Grid background
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(GameConfig.cellSize), spacing: GameConfig.gap), count: GameConfig.gridSize),
                    spacing: GameConfig.gap
                ) {
                    ForEach(0..<(GameConfig.gridSize * GameConfig.gridSize), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    }
                }
                .frame(width: totalSize, height: totalSize)

                // Snakes layer (can overflow when exiting)
                ZStack(alignment: .topLeading) {
                    ForEach(snakes) { snake in
                        SnakeEntityView(
                            snake: snake,
                            onTap: onSnakeTap,
                            shakePhase: shakePhases[snake.id] ?? 0
                        )
                    }
                }
                .frame(width: totalSize, height: totalSize, alignment: .topLeading)
                .allowsHitTesting(true)
            }
            .padding(14)
        }
    }
}


