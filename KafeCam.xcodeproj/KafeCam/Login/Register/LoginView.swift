//
//  LoginView.swift
//  Register
//
//  Created by Guillermo Lira on 10/09/25.
//
import SwiftUI

struct LoginView: View {
    @ObservedObject var vm: LoginViewModel
    @State private var goRegister = false

    // Palette
    private let accentColor = Color(red: 88/255, green: 129/255, blue: 87/255)
    private let darkColor   = Color(red: 82/255,  green: 76/255,  blue: 41/255)

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                VStack(spacing: 16) {
                    // Leaf icon on top
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 40))
                        .foregroundColor(accentColor)

                    Text("Bienvenido")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(accentColor)

                    Text("Inicia sesión para continuar")
                        .foregroundColor(darkColor)

                    AuthCard {
                        // Phone
                        ktextfild(title: "Teléfono (10 dígitos)",
                                  text: $vm.phone,
                                  keyboard: .numberPad,
                                  contentType: .telephoneNumber)
                        if let err = vm.phoneError {
                            Text(err).font(.caption).foregroundColor(.red)
                        }

                        // Password
                        ktextfild(title: "Contraseña",
                                  text: $vm.password,
                                  isSecure: true,
                                  keyboard: .default,
                                  contentType: .password)
                        if let err = vm.passwordError {
                            Text(err).font(.caption).foregroundColor(.red)
                        }

                        // Apple-like button
                        Button("Iniciar sesión", action: vm.submit)
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

                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text("¿No tienes cuenta?")
                            Button("Crear una") { goRegister = true }
                                .foregroundColor(accentColor)
                        }
                        .font(.subheadline)
                        NavigationLink {
                            ForgotPasswordView()
                        } label: {
                            Text("¿Olvidaste tu contraseña?").underline()
                        }
                        .foregroundColor(accentColor)
                        .font(.footnote)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationDestination(isPresented: $goRegister) {
                // Pass the same auth & session to Register
                RegisterView(vm: RegisterViewModel(auth: vm.auth, session: vm.session))
            }
        }
        // Signup success alert disabled to avoid showing on cold launches
    }
}
