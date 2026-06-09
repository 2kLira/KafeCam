import SwiftUI

// Module-level aliases — kept for backward compatibility with callers in HomeView.
let green1 = AppTheme.cardGreen1
let brown1 = AppTheme.cardBrown1
let green2 = AppTheme.cardGreen2
let brown2 = AppTheme.cardBrown2

struct ActionCardView: View {
    var color: Color
    var systemImage: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey

    init(color: Color, systemImage: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) {
        self.color = color
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }
    init(color: Color, systemImage: String, title: String, subtitle: String) {
        self.init(color: color,
                  systemImage: systemImage,
                  title: LocalizedStringKey(title),
                  subtitle: LocalizedStringKey(subtitle))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white)
                .padding(.bottom, 10)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.top, 2)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
        .shadow(color: color.opacity(0.28), radius: 8, x: 0, y: 4)
    }
}
