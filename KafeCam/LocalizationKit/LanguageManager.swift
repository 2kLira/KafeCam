//
//  LanguageManager.swift
//  KafeCam
//
//  Created by Guillermo Lira on 15/10/25.
//


import SwiftUI
import Combine

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    // Idioma elegido por el usuario; persiste en UserDefaults
    @AppStorage("appLanguage") var appLanguage: String = "es" {
        didSet {
            objectWillChange.send()
            // Sincroniza la lengua activa con el cerebro de IA.
            let code = appLanguage
            Task { @MainActor in
                if let lang = CaficultorLanguage(rawValue: code) {
                    await CaficultorBrain.shared.setLanguage(lang)
                }
            }
        }
    }

    // Locale que inyectaremos en la app para que lea .strings del idioma elegido
    var currentLocale: Locale {
        Locale(identifier: appLanguage) // "es", "en", "tzo", "nah"
    }

    // Opciones visibles en el selector. Incluye nombre en idioma propio
    // (lo que ven los hablantes) además del nombre en español.
    let supported: [(code: String, name: String, native: String)] = [
        ("es",  "Español",  "Español"),
        ("en",  "English",  "English"),
        ("tzo", "Tzotzil",  "Bats'i k'op"),
        ("nah", "Náhuatl",  "Nāhuatl")
    ]
}
