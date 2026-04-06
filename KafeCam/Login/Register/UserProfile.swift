//
//  UserProfile.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation

struct UserProfile: Codable, Equatable, Identifiable {
    var id: String { phone }
    let name: String                 // required
    let email: String?               // optional
    let phone: String                // exactly 10 digits
    let organization: String         // "Kaapeh"
    let createdAt: Date
}
