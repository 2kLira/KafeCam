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
    /// Requests a short-lived signed upload URL from the Edge Function `upload_url`.
    /// The function runs with service role on the backend and returns a pre-signed
    /// PUT URL for direct upload to Supabase Storage, plus the object key used.
    ///
    /// Expected function response shape: { signedUrl: string, token?: string, objectKey?: string }
    /// - bucket and objectKey are determined by the function. We pass a suggested key.
    #if canImport(Supabase)
    private struct UploadURLResponse: Decodable { let signedUrl: String?; let signedURL: String?; let objectKey: String? }
    #endif

    /// Returns (objectKey, url) to perform a single PUT upload.
    func createSignedUploadURL(filename: String) async throws -> (objectKey: String, url: URL) {
        #if canImport(Supabase)
        let userId = try await SupaAuthService.currentUserId()
        // Suggest path inside captures bucket: <user-id>/<filename>
        let suggestedKey = "\(userId.uuidString)/\(filename)"

        // Call edge function
        let payload: [String: String] = [
            "objectKey": suggestedKey
        ]
        let data: Data = try await SupaClient.shared.functions
            .invoke("upload_url", options: .init(body: payload))
        let resp = try JSONDecoder().decode(UploadURLResponse.self, from: data)

        guard let urlStr = resp.signedUrl ?? resp.signedURL, let url = URL(string: urlStr) else {
            throw NSError(domain: "upload", code: -2, userInfo: [NSLocalizedDescriptionKey: "signedUrl missing from upload_url response"])
        }
        let key = resp.objectKey ?? suggestedKey
        return (objectKey: key, url: url)
        #else
        throw NSError(domain: "supabase", code: -1)
        #endif
    }
	
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
		let inserted: CaptureDTO = try await SupaClient.shared
			.from("captures")
			.insert(payload)
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
