//
//  AlertModels.swift
//  KafeCam
//
//  Created by Grecia Saucedo on 08/09/25.
//
import SwiftUI

enum AlertLevel {
    case critical, warning, ok
    
    var bg: Color {
        switch self {
        case .critical: return .red.opacity(0.18)
        case .warning:  return .yellow.opacity(0.22)
        case .ok:       return .green.opacity(0.18)
        }
    }
    var border: Color {
        switch self {
        case .critical: return .red
        case .warning:  return .yellow
        case .ok:       return .green
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
