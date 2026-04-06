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
        didSet { objectWillChange.send() }
    }

    // Locale que inyectaremos en la app para que lea .strings del idioma elegido
    var currentLocale: Locale {
        Locale(identifier: appLanguage) // "es", "en", "tzo"
    }

    // Opciones visibles en el selector
    let supported: [(code: String, name: String)] = [
        ("es", "Español"),
        ("en", "English"),
        ("tzo", "Tzotzil (beta)")
    ]
}
