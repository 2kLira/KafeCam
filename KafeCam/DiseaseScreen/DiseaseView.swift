//
//  DiseaseView.swift
//  KafeCam
//
//  Created by Bruno Rivera on 11/09/25.
//

import SwiftUI

struct DiseaseView: View {
    let diseaseList: [DiseaseModel]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    private let darkColor = Color(red: 82/255, green: 76/255, blue: 41/255)
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Enciclopedia de Enfermedades")
                    .font(.largeTitle.bold())
                    .foregroundStyle(accentColor)
                    .padding(.horizontal)
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(diseaseList) { item in
                            NavigationLink {
                                DiseaseDetailView(disease: item)
                            } label: {
                                DiseaseRowView(disease: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Infórmate")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    DiseaseView(diseaseList: diseases)
}
