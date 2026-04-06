//
//  LocalAuthService.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation
import CryptoKit

final class LocalAuthService: AuthService {
    private let store = LocalUserStore()
    private(set) var currentPhone: String? = nil // non-persistent (resets on app close)

    func isLoggedIn() -> Bool { currentPhone != nil }

    // New protocol requirement (personal fields). Locally we ignore them and reuse existing flow.
    func register(name: String, email: String?, phone: String, password: String, organization: String,
                  gender: String, dateOfBirth: Date, age: Int, country: String, state: String) throws {
        try register(name: name, email: email, phone: phone, password: password, organization: organization)
    }

    // Legacy local register retained for internal reuse
    func register(name: String, email: String?, phone: String, password: String, organization: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AuthError.invalidName }
        if let email = email, !email.isEmpty, !Self.validateEmail(email) { throw AuthError.invalidEmail }
        guard Self.validatePhone(phone) else { throw AuthError.invalidPhone }
        guard Self.validatePassword(password) else { throw AuthError.weakPassword }
        guard !store.exists(phone: phone) else { throw AuthError.duplicatePhone }

        let salt = Self.randomSalt(length: 16)
        let hash = Self.hashPassword(password, salt: salt)
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            email: (email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) ? nil : email?.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone,
            organization: organization,
            createdAt: Date()
        )
        let user = StoredUser(profile: profile,
                              saltBase64: salt.base64EncodedString(),
                              passwordHashBase64: hash)
        try store.save(user)
        currentPhone = phone
    }

    func login(phone: String, password: String) throws {
        guard Self.validatePhone(phone) else { throw AuthError.userNotFoundOrBadPassword }
        guard let stored = store.get(phone: phone),
              let salt = Data(base64Encoded: stored.saltBase64) else {
            throw AuthError.userNotFoundOrBadPassword
        }
        let candidate = Self.hashPassword(password, salt: salt)
        guard candidate == stored.passwordHashBase64 else { throw AuthError.userNotFoundOrBadPassword }
        currentPhone = phone
    }

    func logout() { currentPhone = nil }

    // MARK: - Validators & Crypto
    static func validatePhone(_ phone: String) -> Bool {
        let regex = try! NSRegularExpression(pattern: "^\\d{10}$")
        let range = NSRange(location: 0, length: phone.utf16.count)
        return regex.firstMatch(in: phone, range: range) != nil
    }

    static func validatePassword(_ pass: String) -> Bool {
        // min 8, at least one letter and one number
        let regex = try! NSRegularExpression(pattern: "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{8,}$")
        let range = NSRange(location: 0, length: pass.utf16.count)
        return regex.firstMatch(in: pass, range: range) != nil
    }

    static func validateEmail(_ email: String) -> Bool {
        // simple email check
        let regex = try! NSRegularExpression(pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$", options: [.caseInsensitive])
        let range = NSRange(location: 0, length: email.utf16.count)
        return regex.firstMatch(in: email, range: range) != nil
    }

    static func randomSalt(length: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes)
    }

    static func hashPassword(_ password: String, salt: Data) -> String {
        var data = Data()
        data.append(salt)
        data.append(password.data(using: .utf8)!)
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
    }
}

