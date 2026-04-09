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
    private(set) var currentPhone: String? = nil

    func isLoggedIn() -> Bool { currentPhone != nil }

    // MARK: - Register (async — local work, no network)

    func register(name: String, email: String?, phone: String, password: String,
                  organization: String, gender: String, dateOfBirth: Date,
                  age: Int, country: String, state: String) async throws {
        try registerLocal(name: name, email: email, phone: phone,
                          password: password, organization: organization)
    }

    private func registerLocal(name: String, email: String?, phone: String,
                                password: String, organization: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthError.invalidName
        }
        if let email, !email.isEmpty, !Self.validateEmail(email) {
            throw AuthError.invalidEmail
        }
        guard Self.validatePhone(phone)    else { throw AuthError.invalidPhone }
        guard Self.validatePassword(password) else { throw AuthError.weakPassword }
        guard !store.exists(phone: phone)  else { throw AuthError.duplicatePhone }

        let salt = Self.randomSalt(length: 16)
        let hash = Self.hashPassword(password, salt: salt)
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
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

    // MARK: - Login (async)

    func login(phone: String, password: String) async throws {
        guard Self.validatePhone(phone) else { throw AuthError.userNotFoundOrBadPassword }
        guard let stored = store.get(phone: phone),
              let salt = Data(base64Encoded: stored.saltBase64) else {
            throw AuthError.userNotFoundOrBadPassword
        }
        let candidate = Self.hashPassword(password, salt: salt)
        guard candidate == stored.passwordHashBase64 else {
            throw AuthError.userNotFoundOrBadPassword
        }
        currentPhone = phone
    }

    // MARK: - Logout (async)

    func logout() async { currentPhone = nil }

    // MARK: - Validators & Crypto

    static func validatePhone(_ phone: String) -> Bool {
        let regex = try! NSRegularExpression(pattern: "^\\d{10}$")
        return regex.firstMatch(in: phone, range: NSRange(phone.startIndex..., in: phone)) != nil
    }

    static func validatePassword(_ pass: String) -> Bool {
        let regex = try! NSRegularExpression(pattern: "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{8,}$")
        return regex.firstMatch(in: pass, range: NSRange(pass.startIndex..., in: pass)) != nil
    }

    static func validateEmail(_ email: String) -> Bool {
        let regex = try! NSRegularExpression(
            pattern: "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$",
            options: [.caseInsensitive]
        )
        return regex.firstMatch(in: email, range: NSRange(email.startIndex..., in: email)) != nil
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
        return Data(SHA256.hash(data: data)).base64EncodedString()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
