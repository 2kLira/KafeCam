import SwiftUI

struct InfoView: View {
    let diseaseName: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Información sobre: \(diseaseName)")
                        .font(.title2)
                        .bold()
                    
                    Text("Aquí puedes agregar información detallada sobre la enfermedad detectada.")
                        .font(.body)
                }
                .padding()
            }
            .navigationTitle("Información")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}
