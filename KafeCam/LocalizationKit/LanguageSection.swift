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
        Section(header: Text("Idioma")) {
            Picker("Idioma", selection: $lm.appLanguage) {
                ForEach(lm.supported, id: \.code) { item in
                    Text(item.name).tag(item.code)
                }
            }
            .pickerStyle(.navigationLink)

            Text("Tzotzil (beta) — puede contener errores")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}
