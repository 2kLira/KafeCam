import Foundation

struct DiagnosisDTO: Codable, Identifiable {
    let id: UUID
    let captureId: UUID
    let diseaseCode: String
    let stage: Int16
    let confidence: Float?
    let modelVersion: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case captureId    = "capture_id"
        case diseaseCode  = "disease_code"
        case stage
        case confidence
        case modelVersion = "model_version"
        case createdAt    = "created_at"
    }
}

extension PlotStatus {
    /// Maps PlotStatus to the 0/1/2 stage values in the `diagnoses` table.
    var diagnosisStage: Int16 {
        switch self {
        case .sano:     return 0
        case .sospecha: return 1
        case .enfermo:  return 2
        }
    }
}
