//
//  PendingCaptureStore.swift
//  KafeCam
//
//  Persiste diagnósticos en Documents/ antes de subirlos a Supabase.
//  Si el dispositivo no tiene red al capturar, el diagnóstico se guarda
//  aquí y OfflineSyncService lo sube cuando haya conectividad.
//

import Foundation
import UIKit

struct PendingCapture: Codable, Identifiable {
    let id: UUID
    let userId: String
    let clientUUID: UUID
    let imageFileName: String   // relativo a Documents/captures/<userId>/
    let prediction: String
    let diseaseName: String
    let statusRaw: String
    let confidencePct: Double
    let lat: Double?
    let lon: Double?
    let takenAt: Date
    var syncedAt: Date?

    var isPending: Bool { syncedAt == nil }
    var status: PlotStatus { PlotStatus(rawValue: statusRaw) ?? .sospecha }
}

@MainActor
final class PendingCaptureStore {
    static let shared = PendingCaptureStore()

    private(set) var captures: [PendingCapture] = []

    private var storeURL: URL {
        documents.appendingPathComponent("pending_captures.json")
    }

    private var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private init() { load() }

    // MARK: - Image persistence

    /// Guarda la imagen en Documents/captures/<userId>/ y devuelve el filename.
    func saveImage(_ image: UIImage, userId: String) -> String? {
        let dir = imageDir(for: userId)
        let name = "\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
        let url = dir.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch { return nil }
    }

    func imageURL(for capture: PendingCapture) -> URL {
        imageDir(for: capture.userId).appendingPathComponent(capture.imageFileName)
    }

    // MARK: - Queue management

    func queue(_ capture: PendingCapture) {
        captures.removeAll { $0.id == capture.id }
        captures.insert(capture, at: 0)
        persist()
    }

    func markSynced(id: UUID) {
        guard let i = captures.firstIndex(where: { $0.id == id }) else { return }
        captures[i].syncedAt = Date()
        persist()
    }

    func pending(for userId: String) -> [PendingCapture] {
        captures.filter { $0.userId == userId && $0.isPending }
    }

    func all(for userId: String) -> [PendingCapture] {
        captures.filter { $0.userId == userId }
    }

    // MARK: - Internals

    private func imageDir(for userId: String) -> URL {
        let dir = documents
            .appendingPathComponent("captures")
            .appendingPathComponent(userId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([PendingCapture].self, from: data)
        else { return }
        captures = decoded
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(captures) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
