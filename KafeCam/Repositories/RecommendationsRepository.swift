import Foundation
#if canImport(Supabase)
import Supabase
#endif

struct RecommendationsRepository {

    // MARK: - Static content

    /// Returns the default recommendations for a disease at a given stage.
    /// These are inserted once per diagnosis and queryable by technicians.
    static func defaultItems(diseaseCode: String, stage: Int16) -> [(level: String, text: String)] {
        switch diseaseCode {
        case "roya":
            if stage == 2 {
                return [
                    ("critical", "Roya con alta incidencia. Si supera el 5% del follaje, aplica fungicida cúprico inmediatamente. Retira todas las hojas con polvo naranja."),
                    ("warn",     "Evita mojar el follaje al regar. Mejora la circulación de aire podando ramas basales."),
                    ("info",     "Consulta a tu técnico antes de cualquier aplicación química. Registra el área afectada.")
                ]
            } else {
                return [
                    ("warn", "Inicio posible de roya. Monitorea de cerca y prepara fungicida cúprico preventivo."),
                    ("info", "Retira hojas con manchas sospechosas para reducir el inóculo en el lote.")
                ]
            }
        case "minador":
            if stage == 2 {
                return [
                    ("warn", "Infestación activa de minador. Elimina hojas con galerías visibles. Favorece parasitoides naturales."),
                    ("info", "Evita insecticidas de amplio espectro para no afectar controladores biológicos.")
                ]
            } else {
                return [
                    ("info", "Presencia baja de minador. Monitorea semanalmente y elimina hojas con galerías.")
                ]
            }
        case "phoma":
            if stage == 2 {
                return [
                    ("warn", "Phoma con alta incidencia. Mejora el drenaje y la aireación del cafetal. Aplica fungicida si el daño es extenso."),
                    ("info", "Retira frutos momificados y hojas afectadas. Evita heridas en las plantas.")
                ]
            } else {
                return [
                    ("info", "Posible phoma. Mejora el drenaje, retira material enfermo y aumenta la ventilación entre plantas.")
                ]
            }
        case "sano":
            return [
                ("info", "Planta en buen estado. Continúa con las labores de rutina: deshije, fertilización y monitoreo semanal.")
            ]
        case "BROWN_EYE":
            if stage == 2 {
                return [
                    ("warn", "Mancha de ojo café con alta incidencia. Revisa el nivel de zinc y boro. Aplica fungicida cúprico si supera el 10% de follaje afectado."),
                    ("info", "Retira hojas con manchas visibles y mejora la nutrición del cafetal.")
                ]
            } else {
                return [
                    ("info", "Presencia baja de mancha de ojo café. Monitorea la nutrición y retira hojas afectadas.")
                ]
            }
        case "WHITE_EYE":
            if stage == 2 {
                return [
                    ("warn", "Mancha de ojo blanco activa. Mejora el drenaje y reduce la humedad del cafetal. Retira y destruye el material vegetal afectado."),
                    ("info", "Monitorea la propagación semanalmente y evita el riego por aspersión.")
                ]
            } else {
                return [
                    ("info", "Lesiones leves detectadas. Mejora ventilación y drenaje. Retira hojas con síntomas.")
                ]
            }
        default:
            return []
        }
    }

    // MARK: - Database operations

    #if canImport(Supabase)

    /// Inserts a batch of recommendations for a diagnosis (best-effort, fire-and-forget errors).
    func createBatch(diagnosisId: UUID, items: [(level: String, text: String)]) async throws {
        guard !items.isEmpty else { return }
        struct Payload: Encodable {
            let diagnosisId: String
            let level: String
            let text: String
            enum CodingKeys: String, CodingKey {
                case diagnosisId = "diagnosis_id"
                case level
                case text
            }
        }
        let batch = items.map { Payload(diagnosisId: diagnosisId.uuidString, level: $0.level, text: $0.text) }
        try await SupaClient.shared
            .from("recommendations")
            .insert(batch)
            .execute()
    }

    /// Fetches the diagnosis and its recommendations for a given capture.
    /// Uses PostgREST resource embedding — one round-trip.
    func fetchForCapture(captureId: UUID) async throws -> DiagnosisWithRecommendations? {
        let results: [DiagnosisWithRecommendations] = try await SupaClient.shared
            .from("diagnoses")
            .select("id, capture_id, disease_code, stage, confidence, recommendations(*)")
            .eq("capture_id", value: captureId.uuidString)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    #else

    func createBatch(diagnosisId: UUID, items: [(level: String, text: String)]) async throws {}
    func fetchForCapture(captureId: UUID) async throws -> DiagnosisWithRecommendations? { nil }

    #endif
}
