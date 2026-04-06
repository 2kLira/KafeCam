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
                  gender: String, dateOfBirth: Date, age: Int, country: String, state: String) throws
    func login(phone: String, password: String) throws
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
        case .invalidName: return "Please enter your name."
        case .invalidEmail: return "Please enter a valid email address."
        case .invalidPhone: return "Please enter a valid 10-digit phone number."
        case .weakPassword: return "Password must be at least 8 characters and include letters and numbers."
        case .duplicatePhone: return "This phone number is already registered."
        case .userNotFoundOrBadPassword: return "Phone or password is incorrect."
        }
    }
}

