//
//  OfflineSyncService.swift
//  KafeCam
//
//  Monitorea conectividad con NWPathMonitor. Cuando la red vuelve,
//  sube automáticamente los capturas pendientes en PendingCaptureStore.
//

import Foundation
import Network

@MainActor
final class OfflineSyncService: ObservableObject {
    static let shared = OfflineSyncService()

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var isSyncing: Bool = false

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "kafe.network.monitor", qos: .utility)
    private var lastStatus: NWPath.Status = .requiresConnection

    private init() {}

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if path.status == .satisfied && self.lastStatus != .satisfied {
                    await self.syncPending()
                }
                self.lastStatus = path.status
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func refreshPendingCount(for userId: String) {
        pendingCount = PendingCaptureStore.shared.pending(for: userId).count
    }

    /// Sube todos los diagnósticos pendientes. Se puede llamar manualmente también.
    func syncPending() async {
        guard !isSyncing else { return }
        #if canImport(Supabase)
        guard let userId = try? await SupaAuthService.currentUserId() else { return }

        let pending = PendingCaptureStore.shared.pending(for: userId.uuidString)
        guard !pending.isEmpty else { return }

        isSyncing = true
        defer {
            isSyncing = false
            pendingCount = PendingCaptureStore.shared.pending(for: userId.uuidString).count
        }

        let svc = CapturesService()
        for capture in pending {
            let imageURL = PendingCaptureStore.shared.imageURL(for: capture)
            guard let data = try? Data(contentsOf: imageURL) else { continue }
            do {
                _ = try await svc.saveCaptureToDefaultPlot(
                    imageData: data,
                    takenAt: capture.takenAt,
                    deviceModel: capture.prediction,
                    lat: capture.lat,
                    lon: capture.lon
                )
                PendingCaptureStore.shared.markSynced(id: capture.id)
                debugLog("[OfflineSync] Synced capture \(capture.id)")
            } catch {
                debugLog("[OfflineSync] Failed to sync \(capture.id): \(error)")
                CrashMonitor.capture(error, context: [
                    "captureId": capture.id.uuidString,
                    "takenAt": capture.takenAt.description,
                    "retryContext": "offline_sync"
                ])
            }
        }
        #endif
    }
}
