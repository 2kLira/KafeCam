//
//  LearningRoute.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Modelos para la sección Aprende: rutas de capacitación
//  organizadas en lecciones y pasos. Datos cargados desde
//  learning_routes.json (recurso del bundle).
//

import Foundation
import SwiftUI

/// Ruta = curso. Agrupa lecciones sobre un tema.
struct LearningRoute: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let summary: String
    let iconSF: String              // SF Symbol
    let colorTag: ColorTag
    let estimatedMinutes: Int
    let lessons: [Lesson]

    enum ColorTag: String, Codable {
        case green, brown, amber
        var color: Color {
            switch self {
            case .green: return green1
            case .brown: return brown1
            case .amber: return Color(red: 201/255, green: 148/255, blue: 31/255)
            }
        }
    }
}

/// Lección = unidad mínima de capacitación (5–15 min).
struct Lesson: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let intro: String               // Párrafo de apertura (se puede leer en voz alta)
    let durationMinutes: Int
    let steps: [LessonStep]
    let reflection: String?         // Pregunta abierta para la bitácora, opcional
}

/// Paso dentro de una lección. Cada paso tiene texto y opcionalmente
/// una imagen ilustrativa (asset del bundle) o un consejo destacado.
struct LessonStep: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let body: String
    let imageAsset: String?
    let tip: String?
}

// MARK: - Repositorio

/// Carga las rutas desde el JSON empaquetado. Si no encuentra el archivo,
/// devuelve un set mínimo embebido en código para que la app no quede vacía.
final class LearningRoutesRepository {
    static let shared = LearningRoutesRepository()
    private(set) var routes: [LearningRoute] = []

    private init() {
        self.routes = Self.loadFromBundle() ?? Self.fallbackRoutes
    }

    private static func loadFromBundle() -> [LearningRoute]? {
        guard let url = Bundle.main.url(forResource: "learning_routes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([LearningRoute].self, from: data)
        else { return nil }
        return decoded
    }

    // MARK: Fallback (cuando aún no agregas el JSON al bundle)

    private static let fallbackRoutes: [LearningRoute] = [
        LearningRoute(
            id: "roya-basico",
            title: "Convivir con la roya",
            summary: "Aprende a identificar, prevenir y manejar la roya con prácticas que ya hacen otros caficultores.",
            iconSF: "leaf.fill",
            colorTag: .brown,
            estimatedMinutes: 25,
            lessons: [
                Lesson(
                    id: "roya-1",
                    title: "¿Qué es la roya y por qué aparece?",
                    intro: "La roya no es un castigo, es un hongo. Aparece cuando hay humedad alta, plantas debilitadas y poca diversidad en el cafetal. Entenderla es el primer paso para manejarla.",
                    durationMinutes: 6,
                    steps: [
                        LessonStep(id: "s1", title: "Cómo se ve",
                                   body: "Manchas amarillas en la parte de arriba de la hoja y un polvo anaranjado por debajo. Conforme avanza, las manchas se hacen más grandes y de color marrón.",
                                   imageAsset: "Roya",
                                   tip: "Revisa siempre las hojas más viejas, abajo en la planta. Ahí aparece primero."),
                        LessonStep(id: "s2", title: "Por qué llega",
                                   body: "Llega más fuerte después de lluvias largas, en cafetales muy cerrados o con plantas mal nutridas. No viene sola: pregunta a vecinos si la han visto.",
                                   imageAsset: nil,
                                   tip: nil),
                        LessonStep(id: "s3", title: "Qué no hacer",
                                   body: "No visites un cafetal sano después de uno con roya sin cambiarte la ropa. Las esporas viajan en zapatos, manos y herramientas.",
                                   imageAsset: nil,
                                   tip: "Si tu técnico recomienda fungicida, pregunta primero si hay biopreparado que sirva para tu caso.")
                    ],
                    reflection: "¿Cuándo fue la última vez que viste manchas como estas en tu cafetal?"
                ),
                Lesson(
                    id: "roya-2",
                    title: "Biopreparados que sí funcionan",
                    intro: "Antes de comprar producto, prueba lo que la tierra te da. Estos preparados los hacen caficultores en Chiapas y Oaxaca con buenos resultados.",
                    durationMinutes: 10,
                    steps: [
                        LessonStep(id: "b1", title: "Té de cola de caballo",
                                   body: "Hierve 250 g de cola de caballo fresca en 1 litro de agua durante 60 minutos. Cuela, enfría y diluye al 20% (1 parte de té por 5 de agua). Aplica con bomba en hojas y tallos.",
                                   imageAsset: nil,
                                   tip: "Aplica temprano o al atardecer, nunca con sol fuerte."),
                        LessonStep(id: "b2", title: "Biopreparado antihongos",
                                   body: "Mezcla 4 L de agua de lluvia, medio kilo de plantas nativas (monte de tu parcela) y 225 g de plantas medicinales como manzanilla, neem o ajo. Tapa el recipiente y deja reposar 2 semanas, revolviendo cada 2 días. Cuela y aplica.",
                                   imageAsset: nil,
                                   tip: "Guarda el preparado en lugar fresco y oscuro. Dura más.")
                    ],
                    reflection: "¿Qué plantas medicinales tienes cerca de tu casa que puedas usar?"
                )
            ]
        ),
        LearningRoute(
            id: "poda",
            title: "Poda con sentido",
            summary: "Cuándo podar, qué cortar y cómo no debilitar la planta. Sin teoría inútil.",
            iconSF: "scissors",
            colorTag: .green,
            estimatedMinutes: 18,
            lessons: [
                Lesson(
                    id: "poda-1",
                    title: "Cuándo y por qué podar",
                    intro: "Podar no es cortar por cortar. Es decidir qué partes de la planta gastan energía sin producir bien.",
                    durationMinutes: 8,
                    steps: [
                        LessonStep(id: "p1", title: "Tres señales para podar",
                                   body: "Ramas secas, ramas que no dieron grano en dos cosechas, y ramas que se cruzan tapándose la luz. Si ves esto, es momento.",
                                   imageAsset: nil,
                                   tip: "Marca con cinta las ramas a podar antes de cortar. Tómate tu tiempo."),
                        LessonStep(id: "p2", title: "Cómo cortar bien",
                                   body: "Corta cerca del nudo, sin dejar muñones largos. La herida debe quedar lisa. Desinfecta la tijera entre planta y planta con alcohol o cloro diluido.",
                                   imageAsset: nil,
                                   tip: nil)
                    ],
                    reflection: nil
                )
            ]
        ),
        LearningRoute(
            id: "comercio-justo",
            title: "Vender mejor tu café",
            summary: "Cooperativas, certificaciones, comercio justo. Qué te conviene y qué no.",
            iconSF: "scalemass.fill",
            colorTag: .amber,
            estimatedMinutes: 30,
            lessons: [
                Lesson(
                    id: "cj-1",
                    title: "¿Coyote o cooperativa?",
                    intro: "Vender al coyote es rápido pero deja poco. La cooperativa toma tiempo pero suele pagar mejor. Aquí los números reales.",
                    durationMinutes: 10,
                    steps: [
                        LessonStep(id: "c1", title: "Comparando el precio",
                                   body: "El coyote paga al momento, pero suele pagar 20% a 30% por debajo del precio de mercado. Las cooperativas pagan más, pero el pago llega después del beneficio.",
                                   imageAsset: nil,
                                   tip: "Pregunta en tu región si hay cooperativas con anticipos. Algunas adelantan parte del pago."),
                        LessonStep(id: "c2", title: "Certificaciones",
                                   body: "Orgánico, comercio justo, Rainforest. Cada una tiene reglas. Antes de pagar por una certificación, pregunta cuánto sube tu precio realmente.",
                                   imageAsset: nil,
                                   tip: nil)
                    ],
                    reflection: "¿Conoces a alguien de tu comunidad que esté en cooperativa? ¿Cómo le va?"
                )
            ]
        ),
        LearningRoute(
            id: "suelo",
            title: "Cuidar el suelo",
            summary: "Sin suelo vivo, no hay café bueno. Composta, cobertura y nutrición sin químicos.",
            iconSF: "mountain.2.fill",
            colorTag: .green,
            estimatedMinutes: 20,
            lessons: [
                Lesson(
                    id: "suelo-1",
                    title: "Tu cafetal te habla por las hojas",
                    intro: "Hojas amarillas, hojas blanquecinas, hojas con manchas. Cada color te dice qué le falta al suelo. Aprende a leerlas.",
                    durationMinutes: 7,
                    steps: [
                        LessonStep(id: "s1", title: "Amarillo desde la vena",
                                   body: "Hojas adultas que se ponen amarillas empezando por la vena central: falta nitrógeno. Los posos de café secos, espolvoreados en la base, ayudan.",
                                   imageAsset: "DeficienciaNitrogeno",
                                   tip: nil),
                        LessonStep(id: "s2", title: "Hojas jóvenes blancas con venas verdes",
                                   body: "Es falta de hierro. Un abono casero: clavos viejos en una botella con agua, una semana al sol. Cuando el agua se ponga anaranjada, está lista para regar.",
                                   imageAsset: "DeficienciaHierro",
                                   tip: nil)
                    ],
                    reflection: "¿Qué color predominan tus hojas hoy?"
                )
            ]
        )
    ]
}
