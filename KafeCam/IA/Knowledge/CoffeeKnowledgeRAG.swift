//
//  CoffeeKnowledgeRAG.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Sistema de retrieval (RAG) sobre la base de conocimiento local.
//  Usa NaturalLanguage.NLEmbedding (Apple, on-device) para hacer
//  similaridad semántica en español sin descargar ningún modelo extra.
//
//  Las fuentes indexadas:
//    - diseases.json (enciclopedia existente del proyecto)
//    - learning_routes (las rutas de Aprende)
//    - bitacora del usuario (entradas con kind .action y .reflection)
//
//  Decisión de diseño: NLEmbedding tiene cobertura limitada (sí español).
//  Para textos largos hacemos chunking + mean pooling.
//  Para una v2 podríamos cambiar a un sentence-transformer en MLX,
//  pero NLEmbedding es 0 KB de bundle y suficiente para esta escala.
//

import Foundation
import NaturalLanguage

@MainActor
final class CoffeeKnowledgeRAG: ObservableObject {

    static let shared = CoffeeKnowledgeRAG()

    private let embedding: NLEmbedding?
    private var index: [IndexedPassage] = []
    private var isBuilt = false

    /// Pasaje pre-procesado: contenido + vector de embedding.
    private struct IndexedPassage {
        let passage: KnowledgePassage
        let vector: [Double]
    }

    private init() {
        self.embedding = NLEmbedding.sentenceEmbedding(for: .spanish)
        if embedding == nil {
            print("[RAG] Sentence embedding para español no disponible. Caer a wordEmbedding.")
        }
    }

    // MARK: - Construcción del índice

    /// Construye el índice. Llamar una vez al inicio de la app (idealmente
    /// en background al primer launch, luego se sirve desde cache).
    func buildIndex() async {
        guard !isBuilt else { return }
        guard let embedding = embedding else { return }

        var newIndex: [IndexedPassage] = []

        // 1. Enciclopedia de enfermedades (diseases.json)
        if let diseaseFile = Bundle.main.url(forResource: "diseases", withExtension: "json"),
           let data = try? Data(contentsOf: diseaseFile),
           let diseases = try? JSONDecoder().decode([DiseaseDTO].self, from: data) {

            for disease in diseases {
                // Un pasaje por sección de la enfermedad (descripción, impacto, prevención)
                addPassage(
                    id: "disease.\(disease.name).description",
                    title: disease.name,
                    body: disease.description,
                    source: .encyclopedia,
                    embedding: embedding,
                    into: &newIndex
                )
                addPassage(
                    id: "disease.\(disease.name).impact",
                    title: "Impacto de \(disease.name)",
                    body: disease.impact,
                    source: .encyclopedia,
                    embedding: embedding,
                    into: &newIndex
                )
                addPassage(
                    id: "disease.\(disease.name).prevention",
                    title: "Prevención y manejo de \(disease.name)",
                    body: disease.prevention,
                    source: .encyclopedia,
                    embedding: embedding,
                    into: &newIndex
                )
            }
        }

        // 2. Rutas de aprendizaje (cuando estén en JSON, leer aquí).
        // Por ahora, indexamos los pasos del repositorio embebido.
        // Reemplazar este bloque cuando muevas learning_routes a JSON.
        let routes = LearningRoutesRepository.shared.routes
        for route in routes {
            for lesson in route.lessons {
                addPassage(
                    id: "lesson.\(lesson.id).intro",
                    title: lesson.title,
                    body: lesson.intro,
                    source: .lesson,
                    embedding: embedding,
                    into: &newIndex
                )
                for step in lesson.steps {
                    addPassage(
                        id: "lesson.\(lesson.id).step.\(step.id)",
                        title: "\(lesson.title) — \(step.title)",
                        body: step.body + (step.tip.map { "\nConsejo: \($0)" } ?? ""),
                        source: .lesson,
                        embedding: embedding,
                        into: &newIndex
                    )
                }
            }
        }

        // 3. Bitácora del usuario: solo entradas de tipo .action que han
        //    funcionado, podrían servir como conocimiento experiencial.
        //    (Solo si el usuario optó por incluir su bitácora en su RAG.)
        //    Por defecto OFF para no introducir sesgos del propio usuario.

        self.index = newIndex
        self.isBuilt = true

        print("[RAG] Índice construido: \(newIndex.count) pasajes")
    }

    private func addPassage(
        id: String,
        title: String,
        body: String,
        source: KnowledgePassage.Source,
        embedding: NLEmbedding,
        into index: inout [IndexedPassage]
    ) {
        let vector = computeEmbedding(text: "\(title). \(body)", using: embedding)
        guard !vector.isEmpty else { return }

        let passage = KnowledgePassage(
            id: id,
            title: title,
            body: body,
            source: source,
            similarity: 0
        )
        index.append(IndexedPassage(passage: passage, vector: vector))
    }

    // MARK: - Query

    /// Recupera los k pasajes más relevantes para la pregunta.
    /// `keywords` opcional: si vienen de la clasificación de intent,
    /// se concatenan a la consulta para enriquecerla.
    func retrieve(
        query: String,
        keywords: [String] = [],
        topK: Int = 4,
        minSimilarity: Double = 0.45
    ) async -> [KnowledgePassage] {
        if !isBuilt { await buildIndex() }
        guard let embedding = embedding else { return [] }

        let enrichedQuery = ([query] + keywords).joined(separator: ". ")
        let queryVec = computeEmbedding(text: enrichedQuery, using: embedding)
        guard !queryVec.isEmpty else { return [] }

        // Cosine similarity (los embeddings de NL ya están aprox normalizados)
        var scored = index.map { ip -> (passage: KnowledgePassage, score: Double) in
            let s = cosineSimilarity(queryVec, ip.vector)
            return (
                KnowledgePassage(
                    id: ip.passage.id,
                    title: ip.passage.title,
                    body: ip.passage.body,
                    source: ip.passage.source,
                    similarity: s
                ),
                s
            )
        }

        scored.sort { $0.score > $1.score }

        return scored
            .prefix(topK)
            .filter { $0.score >= minSimilarity }
            .map(\.passage)
    }

    // MARK: - Helpers de embedding

    /// Embedding de un texto: si NL ofrece sentence embeddings directos,
    /// úsalos. Si no, hace mean pooling de los embeddings de palabras.
    private func computeEmbedding(text: String, using embedding: NLEmbedding) -> [Double] {
        if let direct = embedding.vector(for: text) {
            return direct
        }

        // Fallback: mean pooling de palabras
        let tokens = text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var sum: [Double] = []
        var n = 0
        for token in tokens {
            if let v = embedding.vector(for: token) {
                if sum.isEmpty { sum = v }
                else if v.count == sum.count {
                    for i in 0..<sum.count { sum[i] += v[i] }
                }
                n += 1
            }
        }
        guard n > 0 else { return [] }
        return sum.map { $0 / Double(n) }
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = (na.squareRoot() * nb.squareRoot())
        guard denom > 0 else { return 0 }
        return dot / denom
    }
}

// MARK: - DTO interno para diseases.json

private struct DiseaseDTO: Codable {
    let name: String
    let description: String
    let impact: String
    let prevention: String
}
