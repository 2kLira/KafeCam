import SwiftUI
#if canImport(PDFKit)
import PDFKit
#endif

struct CommunityListView: View {
    @State private var query: String = ""
    @State private var roleFilter: String = ""
    @State private var isLoading = false
    @State private var profiles: [ProfileDTO] = []
    @State private var currentUserId: UUID? = nil
    @State private var showOnboarding = false
    @State private var onboardedForUser: Bool = false
    @State private var showCreateList = false
    @State private var showManageLists = false
    @State private var editingList: UserList? = nil
    
    @StateObject private var listsManager = UserListsManager()

    // Palette matches app
    private let accentColor  = Color(red: 88/255, green: 129/255, blue: 87/255)
    
    var filteredProfiles: [ProfileDTO] {
        var result = profiles
        
        // Apply list filter if one is selected
        if let selectedList = listsManager.selectedList {
            result = listsManager.filterProfiles(result, with: selectedList)
        }
        
        // Apply search query
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lowered = query.lowercased()
            result = result.filter {
                ($0.name?.lowercased().contains(lowered) == true) ||
                ($0.email?.lowercased().contains(lowered) == true) ||
                ($0.phone?.contains(lowered) == true)
            }
        }
        
        // Apply role filter
        if !roleFilter.isEmpty {
            result = result.filter { $0.role == roleFilter }
        }
        
        return result
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                SearchBar(text: $query)
            }
            .padding(.horizontal)

            // Lists and filters section
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Default filters
                    FilterChip(title: "Todos", selected: roleFilter.isEmpty && listsManager.selectedListId == nil) {
                        roleFilter = ""
                        listsManager.selectedListId = nil
                        Task { await reload() }
                    }
                    FilterChip(title: "Caficultores", selected: roleFilter == "farmer" && listsManager.selectedListId == nil) {
                        roleFilter = "farmer"
                        listsManager.selectedListId = nil
                        Task { await reload() }
                    }
                    FilterChip(title: "Técnicos", selected: roleFilter == "technician" && listsManager.selectedListId == nil) {
                        roleFilter = "technician"
                        listsManager.selectedListId = nil
                        Task { await reload() }
                    }
                    
                    // Custom lists
                    ForEach(listsManager.lists) { list in
                        FilterChip(
                            title: list.name,
                            selected: listsManager.selectedListId == list.id
                        ) {
                            roleFilter = ""
                            listsManager.selectedListId = list.id
                        }
                        .contextMenu {
                            Button {
                                // Edit list
                                editingList = list
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                listsManager.deleteList(list.id)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                    
                    // Add list button
                    Button {
                        showCreateList = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(accentColor)
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 4)

            if isLoading {
                ProgressView().tint(accentColor)
                Spacer()
            } else if filteredProfiles.isEmpty {
                ContentUnavailableView("Sin usuarios", systemImage: "person.2.slash", description: Text("No hay resultados."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredProfiles) { p in
                            NavigationLink {
                                UserDetailView(userId: p.id)
                            } label: {
                                CommunityRow(user: p, isCurrentUser: (currentUserId != nil && p.id == currentUserId!) )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                // Add to list options
                                Menu {
                                    ForEach(listsManager.lists) { list in
                                        Button {
                                            if listsManager.isUserInList(userId: p.id, listId: list.id) {
                                                listsManager.removeUserFromList(userId: p.id, listId: list.id)
                                            } else {
                                                listsManager.addUserToList(userId: p.id, listId: list.id)
                                            }
                                        } label: {
                                            Label(
                                                list.name,
                                                systemImage: listsManager.isUserInList(userId: p.id, listId: list.id) ? "checkmark.circle.fill" : "circle"
                                            )
                                        }
                                    }
                                    
                                    if listsManager.lists.isEmpty {
                                        Button {
                                            showCreateList = true
                                        } label: {
                                            Label("Crear lista", systemImage: "plus.circle")
                                        }
                                    }
                                } label: {
                                    Label("Agregar a lista", systemImage: "text.badge.plus")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Comunidad")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
        .toolbar {
            // Show Edit button when viewing a custom list
            if let selectedList = listsManager.selectedList {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Editar") {
                        editingList = selectedList
                    }
                }
            }
        }
        .onChange(of: query) { _, _ in
            if listsManager.selectedListId == nil {
                debounceReload()
            }
        }
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .init("kafe.avatar.updated"))) { _ in
            Task { await reload() }
        }
        .sheet(isPresented: $showCreateList) {
            CreateListView(listsManager: listsManager)
        }
        .sheet(item: $editingList) { list in
            EditListView(listsManager: listsManager, list: list)
        }
        .task {
            #if canImport(Supabase)
            if let uid = try? await SupaAuthService.currentUserId() { currentUserId = uid }
            #endif
            if let uid = currentUserId {
                let key = "community.onboarded.\(uid.uuidString)"
                onboardedForUser = UserDefaults.standard.bool(forKey: key)
                if !onboardedForUser { showOnboarding = true }
            }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            if let uid = currentUserId {
                let key = "community.onboarded.\(uid.uuidString)"
                if !UserDefaults.standard.bool(forKey: key) {
                    NotificationCenter.default.post(name: .switchToHomeTab, object: nil)
                }
            }
        }) {
            CommunityOnboardingView(onComplete: {
                if let uid = currentUserId {
                    let key = "community.onboarded.\(uid.uuidString)"
                    UserDefaults.standard.set(true, forKey: key)
                    onboardedForUser = true // Update local state
                }
                showOnboarding = false
                Task { await reload() }
            })
            .presentationDetents([.large])
        }
    }

    // MARK: - Data
    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let repo = ProfilesRepository()
            var rows = try await repo.listAll(search: nil, role: roleFilter, limit: 200, offset: 0)
            // Client-side query filter for resilience if server policies change
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let lowered = query.lowercased()
                rows = rows.filter { ($0.name?.lowercased().contains(lowered) == true) || ($0.email?.lowercased().contains(lowered) == true) || ($0.phone?.contains(lowered) == true) }
            }
            profiles = rows
        } catch {
            profiles = []
        }
    }

    @State private var debounceTask: Task<Void, Never>? = nil
    private func debounceReload() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await reload()
        }
    }
}

private struct CommunityRow: View {
    let user: ProfileDTO
    let isCurrentUser: Bool
    var body: some View {
        HStack(spacing: 12) {
            AvatarBubble(userId: user.id, name: user.name, isCurrentUser: isCurrentUser)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name ?? "—")
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: roleIcon(for: user.role))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(roleLabel(user.role))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    private func roleIcon(for role: String?) -> String {
        let r = (role ?? "").lowercased()
        return (r == "technician" || r == "admin") ? "wrench.and.screwdriver" : "leaf"
    }
    private func roleLabel(_ role: String?) -> String {
        let r = (role ?? "").lowercased()
        return (r == "technician" || r == "admin") ? "Técnico" : "Caficultor"
    }
}

private struct FilterChip: View {
    let title: String
    let selected: Bool
    let onTap: () -> Void
    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(selected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? accentColor : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct AvatarBubble: View {
    let userId: UUID
    let name: String?
    let isCurrentUser: Bool
    @EnvironmentObject var avatarStore: AvatarStore
    @State private var image: UIImage? = nil
    
    // Static cache for avatars to make them appear instantly
    private static var avatarCache: [UUID: UIImage] = [:]

    var body: some View {
        ZStack {
            Circle().fill(Color(.systemGray5))
            if let img = displayImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Text(Self.initials(from: name)).font(.headline)
            }
        }
        .frame(width: 40, height: 40)
        .task {
            if isCurrentUser {
                self.image = avatarStore.image
            } else if let cached = Self.avatarCache[userId] {
                self.image = cached
            } else {
                await loadAvatar()
            }
        }
        .onChange(of: avatarStore.image) { _, img in
            if isCurrentUser {
                self.image = img
            }
        }
    }
    
    private var displayImage: UIImage? {
        if isCurrentUser {
            return avatarStore.image ?? image
        } else {
            return image ?? Self.avatarCache[userId]
        }
    }

    private func loadAvatar() async {
        #if canImport(Supabase)
        let storage = StorageRepository()
        let uidLower = userId.uuidString.lowercased()
        let uidUpper = userId.uuidString
        
        // Try the most common patterns first for speed
        let primaryKeys = [
            "\(uidLower).jpg",
            "\(uidLower)-avatar.jpg",
            "\(uidUpper).jpg",
            "\(uidUpper)-avatar.jpg"
        ]
        
        for key in primaryKeys {
            if let url = try? await storage.signedDownloadURL(objectKey: key, bucket: "avatars", expiresIn: 600) {
                if let (data, resp) = try? await URLSession.shared.data(from: url),
                   let http = resp as? HTTPURLResponse,
                   200..<300 ~= http.statusCode {
                    if let img = Self.decodeImage(data: data, response: http) {
                        await MainActor.run {
                            self.image = img
                            // Cache for instant display next time
                            Self.avatarCache[userId] = img
                        }
                        return
                    }
                }
            }
        }
        
        // If primary keys fail, try other extensions
        let exts = ["jpeg", "png", "heic", "pdf"]
        var keys: [String] = []
        for ext in exts {
            keys.append("\(uidLower).\(ext)")
            keys.append("\(uidLower)-avatar.\(ext)")
            keys.append("\(uidUpper).\(ext)")
            keys.append("\(uidUpper)-avatar.\(ext)")
        }
        
        for key in keys {
            if let url = try? await storage.signedDownloadURL(objectKey: key, bucket: "avatars", expiresIn: 600) {
                if let (data, resp) = try? await URLSession.shared.data(from: url),
                   let http = resp as? HTTPURLResponse,
                   200..<300 ~= http.statusCode {
                    if let img = Self.decodeImage(data: data, response: http) {
                        await MainActor.run {
                            self.image = img
                            Self.avatarCache[userId] = img
                        }
                        return
                    }
                }
            }
        }
        #endif
    }

    // no-op helper removed; we rely on isCurrentUser param

    private static func initials(from name: String?) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let parts = trimmed.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    private static func decodeImage(data: Data, response: HTTPURLResponse) -> UIImage? {
        if let img = UIImage(data: data) { return img }
        // Try PDF first page thumbnail
        #if canImport(PDFKit)
        let mime = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if mime.contains("pdf") || data.starts(with: Array("%PDF".utf8)) {
            if let doc = PDFDocument(data: data), let page = doc.page(at: 0) {
                let rect = page.bounds(for: .mediaBox)
                let w = max(64, rect.width.isFinite && rect.width > 0 ? rect.width/2 : 128)
                let h = max(64, rect.height.isFinite && rect.height > 0 ? rect.height/2 : 128)
                let size = CGSize(width: w, height: h)
                return page.thumbnail(of: size, for: .mediaBox)
            }
        }
        #endif
        return nil
    }
}
