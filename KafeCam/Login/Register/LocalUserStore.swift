//
//  LocalUserStore.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


import Foundation

final class LocalUserStore {
    private let key = "kafecam.users" // [phone: StoredUser]

    func save(_ user: StoredUser) throws {
        var all = try loadAll()
        all[user.profile.phone] = user
        let data = try JSONEncoder().encode(all)
        UserDefaults.standard.set(data, forKey: key)
    }

    func exists(phone: String) -> Bool { (try? loadAll()[phone]) != nil }

    func get(phone: String) -> StoredUser? { (try? loadAll()[phone]) }

    private func loadAll() throws -> [String: StoredUser] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: StoredUser].self, from: data)) ?? [:]
    }
}
