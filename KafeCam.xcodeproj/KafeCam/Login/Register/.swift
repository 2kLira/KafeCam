//
//  ContentView 2.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import SwiftUI

struct ContentView: View {
    private let auth = LocalAuthService() // shared instance
    @StateObject private var loginVM: LoginViewModel

    init() {
        _loginVM = StateObject(wrappedValue: LoginViewModel(auth: auth))
    }

    var body: some View {
        LoginView(vm: loginVM)
    }
}

#Preview { ContentView() }
