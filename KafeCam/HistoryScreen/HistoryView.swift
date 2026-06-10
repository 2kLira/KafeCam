import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyStore: HistoryStore
    @State private var searchText = ""

    private var filteredEntries: [HistoryEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return historyStore.entries }
        return historyStore.entries.filter {
            $0.prediction.localizedCaseInsensitiveContains(q)
            || ($0.diseaseName ?? "").localizedCaseInsensitiveContains(q)
            || $0.notes.localizedCaseInsensitiveContains(q)
        }
    }

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
            } else if filteredEntries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredEntries) { entry in
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
        .searchable(text: $searchText, prompt: "Buscar diagnóstico...")
        .tint(AppTheme.accent)
        .onAppear { historyStore.syncLocal() }
        .task { await historyStore.syncFromSupabase() }
    }
}

