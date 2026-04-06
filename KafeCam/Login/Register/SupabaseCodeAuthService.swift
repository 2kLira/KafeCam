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
                  gender: String, dateOfBirth: Date, age: Int, country: String, state: String) throws {
		guard Self.validateCode(phone) else { throw AuthError.invalidPhone }
		debugLog("[SupabaseAuth] Starting registration for phone: \(phone)")
		_ = try Self.blocking {
			let userId = try await SupaAuthService.signUpThenSignIn(code: phone, password: password, metaName: name, metaOrg: organization, metaPhone: phone, metaEmail: (email?.isEmpty == true ? nil : email))
			debugLog("[SupabaseAuth] User created with ID: \(userId)")
			
			// Ensure profile is properly synced
			do {
				let profiles = ProfilesRepository()
                let profile = try await profiles.upsertCurrentUserProfile(
                    name: name,
                    email: (email?.isEmpty == true ? nil : email),
                    phone: phone,
                    organization: organization,
                    gender: gender,
                    dateOfBirth: dateOfBirth,
                    age: age,
                    country: country,
                    state: state
                )
				debugLog("[SupabaseAuth] Profile synced - Name: \(profile.name ?? "nil"), Phone: \(profile.phone ?? "nil")")
				
				// Update display name
				if let full = profile.name?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
					let first = full.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? full
					UserDefaults.standard.set(first, forKey: "displayName")
					debugLog("[SupabaseAuth] Display name set to: \(first)")
				}
				// Also ensure auth metadata reflects profile values for proper display in Supabase Auth UI
				try? await SupaAuthService.updateAuthMetadata(name: name, phone: phone, email: (email?.isEmpty == true ? nil : email), organization: organization, locale: "es")
			} catch {
				debugLog("[SupabaseAuth] Profile sync after signup failed: \(error)")
			}
		}
		currentPhone = phone
		UserDefaults.standard.set(true, forKey: "kafe.isLoggedIn")
	}
	
	func login(phone: String, password: String) throws {
		guard Self.validateCode(phone) else { throw AuthError.userNotFoundOrBadPassword }
		debugLog("[SupabaseAuth] Starting login for phone: \(phone)")
		_ = try Self.blocking {
			let userId = try await SupaAuthService.signInOrSignUp(code: phone, password: password)
			debugLog("[SupabaseAuth] Logged in with User ID: \(userId)")
			
			// Ensure profile exists and sync display name
			do {
				let profiles = ProfilesRepository()
				let me = try await profiles.getOrCreateCurrent()
				debugLog("[SupabaseAuth] Profile fetched - Name: \(me.name ?? "nil"), Phone: \(me.phone ?? "nil")")
				
				if let full = me.name?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
					let first = full.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? full
					UserDefaults.standard.set(first, forKey: "displayName")
					debugLog("[SupabaseAuth] Display name refreshed to: \(first)")
				}
				// Keep auth metadata in sync on login as well
				try? await SupaAuthService.updateAuthMetadata(name: me.name, phone: me.phone, email: me.email, organization: me.organization, locale: me.locale ?? "es")
			} catch {
				debugLog("[SupabaseAuth] Profile sync after login failed: \(error)")
			}
		}
		currentPhone = phone
		UserDefaults.standard.set(true, forKey: "kafe.isLoggedIn")
	}
	
	func logout() {
		_ = try? Self.blocking { try await SupaAuthService.signOut() }
		currentPhone = nil
		UserDefaults.standard.set(false, forKey: "kafe.isLoggedIn")
	}
	
	// MARK: - Helpers
	/// Bridges async work into synchronous context using RunLoop polling.
	/// Avoids DispatchSemaphore which can deadlock on @MainActor.
	private static func blocking<T>(_ work: @escaping () async throws -> T) throws -> T {
		var output: Result<T, Error>? = nil
		Task.detached {
			do { output = .success(try await work()) }
			catch { output = .failure(error) }
		}
		// Spin RunLoop to keep UI responsive while waiting
		while output == nil {
			RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
		}
		return try output!.get()
	}
	
	private static func validateCode(_ code: String) -> Bool {
		let digits = CharacterSet.decimalDigits
		return code.count == 10 && code.unicodeScalars.allSatisfy { digits.contains($0) }
	}
}
