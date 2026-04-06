//
//  LoginViewModel.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation

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
        isLoading = true
        defer { isLoading = false }

        // Validaciones específicas antes de intentar login
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPhone.isEmpty {
            phoneError = "Ingresa tu teléfono."
            return
        }
        if !LocalAuthService.validatePhone(trimmedPhone) {
            phoneError = "Ingresa un teléfono válido de 10 dígitos."
            return
        }
        if password.isEmpty {
            passwordError = "Ingresa tu contraseña."
            return
        }

        // Try login
        do {
            try auth.login(phone: phone, password: password)
            session.isLoggedIn = true
        } catch {
            // Mensaje genérico en español si credenciales no coinciden
            passwordError = "Teléfono o contraseña incorrectos."
        }
    }
}
