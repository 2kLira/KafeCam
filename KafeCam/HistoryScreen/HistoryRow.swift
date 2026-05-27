import SwiftUI

struct HistoryRow: View {
    @EnvironmentObject var historyStore: HistoryStore
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // Imagen con badge de pendiente
            ZStack(alignment: .topTrailing) {
                Image(uiImage: entry.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipped()
                    .cornerRadius(12)

                if entry.isPendingSync {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white, .orange)
                        .offset(x: 6, y: -6)
                }
            }

            // Texto con predicción, fecha y estado de sincronización
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.prediction)
                    .font(.headline)
                    .lineLimit(1)

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

            // Botón de favorito ❤️
            Button {
                historyStore.toggleFavorite(for: entry)
            } label: {
                Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(entry.isFavorite ? .red : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

#Preview("Sincronizado", traits: .sizeThatFitsLayout) {
    HistoryRow(entry: HistoryEntry(
        image: UIImage(systemName: "photo")!,
        prediction: "🌿 Hoja sana (92%)",
        date: Date(),
        isFavorite: true
    ))
    .environmentObject(HistoryStore())
    .padding()
}

#Preview("Pendiente de subir", traits: .sizeThatFitsLayout) {
    var entry = HistoryEntry(
        image: UIImage(systemName: "photo")!,
        prediction: "🚨 Roya del café (87%)",
        date: Date(),
        isFavorite: false
    )
    entry.isPendingSync = true
    return HistoryRow(entry: entry)
        .environmentObject(HistoryStore())
        .padding()
}

