//
// CapturesService.swift
// KafeCam
//

import Foundation
#if canImport(Supabase)
import Supabase
#endif

// MARK: - DiagnosisInput

/// Structured data from the ML model, passed alongside a capture save.
/// Inserted into the `diagnoses` table after the capture row is created.
struct DiagnosisInput {
    let diseaseCode: String
    let stage: Int16
    let confidence: Float
    let modelVersion: String

    static let currentModelVersion = "CoffeeDiseaseClassifier_v100"

    /// Builds a DiagnosisInput from raw detection output.
    /// Returns nil when the disease code is not in the seeded `diseases` table
    /// (avoids FK violation on unknown labels).
    static func from(diseaseName: String, status: PlotStatus, confidencePct: Double) -> DiagnosisInput? {
        guard let code = normalizedCode(diseaseName: diseaseName, status: status) else { return nil }
        return DiagnosisInput(
            diseaseCode: code,
            stage: status.diagnosisStage,
            confidence: Float(confidencePct / 100.0),
            modelVersion: currentModelVersion
        )
    }

    private static func normalizedCode(diseaseName: String, status: PlotStatus) -> String? {
        if diseaseName.isEmpty { return status == .sano ? "sano" : nil }
        switch diseaseName.lowercased() {
        case "sano", "sana", "saludable", "healthy": return "sano"
        case "roya":       return "roya"
        case "minador":    return "minador"
        case "phoma":      return "phoma"
        case "brown_eye", "BROWN_EYE": return "BROWN_EYE"
        case "white_eye", "WHITE_EYE": return "WHITE_EYE"
        default:           return nil
        }
    }
}

// MARK: - CapturesService

struct CapturesService {
    #if canImport(Supabase)
    let capturesRepo   = CapturesRepository()
    let plotsRepo      = PlotsRepository()
    let storageRepo    = StorageRepository()
    let diagnosesRepo  = DiagnosesRepository()
    let recsRepo       = RecommendationsRepository()

    /// Uploads image to Storage, inserts a `captures` row, then inserts a
    /// `diagnoses` row if diagnosis data is provided.
    func saveCapture(
        plotId: UUID,
        imageData: Data,
        takenAt: Date = Date(),
        deviceModel: String? = nil,
        clientUUID: UUID = UUID(),
        diagnosis: DiagnosisInput? = nil
    ) async throws -> CaptureDTO {
        let userId = try await SupaAuthService.currentUserId()

        let folderName = userId.uuidString.lowercased()
        let objectKey  = "\(folderName)/\(clientUUID.uuidString.lowercased()).jpg"

        try await storageRepo.upload(
            bucket: "captures",
            objectKey: objectKey,
            data: imageData,
            contentType: "image/jpeg",
            upsert: true
        )

        let capture = try await capturesRepo.createCapture(
            plotId: plotId,
            takenAt: takenAt,
            photoKey: objectKey,
            clientUUID: clientUUID,
            deviceModel: deviceModel,
            checksumSha256: nil,
            createdOfflineAt: nil
        )

        if let dx = diagnosis {
            do {
                let created = try await diagnosesRepo.createDiagnosis(captureId: capture.id, input: dx)
                let items = RecommendationsRepository.defaultItems(diseaseCode: dx.diseaseCode, stage: dx.stage)
                try? await recsRepo.createBatch(diagnosisId: created.id, items: items)
            } catch {
                // Diagnosis insert is best-effort — don't fail the capture.
                CrashMonitor.capture(error, context: [
                    "phase":     "diagnosis_insert",
                    "captureId": capture.id.uuidString
                ])
            }
        }

        return capture
    }

    /// Ensures the user has at least one plot, returns its id.
    func ensureDefaultPlotId(lat: Double? = nil, lon: Double? = nil) async throws -> UUID {
        let existing = try await plotsRepo.listPlots()
        if let first = existing.first { return first.id }
        let created = try await plotsRepo.createPlot(name: "Mi lote", lat: lat, lon: lon, region: nil)
        return created.id
    }

    /// Convenience: saves to (or creates) the user's default plot.
    func saveCaptureToDefaultPlot(
        imageData: Data,
        takenAt: Date = Date(),
        deviceModel: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil,
        clientUUID: UUID = UUID(),
        diagnosis: DiagnosisInput? = nil
    ) async throws -> CaptureDTO {
        let plotId = try await ensureDefaultPlotId(lat: lat, lon: lon)
        return try await saveCapture(
            plotId: plotId,
            imageData: imageData,
            takenAt: takenAt,
            deviceModel: deviceModel,
            clientUUID: clientUUID,
            diagnosis: diagnosis
        )
    }
    #else
    func saveCapture(plotId: UUID, imageData: Data, takenAt: Date = Date(), deviceModel: String? = nil, clientUUID: UUID = UUID(), diagnosis: DiagnosisInput? = nil) async throws -> CaptureDTO { throw NSError(domain: "supabase", code: -1) }
    func saveCaptureToDefaultPlot(imageData: Data, takenAt: Date = Date(), deviceModel: String? = nil, lat: Double? = nil, lon: Double? = nil, clientUUID: UUID = UUID(), diagnosis: DiagnosisInput? = nil) async throws -> CaptureDTO { throw NSError(domain: "supabase", code: -1) }
    #endif
}
