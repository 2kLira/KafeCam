//
//  AppleIntelligenceAdvisor.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Wrapper sobre Foundation Models (Apple Intelligence, iOS 26+).
//  El razonamiento lingüístico en español/inglés se delega aquí porque
//  el modelo de sistema (~3B parámetros) es excelente en estas lenguas
//  y no cuesta espacio de bundle.
//
//  Responsabilidades:
//    1. Clasificar la intención del caficultor (CaficultorIntent)
//    2. Generar la respuesta usando contexto del RAG (CaficultorResponse)
//
//  Si el dispositivo no soporta Apple Intelligence o el usuario lo
//  deshabilitó, este servicio reporta unavailable y el Brain se cae
//  con gracia a un modo basado solo en MLX + plantillas.
//

import Foundation
import FoundationModels   // iOS 26+

@MainActor
final class AppleIntelligenceAdvisor {

    static let shared = AppleIntelligenceAdvisor()

    enum Availability {
        case available
        case unavailable(reason: String)
    }

    private(set) var availability: Availability = .unavailable(reason: "No verificado")

    // Sesiones reutilizables: mantener el contexto baja la latencia significativamente.
    private var intentSession: LanguageModelSession?
    private var responseSession: LanguageModelSession?

    private init() {
        refreshAvailability()
    }

    // MARK: - Disponibilidad

    func refreshAvailability() {
        let system = SystemLanguageModel.default
        switch system.availability {
        case .available:
            self.availability = .available
        case .unavailable(.deviceNotEligible):
            self.availability = .unavailable(reason: "Este dispositivo no soporta Apple Intelligence")
        case .unavailable(.appleIntelligenceNotEnabled):
            self.availability = .unavailable(reason: "Apple Intelligence no está activado en Ajustes")
        case .unavailable(.modelNotReady):
            self.availability = .unavailable(reason: "El modelo se está descargando")
        case .unavailable(let other):
            self.availability = .unavailable(reason: "No disponible: \(other)")
        @unknown default:
            self.availability = .unavailable(reason: "Estado desconocido")
        }
    }

    /// Precalienta sesiones al entrar a una pantalla que va a usar la IA.
    /// Recomendado llamarlo en .task de la vista principal.
    func prewarm() async {
        guard case .available = availability else { return }

        if intentSession == nil {
            intentSession = LanguageModelSession(instructions: Instructions.intent)
            intentSession?.prewarm()
        }
        if responseSession == nil {
            responseSession = LanguageModelSession(instructions: Instructions.response)
            responseSession?.prewarm()
        }
    }

    // MARK: - Clasificación de intención

    /// Toma el mensaje del caficultor (ya traducido a español por MLX si era
    /// indígena) y devuelve un CaficultorIntent estructurado.
    func classifyIntent(spanishMessage: String) async throws -> CaficultorIntent {
        guard case .available = availability else {
            throw BrainError.appleIntelligenceUnavailable
        }

        let session = intentSession ?? LanguageModelSession(instructions: Instructions.intent)
        self.intentSession = session

        let prompt = """
        Mensaje del caficultor: "\(spanishMessage)"

        Clasifica la intención. Sé conservador con confidence: si hay duda, baja.
        Si el caficultor menciona aplicar químicos, arrancar plantas o vender, marca requiresHumanReview = true.
        """

        let result = try await session.respond(
            to: prompt,
            generating: CaficultorIntent.self,
            options: GenerationOptions(temperature: 0.2)
        )

        return result.content
    }

    // MARK: - Generación de respuesta con contexto RAG

    /// Genera la respuesta usando los pasajes recuperados como contexto.
    /// Foundation Models está restringido (vía @Guide) a citar SOLO IDs
    /// presentes en el contexto, lo que reduce alucinación significativamente.
    func generateResponse(
        intent: CaficultorIntent,
        passages: [KnowledgePassage],
        targetLanguage: CaficultorLanguage
    ) async throws -> CaficultorResponse {
        guard case .available = availability else {
            throw BrainError.appleIntelligenceUnavailable
        }

        let session = responseSession ?? LanguageModelSession(instructions: Instructions.response)
        self.responseSession = session

        // Construir contexto. IDs visibles al modelo para que pueda citarlos.
        let context = passages.map { p in
            """
            [ID: \(p.id) | Fuente: \(p.source.rawValue) | \(p.title)]
            \(p.body)
            """
        }.joined(separator: "\n\n---\n\n")

        let validIDs = passages.map(\.id).joined(separator: ", ")
        let humanCheckHint = intent.requiresHumanReview ? "El usuario podría tomar una decisión costosa, así que recommendHumanCheck DEBE ser true." : "Si involucra químicos o decisiones de dinero, recommendHumanCheck = true."

        let prompt = """
        Pregunta del caficultor: \(intent.normalizedQuestion)
        Categoría: \(intent.category.rawValue)

        Contexto disponible (úsalo, no inventes datos):
        \(context.isEmpty ? "(sin contexto relevante; sé honesto y sugiere hablar con un técnico)" : context)

        IDs válidos para citar (no inventes otros): \(validIDs.isEmpty ? "ninguno" : validIDs)

        \(humanCheckHint)

        Responde en español. Tono cálido, lenguaje de campo, máximo 80 palabras.
        """

        let result = try await session.respond(
            to: prompt,
            generating: CaficultorResponse.self,
            options: GenerationOptions(temperature: 0.4)
        )

        return result.content
    }

    /// Versión con streaming, para mostrar la respuesta token a token en la UI.
    func streamResponse(
        intent: CaficultorIntent,
        passages: [KnowledgePassage]
    ) -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        Task {
            guard case .available = availability else {
                continuation.finish(throwing: BrainError.appleIntelligenceUnavailable)
                return
            }

            let session = responseSession ?? LanguageModelSession(instructions: Instructions.response)
            self.responseSession = session

            let context = passages.map { "\($0.title): \($0.body)" }
                .joined(separator: "\n\n")

            let prompt = """
            Pregunta: \(intent.normalizedQuestion)
            Contexto: \(context)
            Responde en español, máximo 80 palabras.
            """

            do {
                let responseStream = session.streamResponse(to: prompt)
                for try await chunk in responseStream {
                    continuation.yield(chunk.content)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }
}

// MARK: - Errores

enum BrainError: Error, LocalizedError {
    case appleIntelligenceUnavailable
    case mlxModelMissing(language: String)
    case translationFailed
    case retrievalFailed

    var errorDescription: String? {
        switch self {
        case .appleIntelligenceUnavailable:
            return "Apple Intelligence no está disponible en este dispositivo."
        case .mlxModelMissing(let lang):
            return "No hay modelo entrenado para \(lang)."
        case .translationFailed:
            return "No pude traducir el texto."
        case .retrievalFailed:
            return "No pude buscar en la base de conocimiento."
        }
    }
}

// MARK: - Instrucciones del system prompt

private enum Instructions {
    static let intent = """
    Eres un clasificador de intenciones para una app de caficultores en \
    México y Colombia. Recibes mensajes de productores de café —muchas \
    veces hablantes nativos de lenguas indígenas, alfabetización variable, \
    lenguaje coloquial de campo— y debes identificar qué necesitan.

    Reglas estrictas:
    - Conservador con la confianza. Si tienes duda, baja el confidence.
    - Si la persona menciona aplicar agroquímicos, arrancar plantas, vender \
      café, o cualquier acción irreversible, requiresHumanReview = true.
    - normalizedQuestion siempre en español, breve, sin perder la pregunta.
    - keywords son los términos clave que servirán para buscar en la \
      base de conocimiento (enfermedades, prácticas, plagas, fertilizantes).
    """

    static let response = """
    Eres un asistente para caficultores. Tu trabajo es ACOMPAÑAR, no \
    decidir. Hablas con productores de café que conocen su tierra mejor \
    que tú; tú aportas información, ellos deciden.

    Reglas absolutas:
    1. NUNCA recomiendes agroquímicos específicos ni dosis. Si la pregunta \
       va por ahí, redirige a un técnico humano.
    2. NUNCA inventes datos. Solo usa lo que está en el contexto.
    3. Si el contexto no tiene información suficiente, sé honesto: \
       "No tengo información segura sobre eso, ¿podrías hablar con un técnico?".
    4. Tono cálido, lenguaje de campo, frases cortas. Evita tecnicismos.
    5. Máximo 80 palabras en answerSpanish.
    6. Si la respuesta sugiere una acción concreta, ponla en actionSuggestion.
    7. Cita los IDs de pasajes que realmente usaste en citedPassageIDs.
       Si no usaste ninguno, lista vacía. NUNCA inventes IDs.
    8. recommendHumanCheck = true cuando hay dinero, químicos, salud, o duda.
    """
}
