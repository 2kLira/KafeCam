//
//  SessionViewModel.swift
//  KafeCam
//
//  Created by Guillermo Lira on 11/09/25.
//


import Foundation

final class SessionViewModel: ObservableObject {
    @Published var isLoggedIn = false

    let auth: AuthService
    init(auth: AuthService) { self.auth = auth }

    func logout() {
        auth.logout()
        isLoggedIn = false
        // Broadcast so views/app can react (e.g., clear AvatarStore)
        NotificationCenter.default.post(name: .init("kafe.session.logout"), object: nil)
    }
}
