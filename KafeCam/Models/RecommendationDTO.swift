import Foundation

struct RecommendationDTO: Codable, Identifiable {
    let id: UUID
    let diagnosisId: UUID
    let level: String   // "info" | "warn" | "critical"
    let text: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case diagnosisId = "diagnosis_id"
        case level
        case text
        case createdAt   = "created_at"
    }
}

/// Diagnosis row with its recommendations embedded (PostgREST join).
struct DiagnosisWithRecommendations: Codable {
    let id: UUID
    let captureId: UUID
    let diseaseCode: String
    let stage: Int16
    let confidence: Float?
    let recommendations: [RecommendationDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case captureId   = "capture_id"
        case diseaseCode = "disease_code"
        case stage
        case confidence
        case recommendations
    }
}
