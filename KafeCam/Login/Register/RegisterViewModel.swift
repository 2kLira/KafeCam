//
//  RegisterViewModel.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation

@MainActor
final class RegisterViewModel: ObservableObject {
    // Split name fields for greeting "Hola {Nombres}"
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var phone: String = ""
    @Published var password: String = ""
    @Published var organization: String = "Káapeh"

    // Personal info
    @Published var gender: String = ""
    @Published var dateOfBirth: Date = Date()
    @Published var age: String = ""
    @Published var country: String = ""
    @Published var state: String = ""

    @Published var firstNameError: String? = nil
    @Published var lastNameError: String? = nil
    @Published var emailError: String? = nil
    @Published var phoneError: String? = nil
    @Published var passwordError: String? = nil
    @Published var isLoading = false
    @Published var genderError: String? = nil
    @Published var dobError: String? = nil
    @Published var ageError: String? = nil
    @Published var countryError: String? = nil
    @Published var stateError: String? = nil

    let auth: AuthService
    let session: SessionViewModel

    init(auth: AuthService, session: SessionViewModel) {
        self.auth = auth
        self.session = session
    }

    func submit() {
        // Reset all errors
        firstNameError = nil; lastNameError = nil; emailError = nil
        phoneError = nil; passwordError = nil
        genderError = nil; dobError = nil; ageError = nil; countryError = nil; stateError = nil

        // Synchronous validation — early return on failure
        if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            firstNameError = AuthError.invalidName.errorDescription; return
        }
        if !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && lastName.count < 2 {
            lastNameError = "El apellido es muy corto"; return
        }
        if !email.isEmpty && !LocalAuthService.validateEmail(email) {
            emailError = AuthError.invalidEmail.errorDescription; return
        }
        if !LocalAuthService.validatePhone(phone) {
            phoneError = AuthError.invalidPhone.errorDescription; return
        }
        if !LocalAuthService.validatePassword(password) {
            passwordError = AuthError.weakPassword.errorDescription; return
        }

        let ageInt = Int(age) ?? 0
        let fullName = lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? firstName : "\(firstName) \(lastName)"

        isLoading = true
        Task {
            do {
                debugLog("[RegisterVM] Registering with Name: \(fullName), Phone: \(phone), Email: \(email.isEmpty ? "none" : email), Org: \(organization)")
                try await auth.register(
                    name: fullName, email: email.isEmpty ? nil : email,
                    phone: phone, password: password, organization: organization,
                    gender: gender.isEmpty ? "other" : gender,
                    dateOfBirth: dateOfBirth, age: ageInt,
                    country: country.isEmpty ? "" : country,
                    state: state.isEmpty ? "" : state)
                session.isLoggedIn = true
                debugLog("[RegisterVM] Registration successful")
            } catch let err as AuthError {
                switch err {
                case .duplicatePhone: phoneError = err.errorDescription
                case .invalidName:    firstNameError = err.errorDescription
                case .invalidEmail:   emailError = err.errorDescription
                case .invalidPhone:   phoneError = err.errorDescription
                case .weakPassword:   passwordError = err.errorDescription
                default:              passwordError = "Algo salió mal. Intenta de nuevo."
                }
            } catch {
                let msg = error.localizedDescription
                passwordError = msg.isEmpty ? "Algo salió mal. Intenta de nuevo." : msg
            }
            isLoading = false
        }
    }
}
