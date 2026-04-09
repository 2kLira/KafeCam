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
		let flag = UserDefaults.standard.bool(forKey: "kafe.isLoggedIn")
		return flag || (currentPhone != nil)
	}

    func register(name: String, email: String?, phone: String, password: String, organization: String,
                  gender: String, dateOfBirth: Date, age: Int, country: String, state: String) async throws {
		guard Self.validateCode(phone) else { throw AuthError.invalidPhone }
		let cleanEmail = email?.isEmpty == true ? nil : email
		debugLog("[SupabaseAuth] Starting registration for phone: \(phone)")
		let userId = try await SupaAuthService.signUpThenSignIn(
			code: phone, password: password,
			metaName: name, metaOrg: organization, metaPhone: phone, metaEmail: cleanEmail)
		debugLog("[SupabaseAuth] User created with ID: \(userId)")
		currentPhone = phone
		UserDefaults.standard.set(true, forKey: "kafe.isLoggedIn")
		// Profile sync is non-critical — run in background so register returns immediately
		let capName = name; let capEmail = cleanEmail; let capPhone = phone
		let capOrg = organization; let capGender = gender; let capDob = dateOfBirth
		let capAge = age; let capCountry = country; let capState = state
		Task {
			do {
				let profiles = ProfilesRepository()
				let profile = try await profiles.upsertCurrentUserProfile(
					name: capName, email: capEmail, phone: capPhone,
					organization: capOrg, gender: capGender, dateOfBirth: capDob,
					age: capAge, country: capCountry, state: capState
				)
				debugLog("[SupabaseAuth] Profile synced - Name: \(profile.name ?? "nil"), Phone: \(profile.phone ?? "nil")")
				if let full = profile.name?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
					let first = full.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? full
					UserDefaults.standard.set(first, forKey: "displayName")
					debugLog("[SupabaseAuth] Display name set to: \(first)")
				}
				try? await SupaAuthService.updateAuthMetadata(name: capName, phone: capPhone, email: capEmail, organization: capOrg, locale: "es")
			} catch {
				debugLog("[SupabaseAuth] Profile sync after signup failed: \(error)")
			}
		}
	}

	func login(phone: String, password: String) async throws {
		guard Self.validateCode(phone) else { throw AuthError.userNotFoundOrBadPassword }
		debugLog("[SupabaseAuth] Starting login for phone: \(phone)")
		let userId = try await SupaAuthService.signInOrSignUp(code: phone, password: password)
		debugLog("[SupabaseAuth] Logged in with User ID: \(userId)")
		currentPhone = phone
		UserDefaults.standard.set(true, forKey: "kafe.isLoggedIn")
		// Profile sync is non-critical — run in background so login returns immediately
		Task {
			do {
				let profiles = ProfilesRepository()
				let me = try await profiles.getOrCreateCurrent()
				debugLog("[SupabaseAuth] Profile fetched - Name: \(me.name ?? "nil"), Phone: \(me.phone ?? "nil")")
				if let full = me.name?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
					let first = full.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? full
					UserDefaults.standard.set(first, forKey: "displayName")
					debugLog("[SupabaseAuth] Display name refreshed to: \(first)")
				}
				try? await SupaAuthService.updateAuthMetadata(name: me.name, phone: me.phone, email: me.email, organization: me.organization, locale: me.locale ?? "es")
			} catch {
				debugLog("[SupabaseAuth] Profile sync after login failed: \(error)")
			}
		}
	}

	func logout() {
		Task { try? await SupaAuthService.signOut() }
		currentPhone = nil
		UserDefaults.standard.set(false, forKey: "kafe.isLoggedIn")
	}

	// MARK: - Helpers
	private static func validateCode(_ code: String) -> Bool {
		let digits = CharacterSet.decimalDigits
		return code.count == 10 && code.unicodeScalars.allSatisfy { digits.contains($0) }
	}
}
