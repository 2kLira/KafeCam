//
// ProfileTabViewModel.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation
import SwiftUI

@MainActor
final class ProfileTabViewModel: ObservableObject {
	@AppStorage("displayName") private var displayNameAS: String = ""
	@AppStorage("avatarKey") private var avatarKeyAS: String = ""
	@Published var displayName: String = ""
	@Published var initials: String = ""
	@Published var email: String? = nil
	@Published var phone: String? = nil
	@Published var organization: String? = nil
	@Published var role: String? = nil
    @Published var incomingRequests: [AssignmentRequestDTO] = []
    @Published var technicianName: String? = nil
	@Published var avatarImage: UIImage? = nil
	@Published var isUploadingAvatar: Bool = false

	// Personal info
	@Published var gender: String? = nil
	@Published var dateOfBirth: Date? = nil
	@Published var age: Int? = nil
	@Published var country: String? = nil
	@Published var state: String? = nil
	@Published var about: String? = nil
	// Visibility prefs
	@Published var showGender: Bool = true
	@Published var showDateOfBirth: Bool = true
	@Published var showAge: Bool = true
	@Published var showCountry: Bool = true
	@Published var showState: Bool = true
	@Published var showAbout: Bool = true
	
	var canManageFarmers: Bool { (role == "technician") || (role == "admin") }
	
	func load() async {
		do {
			let userId = try await SupaAuthService.currentUserId()
			let uid = userId.uuidString.lowercased()
			print("[ProfileTabVM] Loading profile for User ID: \(userId)")
			
			let repo = ProfilesRepository()
			let p = try await repo.getOrCreateCurrent()
			
			print("[ProfileTabVM] Profile loaded - Name: \(p.name ?? "nil"), Phone: \(p.phone ?? "nil"), Email: \(p.email ?? "nil"), Org: \(p.organization ?? "nil"), Role: \(p.role ?? "nil")")
			
			displayName = p.name ?? ""
			initials = Self.makeInitials(from: p.name)
			email = p.email
			phone = p.phone
			organization = p.organization
			role = p.role

			// Personal info
			gender = p.gender
			dateOfBirth = p.dateOfBirth
			age = p.age
			country = p.country
			state = p.state
			about = p.about
			showGender = p.showGender ?? true
			showDateOfBirth = p.showDateOfBirth ?? true
			showAge = p.showAge ?? true
			showCountry = p.showCountry ?? true
			showState = p.showState ?? true
			showAbout = p.showAbout ?? true

			// Try to load avatar image
			#if canImport(Supabase)
			let session = try await SupaClient.shared.auth.session
			let storage = StorageRepository()
			var resolvedKey: String? = nil
			if let key = session.user.userMetadata["avatar_key"]?.stringValue, !key.isEmpty {
				resolvedKey = key
			} else {
				resolvedKey = self.avatarKeyAS.isEmpty ? nil : self.avatarKeyAS
			}
			if let key = resolvedKey {
				if let url = try? await storage.signedDownloadURL(objectKey: key, bucket: "avatars", expiresIn: 600) {
					if let (data, resp) = try? await URLSession.shared.data(from: url), let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode {
						self.avatarImage = UIImage(data: data)
						self.avatarKeyAS = key
					}
				}
			} else {
				// Fallback: try conventional key <userId>.jpg even if metadata is missing (lowercased)
				let fallbackKey = "\(uid).jpg"
				if let url = try? await storage.signedDownloadURL(objectKey: fallbackKey, bucket: "avatars", expiresIn: 600) {
					if let (data, resp) = try? await URLSession.shared.data(from: url), let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode {
						self.avatarImage = UIImage(data: data)
						self.avatarKeyAS = fallbackKey
					}
				}
			}
			#endif
			
			// Keep Home header in sync
			let fullName = p.name ?? ""
			let firstName = fullName.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? fullName
			displayNameAS = firstName
			
			print("[ProfileTabVM] Display values set - DisplayName: \(displayName), FirstName: \(firstName), Initials: \(initials)")

            // Farmer: load incoming requests
            if (p.role == "farmer") {
                incomingRequests = try await AssignmentRequestsRepository().listIncoming()
                // Load assigned technician(s)
                struct Row: Codable { let id: UUID; let name: String? }
                #if canImport(Supabase)
                let techs: [Row] = try await SupaClient.shared
                    .rpc("list_technicians_for_current_farmer")
                    .execute().value
                technicianName = techs.first?.name
                #else
                technicianName = nil
                #endif
            } else {
                incomingRequests = []
                technicianName = nil
            }
		} catch {
			print("[ProfileTabVM] Error loading profile: \(error)")
		}
	}

	func saveProfile(name: String?, email: String?, phone: String?, organization: String?,
	                gender: String?, dateOfBirth: Date?, age: Int?, country: String?, state: String?,
	                about: String?, showGender: Bool, showDateOfBirth: Bool, showAge: Bool, showCountry: Bool, showState: Bool, showAbout: Bool) async {
		#if canImport(Supabase)
		do {
			let repo = ProfilesRepository()
			let updated = try await repo.upsertCurrentUserProfile(name: name, email: email, phone: phone, organization: organization, gender: gender, dateOfBirth: dateOfBirth, age: age, country: country, state: state, about: about, showGender: showGender, showDateOfBirth: showDateOfBirth, showAge: showAge, showCountry: showCountry, showState: showState, showAbout: showAbout)
			// Reflect latest values locally
			displayName = updated.name ?? ""
			initials = Self.makeInitials(from: updated.name)
			self.email = updated.email
			self.phone = updated.phone
			self.organization = updated.organization
			self.gender = updated.gender
			self.dateOfBirth = updated.dateOfBirth
			self.age = updated.age
			self.country = updated.country
			self.state = updated.state
			self.about = updated.about
			self.showGender = updated.showGender ?? true
			self.showDateOfBirth = updated.showDateOfBirth ?? true
			self.showAge = updated.showAge ?? true
			self.showCountry = updated.showCountry ?? true
			self.showState = updated.showState ?? true
			self.showAbout = updated.showAbout ?? true
		} catch {
			// keep local changes; optionally log
			print("[ProfileTabVM] saveProfile error: \(error)")
		}
		#endif
	}

	/// Upload avatar image to Storage and update auth metadata for avatar_key
	func uploadAvatar(_ image: UIImage) async {
		#if canImport(Supabase)
		isUploadingAvatar = true
		defer { isUploadingAvatar = false }
		do {
			guard let data = image.jpegData(compressionQuality: 0.9) else { return }
			let userId = try await SupaAuthService.currentUserId()
			let uid = userId.uuidString.lowercased()
			let storage = StorageRepository()
			
			// Try multiple key formats to work with different RLS policy patterns
			let candidates = [
				"\(uid).jpg",           // lowercase UUID
				"\(uid)-avatar.jpg",    // lowercase UUID with suffix
				"\(userId.uuidString).jpg",  // original case UUID
			]
			
			var uploadError: Error? = nil
			var chosenKey: String? = nil
			
			for key in candidates {
				do {
					try await storage.upload(bucket: "avatars", objectKey: key, data: data, contentType: "image/jpeg", upsert: true)
					chosenKey = key
					print("[ProfileTabVM] Avatar uploaded successfully with key: \(key)")
					break
				} catch {
					print("[ProfileTabVM] Failed to upload with key \(key): \(error)")
					uploadError = error
					continue
				}
			}
			
			guard let finalKey = chosenKey else {
				print("[ProfileTabVM] All upload attempts failed. Last error: \(uploadError?.localizedDescription ?? "unknown")")
				throw uploadError ?? NSError(domain: "avatar", code: 400, userInfo: [NSLocalizedDescriptionKey: "All upload attempts failed"])
			}
			
			// Update auth metadata
			try await SupaAuthService.updateAuthAvatar(avatarKey: finalKey)
			
			// Update local state
			self.avatarImage = image
			self.avatarKeyAS = finalKey
			UserDefaults.standard.set(finalKey, forKey: "avatarKey")
			
			// Notify other parts of the app
			NotificationCenter.default.post(name: .init("kafe.avatar.updated"), object: nil)
			print("[ProfileTabVM] Avatar upload complete and metadata updated")
		} catch {
			print("[ProfileTabVM] Avatar upload error: \(error)")
		}
		#endif
	}
	
	func logout() {
		// clear app storage and sign out, then flip session flag back to login if available
		displayNameAS = ""
		Task { try? await SupaAuthService.signOut() }
		NotificationCenter.default.post(name: .init("kafe.session.logout"), object: nil)
	}
	
	private static func makeInitials(from name: String?) -> String {
		guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return "" }
		let parts = name.split(separator: " ")
		let first = parts.first?.first.map(String.init) ?? ""
		let second = parts.dropFirst().first?.first.map(String.init) ?? ""
		return (first + second).uppercased()
	}
}
