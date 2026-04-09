//
// ForgotPasswordView.swift
// KafeCam
//
// Created by Jose Manuel Sanchez on 28/09/25
//

//
// ForgotPasswordView.swift
// KafeCam
//
// Flujo de recuperación de contraseña para arquitectura phone@kafe.local.
// No usa resetPasswordForEmail (requeriría email real).
// En su lugar: verifica identidad por nombre+teléfono → re-autentica con
// contraseña actual → actualiza contraseña en sesión temporal → cierra sesión.
//

import SwiftUI
#if canImport(Supabase)
import Supabase
#endif

struct ForgotPasswordView: View {

    // MARK: - Step 1: verificación de identidad
    @State private var firstName: String = ""
    @State private var lastName: String  = ""
    @State private var phone: String     = ""

    // MARK: - Step 2: nueva contraseña
    @State private var currentPassword:  String = ""
    @State private var newPassword:      String = ""
    @State private var confirmPassword:  String = ""

    // MARK: - Estado
    @State private var step: Int = 1
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showSuccess  = false

    @Environment(\.dismiss) private var dismiss

    private let accent = Color(red: 88/255, green: 129/255, blue: 87/255)
    private let dark   = Color(red: 82/255, green: 76/255,  blue: 41/255)

    var body: some View {
        Form {
            if step == 1 {
                // ── Paso 1: confirmar que el usuario existe ──────────────
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ingresa los datos con los que te registraste.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Verificación de identidad") {
                    TextField("Nombres", text: $firstName)
                        .textContentType(.givenName)
                        .autocorrectionDisabled()

                    TextField("Apellidos", text: $lastName)
                        .textContentType(.familyName)
                        .autocorrectionDisabled()

                    TextField("Teléfono (10 dígitos)", text: $phone)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                }

                if let e = errorMessage {
                    Section {
                        Text(e).foregroundColor(.red).font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task { await verifyIdentity() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView().tint(accent)
                            } else {
                                Text("Continuar").foregroundStyle(accent)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                }

            } else {
                // ── Paso 2: cambiar contraseña ───────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ingresa tu contraseña actual para confirmar tu identidad y luego elige una nueva.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Contraseña actual") {
                    SecureField("Contraseña actual", text: $currentPassword)
                        .textContentType(.password)
                }

                Section("Nueva contraseña") {
                    SecureField("Nueva contraseña (mín. 8 caracteres)", text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField("Confirmar nueva contraseña", text: $confirmPassword)
                        .textContentType(.newPassword)
                }

                if let e = errorMessage {
                    Section {
                        Text(e).foregroundColor(.red).font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task { await changePassword() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView().tint(accent)
                            } else {
                                Text("Guardar contraseña").foregroundStyle(accent)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .navigationTitle("Recuperar contraseña")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Contraseña actualizada", isPresented: $showSuccess) {
            Button("Iniciar sesión") { dismiss() }
        } message: {
            Text("Tu contraseña fue cambiada exitosamente. Inicia sesión con tu nueva contraseña.")
        }
    }

    // MARK: - Paso 1: verificar que nombre + teléfono coincidan en DB

    private func verifyIdentity() async {
        errorMessage = nil
        let trimPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimFirst.count >= 2 else {
            errorMessage = "Ingresa tu nombre."
            return
        }
        guard trimPhone.count == 10, trimPhone.allSatisfy({ $0.isNumber }) else {
            errorMessage = "Teléfono inválido (10 dígitos)."
            return
        }

        isLoading = true
        defer { isLoading = false }

        #if canImport(Supabase)
        do {
            struct Row: Decodable { let name: String?; let phone: String? }
            let rows: [Row] = try await SupaClient.shared
                .from("profiles")
                .select("name,phone")
                .eq("phone", value: trimPhone)
                .limit(1)
                .execute()
                .value

            guard let row = rows.first else {
                errorMessage = "No se encontró ninguna cuenta con ese teléfono."
                return
            }

            let tokens = (row.name ?? "").split(whereSeparator: { $0.isWhitespace })
            let firstOK = tokens.first
                .map(String.init)?
                .localizedCaseInsensitiveCompare(trimFirst) == .orderedSame

            guard firstOK else {
                errorMessage = "Los datos no coinciden con la cuenta registrada."
                return
            }

            // Identidad verificada → mostrar paso 2
            withAnimation { step = 2 }

        } catch {
            errorMessage = "Error de conexión. Intenta de nuevo."
        }
        #else
        withAnimation { step = 2 }
        #endif
    }

    // MARK: - Paso 2: re-autenticar y cambiar contraseña

    private func changePassword() async {
        errorMessage = nil
        let trimPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !currentPassword.isEmpty else {
            errorMessage = "Ingresa tu contraseña actual."
            return
        }
        guard newPassword.count >= 8 else {
            errorMessage = "La nueva contraseña debe tener al menos 8 caracteres."
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Las contraseñas no coinciden."
            return
        }
        guard newPassword != currentPassword else {
            errorMessage = "La nueva contraseña debe ser diferente a la actual."
            return
        }

        isLoading = true
        defer { isLoading = false }

        #if canImport(Supabase)
        do {
            // 1. Iniciar sesión con credenciales actuales para obtener sesión válida
            let email = "\(trimPhone)@kafe.local"
            _ = try await SupaClient.shared.auth.signIn(
                email: email,
                password: currentPassword
            )

            // 2. Con sesión activa, actualizar la contraseña
            _ = try await SupaClient.shared.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 3. Cerrar la sesión temporal (el usuario debe volver a login)
            try? await SupaClient.shared.auth.signOut()

            // 4. Mostrar confirmación y navegar a login
            showSuccess = true

        } catch {
            let msg = String(describing: error).lowercased()
            if msg.contains("invalid") || msg.contains("credentials") || msg.contains("wrong") {
                errorMessage = "Contraseña actual incorrecta."
            } else {
                errorMessage = "No se pudo actualizar la contraseña. Intenta de nuevo."
            }
        }
        #else
        showSuccess = true
        #endif
    }
}

#Preview {
    NavigationStack { ForgotPasswordView() }
}
