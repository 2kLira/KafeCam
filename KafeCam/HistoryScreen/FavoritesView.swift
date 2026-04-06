import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var historyStore: HistoryStore
    private let accentColor = Color(red: 134/255.0, green: 155/255.0, blue: 116/255.0)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Favoritos")
                    .font(.largeTitle.bold())
                    .foregroundColor(accentColor)
                    .padding(.horizontal)

                let favorites = historyStore.favorites

                if favorites.isEmpty {
                    ContentUnavailableView(
                        "Sin favoritos",
                        systemImage: "heart.slash",
                        description: Text("Marca con un corazón tus fotos favoritas en el historial.")
                    )
                } else {
                    List(favorites) { entry in
                        NavigationLink {
                            HistoryDetailView(entry: entry)
                                .environmentObject(historyStore)
                        } label: {
                            HistoryRow(entry: entry)
                                .environmentObject(historyStore)
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favoritos")
            .navigationBarTitleDisplayMode(.inline)
            .tint(accentColor)
        }
    }
}

