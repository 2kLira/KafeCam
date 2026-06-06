//
// CapturesRepository.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation
#if canImport(Supabase)
import Supabase
#endif

struct CapturesRepository {
	// NOTE: The `upload_url` Edge Function path was removed — it had zero callers
	// and the function is not deployed. Real uploads go through
	// `StorageRepository.upload()` (see `CapturesService.saveCapture`).
	#if canImport(Supabase)
	private struct NewCapturePayload: Encodable {
		let plotId: String
		let uploadedByUserId: String
		let takenAt: String
		let photoKey: String
		let clientUUID: String?
		let createdOfflineAt: String?
		let deviceModel: String?
		let checksumSha256: String?
		
		enum CodingKeys: String, CodingKey {
			case plotId = "plot_id"
			case uploadedByUserId = "uploaded_by_user_id"
			case takenAt = "taken_at"
			case photoKey = "photo_key"
			case clientUUID = "client_uuid"
			case createdOfflineAt = "created_offline_at"
			case deviceModel = "device_model"
			case checksumSha256 = "checksum_sha256"
		}
	}
	
	func createCapture(plotId: UUID, takenAt: Date, photoKey: String, clientUUID: UUID? = nil, deviceModel: String? = nil, checksumSha256: String? = nil, createdOfflineAt: Date? = nil) async throws -> CaptureDTO {
		let userId = try await SupaAuthService.currentUserId()
		let iso = ISO8601DateFormatter()
		let payload = NewCapturePayload(
			plotId: plotId.uuidString,
			uploadedByUserId: userId.uuidString,
			takenAt: iso.string(from: takenAt),
			photoKey: photoKey,
			clientUUID: clientUUID?.uuidString,
			createdOfflineAt: createdOfflineAt.map { iso.string(from: $0) },
			deviceModel: deviceModel,
			checksumSha256: checksumSha256
		)
		// Upsert on (uploaded_by_user_id, client_uuid) so an offline retry of the
		// same capture updates the existing row instead of inserting a duplicate.
		// Requires the unique index from migration 20260529150000.
		let inserted: CaptureDTO = try await SupaClient.shared
			.from("captures")
			.upsert(payload, onConflict: "uploaded_by_user_id,client_uuid")
			.select()
			.single()
			.execute()
			.value
		return inserted
	}

    /// List captures for a specific user (used by technician views)
    func listCaptures(uploadedBy userId: UUID) async throws -> [CaptureDTO] {
        let items: [CaptureDTO] = try await SupaClient.shared
            .from("captures")
            .select()
            .eq("uploaded_by_user_id", value: userId.uuidString)
            .order("taken_at", ascending: false)
            .execute()
            .value
        return items
    }
    
    /// Update notes for a capture
    func updateNotes(captureId: UUID, notes: String?) async throws -> CaptureDTO {
        // Create a simple encodable struct for the update
        struct NotesUpdate: Encodable {
            let notes: String?
        }
        
        let updateData = NotesUpdate(notes: notes)
        
        let updated: CaptureDTO = try await SupaClient.shared
            .from("captures")
            .update(updateData)
            .eq("id", value: captureId.uuidString)
            .select()
            .single()
            .execute()
            .value
        return updated
    }
	#else
	func createCapture(plotId: UUID, takenAt: Date, photoKey: String, clientUUID: UUID? = nil, deviceModel: String? = nil, checksumSha256: String? = nil, createdOfflineAt: Date? = nil) async throws -> CaptureDTO { throw NSError(domain: "supabase", code: -1) }
	func listCaptures(uploadedBy userId: UUID) async throws -> [CaptureDTO] { [] }
    func updateNotes(captureId: UUID, notes: String?) async throws -> CaptureDTO { throw NSError(domain: "supabase", code: -1) }
	#endif
}
