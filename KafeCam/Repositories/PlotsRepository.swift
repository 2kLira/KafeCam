//
// PlotsRepository.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation
#if canImport(Supabase)
import Supabase
#endif

struct PlotsRepository {
	#if canImport(Supabase)
	func listPlots() async throws -> [PlotDTO] {
		let userId = try await SupaAuthService.currentUserId()
		let list: [PlotDTO] = try await SupaClient.shared
			.from("plots")
			.select()
			.eq("owner_user_id", value: userId.uuidString)
			.execute()
			.value
		return list
	}

    /// List plots for a specific owner (used by technician views)
    func listPlots(ownerUserId: UUID) async throws -> [PlotDTO] {
        let list: [PlotDTO] = try await SupaClient.shared
            .from("plots")
            .select()
            .eq("owner_user_id", value: ownerUserId.uuidString)
            .execute()
            .value
        return list
    }
	
	private struct NewPlotPayload: Encodable {
		let name: String
		let ownerUserId: String
		let lat: Double?
		let lon: Double?
		let region: String?
		
		enum CodingKeys: String, CodingKey {
			case name
			case ownerUserId = "owner_user_id"
			case lat
			case lon
			case region
		}
	}
	
	func createPlot(name: String, lat: Double?, lon: Double?, region: String?) async throws -> PlotDTO {
		let userId = try await SupaAuthService.currentUserId()
		let payload = NewPlotPayload(
			name: name,
			ownerUserId: userId.uuidString,
			lat: lat,
			lon: lon,
			region: region
		)
		let inserted: PlotDTO = try await SupaClient.shared
			.from("plots")
			.insert(payload)
			.select()
			.single()
			.execute()
			.value
		return inserted
	}
	
	/// Get a specific plot by ID
	func get(byId id: UUID) async throws -> PlotDTO? {
		let plots: [PlotDTO] = try await SupaClient.shared
			.from("plots")
			.select()
			.eq("id", value: id.uuidString)
			.execute()
			.value
		return plots.first
	}
	
	/// List plots for a specific owner with limit
	func listPlots(ownerId: UUID, limit: Int) async throws -> [PlotDTO] {
		let list: [PlotDTO] = try await SupaClient.shared
			.from("plots")
			.select()
			.eq("owner_user_id", value: ownerId.uuidString)
			.limit(limit)
			.execute()
			.value
		return list
	}
	#else
	func listPlots() async throws -> [PlotDTO] { [] }
	func listPlots(ownerUserId: UUID) async throws -> [PlotDTO] { [] }
	func createPlot(name: String, lat: Double?, lon: Double?, region: String?) async throws -> PlotDTO { throw NSError(domain: "supabase", code: -1) }
	func get(byId id: UUID) async throws -> PlotDTO? { nil }
	func listPlots(ownerId: UUID, limit: Int) async throws -> [PlotDTO] { [] }
	#endif
}
