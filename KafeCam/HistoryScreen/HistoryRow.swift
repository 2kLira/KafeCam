import SwiftUI

struct HistoryRow: View {
    @EnvironmentObject var historyStore: HistoryStore
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // Imagen de la foto
            Image(uiImage: entry.image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipped()
                .cornerRadius(12)

            // Texto con predicción y fecha
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.prediction)
                    .font(.headline)
                    .lineLimit(1)

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Botón de favorito ❤️
            Button {
                historyStore.toggleFavorite(for: entry)
            } label: {
                Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(entry.isFavorite ? .red : .gray)
            }
            .buttonStyle(.plain) // evita efecto de selección en el List
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

/* Preview updated for Swift 6 macro guidance */
#Preview("SizeThatFits", traits: .sizeThatFitsLayout) {
    HistoryRow(entry: HistoryEntry(
        image: UIImage(systemName: "photo")!,
        prediction: "Predicción: Planta sana",
        date: Date(),
        isFavorite: true
    ))
    .environmentObject(HistoryStore())
    .padding()
}

