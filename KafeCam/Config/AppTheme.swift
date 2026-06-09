import SwiftUI

// MARK: - Visual Design Tokens
// Single source of truth for colors, animation durations, corner radii, and touch targets.
// Use these instead of hardcoding values anywhere in the UI.

enum AppTheme {

    // MARK: - Brand Colors
    /// Forest green — primary accent used for CTAs, icons, and highlights.
    static let accent = Color(red: 88/255, green: 129/255, blue: 87/255)
    /// Earthy olive — secondary accent used for dark labels and tonal contrast.
    static let dark   = Color(red: 82/255,  green: 76/255,  blue: 41/255)

    // MARK: - Action Card Palette (HomeView grid)
    static let cardGreen1 = Color(red: 88/255,  green: 129/255, blue: 87/255) // Anticipa
    static let cardBrown1 = Color(red: 127/255, green: 85/255,  blue: 57/255) // Detecta
    static let cardGreen2 = Color(red: 106/255, green: 153/255, blue: 78/255) // Consulta
    static let cardBrown2 = Color(red: 166/255, green: 138/255, blue: 100/255) // Infórmate
    static let cardTeal   = Color(red: 70/255,  green: 120/255, blue: 108/255) // Asistente

    // MARK: - Semantic Status Colors (disease diagnosis)
    static let statusHealthy = Color(red: 34/255,  green: 139/255, blue: 74/255)
    static let statusSuspect = Color(red: 200/255, green: 120/255, blue: 20/255)
    static let statusSick    = Color(red: 190/255, green: 45/255,  blue: 35/255)

    // MARK: - Animation Durations (seconds)
    static let animFast:   Double = 0.15
    static let animNormal: Double = 0.25
    static let animSlow:   Double = 0.35

    // MARK: - Corner Radius
    static let radiusSM: CGFloat = 10
    static let radiusMD: CGFloat = 16
    static let radiusLG: CGFloat = 20

    // MARK: - Minimum Touch Target
    static let minTouchTarget: CGFloat = 44
}

// MARK: - Press Scale Button Style
/// Adds a subtle scale-down on press. Apply to tappable cards in place of .buttonStyle(.plain).
struct KafeCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: AppTheme.animFast), value: configuration.isPressed)
    }
}
