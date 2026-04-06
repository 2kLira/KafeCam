//
//  DiseaseDetailView.swift
//  KafeCam
//
//  Created by Bruno Rivera Juárez on 11/09/25.
//

import SwiftUI

struct DiseaseDetailView: View {
    let disease: DiseaseModel
    private let labels = ["Descripción", "Impacto", "Prevención"]
    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    
    @State private var selectedScreen = 0
    
    var body: some View {
        
        let descriptions = [
            disease.description,
            disease.impact,
            disease.prevention,
        ]
        
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(disease.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(16)
                
                VStack(alignment: .leading, spacing: 8){
                    Text(disease.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(accentColor)
                    
                    if let scientificName = disease.scientificName {
                        Text(scientificName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Picker("Choose description", selection: $selectedScreen) {
                    ForEach(labels.indices, id: \.self) { index in
                        Text(labels[index])
                            .tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                if descriptions.indices.contains(selectedScreen) {
                    VStack(alignment: .leading, spacing: 8) {
                        if labels[selectedScreen] == "Prevención" {
                            Text("⚠️ Aviso - Se recomienda evitar la ingestión y el contacto directo con las sustancias mencionadas. Procura usar guantes para su manejo.")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        
                        ForEach(descriptions[selectedScreen].split(separator: "\n"), id: \.self) { line in
                            formatText(String(line))
                        }
                    }
                    .font(.body)
                }
            }
            .padding()
        }
        .navigationTitle("Detalles")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func formatText(_ line: String) -> some View {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedLine.starts(with: "•") {
            HStack(alignment: .top) {
                Text("•")
                Text(trimmedLine.dropFirst().trimmingCharacters(in: .whitespaces))
            }
        } else if let number = trimmedLine.first, number.isNumber {
             HStack(alignment: .top) {
                Text(String(trimmedLine.prefix(while: { $0.isNumber || $0 == "." })))
                Text(trimmedLine.drop(while: { $0.isNumber || $0 == "." }).trimmingCharacters(in: .whitespaces))
            }
        } else if trimmedLine.contains("**") {
            let parts = trimmedLine.components(separatedBy: "**")
            HStack(spacing: 0) {
                ForEach(parts.indices, id: \.self) { index in
                    Text(parts[index])
                        .fontWeight(index % 2 == 1 ? .bold : .regular)
                }
            }
        } else {
            Text(trimmedLine)
        }
    }
}


#Preview {
    DiseaseDetailView(disease: diseases[0])
}
