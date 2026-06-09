import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var historyStore: HistoryStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Favoritos")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.accent)
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
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favoritos")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
        }
    }
}

