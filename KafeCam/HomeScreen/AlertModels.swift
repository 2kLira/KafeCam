import SwiftUI

enum AlertLevel {
    case critical, warning, ok

    var bg: Color {
        switch self {
        case .critical: return Color.red.opacity(0.15)
        case .warning:  return Color.orange.opacity(0.15)
        case .ok:       return Color.green.opacity(0.15)
        }
    }
    var border: Color {
        switch self {
        case .critical: return Color.red
        case .warning:  return Color.orange   // Changed from .yellow — better contrast (≥3:1)
        case .ok:       return Color.green
        }
    }
    var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .warning:  return "exclamationmark.circle.fill"
        case .ok:       return "checkmark.seal.fill"
        }
    }
}

struct AlertItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let level: AlertLevel
}
