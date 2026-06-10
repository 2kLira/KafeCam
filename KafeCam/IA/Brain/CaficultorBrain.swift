//
//  CaficultorBrain.swift
//  KafeCam
//

import Foundation
import SwiftUI

@MainActor
final class CaficultorBrain: ObservableObject {

    static let shared = CaficultorBrain()

    private let intelligence = AppleIntelligenceAdvisor.shared
    private let translator   = MLXTranslator.shared
    private let rag          = CoffeeKnowledgeRAG.shared
    private let voiceOut     = VoiceOutputService.shared

    @Published var activeLanguage: CaficultorLanguage = .spanish
    @Published var isProcessing = false
    @Published var lastResult: BrainTurnResult?
    @Published var readiness: Readiness = .notReady

    enum Readiness: Equatable {
        case notReady
        case partial(missing: [String])
        case ready
    }

    /// Whether the core LLM (Apple Intelligence) is usable right now.
    var isLLMAvailable: Bool {
        if case .available = intelligence.availability { return true }
        return false
    }

    /// Human-readable reason when the LLM is unavailable.
    var llmUnavailableReason: LLMUnavailableReason {
        switch intelligence.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            let r = reason.lowercased()
            if r.contains("descargando") || r.contains("ready") || r.contains("modelo") {
                return .downloading
            } else if r.contains("activado") || r.contains("enabled") || r.contains("siri") {
                return .notEnabled
            } else {
                return .deviceNotEligible
            }
        }
    }

    enum LLMUnavailableReason {
        case available
        case deviceNotEligible
        case notEnabled
        case downloading
    }

    private init() {}

    // MARK: - Setup

    func warmUp() async {
        await intelligence.prewarm()
        if activeLanguage.isIndigenous {
            try? await translator.load()
        }
        Task.detached { [rag] in await rag.buildIndex() }
        updateReadiness()
    }

    func setLanguage(_ lang: CaficultorLanguage) async {
        activeLanguage = lang
        if lang.isIndigenous { try? await translator.load() }
        updateReadiness()
    }

    private func updateReadiness() {
        var missing: [String] = []
        if case .unavailable = intelligence.availability { missing.append("Apple Intelligence") }
        if activeLanguage.isIndigenous, case .ready = translator.state { }
        else if activeLanguage.isIndigenous { missing.append("Modelo de traducción") }

        if missing.isEmpty         { readiness = .ready }
        else if missing.count == 2 { readiness = .notReady }
        else                       { readiness = .partial(missing: missing) }
    }

    // MARK: - Turno completo

    func process(userText: String) async throws -> BrainTurnResult {
        let t0 = Date()
        isProcessing = true
        defer { isProcessing = false }

        // 1. Traducción de entrada
        let tInTranslate = Date()
        let spanishInput: String
        if activeLanguage.isIndigenous {
            spanishInput = (try? await translator.translateToSpanish(userText, from: activeLanguage)) ?? userText
        } else {
            spanishInput = userText
        }
        let tIn = Date().timeIntervalSince(tInTranslate)

        // 2. Clasificación de intención
        let tIntentStart = Date()
        let intent: CaficultorIntent
        do {
            intent = try await intelligence.classifyIntent(spanishMessage: spanishInput)
        } catch {
            intent = fallbackIntent(for: spanishInput)
        }
        let tIntent = Date().timeIntervalSince(tIntentStart)

        // 3. RAG — solo para preguntas de conocimiento real.
        //    Saludo, smallTalk y navegación no necesitan contexto de enfermedades.
        let tRetrieveStart = Date()
        let needsRAG: Bool
        switch intent.category {
        case .smallTalk, .appNavigation: needsRAG = false
        default: needsRAG = true
        }
        let passages = needsRAG
            ? await rag.retrieve(query: intent.normalizedQuestion, keywords: intent.keywords, topK: 4)
            : []
        let tRetrieve = Date().timeIntervalSince(tRetrieveStart)

        // 4. Generación de respuesta
        let tGenStart = Date()
        let response: CaficultorResponse
        do {
            response = try await intelligence.generateResponse(
                intent: intent,
                passages: passages,
                targetLanguage: activeLanguage
            )
        } catch {
            response = fallbackResponse(intent: intent, passages: passages)
        }
        let tGen = Date().timeIntervalSince(tGenStart)

        // 5. Traducción de salida
        let tOutStart = Date()
        let responseTranslated: String
        if activeLanguage.isIndigenous {
            do {
                responseTranslated = try await translator.translateFromSpanish(
                    response.answerSpanish, to: activeLanguage)
            } catch {
                responseTranslated = response.answerSpanish
            }
        } else {
            responseTranslated = response.answerSpanish
        }
        let tOut = Date().timeIntervalSince(tOutStart)

        let result = BrainTurnResult(
            userTextSpanish:       spanishInput,
            userTextOriginal:      userText,
            intent:                intent,
            response:              response,
            responseInUserLanguage: responseTranslated,
            citedPassages:         passages.filter { response.citedPassageIDs.contains($0.id) },
            timings: .init(
                speechToText:           0,
                translationIn:          tIn,
                intentClassification:   tIntent,
                retrieval:              tRetrieve,
                generation:             tGen,
                translationOut:         tOut,
                total:                  Date().timeIntervalSince(t0)
            )
        )
        self.lastResult = result
        return result
    }

    func processAndSpeak(userText: String) async throws -> BrainTurnResult {
        let result = try await process(userText: userText)
        voiceOut.speak(text: result.responseInUserLanguage, in: activeLanguage)
        return result
    }

    // MARK: - Fallbacks

    /// Intento de clasificación cuando Apple Intelligence no está disponible.
    /// Detecta saludos simples para no lanzar el RAG con basura.
    private func fallbackIntent(for text: String) -> CaficultorIntent {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let category: IntentCategory = Self.greetingSet.contains(normalized) ? .smallTalk : .unclear
        return CaficultorIntent(
            category:           category,
            normalizedQuestion: text,
            keywords:           category == .smallTalk ? [] : extractKeywordsFallback(text),
            confidence:         category == .smallTalk ? 0.9 : 0.4,
            requiresHumanReview: category != .smallTalk
        )
    }

    private static let greetingSet: Set<String> = [
        "hola", "hi", "hello", "buenas", "buen día", "buenos días",
        "buenas tardes", "buenas noches", "qué tal", "cómo estás",
        "hey", "saludos", "ey", "que tal"
    ]

    /// Respuesta defensiva sin Apple Intelligence.
    private func fallbackResponse(intent: CaficultorIntent, passages: [KnowledgePassage]) -> CaficultorResponse {

        // Saludos → respuesta de bienvenida, sin datos de enfermedades
        if intent.category == .smallTalk {
            return CaficultorResponse(
                answerSpanish: "¡Hola! Soy el asistente de KafeCam. Puedo ayudarte con preguntas sobre enfermedades del café, el clima, prácticas de cultivo y cómo usar la app. ¿En qué te puedo ayudar?",
                actionSuggestion: nil,
                recommendHumanCheck: false,
                suggestedAppDestination: nil,
                citedPassageIDs: []
            )
        }

        // Navegación → orientar al usuario en la app
        if intent.category == .appNavigation {
            return CaficultorResponse(
                answerSpanish: "Para navegar en KafeCam: usa Detecta para tomar fotos de hojas, Anticipa para ver el clima, Consulta para ver tu historial y Aprende para las rutas de capacitación. ¿Qué sección buscas?",
                actionSuggestion: nil,
                recommendHumanCheck: false,
                suggestedAppDestination: nil,
                citedPassageIDs: []
            )
        }

        // Pregunta de conocimiento con pasajes relevantes
        if let p = passages.first {
            let summary = String(p.body.prefix(250))
            return CaficultorResponse(
                answerSpanish:          summary,
                actionSuggestion:       nil,
                recommendHumanCheck:    true,
                suggestedAppDestination: nil,
                citedPassageIDs:        [p.id]
            )
        }

        // Sin contexto — respuesta honesta
        return CaficultorResponse(
            answerSpanish: "No tengo información segura sobre eso. Te recomiendo hablar con el técnico de tu cooperativa antes de tomar cualquier decisión.",
            actionSuggestion: "Contactar a un técnico en Pedir ayuda",
            recommendHumanCheck: true,
            suggestedAppDestination: "pedir_ayuda",
            citedPassageIDs: []
        )
    }

    private func extractKeywordsFallback(_ text: String) -> [String] {
        let stopwords: Set<String> = [
            "el","la","los","las","un","una","y","o","de","del","en","con",
            "para","por","mi","tu","su","es","no","sí","que","como","cuando",
            "qué","cómo","cuándo","dónde","yo","él","ella",
            "hola","hi","hello","buenas","hey"        // saludos como stopwords
        ]
        return text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count > 3 && !stopwords.contains($0) }
            .prefix(5)
            .map { String($0) }
    }
}
