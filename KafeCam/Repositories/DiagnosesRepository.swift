import Foundation
#if canImport(Supabase)
import Supabase
#endif

struct DiagnosesRepository {
    #if canImport(Supabase)
    func createDiagnosis(captureId: UUID, input: DiagnosisInput) async throws -> DiagnosisDTO {
        struct Payload: Encodable {
            let captureId:    String
            let diseaseCode:  String
            let stage:        Int16
            let confidence:   Float
            let modelVersion: String
            enum CodingKeys: String, CodingKey {
                case captureId    = "capture_id"
                case diseaseCode  = "disease_code"
                case stage
                case confidence
                case modelVersion = "model_version"
            }
        }
        let payload = Payload(
            captureId:    captureId.uuidString,
            diseaseCode:  input.diseaseCode,
            stage:        input.stage,
            confidence:   input.confidence,
            modelVersion: input.modelVersion
        )
        // Upsert on capture_id: safe to retry — the UNIQUE constraint prevents duplicates.
        let result: DiagnosisDTO = try await SupaClient.shared
            .from("diagnoses")
            .upsert(payload, onConflict: "capture_id")
            .select()
            .single()
            .execute()
            .value
        return result
    }
    #else
    func createDiagnosis(captureId: UUID, input: DiagnosisInput) async throws -> DiagnosisDTO {
        throw NSError(domain: "supabase", code: -1)
    }
    #endif
}
