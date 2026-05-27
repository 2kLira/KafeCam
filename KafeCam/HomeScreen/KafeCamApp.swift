//
//  KafeCamApp.swift
//  KafeCam
//

import SwiftUI

@main
struct KafeCamApp: App {
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var session = SessionViewModel(auth: SupabaseCodeAuthService())
    @StateObject private var avatarStore = AvatarStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.horizontalSizeClass, .compact)
                .environmentObject(historyStore)
                .environmentObject(session)
                .environmentObject(avatarStore)
                .task { await avatarStore.warmStart() }
                .task { await CaficultorBrain.shared.warmUp() }
                .task { startOfflineServices() }
                .onReceive(NotificationCenter.default.publisher(for: .init("kafe.user.changed"))) { _ in
                    Task { await avatarStore.warmStart() }
                }
        }
    }

    private func startOfflineServices() {
        CrashMonitor.start()
        OfflineSyncService.shared.startMonitoring()
        Task {
            #if canImport(Supabase)
            if let uid = try? await SupaAuthService.currentUserId() {
                CrashMonitor.identify(userId: uid.uuidString)
                historyStore.loadPendingEntries(for: uid.uuidString)
            }
            #endif
        }
    }
}
