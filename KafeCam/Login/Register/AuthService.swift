//
//  AuthService.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation

protocol AuthService {
    // registration now includes name, optional email, fixed organization and personal info
    func register(name: String, email: String?, phone: String, password: String, organization: String,
                  gender: String, dateOfBirth: Date, age: Int, country: String, state: String) async throws
    func login(phone: String, password: String) async throws
    func logout()
    func isLoggedIn() -> Bool
    var currentPhone: String? { get }
}

enum AuthError: LocalizedError {
    case invalidName
    case invalidEmail
    case invalidPhone
    case weakPassword
    case duplicatePhone
    case userNotFoundOrBadPassword // generic on purpose

    var errorDescription: String? {
        switch self {
        case .invalidName: return "Por favor ingresa tu nombre."
        case .invalidEmail: return "Por favor ingresa un correo electrónico válido."
        case .invalidPhone: return "Por favor ingresa un número de teléfono válido de 10 dígitos."
        case .weakPassword: return "La contraseña debe tener al menos 8 caracteres e incluir letras y números."
        case .duplicatePhone: return "Este número de teléfono ya está registrado."
        case .userNotFoundOrBadPassword: return "Teléfono o contraseña incorrectos."
        }
    }
}

