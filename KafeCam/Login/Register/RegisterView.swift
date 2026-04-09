//
//  RegisterView.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//


//
//  RegisterView.swift
//  KafeCam
//

import SwiftUI

struct RegisterView: View {
    @ObservedObject var vm: RegisterViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    private let darkColor   = Color(red: 82/255,  green: 76/255,  blue: 41/255)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundColor(accentColor)

                Text("Crear cuenta")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(accentColor)

                Text("Regístrate con tus datos")
                    .foregroundColor(darkColor)

                AuthCard {
                    ktextfild(title: "Nombres",
                              text: $vm.firstName,
                              keyboard: .default,
                              contentType: .givenName)
                    if let e = vm.firstNameError {
                        Text(e).font(.caption).foregroundColor(.red)
                    }

                    ktextfild(title: "Apellidos",
                              text: $vm.lastName,
                              keyboard: .default,
                              contentType: .familyName)
                    if let e = vm.lastNameError {
                        Text(e).font(.caption).foregroundColor(.red)
                    }

                    ktextfild(title: "Teléfono (10 dígitos)",
                              text: $vm.phone,
                              keyboard: .numberPad,
                              contentType: .telephoneNumber)
                    if let e = vm.phoneError {
                        Text(e).font(.caption).foregroundColor(.red)
                    }

                    ktextfild(title: "Correo (opcional)",
                              text: $vm.email,
                              keyboard: .emailAddress,
                              contentType: .emailAddress)
                    if let e = vm.emailError {
                        Text(e).font(.caption).foregroundColor(.red)
                    }

                    ktextfild(title: "Contraseña",
                              text: $vm.password,
                              isSecure: true,
                              keyboard: .default,
                              contentType: .newPassword)
                    if let e = vm.passwordError {
                        Text(e).font(.caption).foregroundColor(.red)
                    }

                    ktextfild(title: "Organización",
                              text: $vm.organization,
                              isSecure: false,
                              keyboard: .default,
                              contentType: .organizationName,
                              isDisabled: true)

                    Button("Crear cuenta") {
                        vm.submit()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        if vm.isLoading { ProgressView().tint(.white) }
                    }
                    .disabled(vm.isLoading)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .padding(.horizontal, 20)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            let minDate = Calendar.current.date(byAdding: .year, value: -120, to: Date()) ?? .distantPast
            if vm.dateOfBirth > Date()    { vm.dateOfBirth = Date() }
            if vm.dateOfBirth < minDate   { vm.dateOfBirth = minDate }
        }
        // Dismiss as soon as the VM signals success
        .onChange(of: vm.registrationSucceeded) { succeeded in
            if succeeded { dismiss() }
        }
    }
}
