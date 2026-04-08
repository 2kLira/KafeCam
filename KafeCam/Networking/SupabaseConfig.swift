//
// SupabaseConfig.swift
// KafeCam
//
// Safe to commit — contains no secrets.
// Values are injected at build time from KafeCamSecrets.xcconfig (gitignored)
// via Info.plist substitution (INFOPLIST_KEY_SupabaseURL / INFOPLIST_KEY_SupabaseAnonKey).
//
// Setup: copy KafeCamSecrets.xcconfig.template → KafeCamSecrets.xcconfig,
// fill in your values, then wire the xcconfig in Xcode:
//   Project → Info tab → Configurations → set KafeCam to "KafeCamSecrets".
//

import Foundation

enum SupabaseConfig {

    /// HTTPS project URL, e.g. https://abcdefg.supabase.co
    /// Injected from SUPABASE_URL in KafeCamSecrets.xcconfig.
    static let url: URL = {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            !raw.isEmpty,
            !raw.hasPrefix("$("),        // un-substituted xcconfig placeholder
            raw.hasPrefix("https://"),   // guard against postgresql:// mistakes
            let url = URL(string: raw)
        else {
            fatalError(
                "[KafeCam] SupabaseURL is missing or invalid.\n" +
                "1. Copy KafeCamSecrets.xcconfig.template → KafeCamSecrets.xcconfig\n" +
                "2. Fill in your Supabase HTTPS project URL\n" +
                "3. Wire the xcconfig: Xcode → Project → Info → Configurations → KafeCamSecrets"
            )
        }
        return url
    }()

    /// Supabase Publishable (anon) key.
    /// Injected from SUPABASE_ANON_KEY in KafeCamSecrets.xcconfig.
    static let anonKey: String = {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
            !key.isEmpty,
            !key.hasPrefix("$(")         // un-substituted xcconfig placeholder
        else {
            fatalError(
                "[KafeCam] SupabaseAnonKey is missing.\n" +
                "1. Copy KafeCamSecrets.xcconfig.template → KafeCamSecrets.xcconfig\n" +
                "2. Fill in your Supabase Publishable key\n" +
                "3. Wire the xcconfig: Xcode → Project → Info → Configurations → KafeCamSecrets"
            )
        }
        return key
    }()
}
