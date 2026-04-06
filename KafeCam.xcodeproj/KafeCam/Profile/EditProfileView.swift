//
// EditProfileView.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import SwiftUI

struct EditProfileView: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var organization: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @EnvironmentObject var avatarStore: AvatarStore
    @Environment(\.dismiss) private var dismiss

    private let repo = ProfilesRepository()

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color(.systemGray5))
                        if let img = avatarStore.image {
                            Image(uiImage: img).resizable().scaledToFill().clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().padding(8)
                        }
                    }
                    .frame(width: 128, height: 128)
                    Button {
                        NotificationCenter.default.post(name: .init("kafe.open.profile.camera"), object: nil)
                    } label: {
                        Text("Cambiar foto")
                    }
                    Button(role: .destructive) {
                        Task { await deleteAvatar() }
                    } label: {
                        Text("Eliminar foto")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

            Section("Cuenta") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Teléfono").font(.subheadline).foregroundStyle(.secondary)
                    TextField("Teléfono", text: $phone).keyboardType(.numberPad)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mail").font(.subheadline).foregroundStyle(.secondary)
                    TextField("Mail", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Organización").font(.subheadline).foregroundStyle(.secondary)
                    TextField("Organización", text: $organization)
                }
            }

            Section("Nombre") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombres").font(.subheadline).foregroundStyle(.secondary)
                    TextField("Nombres", text: $firstName).textInputAutocapitalization(.words)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apellidos").font(.subheadline).foregroundStyle(.secondary)
                    TextField("Apellidos", text: $lastName).textInputAutocapitalization(.words)
                }
            }

            if let e = errorMessage { Text(e).foregroundColor(.red) }
            Section {
                Button("Guardar cambios") { Task { await save() } }
                    .disabled(isSaving)
            }
        }
        .navigationTitle("Editar perfil")
        .task { await loadInitial() }
    }

    private func loadInitial() async {
        do {
            let p = try await repo.getOrCreateCurrent()
            let full = (p.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if full.isEmpty {
                firstName = ""
                lastName = ""
            } else {
                let parts = full.split(separator: " ")
                firstName = parts.first.map(String.init) ?? full
                lastName = parts.dropFirst().joined(separator: " ")
            }
            email = p.email ?? ""
            phone = p.phone ?? ""
            organization = p.organization ?? ""
        } catch {
            errorMessage = "No se pudo cargar el perfil"
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let fullName = lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? firstName : "\(firstName) \(lastName)"
            _ = try await repo.upsertCurrentUserProfile(
                name: fullName,
                email: email.isEmpty ? nil : email,
                phone: phone.isEmpty ? nil : phone,
                organization: organization.isEmpty ? nil : organization
            )
            // Keep Home header in sync immediately
            let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !first.isEmpty { UserDefaults.standard.set(first, forKey: "displayName") }
            dismiss()
        } catch {
            errorMessage = "No se pudo guardar"
        }
    }

    private func deleteAvatar() async {
        #if canImport(Supabase)
        do {
            let uid = try await SupaAuthService.currentUserId()
            let key = "\(uid.uuidString).jpg"
            // Overwrite with a 1x1 transparent png to effectively clear; or implement storage delete if allowed
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
            let img = renderer.image { _ in UIColor.clear.setFill(); UIBezierPath(rect: CGRect(x: 0, y: 0, width: 1, height: 1)).fill() }
            if let data = img.pngData() {
                let storage = StorageRepository()
                try await storage.upload(bucket: "avatars", objectKey: key, data: data, contentType: "image/png", upsert: true)
            }
            avatarStore.clear()
        } catch { }
        #endif
    }
}

#Preview { NavigationStack { EditProfileView() } }


