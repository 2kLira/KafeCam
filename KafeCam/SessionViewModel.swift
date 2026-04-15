//
//  SessionViewModel.swift
//  KafeCam
//
//  Created by Guillermo Lira on 11/09/25.
//


import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isGuest = false

    let auth: AuthService
    init(auth: AuthService) { self.auth = auth }

    func continueAsGuest() {
        isGuest = true
    }

    func logout() {
        Task {
            await auth.logout()
            isLoggedIn = false
            isGuest = false
            NotificationCenter.default.post(name: .init("kafe.session.logout"), object: nil)
        }
    }
}
