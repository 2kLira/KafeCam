import SwiftUI

struct RegisterView: View {
    @ObservedObject var vm: RegisterViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.accent)

                VStack(spacing: 6) {
                    Text("Crear cuenta")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.accent)

                    Text("Regístrate con tus datos")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.dark)
                }

                AuthCard {
                    ktextfild(title: "Nombres",
                              text: $vm.firstName,
                              keyboard: .default,
                              contentType: .givenName)
                    if let e = vm.firstNameError {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }

                    ktextfild(title: "Apellidos",
                              text: $vm.lastName,
                              keyboard: .default,
                              contentType: .familyName)
                    if let e = vm.lastNameError {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }

                    ktextfild(title: "Teléfono (10 dígitos)",
                              text: $vm.phone,
                              keyboard: .numberPad,
                              contentType: .telephoneNumber)
                    if let e = vm.phoneError {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }

                    ktextfild(title: "Correo (opcional)",
                              text: $vm.email,
                              keyboard: .emailAddress,
                              contentType: .emailAddress)
                    if let e = vm.emailError {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }

                    ktextfild(title: "Contraseña",
                              text: $vm.password,
                              isSecure: true,
                              keyboard: .default,
                              contentType: .newPassword)
                    if let e = vm.passwordError {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }

                    ktextfild(title: "Organización (opcional)",
                              text: $vm.organization,
                              isSecure: false,
                              keyboard: .default,
                              contentType: .organizationName,
                              isDisabled: false)

                    // Primary CTA — spinner replaces text while loading
                    Button {
                        vm.submit()
                    } label: {
                        ZStack {
                            Text("Crear cuenta")
                                .opacity(vm.isLoading ? 0 : 1)
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .buttonBorderShape(.roundedRectangle(radius: AppTheme.radiusSM))
                    .controlSize(.large)
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
            if vm.dateOfBirth > Date()  { vm.dateOfBirth = Date() }
            if vm.dateOfBirth < minDate { vm.dateOfBirth = minDate }
        }
        .onChange(of: vm.registrationSucceeded) { _, succeeded in
            if succeeded { dismiss() }
        }
    }
}
