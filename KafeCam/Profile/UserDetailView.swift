import SwiftUI

struct UserDetailView: View {
    let userId: UUID

    @State private var profile: ProfileDTO? = nil
    @State private var avatar: UIImage? = nil
    @EnvironmentObject var avatarStore: AvatarStore
    @State private var isTech = false
    @State private var isLoading = false
    @State private var captures: [CaptureDTO] = []
    @State private var showViewer = false

    private let accentColor  = Color(red: 88/255, green: 129/255, blue: 87/255)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 12) {
                    Button { showViewer = true } label: { Avatar(size: 120) }
                        .buttonStyle(.plain)
                    VStack(alignment: .center, spacing: 6) {
                        Text(profile?.name ?? "—")
                            .font(.title2.bold())
                        if let role = profile?.role { Text(roleLabel(role)).font(.footnote).foregroundStyle(.secondary) }
                        if let phone = profile?.phone, !phone.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill").foregroundStyle(.secondary).font(.caption)
                                Text(phone).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                        if let email = profile?.email, !email.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope.fill").foregroundStyle(.secondary).font(.caption)
                                Text(email).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

                if let p = profile {
                    Section {
                        if (p.showGender ?? true) { LabeledContent("Género", value: labelGender(p.gender)) }
                        if (p.showDateOfBirth ?? true) { LabeledContent("Fecha de nacimiento", value: labelDate(p.dateOfBirth)) }
                        if (p.showAge ?? true) { LabeledContent("Edad", value: p.age.map { String($0) } ?? "—") }
                        if (p.showCountry ?? true) { LabeledContent("País", value: p.country ?? "—") }
                        if (p.showState ?? true) { LabeledContent("Estado", value: p.state ?? "—") }
                    } header: { Text("Información").foregroundStyle(accentColor) }

                    if (p.showAbout ?? true), let about = p.about, !about.isEmpty {
                        Section {
                            Text(about).fixedSize(horizontal: false, vertical: true)
                        } header: { Text("Biografía").foregroundStyle(accentColor) }
                    }
                }

                if isTech {
                    // Technician actions
                    HStack(spacing: 12) {
                        Button {
                            Task { await addToFirm() }
                        } label: {
                            Label("Agregar a firma", systemImage: "person.badge.plus")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task { await removeFromFirm() }
                        } label: {
                            Label("Quitar de firma", systemImage: "person.fill.xmark")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Activity section with captures and map
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actividad")
                        .font(.headline)
                        .foregroundColor(accentColor)
                    
                    // Activity tabs view
                    UserActivityView(userId: userId)
                        // mapViewModel is already available as environment object from HomeView
                        .frame(height: 400)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.top)

                if isLoading { ProgressView().tint(accentColor) }
            }
            .padding()
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
        .task { await load() }
        .fullScreenCover(isPresented: $showViewer) {
            AvatarFullScreenView(image: avatar) {
                showViewer = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("kafe.avatar.updated"))) { _ in
            Task { @MainActor in
                #if canImport(Supabase)
                if let me = try? await SupaAuthService.currentUserId(), me == userId {
                    self.avatar = avatarStore.image
                }
                #endif
            }
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func Avatar(size: CGFloat = 56) -> some View {
        ZStack {
            Circle().fill(Color(.systemGray5))
            if let avatar {
                Image(uiImage: avatar)
                    .resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(Self.initials(from: profile?.name)).font(.headline)
            }
        }
        .frame(width: size, height: size)
    }

    private struct CaptureTile: View {
        let capture: CaptureDTO
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                // Placeholder tile: we could fetch thumbnails via signed URL if needed
                Image(systemName: "photo")
                    .resizable().scaledToFit()
                    .frame(height: 90)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(capture.takenAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Data
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let me = try await SupaAuthService.currentUserId()
            let myProfile = try await ProfilesRepository().get(byId: me)
            isTech = (myProfile.role == "technician" || myProfile.role == "admin")

            profile = try await ProfilesRepository().get(byId: userId)
            // Local-first: if viewing my own profile, use global store immediately
            if me == userId, let img = avatarStore.image { self.avatar = img }
            else { await loadAvatar() }

            // Load captures for this user (subject to RLS)
            let list = try await CapturesRepository().listCaptures(uploadedBy: userId)
            captures = list
        } catch {
            // ignore
        }
    }

    private func loadAvatar() async {
        #if canImport(Supabase)
        let storage = StorageRepository()
        // Try multiple key formats to find the avatar
        let uid = userId.uuidString
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
                    await MainActor.run { self.avatar = img }
                    return
                }
            }
        }
        #endif
    }

    private func labelGender(_ g: String?) -> String {
        switch (g ?? "").lowercased() {
        case "male": return "Masculino"
        case "female": return "Femenino"
        case "other": return "Otro"
        default: return "—"
        }
    }

    private func labelDate(_ d: Date?) -> String {
        guard let d else { return "—" }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    private func addToFirm() async {
        do { try await TechnicianAssignmentsRepository().assign(farmerId: userId) } catch { }
    }

    private func removeFromFirm() async {
        do { try await TechnicianAssignmentsRepository().unassign(farmerId: userId) } catch { }
    }

    private static func initials(from name: String?) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let parts = trimmed.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    private func roleLabel(_ role: String) -> String {
        let r = role.lowercased()
        return (r == "technician" || r == "admin") ? "Técnico" : "Caficultor"
    }
}


