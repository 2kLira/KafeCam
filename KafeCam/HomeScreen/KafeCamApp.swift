//
//  KafeCamApp.swift
//  KafeCam
//

import SwiftUI

@main
struct KafeCamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
                .task { await session.restoreSession() }
                .task { await avatarStore.warmStart() }
                .task { await CaficultorBrain.shared.warmUp() }
                .task { startOfflineServices() }
                .task { await PushNotificationService.shared.requestAuthorization() }
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
