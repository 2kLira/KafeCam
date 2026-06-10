//
//  LanguageSection.swift
//  KafeCam
//
//  Created by Guillermo Lira on 15/10/25.
//

import SwiftUI

struct LanguageSection: View {
    @ObservedObject private var lm = LanguageManager.shared

    var body: some View {
        Section {
            Picker("Idioma", selection: $lm.appLanguage) {
                ForEach(lm.supported, id: \.code) { item in
                    Text(isBeta(item.code) ? "\(item.name) (Beta)" : item.name)
                        .tag(item.code)
                }
            }
            .pickerStyle(.navigationLink)

            if isBeta(lm.appLanguage) {
                Label {
                    Text("Traducción comunitaria en progreso. Algunos textos pueden aparecer en español.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            }
        } header: {
            Text("Idioma")
        }
    }

    private func isBeta(_ code: String) -> Bool {
        code == "tzo" || code == "nah"
    }
}
