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
                .environmentObject(historyStore)
                .environmentObject(session)
                .environmentObject(avatarStore)
                .task { await avatarStore.warmStart() }
                .onReceive(NotificationCenter.default.publisher(for: .init("kafe.user.changed"))) { _ in
                    Task { await avatarStore.warmStart() }
                }
        }
    }
}
