import SwiftUI

struct HistoryRow: View {
    @EnvironmentObject var historyStore: HistoryStore
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with sync badge
            ZStack(alignment: .topTrailing) {
                Image(uiImage: entry.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if entry.isPendingSync {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white, .orange)
                        .offset(x: 6, y: -6)
                }
            }

            // Text section
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(for: entry.status))
                        .frame(width: 8, height: 8)
                    Text(displayPrediction)
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if entry.isPendingSync {
                    Label("Pendiente de subir", systemImage: "wifi.slash")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Favorite button — 44pt touch target
            Button {
                historyStore.toggleFavorite(for: entry)
            } label: {
                Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(entry.isFavorite ? .red : Color(.systemGray3))
                    .frame(width: AppTheme.minTouchTarget, height: AppTheme.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.isFavorite ? "Quitar de favoritos" : "Agregar a favoritos")
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    // Strip leading emoji prefix that classify() prepends to the stored prediction string.
    private var displayPrediction: String {
        let raw = entry.prediction
        let knownPrefixes = ["🌿 ", "⚠️ ", "🚨 ", "📷 "]
        for prefix in knownPrefixes where raw.hasPrefix(prefix) {
            return String(raw.dropFirst(prefix.count))
        }
        return raw
    }

    private func statusColor(for status: PlotStatus) -> Color {
        switch status {
        case .sano:     return AppTheme.statusHealthy
        case .sospecha: return AppTheme.statusSuspect
        case .enfermo:  return AppTheme.statusSick
        }
    }
}

#Preview("Sincronizado", traits: .sizeThatFitsLayout) {
    HistoryRow(entry: HistoryEntry(
        image: UIImage(systemName: "photo")!,
        prediction: "🌿 Hoja sana (92%)",
        date: Date(),
        isFavorite: true,
        status: .sano
    ))
    .environmentObject(HistoryStore())
    .padding()
}

#Preview("Pendiente de subir", traits: .sizeThatFitsLayout) {
    var entry = HistoryEntry(
        image: UIImage(systemName: "photo")!,
        prediction: "🚨 Roya del café (87%)",
        date: Date(),
        isFavorite: false,
        status: .enfermo
    )
    entry.isPendingSync = true
    return HistoryRow(entry: entry)
        .environmentObject(HistoryStore())
        .padding()
}
