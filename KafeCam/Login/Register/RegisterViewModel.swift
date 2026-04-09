//
//  RegisterViewModel.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var firstName:    String = ""
    @Published var lastName:     String = ""
    @Published var email:        String = ""
    @Published var phone:        String = ""
    @Published var password:     String = ""
    @Published var organization: String = "Káapeh"

    // Personal info (collected, sent to DB, hidden in UI)
    @Published var gender:      String = ""
    @Published var dateOfBirth: Date   = Date()
    @Published var age:         String = ""
    @Published var country:     String = ""
    @Published var state:       String = ""

    // Errors
    @Published var firstNameError: String? = nil
    @Published var lastNameError:  String? = nil
    @Published var emailError:     String? = nil
    @Published var phoneError:     String? = nil
    @Published var passwordError:  String? = nil
    @Published var isLoading:      Bool    = false

    // Signals RegisterView to dismiss on success
    @Published var registrationSucceeded = false

    let auth:    AuthService
    let session: SessionViewModel

    init(auth: AuthService, session: SessionViewModel) {
        self.auth    = auth
        self.session = session
    }

    // MARK: - Called from the button — validates locally then fires async work

    func submit() {
        guard validateLocally() else { return }

        let fullName = lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? firstName
            : "\(firstName) \(lastName)"
        let ageInt   = Int(age) ?? 0

        debugLog("[RegisterVM] Registering Name: \(fullName), Phone: \(phone)")
        Task { await performRegister(fullName: fullName, ageInt: ageInt) }
    }

    // MARK: - Async network work

    private func performRegister(fullName: String, ageInt: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await auth.register(
                name: fullName,
                email: email.isEmpty ? nil : email,
                phone: phone,
                password: password,
                organization: organization,
                gender: gender.isEmpty ? "other" : gender,
                dateOfBirth: dateOfBirth,
                age: ageInt,
                country: country.isEmpty ? "" : country,
                state: state.isEmpty ? "" : state
            )
            // Flag only set here — after confirmed success
            UserDefaults.standard.set(true, forKey: "signupSuccess")
            debugLog("[RegisterVM] Registration successful")
            registrationSucceeded = true

        } catch let err as AuthError {
            switch err {
            case .duplicatePhone: phoneError    = err.errorDescription
            case .invalidName:    firstNameError = err.errorDescription
            case .invalidEmail:   emailError     = err.errorDescription
            case .invalidPhone:   phoneError     = err.errorDescription
            case .weakPassword:   passwordError  = err.errorDescription
            default:              passwordError  = "Algo salió mal. Intenta de nuevo."
            }
        } catch {
            passwordError = "Algo salió mal. Intenta de nuevo."
        }
    }

    // MARK: - Local validation (no network, instant feedback)

    @discardableResult
    private func validateLocally() -> Bool {
        firstNameError = nil; lastNameError = nil; emailError = nil
        phoneError     = nil; passwordError = nil

        if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            firstNameError = AuthError.invalidName.errorDescription
            return false
        }
        if !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, lastName.count < 2 {
            lastNameError = "El apellido es muy corto."
            return false
        }
        if !email.isEmpty, !LocalAuthService.validateEmail(email) {
            emailError = AuthError.invalidEmail.errorDescription
            return false
        }
        if !LocalAuthService.validatePhone(phone) {
            phoneError = AuthError.invalidPhone.errorDescription
            return false
        }
        if !LocalAuthService.validatePassword(password) {
            passwordError = AuthError.weakPassword.errorDescription
            return false
        }
        return true
    }
}
