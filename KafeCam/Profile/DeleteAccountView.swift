//
// DeleteAccountView.swift
// KafeCam
//
// App Store Guideline 5.1.1(v): Account deletion required
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var confirmText: String = ""
    @State private var isDeleting = false
    @State private var errorMessage: String? = nil
    @State private var showFinalConfirmation = false

    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    private let requiredConfirmation = "ELIMINAR"

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Esta acción es permanente", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundColor(.red)

                    Text("Al eliminar tu cuenta se borrarán todos tus datos, incluyendo:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        BulletRow(text: "Tu perfil y datos personales")
                        BulletRow(text: "Historial de capturas y diagnósticos")
                        BulletRow(text: "Fotos de perfil y plantíos")
                        BulletRow(text: "Membresías de comunidad")
                    }
                    .padding(.leading, 4)

                    Text("Esta acción no se puede deshacer.")
                        .font(.footnote)
                        .foregroundColor(.red)
                        .bold()
                }
                .padding(.vertical, 8)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Escribe \"\(requiredConfirmation)\" para confirmar:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("", text: $confirmText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button(role: .destructive) {
                    showFinalConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Eliminar mi cuenta")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(confirmText != requiredConfirmation || isDeleting)
            }
        }
        .navigationTitle("Eliminar cuenta")
        .navigationBarTitleDisplayMode(.inline)
        .alert("¿Estás seguro?", isPresented: $showFinalConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Sí, eliminar mi cuenta", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Se eliminarán permanentemente todos tus datos. No podrás recuperar tu cuenta.")
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil

        #if canImport(Supabase)
        do {
            let userId = try await SupaAuthService.currentUserId()

            // 1. Delete captures for this user (best-effort)
            _ = try? await SupaClient.shared
                .from("captures")
                .delete()
                .eq("uploaded_by_user_id", value: userId.uuidString)
                .execute()

            // 2. Delete profile row (best-effort — also deleted by cascade if configured)
            _ = try? await SupaClient.shared
                .from("profiles")
                .delete()
                .eq("id", value: userId.uuidString)
                .execute()

            // 3. Delete avatar from storage (best-effort)
            let storage = StorageRepository()
            let avatarKey = "\(userId.uuidString.lowercased()).jpg"
            try? await storage.delete(bucket: "avatars", objectKey: avatarKey)

            // 4. Delete auth user via server-side RPC (REQUIRED — this is what actually prevents re-login)
            //    Requires: CREATE FUNCTION delete_current_user() SECURITY DEFINER in Supabase SQL Editor
            try await SupaAuthService.deleteCurrentUser()

            // 5. Clear all local data
            clearLocalData()

            // 6. Go back to login
            NotificationCenter.default.post(name: .init("kafe.session.logout"), object: nil)
        } catch {
            errorMessage = "No se pudo eliminar la cuenta. Intenta de nuevo."
            isDeleting = false
        }
        #else
        clearLocalData()
        NotificationCenter.default.post(name: .init("kafe.session.logout"), object: nil)
        #endif
    }

    private func clearLocalData() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "displayName")
        defaults.removeObject(forKey: "profileInitials")
        defaults.removeObject(forKey: "avatarKey")
        defaults.removeObject(forKey: "lastUserId")
        defaults.removeObject(forKey: "kafe.isLoggedIn")
        defaults.removeObject(forKey: "signupSuccess")
    }
}

private struct BulletRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
    }
}
