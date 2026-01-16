import SwiftUI

struct SnakeEntityView: View {
    let snake: Snake
    let onTap: (String) -> Void
    let shakePhase: CGFloat

    var body: some View {
        ForEach(Array(snake.segments.enumerated()), id: \.offset) { index, seg in
            let isHead = index == 0
            let x = CGFloat(seg.x) * (GameConfig.cellSize + GameConfig.gap)
            let y = CGFloat(seg.y) * (GameConfig.cellSize + GameConfig.gap)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(snake.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                if isHead {
                    Image(systemName: snake.direction.headSymbolName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                } else {
                    Circle()
                        .fill(.white.opacity(0.28))
                        .frame(width: 10, height: 10)
                }
            }
            .frame(width: GameConfig.cellSize, height: GameConfig.cellSize)
            .offset(x: x, y: y)
            .zIndex(snake.status == .exiting ? 50 : 10)
            .modifier(isHead && snake.status == .blocked ? ShakeEffect(animatableData: shakePhase) : ShakeEffect(animatableData: 0))
            .onTapGesture { onTap(snake.id) }
            .animation(.linear(duration: 0.15), value: snake.segments)
        }
    }
}


