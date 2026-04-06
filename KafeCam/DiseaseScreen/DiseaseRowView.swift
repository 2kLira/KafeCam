//
//  DiseaseRowView.swift
//  KafeCam
//
//  Created by Bruno Rivera on 11/09/25.
//

import SwiftUI

struct DiseaseRowView: View {
    let disease: DiseaseModel
    
    var body: some View {
        VStack(spacing: 12) {
            Image(disease.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipped()
                .cornerRadius(14)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(disease.name)
                    .font(.headline)
                    .lineLimit(1)
                 
                if let scientificName = disease.scientificName {
                    Text(scientificName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Image(systemName: "book.circle.fill")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    ScrollView {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(diseases) { item in
                DiseaseRowView(disease: DiseaseModel(name: item.name, scientificName: item.scientificName, description: item.description, impact: item.impact, prevention: item.prevention, imageName: item.imageName))
            }
        }
        .padding()
    }
}
