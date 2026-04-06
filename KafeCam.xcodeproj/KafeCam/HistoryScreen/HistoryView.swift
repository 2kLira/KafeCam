import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyStore: HistoryStore
    private let accentColor = Color(red: 134/255.0, green: 155/255.0, blue: 116/255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tus fotos")
                .font(.largeTitle.bold())
                .foregroundColor(accentColor)
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
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
        .onAppear { historyStore.syncLocal() }
        .task { await historyStore.syncFromSupabase() }
    }
}

