import SwiftUI

struct AuthCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 44/255, green: 44/255, blue: 46/255)   // iOS dark secondary surface
            : Color(red: 226/255, green: 219/255, blue: 199/255) // Warm beige for light mode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusLG)
                .fill(cardBackground)
        )
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 6)
    }
}
