//
//  EditListView.swift
//  KafeCam
//
//  Edit an existing user list - manage users and delete list
//

import SwiftUI

struct EditListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var listsManager: UserListsManager
    let list: UserList
    
    @State private var listName: String = ""
    @State private var selectedUsers: Set<UUID> = []
    @State private var allProfiles: [ProfileDTO] = []
    @State private var searchQuery: String = ""
    @State private var isLoading: Bool = false
    @State private var showDeleteAlert: Bool = false
    
    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    
    var filteredProfiles: [ProfileDTO] {
        if searchQuery.isEmpty {
            return allProfiles
        }
        let query = searchQuery.lowercased()
        return allProfiles.filter {
            ($0.name?.lowercased().contains(query) == true) ||
            ($0.email?.lowercased().contains(query) == true) ||
            ($0.phone?.contains(query) == true)
        }
    }
    
    var usersInList: [ProfileDTO] {
        allProfiles.filter { selectedUsers.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // List name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre de la lista")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Nombre", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                // Current users in list
                if !selectedUsers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Usuarios en la lista (\(selectedUsers.count))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(usersInList) { profile in
                                    UserEditRow(
                                        profile: profile,
                                        onRemove: {
                                            selectedUsers.remove(profile.id)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                }
                
                // Search to add more users
                VStack(alignment: .leading, spacing: 8) {
                    Text("Agregar más usuarios")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Buscar usuarios...", text: $searchQuery)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                
                // Available users list
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    List(filteredProfiles.filter { !selectedUsers.contains($0.id) }) { profile in
                        UserAddRow(
                            profile: profile,
                            onAdd: {
                                selectedUsers.insert(profile.id)
                            }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Editar lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            saveChanges()
                        } label: {
                            Label("Guardar cambios", systemImage: "checkmark")
                        }
                        
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Eliminar lista", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                    }
                }
            }
            .alert("Eliminar lista", isPresented: $showDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    listsManager.deleteList(list.id)
                    dismiss()
                }
            } message: {
                Text("¿Estás seguro de que quieres eliminar esta lista? Esta acción no se puede deshacer.")
            }
        }
        .tint(accentColor)
        .task {
            listName = list.name
            selectedUsers = Set(list.userIds)
            await loadProfiles()
        }
    }
    
    private func loadProfiles() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let repo = ProfilesRepository()
            allProfiles = try await repo.listAll(search: nil, role: nil, limit: 500, offset: 0)
        } catch {
            print("[EditListView] Error loading profiles: \(error)")
            allProfiles = []
        }
    }
    
    private func saveChanges() {
        var updated = list
        updated.name = listName
        updated.userIds = Array(selectedUsers)
        listsManager.updateList(updated)
        dismiss()
    }
}

// MARK: - User Edit Row (for users already in list)
private struct UserEditRow: View {
    let profile: ProfileDTO
    let onRemove: () -> Void
    @State private var avatarImage: UIImage? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                
                if let img = avatarImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(initials(from: profile.name))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .task {
                await loadAvatar()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name ?? "—")
                    .font(.subheadline)
                Text(roleLabel(profile.role))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func loadAvatar() async {
        #if canImport(Supabase)
        let storage = StorageRepository()
        let uid = profile.id.uuidString
        let uidLower = uid.lowercased()
        
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

// MARK: - User Add Row (for available users to add)
private struct UserAddRow: View {
    let profile: ProfileDTO
    let onAdd: () -> Void
    @State private var avatarImage: UIImage? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
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
            
            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color(red: 88/255, green: 129/255, blue: 87/255))
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
    }
    
    private func loadAvatar() async {
        #if canImport(Supabase)
        let storage = StorageRepository()
        let uid = profile.id.uuidString
        let uidLower = uid.lowercased()
        
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
