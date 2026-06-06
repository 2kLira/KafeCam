//
//  LoginViewModel.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation
import AuthenticationServices

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

    // MARK: - Sign in with Apple

    /// Handles the `SignInWithAppleButton` completion. `rawNonce` is the un-hashed
    /// nonce that was generated for the request (its SHA-256 went to Apple).
    func handleApple(_ result: Result<ASAuthorization, Error>, rawNonce: String) {
        phoneError = nil
        passwordError = nil

        guard case .success(let authorization) = result else {
            // User cancellation is not an error worth surfacing.
            if case .failure(let err) = result,
               (err as? ASAuthorizationError)?.code != .canceled {
                passwordError = "No se pudo iniciar sesión con Apple."
            }
            return
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            passwordError = "No se pudo iniciar sesión con Apple."
            return
        }

        // Apple returns fullName/email ONLY on the first authorization — capture now.
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let email = credential.email

        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                _ = try await SupaAuthService.signInWithApple(idToken: idToken, nonce: rawNonce)
                UserDefaults.standard.set(true, forKey: "kafe.isLoggedIn")

                #if canImport(Supabase)
                // Persist name/email on first sign-in (best-effort; profile row is
                // already created by the handle_new_user trigger).
                if !fullName.isEmpty || (email?.isEmpty == false) {
                    _ = try? await ProfilesRepository().upsertCurrentUserProfile(
                        name: fullName.isEmpty ? nil : fullName,
                        email: email,
                        phone: nil,
                        organization: nil
                    )
                    if !fullName.isEmpty {
                        let first = fullName.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? fullName
                        UserDefaults.standard.set(first, forKey: "displayName")
                    }
                }
                #endif

                session.isLoggedIn = true
            } catch {
                debugLog("[AppleSignIn] failed: \(error)")
                passwordError = "No se pudo iniciar sesión con Apple."
            }
        }
    }
}
