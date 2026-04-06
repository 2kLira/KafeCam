//
//  StoredUser.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation

struct StoredUser: Codable {
    let profile: UserProfile
    let saltBase64: String
    let passwordHashBase64: String
}
