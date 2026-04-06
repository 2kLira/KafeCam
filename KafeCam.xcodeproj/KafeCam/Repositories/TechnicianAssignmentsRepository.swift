//
// TechnicianAssignmentsRepository.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation
#if canImport(Supabase)
import Supabase
#endif

struct TechnicianAssignmentsRepository {
	#if canImport(Supabase)
	struct FarmerSummary: Codable, Identifiable, Hashable {
		let id: UUID
		let name: String?
		let phone: String?
		let email: String?
	}
	
	func listFarmersForCurrentTechnician() async throws -> [FarmerSummary] {
		let techId = try await SupaAuthService.currentUserId()
		// 1) Get farmer ids linked to this technician
		struct Link: Codable { let farmer_id: UUID }
		let links: [Link] = try await SupaClient.shared
			.from("technician_farmers")
			.select("farmer_id")
			.eq("technician_id", value: techId.uuidString)
			.execute()
			.value
		let ids = links.map { $0.farmer_id.uuidString }
		guard !ids.isEmpty else { return [] }
		// 2) Fetch profiles for those ids
		let farmers: [FarmerSummary] = try await SupaClient.shared
			.from("profiles")
			.select("id,name,phone,email")
			.`in`("id", values: ids)
			.execute()
			.value
		return farmers
	}
	
	func assign(farmerId: UUID) async throws {
		let techId = try await SupaAuthService.currentUserId()
		let payload: [String: String] = [
			"technician_id": techId.uuidString,
			"farmer_id": farmerId.uuidString
		]
		let _: Void = try await SupaClient.shared
			.from("technician_farmers")
			.insert(payload)
			.execute()
			.value
	}
	
	func unassign(farmerId: UUID) async throws {
		let techId = try await SupaAuthService.currentUserId()
		let _: Void = try await SupaClient.shared
			.from("technician_farmers")
			.delete()
			.eq("technician_id", value: techId.uuidString)
			.eq("farmer_id", value: farmerId.uuidString)
			.execute()
			.value
	}
	#else
	struct FarmerSummary: Codable, Identifiable, Hashable { let id: UUID; let name: String?; let phone: String?; let email: String? }
	func listFarmersForCurrentTechnician() async throws -> [FarmerSummary] { [] }
	func assign(farmerId: UUID) async throws { }
	func unassign(farmerId: UUID) async throws { }
	#endif
}
