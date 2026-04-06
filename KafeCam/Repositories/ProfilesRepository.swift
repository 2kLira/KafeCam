//
// ProfilesRepository.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation
#if canImport(Supabase)
import Supabase
#endif

struct ProfilesRepository {
	#if canImport(Supabase)
    private struct UpsertProfilePayload: Encodable {
        let id: String
        let name: String?
        let email: String?
        let phone: String?
        let organization: String?
        let locale: String?
        let role: String?
        let gender: String?
        let date_of_birth: String?
        let age: Int?
        let country: String?
        let state: String?
        let about: String?
        let show_gender: Bool?
        let show_date_of_birth: Bool?
        let show_age: Bool?
        let show_country: Bool?
        let show_state: Bool?
        let show_about: Bool?

        enum CodingKeys: String, CodingKey {
            case id, name, email, phone, organization, locale, role, gender, date_of_birth, age, country, state, about, show_gender, show_date_of_birth, show_age, show_country, show_state, show_about
        }

        // Omit nils so we don't violate NOT NULL columns on upsert
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            if let name { try c.encode(name, forKey: .name) }
            if let email { try c.encode(email, forKey: .email) }
            if let phone { try c.encode(phone, forKey: .phone) }
            if let organization { try c.encode(organization, forKey: .organization) }
            if let locale { try c.encode(locale, forKey: .locale) }
            if let role { try c.encode(role, forKey: .role) }
            if let gender { try c.encode(gender, forKey: .gender) }
            if let date_of_birth { try c.encode(date_of_birth, forKey: .date_of_birth) }
            if let age { try c.encode(age, forKey: .age) }
            if let country { try c.encode(country, forKey: .country) }
            if let state { try c.encode(state, forKey: .state) }
            if let about { try c.encode(about, forKey: .about) }
            if let show_gender { try c.encode(show_gender, forKey: .show_gender) }
            if let show_date_of_birth { try c.encode(show_date_of_birth, forKey: .show_date_of_birth) }
            if let show_age { try c.encode(show_age, forKey: .show_age) }
            if let show_country { try c.encode(show_country, forKey: .show_country) }
            if let show_state { try c.encode(show_state, forKey: .show_state) }
            if let show_about { try c.encode(show_about, forKey: .show_about) }
        }
    }
	
    func upsertCurrentUserProfile(name: String?, email: String?, phone: String?, organization: String?,
                                 gender: String? = nil, dateOfBirth: Date? = nil, age: Int? = nil,
                                 country: String? = nil, state: String? = nil, about: String? = nil,
                                 showGender: Bool? = nil, showDateOfBirth: Bool? = nil, showAge: Bool? = nil,
                                 showCountry: Bool? = nil, showState: Bool? = nil, showAbout: Bool? = nil) async throws -> ProfileDTO {
		let userId = try await SupaAuthService.currentUserId()
        // Ensure row exists so we don't violate NOT NULL on insert; if missing, create minimal row first
        _ = try? await getOrCreateCurrent()
		let dobString: String?
		if let dob = dateOfBirth {
			let f = ISO8601DateFormatter()
			f.formatOptions = [.withFullDate]
			dobString = f.string(from: dob)
		} else { dobString = nil }
		let payload = UpsertProfilePayload(
			id: userId.uuidString,
			name: name?.trimmingCharacters(in: .whitespacesAndNewlines),
			email: email?.trimmingCharacters(in: .whitespacesAndNewlines),
			phone: phone?.trimmingCharacters(in: .whitespacesAndNewlines),
			organization: organization?.trimmingCharacters(in: .whitespacesAndNewlines),
			locale: "es",
            role: nil,
			gender: gender,
			date_of_birth: dobString,
			age: age,
			country: country,
			state: state,
			about: about,
			show_gender: showGender,
			show_date_of_birth: showDateOfBirth,
			show_age: showAge,
			show_country: showCountry,
			show_state: showState,
			show_about: showAbout
		)
        let updated: ProfileDTO = try await SupaClient.shared
            .from("profiles")
            .update(payload)
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
		return updated
	}
	
    func getCurrent() async throws -> ProfileDTO {
		let userId = try await SupaAuthService.currentUserId()
		let profile: ProfileDTO = try await SupaClient.shared
			.from("profiles")
			.select()
			.eq("id", value: userId.uuidString)
			.single()
			.execute()
			.value
		return profile
	}

    /// Fetch any profile by id (used by technician flows)
    func get(byId id: UUID) async throws -> ProfileDTO {
        let profile: ProfileDTO = try await SupaClient.shared
            .from("profiles")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        return profile
    }

    /// Ensure a profile row exists for the current user; create a populated row if missing, then return it.
    func getOrCreateCurrent() async throws -> ProfileDTO {
        do {
            // Try to fetch existing profile
            let profile = try await getCurrent()
            
            // If profile exists but critical fields are empty, populate them
            if (profile.phone == nil || profile.phone?.isEmpty == true || profile.name == nil || profile.name?.isEmpty == true) {
                // Get session metadata
                let session = try await SupaClient.shared.auth.session
                let loginCode = try? await SupaAuthService.currentLoginCode()
                let userMetadata = session.user.userMetadata
                
                // Extract metadata values
                let metaName = userMetadata["name"]?.stringValue
                let metaEmail = userMetadata["email"]?.stringValue  
                let metaPhone = userMetadata["phone"]?.stringValue ?? loginCode
                let metaOrg = userMetadata["organization"]?.stringValue
                
                // Update profile with any missing critical fields
                let updatedProfile = try await upsertCurrentUserProfile(
                    name: profile.name ?? metaName,
                    email: profile.email ?? metaEmail ?? session.user.email,
                    phone: profile.phone ?? metaPhone,
                    organization: profile.organization ?? metaOrg
                )
                return updatedProfile
            }
            
            return profile
        } catch {
            // Profile doesn't exist, create one with session metadata
            let userId = try await SupaAuthService.currentUserId()
            let session = try await SupaClient.shared.auth.session
            let loginCode = try? await SupaAuthService.currentLoginCode()
            let userMetadata = session.user.userMetadata
            
            // Extract metadata from session
            let metaName = userMetadata["name"]?.stringValue
            let metaEmail = userMetadata["email"]?.stringValue
            let metaPhone = userMetadata["phone"]?.stringValue ?? loginCode
            let metaOrg = userMetadata["organization"]?.stringValue
            
            // Create profile with all available metadata
			let payload = UpsertProfilePayload(
                id: userId.uuidString,
                name: metaName ?? (metaPhone ?? "Usuario"),
                email: metaEmail ?? session.user.email,
                phone: metaPhone,
				organization: metaOrg,
				locale: "es",
                role: "farmer",
				gender: nil,
				date_of_birth: nil,
				age: nil,
				country: nil,
				state: nil,
				about: nil,
				show_gender: nil,
				show_date_of_birth: nil,
				show_age: nil,
				show_country: nil,
				show_state: nil,
				show_about: nil
            )
            
			let _: ProfileDTO = try await SupaClient.shared
				.from("profiles")
				.upsert(payload, onConflict: "id")
				.select()
				.single()
				.execute()
				.value
                
            return try await getCurrent()
        }
    }

	/// Lists profiles for the Community view. Applies optional role filter and simple client-side search.
	/// - Parameters:
	///   - search: optional query matched against name/email/phone (client-side)
	///   - role: optional role filter ("farmer" or "technician")
	///   - limit: max rows to fetch from server (defaults 200)
	///   - offset: pagination offset
	func listAll(search: String? = nil, role: String? = nil, limit: Int = 200, offset: Int = 0) async throws -> [ProfileDTO] {
		let query = SupaClient.shared
			.from("profiles")
			.select()
			.order("created_at", ascending: false)
			.range(from: offset, to: offset + max(0, limit - 1))
		let rows: [ProfileDTO] = try await query.execute().value
		// Client-side filters to avoid builder type mismatches across SDK versions
		let filteredByRole: [ProfileDTO]
		if let role, !role.isEmpty {
			filteredByRole = rows.filter { ($0.role ?? "").lowercased() == role.lowercased() }
		} else {
			filteredByRole = rows
		}

		guard let q = search?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty else { return filteredByRole }
		let lowered = q.lowercased()
		return filteredByRole.filter { p in
			(p.name?.lowercased().contains(lowered) == true) ||
			(p.email?.lowercased().contains(lowered) == true) ||
			(p.phone?.lowercased().contains(lowered) == true)
		}
	}
	#else
	func upsertCurrentUserProfile(name: String?, email: String?, phone: String?, organization: String?) async throws -> ProfileDTO { throw NSError(domain: "supabase", code: -1) }
	func getCurrent() async throws -> ProfileDTO { throw NSError(domain: "supabase", code: -1) }
	func get(byId id: UUID) async throws -> ProfileDTO { throw NSError(domain: "supabase", code: -1) }
	func listAll(search: String? = nil, role: String? = nil, limit: Int = 200, offset: Int = 0) async throws -> [ProfileDTO] { [] }
	#endif
}
