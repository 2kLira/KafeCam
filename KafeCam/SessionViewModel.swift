//
//  SessionViewModel.swift
//  KafeCam
//
//  Created by Guillermo Lira on 11/09/25.
//


import Foundation
#if canImport(Supabase)
import Supabase
#endif

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isGuest = false

    let auth: AuthService
    init(auth: AuthService) {
        self.auth = auth
        // Restore persisted login state so returning users are NOT dumped back
        // to the login screen on every cold launch. `auth.isLoggedIn()` reads the
        // persisted `kafe.isLoggedIn` flag; `restoreSession()` then validates the
        // actual Supabase session asynchronously.
        self.isLoggedIn = auth.isLoggedIn()
    }

    /// Validates the persisted Supabase session at launch. If the session is gone
    /// or expired, flip back to logged-out so the user re-authenticates instead of
    /// silently hitting failing API calls.
    func restoreSession() async {
        guard isLoggedIn, !isGuest else { return }
        #if canImport(Supabase)
        do {
            _ = try await SupaClient.shared.auth.session
        } catch {
            isLoggedIn = false
            await auth.logout()
        }
        #endif
    }

    func continueAsGuest() {
        isGuest = true
    }

    func logout() {
        Task {
            await auth.logout()
            isLoggedIn = false
            isGuest = false
            CrashMonitor.clearUser()
            NotificationCenter.default.post(name: .init("kafe.session.logout"), object: nil)
        }
    }
}
