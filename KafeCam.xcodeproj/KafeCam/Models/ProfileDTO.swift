//
// ProfileDTO.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import Foundation

struct ProfileDTO: Codable, Identifiable, Hashable {
    let id: UUID
    let phone: String?
    let name: String?
    let email: String?
    let role: String?
    let organization: String?
    let locale: String?
    let createdAt: Date?
    // Personal info
    let gender: String?
    let dateOfBirth: Date?
    let age: Int?
    let country: String?
    let state: String?
    let about: String?
    // Visibility preferences
    let showGender: Bool?
    let showDateOfBirth: Bool?
    let showAge: Bool?
    let showCountry: Bool?
    let showState: Bool?
    let showAbout: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case name
        case email
        case role
        case organization
        case locale
        case createdAt = "created_at"
        case gender
        case dateOfBirth = "date_of_birth"
        case age
        case country
        case state
        case about
        case showGender = "show_gender"
        case showDateOfBirth = "show_date_of_birth"
        case showAge = "show_age"
        case showCountry = "show_country"
        case showState = "show_state"
        case showAbout = "show_about"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        phone = try? c.decode(String.self, forKey: .phone)
        name = try? c.decode(String.self, forKey: .name)
        email = try? c.decode(String.self, forKey: .email)
        role = try? c.decode(String.self, forKey: .role)
        organization = try? c.decode(String.self, forKey: .organization)
        locale = try? c.decode(String.self, forKey: .locale)
        // created_at may be timestamp or string
        if let createdStr = try? c.decode(String.self, forKey: .createdAt) {
            createdAt = ProfileDTO.parseDate(createdStr)
        } else if let createdDate = try? c.decode(Date.self, forKey: .createdAt) {
            createdAt = createdDate
        } else {
            createdAt = nil
        }
        gender = try? c.decode(String.self, forKey: .gender)
        if let dobStr = try? c.decode(String.self, forKey: .dateOfBirth) {
            dateOfBirth = ProfileDTO.parseDate(dobStr)
        } else if let dobDate = try? c.decode(Date.self, forKey: .dateOfBirth) {
            dateOfBirth = dobDate
        } else {
            dateOfBirth = nil
        }
        age = try? c.decode(Int.self, forKey: .age)
        country = try? c.decode(String.self, forKey: .country)
        state = try? c.decode(String.self, forKey: .state)
        about = try? c.decode(String.self, forKey: .about)
        showGender = try? c.decode(Bool.self, forKey: .showGender)
        showDateOfBirth = try? c.decode(Bool.self, forKey: .showDateOfBirth)
        showAge = try? c.decode(Bool.self, forKey: .showAge)
        showCountry = try? c.decode(Bool.self, forKey: .showCountry)
        showState = try? c.decode(Bool.self, forKey: .showState)
        showAbout = try? c.decode(Bool.self, forKey: .showAbout)
    }

    static func parseDate(_ s: String) -> Date? {
        // Try common formats: date, datetime, iso8601
        let fmts = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd"
        ]
        for f in fmts {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = f
            if let d = df.date(from: s) { return d }
        }
        return nil
    }
}
