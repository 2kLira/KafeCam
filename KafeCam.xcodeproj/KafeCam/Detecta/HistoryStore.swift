import SwiftUI
import Foundation
#if canImport(Supabase)
import Supabase
#endif

@MainActor
class HistoryStore: ObservableObject {
    @Published var entries: [HistoryEntry] = []

    // Agrega una nueva entrada al historial
    func add(image: UIImage, prediction: String) {
        let new = HistoryEntry(image: image, prediction: prediction, date: Date(), isFavorite: false)
        entries.insert(new, at: 0)
    }

    // Alterna favorito
    func toggleFavorite(for entry: HistoryEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].isFavorite.toggle()
        }
    }

    // Lista de favoritos
    var favorites: [HistoryEntry] {
        entries.filter { $0.isFavorite }
    }
    
    // Update notes for an entry
    func updateNotes(for entry: HistoryEntry, notes: String) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].notes = notes
            if entries[index].captureData != nil {
                entries[index].captureData?.notes = notes.isEmpty ? nil : notes
            }
        }
    }

    // Recarga de ejemplo (sin backend)
    func syncLocal() {
        // Aquí podrías cargar desde UserDefaults o archivo local si lo agregamos después
        print("Historial cargado localmente (\(entries.count) entradas)")
    }

    /// Descarga el historial desde Supabase para el usuario actual y mapea a imágenes
    func syncFromSupabase() async {
        #if canImport(Supabase)
        do {
            let userId = try await SupaAuthService.currentUserId()
            print("[HistoryStore] Syncing captures for user: \(userId)")
            
            // Use CapturesRepository to list captures for current user
            let repo = CapturesRepository()
            let items = try await repo.listCaptures(uploadedBy: userId)

            print("[HistoryStore] Found \(items.count) captures in database")

            let storage = StorageRepository()
            let placeholder = UIImage(systemName: "photo") ?? UIImage()
            
            // Load existing local entries first for immediate display
            let localEntries = self.entries
            
            // Fetch remote images
            let mapped: [HistoryEntry] = try await withThrowingTaskGroup(of: HistoryEntry?.self) { group in
                for c in items {
                    group.addTask {
                        do {
                            if let img = try await Self.fetchImage(for: c, using: storage) {
                                var entry = HistoryEntry(image: img, prediction: c.deviceModel ?? "Foto", date: c.takenAt)
                                entry.captureData = c
                                entry.notes = c.notes ?? ""
                                return entry
                            }
                        } catch {
                            print("[HistoryStore] Failed to fetch image for key \(c.photoKey): \(error)")
                        }
                        var entry = HistoryEntry(image: placeholder, prediction: c.deviceModel ?? "Foto", date: c.takenAt)
                        entry.captureData = c
                        entry.notes = c.notes ?? ""
                        return entry
                    }
                }
                var tmp: [HistoryEntry] = []
                for try await e in group {
                    if let entry = e {
                        tmp.append(entry)
                    }
                }
                return tmp
            }
            
            // Merge local and remote entries, avoiding duplicates
            var merged = localEntries
            for remoteEntry in mapped {
                if !merged.contains(where: { abs($0.date.timeIntervalSince(remoteEntry.date)) < 1 }) {
                    merged.append(remoteEntry)
                }
            }
            
            // Sort by date descending
            merged.sort { $0.date > $1.date }
            
            await MainActor.run { self.entries = merged }
            print("[HistoryStore] Sync complete with \(merged.count) total entries")
        } catch {
            // Mantener historial local si falla
            print("[HistoryStore] Sync from Supabase failed: \(error)")
        }
        #endif
    }

    private static func fetchImage(for capture: CaptureDTO, using storage: StorageRepository) async throws -> UIImage? {
        #if canImport(Supabase)
        // The photoKey already contains the full path (e.g., "Manuel Perez/1234567890_abc123.jpg")
        do {
            let url = try await storage.signedDownloadURL(objectKey: capture.photoKey, bucket: "captures", expiresIn: 600)
            print("[HistoryStore] Fetching image from: \(capture.photoKey)")
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { 
                print("[HistoryStore] Failed to fetch image, status: \((resp as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil 
            }
            return UIImage(data: data)
        } catch {
            print("[HistoryStore] Error fetching image for \(capture.photoKey): \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }

    // Local-only sync: list from disk per current user and show
    func syncFromLocal(userId: String) {
        let urls = LocalCapturesStore.shared.list(for: userId)
        let mapped: [HistoryEntry] = urls.compactMap { url in
            guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return nil }
            return HistoryEntry(image: img, prediction: "Foto", date: (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date(), isFavorite: false)
        }
        entries = mapped
    }
}
