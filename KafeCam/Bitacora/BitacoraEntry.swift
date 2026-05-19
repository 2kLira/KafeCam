//
//  BitacoraEntry.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Modelo y store local para la Bitácora del caficultor.
//  Persistencia simple en UserDefaults (suficiente para MVP).
//  Cuando integres SwiftData o Supabase, este es el contrato a respetar.
//

import Foundation
import SwiftUI

enum BitacoraEntryKind: String, Codable, CaseIterable {
    case observation     // anotación abierta
    case reflection      // viene de una lección
    case capture         // anexada a una foto del cafetal
    case action          // acción tomada (apliqué biopreparado, etc.)

    var displayName: String {
        switch self {
        case .observation: return "Observación"
        case .reflection:  return "Reflexión"
        case .capture:     return "Foto del cafetal"
        case .action:      return "Acción"
        }
    }

    var iconSF: String {
        switch self {
        case .observation: return "eye.fill"
        case .reflection:  return "bubble.left.and.bubble.right.fill"
        case .capture:     return "camera.fill"
        case .action:      return "hand.thumbsup.fill"
        }
    }

    var color: Color {
        switch self {
        case .observation: return brown2
        case .reflection:  return brown1
        case .capture:     return green1
        case .action:      return green2
        }
    }
}

struct BitacoraEntry: Identifiable, Codable, Hashable {
    let id: String
    let date: Date
    let kind: BitacoraEntryKind
    let title: String
    let body: String
    let imageData: Data?
}

@MainActor
final class BitacoraStore: ObservableObject {
    static let shared = BitacoraStore()

    @Published private(set) var entries: [BitacoraEntry] = []

    private let storageKey = "bitacoraEntries.v1"

    private init() {
        load()
    }

    func add(_ entry: BitacoraEntry) {
        entries.insert(entry, at: 0)
        save()
    }

    func delete(_ entry: BitacoraEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    // MARK: - Persistencia

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([BitacoraEntry].self, from: data)
        else { return }
        entries = list.sorted { $0.date > $1.date }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
