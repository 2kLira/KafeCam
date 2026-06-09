// ProfileTabView.swift
// KafeCam
import Foundation
import SwiftUI
import PhotosUI

struct ProfileTabView: View {
    @StateObject private var vm = ProfileTabViewModel()
    // Observing LanguageManager forces a re-render whenever the user switches language,
    // so all Text() keys are re-looked-up against the new bundle immediately.
    @ObservedObject private var lang = LanguageManager.shared

    // Avatar / picker (pure UI state — stays in View)
    @State private var showAvatarEditor = false
    @State private var pickedImage: UIImage? = nil
    @State private var showAvatarSource = false
    @State private var presentPicker = false
    @State private var avatarSourceToPresent: ImagePicker.Source = .library
    @State private var showViewer = false

    @EnvironmentObject var avatarStore: AvatarStore
    @EnvironmentObject var session: SessionViewModel

    var body: some View {
        if session.isGuest {
            GuestLoginPromptView()
        } else {
            NavigationStack {
                Form {
                    // MARK: - CUENTA (header con avatar y nombre)
                    Section {
                        VStack(spacing: 10) {
                            let headerImage = avatarStore.image ?? vm.avatarImage
                            ZStack {
                                Circle().fill(Color(.systemGray5))
                                if let img = headerImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(Circle())
                                } else {
                                    avatarPlaceholder
                                }
                            }
                            .frame(width: 128, height: 128)
                            .onTapGesture {
                                let hasAvatar = (avatarStore.image != nil) || (vm.avatarImage != nil)
                                if vm.isEditing { showAvatarSource = true }
                                else if hasAvatar { showViewer = true }
                                else { showAvatarSource = true }
                            }

                            Spacer(minLength: 4)
                            Text(vm.displayName.isEmpty ? "—" : vm.displayName)
                                .font(.title3.bold())
                            if let email = vm.email, !email.isEmpty {
                                Text(email).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } header: {
                        Text("Cuenta").foregroundStyle(AppTheme.accent)
                    }
                    .listRowBackground(Color.clear)

                    // MARK: - MODO EDICIÓN
                    if vm.isEditing {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nombres").font(.subheadline).foregroundStyle(.secondary)
                                TextField("Nombres", text: $vm.editFirstName)
                                    .textInputAutocapitalization(.words)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Apellidos").font(.subheadline).foregroundStyle(.secondary)
                                TextField("Apellidos", text: $vm.editLastName)
                                    .textInputAutocapitalization(.words)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Teléfono").font(.subheadline).foregroundStyle(.secondary)
                                Text(vm.phone?.isEmpty == false ? (vm.phone ?? "—") : "—")
                                    .foregroundStyle(.secondary)
                                Text("Tu teléfono es tu identificador de acceso y no puede cambiarse aquí.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Correo").font(.subheadline).foregroundStyle(.secondary)
                                TextField("Correo", text: $vm.editEmail)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Organización").font(.subheadline).foregroundStyle(.secondary)
                                TextField("Organización", text: $vm.editOrganization)
                            }
                            LabeledContent {
                                Text(roleDisplayText(vm.role))
                            } label: {
                                Label { Text("Rol") } icon: {
                                    Image(systemName: "person.text.rectangle")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        } header: {
                            Text("Cuenta").foregroundStyle(AppTheme.accent)
                        }

                        // Información personal (edición)
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Género").font(.subheadline).foregroundStyle(.secondary)
                                Picker("Género", selection: $vm.editGender) {
                                    Text("Masculino").tag("male")
                                    Text("Femenino").tag("female")
                                    Text("Otro").tag("other")
                                }
                                .pickerStyle(.segmented)
                            }
                            DatePicker("Fecha de nacimiento", selection: $vm.editDOB, displayedComponents: .date)
                            TextField("Edad", text: $vm.editAge).keyboardType(.numberPad)
                            TextField("País", text: $vm.editCountry)
                            TextField("Estado", text: $vm.editState)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Biografía").font(.subheadline).foregroundStyle(.secondary)
                                TextEditor(text: Binding(
                                    get: { vm.about ?? "" },
                                    set: { vm.about = $0 }
                                ))
                                .frame(minHeight: 120)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator)))
                            }
                            Toggle("Mostrar género", isOn: $vm.showGender)
                            Toggle("Mostrar fecha de nacimiento", isOn: $vm.showDateOfBirth)
                            Toggle("Mostrar edad", isOn: $vm.showAge)
                            Toggle("Mostrar país", isOn: $vm.showCountry)
                            Toggle("Mostrar estado", isOn: $vm.showState)
                        } header: {
                            Text("Información").foregroundStyle(AppTheme.accent)
                        }

                    } else {
                        // MARK: - DETALLES (modo lectura)
                        Section {
                            LabeledContent {
                                Text(vm.phone ?? "—")
                            } label: {
                                Label { Text("Teléfono") } icon: {
                                    Image(systemName: "phone.fill").foregroundStyle(AppTheme.accent)
                                }
                            }
                            LabeledContent {
                                Text(vm.email?.isEmpty == false ? (vm.email ?? "—") : "—")
                            } label: {
                                Label { Text("Mail") } icon: {
                                    Image(systemName: "envelope.fill").foregroundStyle(AppTheme.accent)
                                }
                            }
                            LabeledContent {
                                Text(vm.organization ?? "—")
                            } label: {
                                Label { Text("Organización") } icon: {
                                    Image(systemName: "leaf.fill").foregroundStyle(AppTheme.accent)
                                }
                            }
                            // Role inside the Details section
                            if let role = vm.role {
                                LabeledContent {
                                    Text(roleDisplayText(role))
                                } label: {
                                    Label { Text("Rol") } icon: {
                                        Image(systemName: "person.text.rectangle")
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                            }
                        } header: {
                            Text("Detalles").foregroundStyle(AppTheme.accent)
                        }

                        // Assignment flows (gated by feature flag)
                        if FeatureFlags.assignmentsEnabled {
                            if let tname = vm.technicianName, !tname.isEmpty {
                                LabeledContent("Técnico", value: tname)
                            }
                            if !vm.incomingRequests.isEmpty {
                                NavigationLink {
                                    RequestsInboxView(requests: vm.incomingRequests)
                                } label: {
                                    Label("Peticiones", systemImage: "tray.full.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            if vm.canManageFarmers {
                                NavigationLink {
                                    FarmersListView()
                                } label: {
                                    Label("Farmers", systemImage: "person.3.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                    }

                    // MARK: - INFORMACIÓN (datos personales, solo si existen)
                    if (vm.gender?.isEmpty == false) || (vm.dateOfBirth != nil) || (vm.age != nil) ||
                        (vm.country?.isEmpty == false) || (vm.state?.isEmpty == false) || (vm.about?.isEmpty == false) {
                        Section {
                            LabeledContent("Género", value: labelGender(vm.gender))
                            LabeledContent("Fecha de nacimiento", value: labelDate(vm.dateOfBirth))
                            LabeledContent("Edad", value: vm.age.map { String($0) } ?? "—")
                            LabeledContent("País", value: vm.country ?? "—")
                            LabeledContent("Estado", value: vm.state ?? "—")
                            if let about = vm.about, !about.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Biografía")
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.accent)
                                    Text(about)
                                }
                            }
                        } header: {
                            Text("Información").foregroundStyle(AppTheme.accent)
                        }
                    }

                    // MARK: - IDIOMA
                    LanguageSection()

                    // MARK: - CONFIGURACIÓN
                    Section {
                        NavigationLink { ChangePasswordView() } label: {
                            Label("Cambiar contraseña", systemImage: "key.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                        // Cerrar sesión no es una acción destructiva (no borra datos)
                        Button { vm.logout() } label: {
                            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red.opacity(0.85))
                        }
                    } header: {
                        Text("Configuración").foregroundStyle(AppTheme.accent)
                    }

                    // MARK: - LEGAL
                    Section {
                        Link(destination: URL(string: "https://apps.apple.com/mx/app/kafecam/id6762103541")!) {
                            Label("Política de privacidad y términos", systemImage: "hand.raised.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    } header: {
                        Text("Legal").foregroundStyle(AppTheme.accent)
                    }

                    // MARK: - ZONA DE PELIGRO
                    Section {
                        NavigationLink {
                            DeleteAccountView()
                        } label: {
                            Label("Eliminar mi cuenta", systemImage: "trash.fill")
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("Zona de peligro").foregroundStyle(.red)
                    }
                }
                .navigationTitle("Perfil")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if vm.isEditing {
                            Button("Cancelar") { vm.cancelEditing() }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if vm.isSaving {
                            ProgressView().controlSize(.small).tint(AppTheme.accent)
                        } else {
                            Button(vm.isEditing ? "Guardar" : "Editar") {
                                vm.isEditing ? vm.commitEdits() : vm.beginEditing()
                            }
                        }
                    }
                }
            }
            // Avatar: editor / visor / fuentes
            .sheet(isPresented: $showAvatarEditor) {
                if let base = pickedImage {
                    AvatarEditorView(original: base) {
                        showAvatarEditor = false
                    } onSave: { cropped in
                        vm.avatarImage = cropped
                        Task {
                            #if canImport(Supabase)
                            if let uid = try? await SupaAuthService.currentUserId() {
                                let localKey = "\(uid.uuidString)-local.jpg"
                                avatarStore.set(image: cropped, key: localKey)
                            } else {
                                avatarStore.set(image: cropped, key: "local-avatar.jpg")
                            }
                            #else
                            avatarStore.set(image: cropped, key: "local-avatar.jpg")
                            #endif
                            await vm.uploadAvatar(cropped)
                        }
                        showAvatarEditor = false
                    }
                }
            }
            .fullScreenCover(isPresented: $showViewer) {
                AvatarFullScreenView(image: avatarStore.image ?? vm.avatarImage) { showViewer = false }
            }
            .confirmationDialog("Foto de perfil", isPresented: $showAvatarSource, titleVisibility: .visible) {
                Button("Tomar foto") { avatarSourceToPresent = .camera; presentPicker = true }
                Button("Ver biblioteca") { avatarSourceToPresent = .library; presentPicker = true }
                Button("Eliminar foto", role: .destructive) {
                    avatarStore.clear()
                    vm.avatarImage = nil
                }
                Button("Cancelar", role: .cancel) { }
            }
            .sheet(isPresented: $presentPicker) {
                ImagePicker(source: avatarSourceToPresent == .camera ? .camera : .library) { img in
                    pickedImage = img
                }
            }
            .onChange(of: pickedImage) { _, img in
                guard img != nil else { return }
                DispatchQueue.main.async { showAvatarEditor = true }
            }
            .task { await vm.load() }
        }
    }

    // MARK: - Avatar Placeholder
    /// Shows initials in view mode; shows "+" icon in edit mode.
    @ViewBuilder
    private var avatarPlaceholder: some View {
        if vm.isEditing {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.accent)
        } else {
            let initials = makeInitials(from: vm.displayName)
            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(.systemGray3))
            } else {
                Text(initials)
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }
}

// MARK: - Private helpers
private extension ProfileTabView {

    func makeInitials(from name: String) -> String {
        let parts = name.split(whereSeparator: { $0.isWhitespace })
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    func labelGender(_ g: String?) -> String {
        switch (g ?? "").lowercased() {
        case "male":   return "Masculino"
        case "female": return "Femenino"
        case "other":  return "Otro"
        default:       return "—"
        }
    }

    func labelDate(_ d: Date?) -> String {
        guard let d else { return "—" }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    func roleDisplayText(_ role: String?) -> String {
        guard let role = role else { return "—" }
        let r = role.lowercased()
        return (r == "technician" || r == "admin") ? "Técnico" : "Caficultor"
    }
}

#Preview {
    ProfileTabView()
}
