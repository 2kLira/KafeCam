import SwiftUI

struct ConsultaDetailView: View {
    let entry: HistoryEntry
    @State private var showInfo = false
    @State private var notesText: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Image(uiImage: entry.image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)

                    Text(entry.prediction)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    if let disease = entry.diseaseName, !disease.isEmpty {
                        Text("Enfermedad: \(disease.capitalized)")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }

                    Text("Estado: \(entry.status.rawValue.capitalized)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: {
                        showInfo.toggle()
                    }) {
                        Label("ℹ️ Infórmate", systemImage: "info.circle")
                    }

                    Divider().padding(.vertical, 10)

                    Text("📝 Notas de campo")
                        .font(.headline)
                        .padding(.top)

                    TextEditor(text: $notesText)
                        .frame(height: 200)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    Button(action: {
                        // Guardar notas
                    }) {
                        Label("Guardar nota", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Consulta")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showInfo) {
                InfoView(diseaseName: entry.diseaseName ?? "Desconocida")
            }
        }
        .onAppear {
            notesText = entry.notes
        }
    }
}
