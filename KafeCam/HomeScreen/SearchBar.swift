//
//  SearchBar.swift
//  KafeCam
//
//  Created by Grecia Saucedo on 08/09/25.
//
import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar", text: $text)
                .focused($focused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
