//
// SupaClient.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation
#if canImport(Supabase)
import Supabase
#endif

enum SupaClient {
	#if canImport(Supabase)
	static let shared: SupabaseClient = {
		let client = SupabaseClient(
			supabaseURL: SupabaseConfig.url,
			supabaseKey: SupabaseConfig.anonKey
		)
		return client
	}()
	#endif
}

enum SupaAuthService {
	#if canImport(Supabase)
	static func signInDev() async throws {
		_ = try await SupaClient.shared.auth.signIn(
			email: SupabaseConfig.devEmail,
			password: SupabaseConfig.devPassword
		)
	}
	
	@discardableResult
	static func signInOrSignUp(code: String, password: String) async throws -> UUID {
		let emailAddr = "\(code)@kafe.local"
		// Only allow login for existing users, don't auto-create
		let session = try await SupaClient.shared.auth.signIn(email: emailAddr, password: password)
		return session.user.id
	}
	
	@discardableResult
	static func signUpThenSignIn(code: String, password: String, metaName: String?, metaOrg: String?, metaPhone: String?, metaEmail: String?) async throws -> UUID {
		let emailAddr = "\(code)@kafe.local"
		var metadata: [String: AnyJSON] = [:]
		if let metaName { metadata["name"] = .string(metaName) }
		if let metaOrg { metadata["organization"] = .string(metaOrg) }
		if let metaPhone { metadata["phone"] = .string(metaPhone) }
		if let metaEmail, !metaEmail.isEmpty { metadata["email"] = .string(metaEmail) }
		do {
			_ = try await SupaClient.shared.auth.signUp(
				email: emailAddr,
				password: password,
				data: metadata.isEmpty ? nil : metadata
			)
		} catch {
			let msg = String(describing: error).lowercased()
			if msg.contains("already registered") || msg.contains("user already") {
				throw AuthError.duplicatePhone
			}
			throw error
		}
		let session = try await SupaClient.shared.auth.signIn(email: emailAddr, password: password)
		return session.user.id
	}
	
	static func currentUserId() async throws -> UUID {
		try await SupaClient.shared.auth.session.user.id
	}
	
	static func signOut() async throws {
		try await SupaClient.shared.auth.signOut()
	}

		/// Extracts the 10-digit code from the current session email (e.g., 1234567890@kafe.local)
		static func currentLoginCode() async throws -> String? {
			let email = try await SupaClient.shared.auth.session.user.email ?? ""
			let code = email.split(separator: "@").first.map(String.init) ?? ""
			return code
		}

		/// Updates auth user metadata (name/phone/email/organization/locale)
		static func updateAuthMetadata(name: String?, phone: String?, email: String?, organization: String?, locale: String?) async throws {
			var metadata: [String: AnyJSON] = [:]
			if let name, !name.isEmpty { metadata["name"] = .string(name) }
			if let phone, !phone.isEmpty { metadata["phone"] = .string(phone) }
			if let organization, !organization.isEmpty { metadata["organization"] = .string(organization) }
			if let locale, !locale.isEmpty { metadata["locale"] = .string(locale) }
			if let email, !email.isEmpty { metadata["email"] = .string(email) }

			let attrs = UserAttributes(data: metadata.isEmpty ? nil : metadata)
			_ = try await SupaClient.shared.auth.update(user: attrs)
		}

		/// Updates the avatar_key metadata in auth.user
		static func updateAuthAvatar(avatarKey: String) async throws {
			let attrs = UserAttributes(data: ["avatar_key": .string(avatarKey)])
			_ = try await SupaClient.shared.auth.update(user: attrs)
		}
	#else
	static func signInDev() async throws { }
	@discardableResult
	static func signInOrSignUp(code: String, password: String) async throws -> UUID { UUID() }
	@discardableResult
	static func signUpThenSignIn(code: String, password: String, metaName: String?, metaOrg: String?, metaPhone: String?, metaEmail: String?) async throws -> UUID { UUID() }
	static func currentUserId() async throws -> UUID { UUID() }
	static func signOut() async throws { }
		static func currentLoginCode() async throws -> String? { nil }
	#endif
}
