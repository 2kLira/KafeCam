//
//  LoginViewModel.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var phone:         String  = ""
    @Published var password:      String  = ""
    @Published var phoneError:    String? = nil
    @Published var passwordError: String? = nil
    @Published var isLoading:     Bool    = false

    let auth: AuthService
    let session: SessionViewModel

    init(auth: AuthService, session: SessionViewModel) {
        self.auth    = auth
        self.session = session
    }

    func submit() {
        // Validación local — sin red, sin async
        phoneError    = nil
        passwordError = nil

        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty else {
            phoneError = "Ingresa tu teléfono."
            return
        }
        guard LocalAuthService.validatePhone(trimmedPhone) else {
            phoneError = "Ingresa un teléfono válido de 10 dígitos."
            return
        }
        guard !password.isEmpty else {
            passwordError = "Ingresa tu contraseña."
            return
        }

        // Llamada de red — async
        Task { await performLogin(phone: trimmedPhone, password: password) }
    }

    private func performLogin(phone: String, password: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await auth.login(phone: phone, password: password)
            session.isLoggedIn = true
        } catch {
            passwordError = "Teléfono o contraseña incorrectos."
        }
    }
}
