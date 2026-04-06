//
//  UserList.swift
//  KafeCam
//
//  Custom lists for organizing Comunidad users
//

import Foundation
import SwiftUI

// MARK: - User List Model
struct UserList: Identifiable, Codable {
    let id: UUID
    var name: String
    var userIds: [UUID]
    var filters: ListFilters
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, userIds: [UUID] = [], filters: ListFilters = ListFilters()) {
        self.id = UUID()
        self.name = name
        self.userIds = userIds
        self.filters = filters
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - List Filters
struct ListFilters: Codable {
    var organization: String?
    var country: String?
    var state: String?
    var gender: String?
    var role: String?
    
    var isEmpty: Bool {
        organization == nil && country == nil && state == nil && gender == nil && role == nil
    }
}

// MARK: - Lists Manager
@MainActor
class UserListsManager: ObservableObject {
    @Published var lists: [UserList] = []
    @Published var selectedListId: UUID? = nil
    
    private let baseStorageKey = "comunidad.userLists"
    private var currentUserId: UUID? = nil
    
    private var storageKey: String {
        guard let userId = currentUserId else { return baseStorageKey }
        return "\(baseStorageKey).\(userId.uuidString)"
    }
    
    init() {
        Task {
            await loadUserAndLists()
        }
    }
    
    private func loadUserAndLists() async {
        #if canImport(Supabase)
        do {
            currentUserId = try await SupaAuthService.currentUserId()
            loadLists()
        } catch {
            print("[UserListsManager] Could not get current user: \(error)")
        }
        #endif
    }
    
    var selectedList: UserList? {
        guard let id = selectedListId else { return nil }
        return lists.first { $0.id == id }
    }
    
    func createList(name: String, userIds: [UUID], filters: ListFilters) {
        let newList = UserList(name: name, userIds: userIds, filters: filters)
        lists.append(newList)
        saveLists()
    }
    
    func updateList(_ list: UserList) {
        if let index = lists.firstIndex(where: { $0.id == list.id }) {
            var updated = list
            updated.updatedAt = Date()
            lists[index] = updated
            saveLists()
        }
    }
    
    func deleteList(_ listId: UUID) {
        lists.removeAll { $0.id == listId }
        if selectedListId == listId {
            selectedListId = nil
        }
        saveLists()
    }
    
    func addUserToList(userId: UUID, listId: UUID) {
        if let index = lists.firstIndex(where: { $0.id == listId }) {
            if !lists[index].userIds.contains(userId) {
                lists[index].userIds.append(userId)
                lists[index].updatedAt = Date()
                saveLists()
            }
        }
    }
    
    func removeUserFromList(userId: UUID, listId: UUID) {
        if let index = lists.firstIndex(where: { $0.id == listId }) {
            lists[index].userIds.removeAll { $0 == userId }
            lists[index].updatedAt = Date()
            saveLists()
        }
    }
    
    func isUserInList(userId: UUID, listId: UUID) -> Bool {
        guard let list = lists.first(where: { $0.id == listId }) else { return false }
        return list.userIds.contains(userId)
    }
    
    func filterProfiles(_ profiles: [ProfileDTO], with list: UserList?) -> [ProfileDTO] {
        guard let list = list else { return profiles }
        
        var filtered = profiles
        
        // Filter by specific user IDs in the list
        if !list.userIds.isEmpty {
            filtered = filtered.filter { list.userIds.contains($0.id) }
        }
        
        // Apply additional filters
        if let org = list.filters.organization, !org.isEmpty {
            filtered = filtered.filter { $0.organization?.lowercased().contains(org.lowercased()) == true }
        }
        if let country = list.filters.country, !country.isEmpty {
            filtered = filtered.filter { $0.country?.lowercased().contains(country.lowercased()) == true }
        }
        if let state = list.filters.state, !state.isEmpty {
            filtered = filtered.filter { $0.state?.lowercased().contains(state.lowercased()) == true }
        }
        if let gender = list.filters.gender, !gender.isEmpty {
            filtered = filtered.filter { $0.gender?.lowercased() == gender.lowercased() }
        }
        if let role = list.filters.role, !role.isEmpty {
            filtered = filtered.filter { $0.role?.lowercased() == role.lowercased() }
        }
        
        return filtered
    }
    
    // MARK: - Persistence
    private func saveLists() {
        if let encoded = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadLists() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([UserList].self, from: data) else {
            return
        }
        lists = decoded
    }
}
