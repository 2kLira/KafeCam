//
//  LanguageManager.swift
//  KafeCam
//

import SwiftUI
import Combine
import ObjectiveC

// MARK: - Bundle swapping

// Stores the resolved language bundle as an associated object on Bundle.main.
private var _languageBundleKey: Void?

// Subclass of Bundle that intercepts ALL localizedString calls and redirects
// them to the per-language bundle stored above. Falls back to Spanish when
// a key is missing from the target language.
private final class _LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String,
                                  value: String?,
                                  table tableName: String?) -> String {
        guard let override = objc_getAssociatedObject(self, &_languageBundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        let result = override.localizedString(forKey: key, value: value, table: tableName)
        // Key not found in target language — fall back to Spanish
        if result == key,
           let esPath = super.path(forResource: "es", ofType: "lproj"),
           let esBundle = Bundle(path: esPath) {
            return esBundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return result
    }
}

// MARK: - LanguageManager

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @AppStorage("appLanguage") var appLanguage: String = "es" {
        didSet {
            applyBundle(for: appLanguage)
            objectWillChange.send()
            let code = appLanguage
            Task { @MainActor in
                if let lang = CaficultorLanguage(rawValue: code) {
                    await CaficultorBrain.shared.setLanguage(lang)
                }
            }
        }
    }

    var currentLocale: Locale {
        Locale(identifier: appLanguage)
    }

    let supported: [(code: String, name: String, native: String)] = [
        ("es",  "Español",  "Español"),
        ("en",  "English",  "English"),
        ("tzo", "Tzotzil",  "Bats'i k'op"),
        ("nah", "Náhuatl",  "Nāhuatl")
    ]

    private init() {
        applyBundle(for: appLanguage)
    }

    // Activates the .lproj bundle for the given language code. If the lproj
    // doesn't exist on disk, resolves to "es" so the app never shows raw keys.
    private func applyBundle(for code: String) {
        let resolved = Bundle.main.path(forResource: code, ofType: "lproj") != nil ? code : "es"
        guard let path = Bundle.main.path(forResource: resolved, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return }
        objc_setAssociatedObject(Bundle.main, &_languageBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        object_setClass(Bundle.main, _LanguageBundle.self)
    }
}
