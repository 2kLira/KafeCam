//
//  CaficultorBrain.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  El cerebro de IA. Orquesta:
//    1. Speech.framework (entrada por voz, opcional)
//    2. MLXTranslator (lengua indígena → español)
//    3. Foundation Models — clasificación de intención (Apple Intelligence)
//    4. CoffeeKnowledgeRAG (recuperación con NaturalLanguage embeddings)
//    5. Foundation Models — generación de respuesta con contexto
//    6. MLXTranslator (español → lengua indígena)
//    7. VoiceOutputService (audio nativo o TTS)
//
//  La UI solo habla con esta clase. El resto son detalles internos.
//

import Foundation
import SwiftUI

@MainActor
final class CaficultorBrain: ObservableObject {

    static let shared = CaficultorBrain()

    // Dependencias
    private let intelligence = AppleIntelligenceAdvisor.shared
    private let translator   = MLXTranslator.shared
    private let rag          = CoffeeKnowledgeRAG.shared
    private let voiceOut     = VoiceOutputService.shared

    @Published var activeLanguage: CaficultorLanguage = .spanish
    @Published var isProcessing = false
    @Published var lastResult: BrainTurnResult?

    /// Estado agregado de las dependencias para mostrar en UI.
    @Published var readiness: Readiness = .notReady

    enum Readiness: Equatable {
        case notReady
        case partial(missing: [String])
        case ready
    }

    private init() {}

    // MARK: - Setup

    /// Precarga lo esencial. Llamar en .task de la pantalla principal del
    /// asistente o al login para no pagar la latencia en el primer turno.
    func warmUp() async {
        // 1. Apple Intelligence
        await intelligence.prewarm()

        // 2. MLX translator solo si el usuario eligió lengua indígena
        if activeLanguage.isIndigenous {
            try? await translator.load()
        }

        // 3. RAG (instantáneo, solo construye índice en background)
        Task.detached { [rag] in await rag.buildIndex() }

        updateReadiness()
    }

    func setLanguage(_ lang: CaficultorLanguage) async {
        activeLanguage = lang
        if lang.isIndigenous {
            try? await translator.load()
        }
        updateReadiness()
    }

    private func updateReadiness() {
        var missing: [String] = []
        if case .unavailable = intelligence.availability {
            missing.append("Apple Intelligence")
        }
        if activeLanguage.isIndigenous,
           case .ready = translator.state {
            // ok
        } else if activeLanguage.isIndigenous {
            missing.append("Modelo de traducción")
        }

        if missing.isEmpty { readiness = .ready }
        else if missing.count == 2 { readiness = .notReady }
        else { readiness = .partial(missing: missing) }
    }

    // MARK: - Turno completo de conversación

    /// Procesa un turno completo del caficultor.
    /// - Parameter userText: texto del usuario, en la lengua que él habla.
    ///   Si vino de Speech, ya está transcrito.
    func process(userText: String) async throws -> BrainTurnResult {
        let t0 = Date()
        isProcessing = true
        defer { isProcessing = false }

        // 1. Traducción de entrada (si la lengua es indígena)
        let tInTranslate = Date()
        let spanishInput: String
        if activeLanguage.isIndigenous {
            spanishInput = (try? await translator.translateToSpanish(userText, from: activeLanguage)) ?? userText
        } else {
            spanishInput = userText
        }
        let tIn = Date().timeIntervalSince(tInTranslate)

        // 2. Clasificación de intención con Apple Intelligence
        let tIntentStart = Date()
        let intent: CaficultorIntent
        do {
            intent = try await intelligence.classifyIntent(spanishMessage: spanishInput)
        } catch {
            // Fallback: si Apple Intelligence no está, crear un intent stub.
            // El RAG aún puede ayudar con keywords del texto.
            intent = CaficultorIntent(
                category: .unclear,
                normalizedQuestion: spanishInput,
                keywords: extractKeywordsFallback(spanishInput),
                confidence: 0.4,
                requiresHumanReview: true
            )
        }
        let tIntent = Date().timeIntervalSince(tIntentStart)

        // 3. RAG: recuperar pasajes relevantes
        let tRetrieveStart = Date()
        let passages = await rag.retrieve(
            query: intent.normalizedQuestion,
            keywords: intent.keywords,
            topK: 4
        )
        let tRetrieve = Date().timeIntervalSince(tRetrieveStart)

        // 4. Generación de respuesta con contexto
        let tGenStart = Date()
        let response: CaficultorResponse
        do {
            response = try await intelligence.generateResponse(
                intent: intent,
                passages: passages,
                targetLanguage: activeLanguage
            )
        } catch {
            // Sin Apple Intelligence: respuesta canned basada en RAG.
            response = fallbackResponse(intent: intent, passages: passages)
        }
        let tGen = Date().timeIntervalSince(tGenStart)

        // 5. Traducción de salida
        let tOutStart = Date()
        let responseTranslated: String
        if activeLanguage.isIndigenous {
            do {
                responseTranslated = try await translator.translateFromSpanish(
                    response.answerSpanish,
                    to: activeLanguage
                )
            } catch {
                // Si la traducción falla, mostrar en español con etiqueta
                responseTranslated = response.answerSpanish + " (en español)"
            }
        } else {
            responseTranslated = response.answerSpanish
        }
        let tOut = Date().timeIntervalSince(tOutStart)

        let result = BrainTurnResult(
            userTextSpanish: spanishInput,
            userTextOriginal: userText,
            intent: intent,
            response: response,
            responseInUserLanguage: responseTranslated,
            citedPassages: passages.filter { response.citedPassageIDs.contains($0.id) },
            timings: .init(
                speechToText: 0,    // se llena externamente si vino de Speech
                translationIn: tIn,
                intentClassification: tIntent,
                retrieval: tRetrieve,
                generation: tGen,
                translationOut: tOut,
                total: Date().timeIntervalSince(t0)
            )
        )

        self.lastResult = result
        return result
    }

    // MARK: - Conveniencia: turno con audio out

    /// Mismo flujo que `process`, pero también dispara TTS / audio nativo.
    func processAndSpeak(userText: String) async throws -> BrainTurnResult {
        let result = try await process(userText: userText)
        voiceOut.speak(
            text: result.responseInUserLanguage,
            in: activeLanguage
        )
        return result
    }

    // MARK: - Fallbacks

    /// Cuando Apple Intelligence no está disponible, hacemos extracción
    /// boba de keywords para que el RAG aún funcione.
    private func extractKeywordsFallback(_ text: String) -> [String] {
        let stopwords: Set<String> = [
            "el","la","los","las","un","una","y","o","de","del","en","con",
            "para","por","mi","tu","su","es","no","sí","que","como","cuando",
            "qué","cómo","cuándo","dónde","yo","tu","él","ella"
        ]
        return text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count > 3 && !stopwords.contains($0) }
            .prefix(5)
            .map { String($0) }
    }

    /// Respuesta defensiva cuando no podemos generar.
    private func fallbackResponse(
        intent: CaficultorIntent,
        passages: [KnowledgePassage]
    ) -> CaficultorResponse {

        if let p = passages.first {
            // Usamos el primer pasaje recuperado como respuesta directa.
            let summary = String(p.body.prefix(220))
            return CaficultorResponse(
                answerSpanish: summary,
                actionSuggestion: nil,
                recommendHumanCheck: true,
                suggestedAppDestination: nil,
                citedPassageIDs: [p.id]
            )
        }

        return CaficultorResponse(
            answerSpanish: "No tengo información segura sobre eso. Te sugiero hablar con un técnico de tu cooperativa.",
            actionSuggestion: "Abrir Pedir Ayuda y contactar a un técnico",
            recommendHumanCheck: true,
            suggestedAppDestination: "pedir_ayuda",
            citedPassageIDs: []
        )
    }
}
