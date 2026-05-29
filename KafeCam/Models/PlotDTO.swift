//
// PlotDTO.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation

struct PlotDTO: Codable, Identifiable, Hashable {
	let id: UUID
	let name: String
	let lat: Double?
	let lon: Double?
	let altitudeM: Int?
	let region: String?
	let createdAt: Date?
	/// Nullable in the DB (`plots.owner_user_id` is nullable). Optional here to
	/// avoid a decode-crash on rows with no owner.
	let ownerUserId: UUID?

	enum CodingKeys: String, CodingKey {
		case id
		case name
		case lat
		case lon
		case altitudeM = "altitude_m"
		case region
		case createdAt = "created_at"
		case ownerUserId = "owner_user_id"
	}
}

extension JSONDecoder {
	static var supabaseDefault: JSONDecoder {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return decoder
	}
}
