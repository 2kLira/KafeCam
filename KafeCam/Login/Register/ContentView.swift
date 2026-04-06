//
//  ContentView.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionViewModel

    var body: some View {
        if session.isLoggedIn {
            HomeView() // <- tu pantalla existente
                .environmentObject(session)
                .onReceive(NotificationCenter.default.publisher(for: .init("kafe.session.logout"))) { _ in
                    session.logout()
                }
        } else {
            // Inyectamos session en el VM del login
            LoginView(vm: LoginViewModel(auth: session.auth, session: session))
                .environmentObject(session)
        }
    }
}

#Preview { ContentView().environmentObject(SessionViewModel(auth: SupabaseCodeAuthService())) }
