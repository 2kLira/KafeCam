//
//  LoginViewModel.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var phone: String = ""
    @Published var password: String = ""
    @Published var phoneError: String? = nil
    @Published var passwordError: String? = nil   // generic error shown under password
    @Published var isLoading = false
    @Published var signupJustSucceeded = false

    let auth: AuthService
    let session: SessionViewModel

    init(auth: AuthService, session: SessionViewModel) {
        self.auth = auth
        self.session = session
        // one-time flag to inform user after returning from signup
        if UserDefaults.standard.bool(forKey: "signupSuccess") {
            self.signupJustSucceeded = true
            UserDefaults.standard.removeObject(forKey: "signupSuccess")
        }
    }

    func submit() {
        phoneError = nil
        passwordError = nil

        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty else { phoneError = "Ingresa tu teléfono."; return }
        guard LocalAuthService.validatePhone(trimmedPhone) else {
            phoneError = "Ingresa un teléfono válido de 10 dígitos."; return
        }
        guard !password.isEmpty else { passwordError = "Ingresa tu contraseña."; return }

        isLoading = true
        Task {
            do {
                try await auth.login(phone: phone, password: password)
                session.isLoggedIn = true
            } catch {
                passwordError = "Teléfono o contraseña incorrectos."
            }
            isLoading = false
        }
    }
}
