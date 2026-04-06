//
// CaptureDTO.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation

struct CaptureDTO: Codable, Identifiable, Hashable {
	let id: UUID
	let plotId: UUID
	let uploadedByUserId: UUID
	let takenAt: Date
	let photoKey: String
	let clientUUID: UUID?
	let createdOfflineAt: Date?
	let deviceModel: String?
	let checksumSha256: String?
	let createdAt: Date?
	var notes: String?  // Made var so we can update it
	
	enum CodingKeys: String, CodingKey {
		case id
		case plotId = "plot_id"
		case uploadedByUserId = "uploaded_by_user_id"
		case takenAt = "taken_at"
		case photoKey = "photo_key"
		case clientUUID = "client_uuid"
		case createdOfflineAt = "created_offline_at"
		case deviceModel = "device_model"
		case checksumSha256 = "checksum_sha256"
		case createdAt = "created_at"
		case notes
	}
}
