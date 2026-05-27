//
//  AIModels.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Tipos compartidos por el cerebro de IA. Los structs anotados con
//  @Generable son usados por Foundation Models para producir output
//  estructurado y tipo-safe (constrained decoding a nivel de tokens).
//

import Foundation
import FoundationModels   // Apple Intelligence, iOS 26+

// MARK: - Lengua del caficultor

/// Lengua activa de comunicación. Espejo del IndigenousLanguage del Nivel 1
/// pero incluye español e inglés para el código del Brain.
enum CaficultorLanguage: String, Codable, Sendable {
    case spanish     = "es"
    case english     = "en"
    case tzotzil     = "tzo"
    case zapoteco    = "zap"
    case nasaYuwe    = "nasa"
    case emberaChami = "emp"

    var displayName: String {
        switch self {
        case .spanish:      return "español"
        case .english:      return "inglés"
        case .tzotzil:      return "Tzotzil"
        case .zapoteco:     return "Zapoteco"
        case .nasaYuwe:     return "Nasa Yuwe"
        case .emberaChami:  return "Embera Chamí"
        }
    }

    var isIndigenous: Bool {
        switch self {
        case .spanish, .english: return false
        default: return true
        }
    }

    /// Locale para Speech.framework / AVSpeechSynthesizer. Las lenguas
    /// indígenas hacen fallback a es-MX (no hay STT/TTS nativo para ellas).
    var speechLocale: Locale {
        switch self {
        case .english:                return Locale(identifier: "en-US")
        case .spanish:                return Locale(identifier: "es-MX")
        case .tzotzil, .zapoteco:     return Locale(identifier: "es-MX")
        case .nasaYuwe, .emberaChami: return Locale(identifier: "es-CO")
        }
    }
}

// MARK: - Intención del usuario (clasificada por Foundation Models)

/// Lo que el caficultor quiere hacer. El Brain usa Foundation Models
/// con guided generation para clasificar el mensaje del usuario en una de
/// estas categorías antes de decidir qué hacer.
@Generable
struct CaficultorIntent: Sendable {

    @Guide(description: "Categoría principal de lo que el caficultor quiere hacer.")
    let category: IntentCategory

    @Guide(description: "Resumen en español de máximo 15 palabras de lo que el caficultor está preguntando o pidiendo.")
    let normalizedQuestion: String

    @Guide(description: "Términos clave en español extraídos del mensaje, útiles para buscar en la base de conocimiento. Cero a cinco términos.")
    let keywords: [String]

    @Guide(description: "Qué tan seguro estás de la clasificación, de 0.0 a 1.0.")
    let confidence: Double

    @Guide(description: "Si el caficultor parece estar en riesgo de tomar una decisión costosa (aplicar químico, arrancar plantas, vender por debajo del mercado), poner true. En cualquier duda, poner true.")
    let requiresHumanReview: Bool
}

@Generable
enum IntentCategory: String, Sendable {
    case diseaseDiagnosisQuestion   // "Mis hojas tienen manchas amarillas"
    case treatmentAdvice            // "¿Qué pongo para la roya?"
    case practiceExplanation        // "¿Cómo se hace el biopreparado?"
    case weatherPlanning            // "¿Puedo aplicar hoy?"
    case marketAndPricing           // "¿A cuánto está el café?"
    case communityConnection        // "Quiero hablar con un técnico"
    case appNavigation              // "¿Dónde guardo mi foto?"
    case smallTalk                  // "Buenos días"
    case unclear                    // No se entiende
}

// MARK: - Respuesta del asistente

/// Respuesta estructurada que el Brain devuelve a la UI. Se construye
/// con Foundation Models usando los pasajes del RAG como contexto.
@Generable
struct CaficultorResponse: Sendable {

    @Guide(description: "Respuesta principal en español, clara y breve. Máximo 80 palabras. Tono cálido y directo, lenguaje de campo, evitar tecnicismos.")
    let answerSpanish: String

    @Guide(description: "Si la respuesta sugiere alguna acción concreta (revisar hojas, aplicar biopreparado, llamar al técnico), descríbela en una oración. Si no aplica, dejar nil.")
    let actionSuggestion: String?

    @Guide(description: "Si el caficultor debería confirmar con un humano antes de actuar, true. Default true cuando hay duda sobre tratamientos químicos, plagas o decisiones económicas.")
    let recommendHumanCheck: Bool

    @Guide(description: "Si la pregunta es sobre algo que la app puede mostrar (una lección, una sección de la enciclopedia, el mapa), nombrar el destino. Si no aplica, nil. Valores válidos: 'aprende.roya', 'aprende.poda', 'aprende.suelo', 'aprende.comercio_justo', 'detecta', 'anticipa', 'bitacora', 'pedir_ayuda', 'infomate'.")
    let suggestedAppDestination: String?

    @Guide(description: "Lista de los IDs de pasajes del contexto que realmente usaste. Si no usaste ninguno o inventaste, lista vacía. NUNCA inventes IDs.")
    let citedPassageIDs: [String]
}

// MARK: - Pasaje del RAG

/// Pieza de conocimiento recuperada por similaridad semántica desde
/// la base local (enciclopedia, lecciones, bitácora histórica).
struct KnowledgePassage: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let body: String
    let source: Source
    let similarity: Double   // 0.0 - 1.0, llenado por el RAG

    enum Source: String, Codable, Sendable {
        case encyclopedia
        case lesson
        case userJournal
        case weatherTip
        case practiceGuide
    }
}

// MARK: - Resultado del Brain

/// Lo que la UI recibe después de procesar el turno completo.
struct BrainTurnResult: Sendable {
    let userTextSpanish: String        // Lo que el usuario dijo, ya en español
    let userTextOriginal: String       // En la lengua del usuario (puede ser igual)
    let intent: CaficultorIntent
    let response: CaficultorResponse
    let responseInUserLanguage: String // answerSpanish traducido si aplica
    let citedPassages: [KnowledgePassage]
    let timings: Timings

    struct Timings: Sendable {
        let speechToText: TimeInterval
        let translationIn: TimeInterval
        let intentClassification: TimeInterval
        let retrieval: TimeInterval
        let generation: TimeInterval
        let translationOut: TimeInterval
        let total: TimeInterval
    }
}
