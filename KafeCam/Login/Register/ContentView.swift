//
//  ContentView.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if session.isLoggedIn || session.isGuest {
            if !hasSeenOnboarding {
                OnboardingView {
                    hasSeenOnboarding = true
                }
            } else {
                HomeView()
                    .environmentObject(session)
                    .onReceive(NotificationCenter.default.publisher(for: .init("kafe.session.logout"))) { _ in
                        session.logout()
                    }
            }
        } else {
            LoginView(vm: LoginViewModel(auth: session.auth, session: session))
                .environmentObject(session)
        }
    }
}

#Preview { ContentView().environmentObject(SessionViewModel(auth: SupabaseCodeAuthService())) }
