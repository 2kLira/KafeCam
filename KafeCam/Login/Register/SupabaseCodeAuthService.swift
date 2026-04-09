//
// SupabaseCodeAuthService.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//


import Foundation

final class SupabaseCodeAuthService: AuthService {
    private(set) var currentPhone: String? = nil

    func isLoggedIn() -> Bool {
        UserDefaults.standard.bool(forKey: "kafe.isLoggedIn") || currentPhone != nil
    }

    // MARK: - Register

    func register(name: String, email: String?, phone: String, password: String,
                  organization: String, gender: String, dateOfBirth: Date,
                  age: Int, country: String, state: String) async throws {
        guard Self.validateCode(phone) else { throw AuthError.invalidPhone }
        debugLog("[SupabaseAuth] Starting registration for phone: \(phone)")

        #if canImport(Supabase)
        let userId = try await SupaAuthService.signUpThenSignIn(
            code: phone, password: password,
            metaName: name, metaOrg: organization,
            metaPhone: phone, metaEmail: email?.isEmpty == true ? nil : email
        )
        debugLog("[SupabaseAuth] User created with ID: \(userId)")

        do {
            let profiles = ProfilesRepository()
            let profile = try await profiles.upsertCurrentUserProfile(
                name: name,
                email: email?.isEmpty == true ? nil : email,
                phone: phone,
                organization: organization,
                gender: gender,
                dateOfBirth: dateOfBirth,
                age: age,
                country: country,
                state: state
            )
            debugLog("[SupabaseAuth] Profile synced - Name: \(profile.name ?? "nil")")

            if let full = profile.name?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
                let first = full.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? full
                await MainActor.run { UserDefaults.standard.set(first, forKey: "displayName") }
            }
            try? await SupaAuthService.updateAuthMetadata(
                name: name, phone: phone,
                email: email?.isEmpty == true ? nil : email,
                organization: organization, locale: "es"
            )
        } catch {
            debugLog("[SupabaseAuth] Profile sync after signup failed: \(error)")
        }
        #endif

        // Only mark logged-in after everything succeeded
        currentPhone = phone
        await MainActor.run { UserDefaults.standard.set(true, forKey: "kafe.isLoggedIn") }
    }

    // MARK: - Login

    func login(phone: String, password: String) async throws {
        guard Self.validateCode(phone) else { throw AuthError.userNotFoundOrBadPassword }
        debugLog("[SupabaseAuth] Starting login for phone: \(phone)")

        #if canImport(Supabase)
        let userId = try await SupaAuthService.signInOrSignUp(code: phone, password: password)
        debugLog("[SupabaseAuth] Logged in with User ID: \(userId)")

        do {
            let profiles = ProfilesRepository()
            let me = try await profiles.getOrCreateCurrent()
            debugLog("[SupabaseAuth] Profile fetched - Name: \(me.name ?? "nil")")

            if let full = me.name?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
                let first = full.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? full
                await MainActor.run { UserDefaults.standard.set(first, forKey: "displayName") }
            }
            try? await SupaAuthService.updateAuthMetadata(
                name: me.name, phone: me.phone, email: me.email,
                organization: me.organization, locale: me.locale ?? "es"
            )
        } catch {
            debugLog("[SupabaseAuth] Profile sync after login failed: \(error)")
        }
        #endif

        // Only mark logged-in after Supabase confirmed the session
        currentPhone = phone
        await MainActor.run { UserDefaults.standard.set(true, forKey: "kafe.isLoggedIn") }
    }

    // MARK: - Logout

    func logout() async {
        #if canImport(Supabase)
        do {
            try await SupaAuthService.signOut()
        } catch {
            debugLog("[SupabaseAuth] Sign out error (ignored): \(error)")
        }
        #endif
        currentPhone = nil
        await MainActor.run { UserDefaults.standard.set(false, forKey: "kafe.isLoggedIn") }
    }

    // MARK: - Validation

    private static func validateCode(_ code: String) -> Bool {
        code.count == 10 && code.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }
}
