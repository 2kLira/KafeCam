//
// ChangePasswordView.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import SwiftUI
#if canImport(Supabase)
import Supabase
#endif

struct ChangePasswordView: View {
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String? = nil
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Nueva contraseña") {
                SecureField("Contraseña nueva", text: $newPassword)
                SecureField("Confirmar contraseña", text: $confirmPassword)
            }
            if let e = errorMessage { Text(e).foregroundColor(.red) }
            Section {
                Button("Guardar") { Task { await onSave() } }
                    .disabled(isSaving)
            }
        }
        .navigationTitle("Cambiar contraseña")
        // Use system back button only; avoid double chevron
    }

    private func onSave() async {
        errorMessage = nil
        guard newPassword.count >= 6 else { errorMessage = "Mínimo 6 caracteres"; return }
        guard newPassword == confirmPassword else { errorMessage = "Las contraseñas no coinciden"; return }
        isSaving = true
        defer { isSaving = false }
        #if canImport(Supabase)
        do {
            try await SupaClient.shared.auth.update(user: UserAttributes(password: newPassword))
            dismiss()
        } catch {
            errorMessage = "No se pudo actualizar la contraseña"
        }
        #else
        dismiss()
        #endif
    }
}

#Preview {
    NavigationStack { ChangePasswordView() }
}


