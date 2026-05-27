//
//  MLXTranslator.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Modelo MLX fine-tuneado especializado en traducción bidireccional
//  ES ↔ lengua indígena. Usa mlx-swift-lm 3.x (API actual).
//
//  Dependencias Swift Package:
//      https://github.com/ml-explore/mlx-swift          (from: "0.31.0")
//      https://github.com/ml-explore/mlx-swift-lm       (from: "3.31.0")
//
//  Products a agregar al target:
//      MLX, MLXNN, MLXLLM, MLXLMCommon
//
//  El modelo .mlx empaquetado en el bundle se llama:
//      kafecam-translator-q4/  (carpeta con weights + tokenizer.json)
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
final class MLXTranslator: ObservableObject {

    static let shared = MLXTranslator()

    enum State {
        case notLoaded
        case loading(progress: Double)
        case ready
        case failed(reason: String)
    }

    @Published private(set) var state: State = .notLoaded

    private var modelContainer: ModelContainer?

    private let generateParameters = GenerateParameters(
        maxTokens: 250,
        temperature: Float(0.25),
        topP: Float(0.9)
    )

    private init() {
        #if !targetEnvironment(simulator)
        MLX.Memory.cacheLimit = 512 * 1024 * 1024
        #endif
    }

    // MARK: - Carga

    func load() async throws {
        if case .ready = state { return }

        #if targetEnvironment(simulator)
        state = .failed(reason: "MLX no soportado en simulador")
        throw BrainError.mlxModelMissing(language: "translator")
        #else
        state = .loading(progress: 0)

        guard let modelURL = Bundle.main.url(
            forResource: "kafecam-translator-q4",
            withExtension: nil
        ) else {
            state = .failed(reason: "Modelo no encontrado en el bundle")
            throw BrainError.mlxModelMissing(language: "translator")
        }

        do {
            let container = try await LLMModelFactory.shared.loadContainer(
                from: modelURL,
                using: BundleTokenizerLoader()
            )
            self.modelContainer = container
            self.state = .ready
        } catch {
            state = .failed(reason: error.localizedDescription)
            throw error
        }
        #endif
    }

    /// Libera memoria. Llamar al entrar a background.
    func unload() {
        modelContainer = nil
        state = .notLoaded
        #if !targetEnvironment(simulator)
        MLX.Memory.clearCache()
        #endif
    }

    // MARK: - Traducción

    func translateFromSpanish(
        _ text: String,
        to target: CaficultorLanguage
    ) async throws -> String {
        guard target.isIndigenous else { return text }
        try await ensureReady()
        let prompt = makePrompt(sourceLang: .spanish, targetLang: target, text: text)
        return try await generate(prompt: prompt)
    }

    func translateToSpanish(
        _ text: String,
        from source: CaficultorLanguage
    ) async throws -> String {
        guard source.isIndigenous else { return text }
        try await ensureReady()
        let prompt = makePrompt(sourceLang: source, targetLang: .spanish, text: text)
        return try await generate(prompt: prompt)
    }

    // MARK: - Internals

    private func ensureReady() async throws {
        switch state {
        case .ready: return
        case .notLoaded, .failed: try await load()
        case .loading:
            while case .loading = state {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            if case .failed(let reason) = state {
                throw NSError(domain: "MLXTranslator", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: reason])
            }
        }
    }

    private func makePrompt(
        sourceLang: CaficultorLanguage,
        targetLang: CaficultorLanguage,
        text: String
    ) -> String {
        // El modelo fue entrenado con este formato exacto.
        // Cualquier cambio aquí requiere re-fine-tunear o ajustar el dataset.
        """
        Traduce del \(sourceLang.displayName) al \(targetLang.displayName).
        Si no estás seguro de cómo traducir alguna palabra, déjala en español \
        entre paréntesis. No inventes palabras nuevas.

        Texto: \(text)
        Traducción:
        """
    }

    private func generate(prompt: String) async throws -> String {
        guard let container = modelContainer else {
            throw BrainError.mlxModelMissing(language: "translator")
        }

        let lmInput = try await container.prepare(input: UserInput(prompt: prompt))
        let stream  = try await container.generate(input: lmInput, parameters: generateParameters)

        var output = ""
        for await generation in stream {
            if case .chunk(let text) = generation { output += text }
        }

        return postProcess(output)
    }

    private func postProcess(_ raw: String) -> String {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "Traducción:", with: "")
            .replacingOccurrences(of: "Translation:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if hasExcessiveRepetition(trimmed) {
            return "[!] \(trimmed.prefix(150))"
        }
        return trimmed
    }

    private func hasExcessiveRepetition(_ text: String) -> Bool {
        let words = text.split(separator: " ").map { String($0).lowercased() }
        guard words.count > 8 else { return false }
        var counts: [String: Int] = [:]
        for w in words { counts[w, default: 0] += 1 }
        let mostFrequent = counts.values.max() ?? 0
        return Double(mostFrequent) / Double(words.count) > 0.35
    }
}

// MARK: - SwiftUI integration helper

extension MLXTranslator {
    var statusText: String {
        switch state {
        case .notLoaded:          return "Modelo no cargado"
        case .loading(let p):     return "Cargando modelo… \(Int(p * 100))%"
        case .ready:              return "Listo"
        case .failed(let reason): return "Error: \(reason)"
        }
    }
}

// MARK: - BundleTokenizerLoader

/// Carga el tokenizer desde un directorio local del bundle sin requerir swift-transformers.
private struct BundleTokenizerLoader: TokenizerLoader {
    func load(from directory: URL) async throws -> any Tokenizer {
        try BPETokenizer(directory: directory)
    }
}

// MARK: - BPETokenizer

/// Tokenizador BPE estilo SentencePiece que lee tokenizer.json localmente.
/// Cubre modelos LLaMA/Mistral fine-tuneados con vocabulario ▁ (U+2581).
private final class BPETokenizer: Tokenizer, @unchecked Sendable {

    private let vocab: [String: Int]
    private let reverseVocab: [Int: String]
    private let mergesRanks: [String: Int]  // "a b" → rank
    private let specialTokenIds: Set<Int>
    let bosToken: String?
    let eosToken: String?
    let unknownToken: String?

    init(directory: URL) throws {
        let data = try Data(contentsOf: directory.appending(component: "tokenizer.json"))
        guard
            let root     = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let model    = root["model"] as? [String: Any],
            let rawVocab = model["vocab"] as? [String: Any]
        else { throw BPETokenizerError.invalidFormat }

        var v: [String: Int] = [:]
        for (token, val) in rawVocab {
            if let id = val as? Int          { v[token] = id }
            else if let n = val as? NSNumber { v[token] = n.intValue }
        }
        self.vocab = v
        self.reverseVocab = Dictionary(uniqueKeysWithValues: v.map { ($1, $0) })

        var ranks: [String: Int] = [:]
        if let merges = model["merges"] as? [String] {
            for (rank, merge) in merges.enumerated() { ranks[merge] = rank }
        }
        self.mergesRanks = ranks

        var specialIds = Set<Int>()
        if let added = root["added_tokens"] as? [[String: Any]] {
            for tok in added {
                if let id = tok["id"] as? Int { specialIds.insert(id) }
            }
        }
        self.specialTokenIds = specialIds

        var bos: String? = nil
        var eos: String? = nil
        var unk: String? = nil
        let cfgURL = directory.appending(component: "tokenizer_config.json")
        if let cfgData = try? Data(contentsOf: cfgURL),
           let cfg = try? JSONSerialization.jsonObject(with: cfgData) as? [String: Any] {
            bos = cfg["bos_token"] as? String
            eos = cfg["eos_token"] as? String
            unk = cfg["unk_token"] as? String
        }
        self.bosToken = bos
        self.eosToken = eos
        self.unknownToken = unk
    }

    // MARK: Encode

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        var ids: [Int] = []
        if addSpecialTokens, let bos = bosToken, let id = vocab[bos] { ids.append(id) }
        // SentencePiece: prepend ▁ y reemplaza espacios con ▁
        let normalized = "▁" + text.replacingOccurrences(of: " ", with: "▁")
        ids.append(contentsOf: bpeEncode(normalized))
        return ids
    }

    private func bpeEncode(_ text: String) -> [Int] {
        var parts = text.unicodeScalars.map { String($0) }
        let unkId = vocab[unknownToken ?? "<unk>"] ?? 0

        while parts.count > 1 {
            var bestRank = Int.max
            var bestIdx  = -1
            for i in 0 ..< parts.count - 1 {
                let key = parts[i] + " " + parts[i + 1]
                if let rank = mergesRanks[key], rank < bestRank {
                    bestRank = rank; bestIdx = i
                }
            }
            guard bestIdx >= 0 else { break }
            parts[bestIdx] = parts[bestIdx] + parts[bestIdx + 1]
            parts.remove(at: bestIdx + 1)
        }

        return parts.map { vocab[$0] ?? unkId }
    }

    // MARK: Decode

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        tokenIds
            .compactMap { id -> String? in
                guard let tok = reverseVocab[id] else { return nil }
                if skipSpecialTokens && specialTokenIds.contains(id) { return nil }
                return tok
            }
            .joined()
            .replacingOccurrences(of: "▁", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    func convertTokenToId(_ token: String) -> Int? { vocab[token] }
    func convertIdToToken(_ id: Int)  -> String?   { reverseVocab[id] }

    // MARK: Chat template

    // Sin plantilla Jinja embebida: el procesador cae al fallback de texto plano,
    // que une los mensajes con \n\n y los codifica directamente. Correcto para
    // modelos fine-tuneados con el formato de prompt simple de makePrompt().
    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        throw TokenizerError.missingChatTemplate
    }
}

private enum BPETokenizerError: Error { case invalidFormat }
