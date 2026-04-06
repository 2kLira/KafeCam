//
//  CreateListView.swift
//  KafeCam
//
//  Create or edit a user list for Comunidad
//

import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var listsManager: UserListsManager
    
    @State private var listName: String = ""
    @State private var selectedUsers: Set<UUID> = []
    @State private var searchQuery: String = ""
    
    // Filters
    @State private var filterOrganization: String = ""
    @State private var filterCountry: String = ""
    @State private var filterState: String = ""
    @State private var filterGender: String = ""
    @State private var filterRole: String = ""
    @State private var showFilters: Bool = false
    
    @State private var allProfiles: [ProfileDTO] = []
    @State private var isLoading: Bool = false
    
    var editingList: UserList? = nil
    
    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    
    var filteredProfiles: [ProfileDTO] {
        var result = allProfiles
        
        // Apply search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                ($0.name?.lowercased().contains(query) == true) ||
                ($0.email?.lowercased().contains(query) == true) ||
                ($0.phone?.contains(query) == true)
            }
        }
        
        // Apply filters
        if !filterOrganization.isEmpty {
            result = result.filter { $0.organization?.lowercased().contains(filterOrganization.lowercased()) == true }
        }
        if !filterCountry.isEmpty {
            result = result.filter { $0.country?.lowercased().contains(filterCountry.lowercased()) == true }
        }
        if !filterState.isEmpty {
            result = result.filter { $0.state?.lowercased().contains(filterState.lowercased()) == true }
        }
        if !filterGender.isEmpty {
            result = result.filter { $0.gender?.lowercased() == filterGender.lowercased() }
        }
        if !filterRole.isEmpty {
            result = result.filter { $0.role?.lowercased() == filterRole.lowercased() }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // List name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre de la lista")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Ej: Equipo de trabajo", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Buscar usuarios...", text: $searchQuery)
                    
                    Button {
                        withAnimation {
                            showFilters.toggle()
                        }
                    } label: {
                        Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(accentColor)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Filters section
                if showFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterChip(title: "Organización", value: $filterOrganization)
                            FilterChip(title: "País", value: $filterCountry)
                            FilterChip(title: "Estado", value: $filterState)
                            
                            Menu {
                                Button("Todos") { filterGender = "" }
                                Button("Masculino") { filterGender = "male" }
                                Button("Femenino") { filterGender = "female" }
                                Button("Otro") { filterGender = "other" }
                            } label: {
                                Label(
                                    filterGender.isEmpty ? "Género" : labelGender(filterGender),
                                    systemImage: "person.fill"
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterGender.isEmpty ? Color(.systemGray6) : accentColor.opacity(0.2))
                                .cornerRadius(8)
                            }
                            
                            Menu {
                                Button("Todos") { filterRole = "" }
                                Button("Caficultor") { filterRole = "farmer" }
                                Button("Técnico") { filterRole = "technician" }
                            } label: {
                                Label(
                                    filterRole.isEmpty ? "Rol" : (filterRole == "farmer" ? "Caficultor" : "Técnico"),
                                    systemImage: filterRole == "technician" ? "wrench.and.screwdriver" : "leaf"
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterRole.isEmpty ? Color(.systemGray6) : accentColor.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }
                
                // Selected count
                if !selectedUsers.isEmpty {
                    HStack {
                        Text("\(selectedUsers.count) usuarios seleccionados")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Limpiar") {
                            selectedUsers.removeAll()
                        }
                        .font(.caption)
                        .foregroundColor(accentColor)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
                
                // Users list
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    List(filteredProfiles) { profile in
                        UserSelectionRow(
                            profile: profile,
                            isSelected: selectedUsers.contains(profile.id),
                            onToggle: {
                                if selectedUsers.contains(profile.id) {
                                    selectedUsers.remove(profile.id)
                                } else {
                                    selectedUsers.insert(profile.id)
                                }
                            }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(editingList != nil ? "Editar lista" : "Nueva lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editingList != nil ? "Guardar" : "Crear") {
                        saveList()
                    }
                    .disabled(listName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(accentColor)
        .task {
            await loadProfiles()
            if let list = editingList {
                listName = list.name
                selectedUsers = Set(list.userIds)
                // Load filters
                filterOrganization = list.filters.organization ?? ""
                filterCountry = list.filters.country ?? ""
                filterState = list.filters.state ?? ""
                filterGender = list.filters.gender ?? ""
                filterRole = list.filters.role ?? ""
            }
        }
    }
    
    private func loadProfiles() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let repo = ProfilesRepository()
            allProfiles = try await repo.listAll(search: nil, role: nil, limit: 500, offset: 0)
        } catch {
            print("[CreateListView] Error loading profiles: \(error)")
            allProfiles = []
        }
    }
    
    private func saveList() {
        let filters = ListFilters(
            organization: filterOrganization.isEmpty ? nil : filterOrganization,
            country: filterCountry.isEmpty ? nil : filterCountry,
            state: filterState.isEmpty ? nil : filterState,
            gender: filterGender.isEmpty ? nil : filterGender,
            role: filterRole.isEmpty ? nil : filterRole
        )
        
        if let list = editingList {
            var updated = list
            updated.name = listName
            updated.userIds = Array(selectedUsers)
            updated.filters = filters
            listsManager.updateList(updated)
        } else {
            listsManager.createList(
                name: listName,
                userIds: Array(selectedUsers),
                filters: filters
            )
        }
        
        dismiss()
    }
    
    private func labelGender(_ gender: String) -> String {
        switch gender.lowercased() {
        case "male": return "Masculino"
        case "female": return "Femenino"
        case "other": return "Otro"
        default: return "—"
        }
    }
}

// MARK: - User Selection Row
private struct UserSelectionRow: View {
    let profile: ProfileDTO
    let isSelected: Bool
    let onToggle: () -> Void
    @State private var avatarImage: UIImage? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with async loading
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                
                if let img = avatarImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Text(initials(from: profile.name))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .task {
                await loadAvatar()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name ?? "—")
                    .font(.subheadline)
                HStack(spacing: 4) {
                    Image(systemName: roleIcon(for: profile.role))
                        .font(.caption2)
                    Text(roleLabel(profile.role))
                        .font(.caption)
                    if let org = profile.organization, !org.isEmpty {
                        Text("• \(org)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? Color(red: 88/255, green: 129/255, blue: 87/255) : .secondary)
                .font(.title3)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
    
    private func loadAvatar() async {
        #if canImport(Supabase)
        let storage = StorageRepository()
        let uid = profile.id.uuidString
        let uidLower = uid.lowercased()
        
        // Try common patterns
        let keys = [
            "\(uidLower).jpg",
            "\(uidLower)-avatar.jpg",
            "\(uid).jpg",
            "\(uid)-avatar.jpg"
        ]
        
        for key in keys {
            if let url = try? await storage.signedDownloadURL(objectKey: key, bucket: "avatars", expiresIn: 600) {
                if let (data, resp) = try? await URLSession.shared.data(from: url),
                   let http = resp as? HTTPURLResponse,
                   200..<300 ~= http.statusCode,
                   let img = UIImage(data: data) {
                    await MainActor.run { self.avatarImage = img }
                    return
                }
            }
        }
        #endif
    }
    
    private func roleIcon(for role: String?) -> String {
        let r = (role ?? "").lowercased()
        return (r == "technician" || r == "admin") ? "wrench.and.screwdriver" : "leaf"
    }
    
    private func roleLabel(_ role: String?) -> String {
        let r = (role ?? "").lowercased()
        return (r == "technician" || r == "admin") ? "Técnico" : "Caficultor"
    }
    
    private func initials(from name: String?) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let parts = trimmed.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }
}

// MARK: - Filter Chip
private struct FilterChip: View {
    let title: String
    @Binding var value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
            TextField("", text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 100)
        }
    }
}
