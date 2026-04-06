//
// ForgotPasswordView.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

import SwiftUI
#if canImport(Supabase)
import Supabase
#endif

struct ForgotPasswordView: View {
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var step: Int = 1
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            if step == 1 {
                Section("Verificación de identidad") {
                    TextField("Nombres", text: $firstName)
                    TextField("Apellidos", text: $lastName)
                    TextField("Teléfono (10 dígitos)", text: $phone)
                        .keyboardType(.numberPad)
                }
                if let e = errorMessage { Text(e).foregroundColor(.red) }
                Section { Button("Continuar") { Task { await verify() } } }
            } else {
                Section("Nueva contraseña") {
                    SecureField("Contraseña nueva", text: $newPassword)
                    SecureField("Confirmar contraseña", text: $confirmPassword)
                }
                if let e = errorMessage { Text(e).foregroundColor(.red) }
                Section { Button("Guardar") { Task { await resetPassword() } } }
            }
        }
        .navigationTitle("Recuperar contraseña")
    }

    private func verify() async {
        errorMessage = nil
        let okPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard okPhone.count == 10 else { errorMessage = "Teléfono inválido"; return }
        // Check against DB: must match an existing profile with same first token + optional last token + phone
        #if canImport(Supabase)
        do {
            struct Row: Decodable { let id: UUID; let name: String?; let phone: String? }
            let rows: [Row] = try await SupaClient.shared
                .from("profiles")
                .select("id,name,phone")
                .eq("phone", value: okPhone)
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { errorMessage = "No se encontró usuario"; return }
            let tokens = (row.name ?? "").split(separator: " ")
            let firstOK = tokens.first.map(String.init)?.localizedCaseInsensitiveCompare(firstName.trimmingCharacters(in: .whitespaces)) == .orderedSame
            let lastOK: Bool = {
                let last = lastName.trimmingCharacters(in: .whitespaces)
                if last.isEmpty { return true }
                return tokens.dropFirst().first.map(String.init)?.localizedCaseInsensitiveCompare(last) == .orderedSame
            }()
            guard firstOK && lastOK else { errorMessage = "Datos no coinciden"; return }
            step = 2
        } catch {
            errorMessage = "Error de verificación"
        }
        #else
        step = 2
        #endif
    }

    private func resetPassword() async {
        errorMessage = nil
        guard newPassword.count >= 6 else { errorMessage = "Mínimo 6 caracteres"; return }
        guard newPassword == confirmPassword else { errorMessage = "No coincide la confirmación"; return }
        #if canImport(Supabase)
        do {
            // User must re-authenticate in a real flow; here we attempt a direct update if session exists
            try await SupaClient.shared.auth.update(user: UserAttributes(password: newPassword))
            dismiss()
        } catch {
            errorMessage = "No se pudo guardar"
        }
        #else
        dismiss()
        #endif
    }
}

#Preview { NavigationStack { ForgotPasswordView() } }


