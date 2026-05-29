//
// CapturesService.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation
#if canImport(Supabase)
import Supabase
#endif

struct CapturesService {
	#if canImport(Supabase)
	let capturesRepo = CapturesRepository()
    let plotsRepo = PlotsRepository()
    let storageRepo = StorageRepository()
	
	/// Uploads image to Storage then inserts a row in `captures` with the object key.
	func saveCapture(plotId: UUID, imageData: Data, takenAt: Date = Date(), deviceModel: String? = nil) async throws -> CaptureDTO {
		let userId = try await SupaAuthService.currentUserId()

		// The object key MUST be prefixed with the (lowercased) user id so it
		// satisfies the Storage RLS policy on the `captures` bucket:
		//   name LIKE auth.uid()::text || '/%'
		// (Postgres renders auth.uid()::text in lowercase; UUID.uuidString is
		// uppercase, so we must lowercase it or every upload is RLS-denied.)
		let folderName = userId.uuidString.lowercased()

		// Create object key with user folder and timestamp-based filename
		let timestamp = Int(Date().timeIntervalSince1970)
		let filename = "\(timestamp)_\(UUID().uuidString.prefix(8)).jpg"
		let objectKey = "\(folderName)/\(filename)"

		// Upload to Storage (RLS enforced)
		try await storageRepo.upload(bucket: "captures", objectKey: objectKey, data: imageData, contentType: "image/jpeg", upsert: true)

		let capture = try await capturesRepo.createCapture(
			plotId: plotId,
			takenAt: takenAt,
			photoKey: objectKey,
			clientUUID: UUID(),
			deviceModel: deviceModel,
			checksumSha256: nil,
			createdOfflineAt: nil
		)
		return capture
	}

    /// Convenience: ensures the user has at least one plot and returns its id.
    /// Now accepts optional coordinates to save with the plot
    func ensureDefaultPlotId(lat: Double? = nil, lon: Double? = nil) async throws -> UUID {
        let existing = try await plotsRepo.listPlots()
        if let first = existing.first { 
            // If plot exists but has no coordinates and we have new ones, we could update it
            // For now, just return the existing plot
            return first.id 
        }
        // Create new plot with coordinates if available
        let created = try await plotsRepo.createPlot(name: "Mi lote", lat: lat, lon: lon, region: nil)
        return created.id
    }

    /// Saves a capture using (or creating) a default plot for the current user.
    /// Now accepts optional coordinates to save with the plot
    func saveCaptureToDefaultPlot(imageData: Data, takenAt: Date = Date(), deviceModel: String? = nil, lat: Double? = nil, lon: Double? = nil) async throws -> CaptureDTO {
        let plotId = try await ensureDefaultPlotId(lat: lat, lon: lon)
        return try await saveCapture(plotId: plotId, imageData: imageData, takenAt: takenAt, deviceModel: deviceModel)
    }
	#else
	func saveCapture(plotId: UUID, imageData: Data, takenAt: Date = Date(), deviceModel: String? = nil) async throws -> CaptureDTO { throw NSError(domain: "supabase", code: -1) }
	#endif
}
