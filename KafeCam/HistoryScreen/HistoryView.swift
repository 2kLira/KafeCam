import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyStore: HistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tus fotos")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal)

            if historyStore.entries.isEmpty {
                ContentUnavailableView(
                    "Sin fotos",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Aún no guardas fotos. Captura una en Detecta y guárdala aquí.")
                )
            } else {
                List(historyStore.entries) { entry in
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
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.accent)
        .onAppear { historyStore.syncLocal() }
        .task { await historyStore.syncFromSupabase() }
    }
}

