import SwiftUI

enum Direction: CaseIterable {
    case up, down, left, right

    var delta: Position {
        switch self {
        case .up: return Position(x: 0, y: -1)
        case .down: return Position(x: 0, y: 1)
        case .left: return Position(x: -1, y: 0)
        case .right: return Position(x: 1, y: 0)
        }
    }

    var headSymbolName: String {
        switch self {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        }
    }
}

struct Position: Hashable {
    var x: Int
    var y: Int

    static func + (lhs: Position, rhs: Position) -> Position {
        Position(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}

enum SnakeStatus: Equatable {
    case idle
    case exiting
    case blocked
}

struct Snake: Identifiable, Equatable {
    let id: String
    var direction: Direction
    var segments: [Position] // 0 is head
    var length: Int
    var color: Color
    var status: SnakeStatus
}

enum GameState: Equatable {
    case intro
    case playing
    case won
}

enum GameConfig {
    static let gridSize: Int = 10
    static let cellSize: CGFloat = 36
    static let gap: CGFloat = 3

    static let initialSnakeCount: Int = 14

    static let palette: [Color] = [
        .green, .blue, .pink, .orange, .purple, .cyan, .mint, .yellow
    ]
}


