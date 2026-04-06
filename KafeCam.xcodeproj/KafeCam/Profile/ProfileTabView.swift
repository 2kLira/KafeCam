// ProfileTabView.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//
import Foundation
import SwiftUI
import PhotosUI

struct ProfileTabView: View {
    @StateObject private var vm = ProfileTabViewModel()

    // Avatar / picker
    @State private var showAvatarEditor = false
    @State private var pickedImage: UIImage? = nil
    @State private var showAvatarSource = false
    @State private var presentPicker = false
    @State private var avatarSourceToPresent: ImagePicker.Source = .library
    @State private var showViewer = false

    // Edición
    @State private var isEditing = false
    @State private var editFirstName: String = ""
    @State private var editLastName: String = ""
    @State private var editPhone: String = ""
    @State private var editEmail: String = ""
    @State private var editOrganization: String = ""

    // Datos personales (edición)
    @State private var editGender: String = ""
    @State private var editDOB: Date = Date(timeIntervalSince1970: 0)
    @State private var editAge: String = ""
    @State private var editCountry: String = ""
    @State private var editState: String = ""

    // Colores
    let accentColor  = Color(red: 88/255, green: 129/255, blue: 87/255)
    let darkColor    = Color(red: 82/255,  green: 76/255,  blue: 41/255)

    @EnvironmentObject var avatarStore: AvatarStore

    var body: some View {
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
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(accentColor)
                            }
                        }
                        .frame(width: 128, height: 128)
                        .onTapGesture {
                            let hasAvatar = (avatarStore.image != nil) || (vm.avatarImage != nil)
                            if isEditing { showAvatarSource = true }
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
                    Text("Cuenta").foregroundStyle(accentColor)
                }
                .listRowBackground(Color.clear)

                // MARK: - MODO EDICIÓN
                if isEditing {
                    // Datos básicos
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nombres").font(.subheadline).foregroundStyle(.secondary)
                            TextField("Nombres", text: $editFirstName).textInputAutocapitalization(.words)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Apellidos").font(.subheadline).foregroundStyle(.secondary)
                            TextField("Apellidos", text: $editLastName).textInputAutocapitalization(.words)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Teléfono").font(.subheadline).foregroundStyle(.secondary)
                            TextField("Teléfono", text: $editPhone).keyboardType(.numberPad)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Correo").font(.subheadline).foregroundStyle(.secondary)
                            TextField("Correo", text: $editEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Organización").font(.subheadline).foregroundStyle(.secondary)
                            TextField("Organización", text: $editOrganization).disabled(true)
                        }
                        LabeledContent { Text(roleDisplayText(vm.role)) } label: {
                            Label { Text("Rol") } icon: { Image(systemName: "person.text.rectangle").foregroundStyle(accentColor) }
                        }
                    } header: { Text("Cuenta").foregroundStyle(accentColor) }

                    // Información personal
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Género").font(.subheadline).foregroundStyle(.secondary)
                            Picker("Género", selection: $editGender) {
                                Text("Masculino").tag("male")
                                Text("Femenino").tag("female")
                                Text("Otro").tag("other")
                            }
                            .pickerStyle(.segmented)
                        }
                        DatePicker("Fecha de nacimiento", selection: $editDOB, displayedComponents: .date)
                        TextField("Edad", text: $editAge).keyboardType(.numberPad)
                        TextField("País", text: $editCountry)
                        TextField("Estado", text: $editState)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Biografía").font(.subheadline).foregroundStyle(.secondary)
                            TextEditor(text: Binding(get: { vm.about ?? "" }, set: { vm.about = $0 }))
                                .frame(minHeight: 120)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator)))
                        }
                        Toggle("Mostrar género", isOn: $vm.showGender)
                        Toggle("Mostrar fecha de nacimiento", isOn: $vm.showDateOfBirth)
                        Toggle("Mostrar edad", isOn: $vm.showAge)
                        Toggle("Mostrar país", isOn: $vm.showCountry)
                        Toggle("Mostrar estado", isOn: $vm.showState)
                    } header: {
                        Text("Información").foregroundStyle(accentColor)
                    }
                } else {
                    // MARK: - DETALLES (modo lectura)
                    Section {
                        LabeledContent { Text(vm.phone ?? "—") } label: {
                            Label { Text("Teléfono") } icon: { Image(systemName: "phone.fill").foregroundStyle(accentColor) }
                        }
                        LabeledContent { Text(vm.email?.isEmpty == false ? (vm.email ?? "—") : "—") } label: {
                            Label { Text("Mail") } icon: { Image(systemName: "envelope.fill").foregroundStyle(accentColor) }
                        }
                        LabeledContent { Text(vm.organization ?? "—") } label: {
                            Label { Text("Organización") } icon: { Image(systemName: "leaf.fill").foregroundStyle(accentColor) }
                        }
                    } header: {
                        Text("Detalles").foregroundStyle(accentColor)
                    }

                    if let role = vm.role {
                        LabeledContent {
                            Text(roleDisplayText(role))
                        } label: {
                            Label { Text("Rol") } icon: { Image(systemName: "person.text.rectangle").foregroundStyle(accentColor) }
                        }
                    }

                    if let tname = vm.technicianName, !tname.isEmpty {
                        LabeledContent("Técnico", value: tname)
                    }

                    if !(vm.incomingRequests.isEmpty) {
                        NavigationLink {
                            RequestsInboxView(requests: vm.incomingRequests)
                        } label: {
                            Label("Peticiones", systemImage: "tray.full.fill").foregroundStyle(accentColor)
                        }
                    }

                    if vm.canManageFarmers {
                        NavigationLink {
                            FarmersListView()
                        } label: {
                            Label("Farmers", systemImage: "person.3.fill").foregroundStyle(accentColor)
                        }
                    }
                }

                // MARK: - INFORMACIÓN (solo si hay datos guardados)
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
                                Text("Biografía").font(.headline).foregroundStyle(accentColor)
                                Text(about)
                            }
                        }
                    } header: {
                        Text("Información").foregroundStyle(accentColor)
                    }
                }

                // MARK: - IDIOMA
                LanguageSection()

                // MARK: - CONFIGURACIÓN (cambiar contraseña / logout)
                Section {
                    NavigationLink { ChangePasswordView() } label: {
                        Label("Cambiar contraseña", systemImage: "key.fill").foregroundStyle(accentColor)
                    }
                    Button(role: .destructive) { vm.logout() } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right").foregroundStyle(accentColor)
                    }
                } header: {
                    Text("Configuración").foregroundStyle(accentColor)
                }
            }
            .navigationTitle("Perfil")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing { Button("Cancelar") { cancelEdits() } }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Guardar" : "Editar") {
                        isEditing ? saveEdits() : beginEdits()
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
                    // Mostrar al instante, luego subir
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
            // Presentar editor en el siguiente runloop
            DispatchQueue.main.async { showAvatarEditor = true }
        }
        .task { await vm.load() }
    }
}

private struct AvatarView: View {
    let image: UIImage?
    let initials: String
    var body: some View {
        ZStack {
            Circle().fill(Color(.systemGray5))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Text(initials.isEmpty ? "" : initials)
                    .font(.headline)
            }
        }
        .frame(width: 48, height: 48)
        .clipped()
    }
}

#Preview {
    ProfileTabView()
}

private extension ProfileTabView {
    func labelGender(_ g: String?) -> String {
        switch (g ?? "").lowercased() {
        case "male": return "Masculino"
        case "female": return "Femenino"
        case "other": return "Otro"
        default: return "—"
        }
    }

    func labelDate(_ d: Date?) -> String {
        guard let d else { return "—" }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    func beginEdits() {
        let full = vm.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if full.isEmpty { editFirstName = ""; editLastName = "" }
        else {
            let parts = full.split(separator: " ")
            editFirstName = parts.first.map(String.init) ?? full
            editLastName = parts.dropFirst().joined(separator: " ")
        }
        editPhone = vm.phone ?? ""
        editEmail = vm.email ?? ""
        editOrganization = vm.organization ?? ""

        // Defaults
        editGender = (vm.gender ?? "").isEmpty ? "male" : (vm.gender ?? "")
        editDOB = vm.dateOfBirth ?? Date(timeIntervalSince1970: 0)
        editAge = vm.age.map { String($0) } ?? ""
        editCountry = vm.country ?? ""
        editState = vm.state ?? ""
        isEditing = true
    }

    func cancelEdits() { isEditing = false }

    func saveEdits() {
        let fullName = editLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? editFirstName
            : "\(editFirstName) \(editLastName)"
        vm.displayName = fullName
        vm.phone = editPhone.isEmpty ? nil : editPhone
        vm.email = editEmail.isEmpty ? nil : editEmail
        vm.organization = editOrganization.isEmpty ? nil : editOrganization

        let first = editFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !first.isEmpty { UserDefaults.standard.set(first, forKey: "displayName") }

        let ageInt = Int(editAge)
        Task {
            await vm.saveProfile(
                name: fullName,
                email: vm.email,
                phone: vm.phone,
                organization: vm.organization,
                gender: editGender,
                dateOfBirth: editDOB,
                age: ageInt,
                country: editCountry,
                state: editState,
                about: vm.about,
                showGender: vm.showGender,
                showDateOfBirth: vm.showDateOfBirth,
                showAge: vm.showAge,
                showCountry: vm.showCountry,
                showState: vm.showState,
                showAbout: vm.showAbout
            )
        }
        isEditing = false
    }

    // Helper para mostrar el rol en español
    func roleDisplayText(_ role: String?) -> String {
        guard let role = role else { return "—" }
        let r = role.lowercased()
        return (r == "technician" || r == "admin") ? "Técnico" : "Caficultor"
    }
}
