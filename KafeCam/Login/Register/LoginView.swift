import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var vm: LoginViewModel
    @State private var goRegister = false
    @State private var appleNonce = ""

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AppTheme.accent)

                    VStack(spacing: 6) {
                        Text("Bienvenido")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppTheme.accent)

                        Text("Inicia sesión para continuar")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.dark)
                    }

                    AuthCard {
                        // Phone
                        ktextfild(title: "Teléfono (10 dígitos)",
                                  text: $vm.phone,
                                  keyboard: .numberPad,
                                  contentType: .telephoneNumber)
                        if let err = vm.phoneError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }

                        // Password
                        ktextfild(title: "Contraseña",
                                  text: $vm.password,
                                  isSecure: true,
                                  keyboard: .default,
                                  contentType: .password)
                        if let err = vm.passwordError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }

                        // Primary CTA — spinner replaces text while loading
                        Button(action: vm.submit) {
                            ZStack {
                                Text("Iniciar sesión")
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

                        // Divider "o"
                        HStack {
                            Rectangle().fill(Color(.separator)).frame(height: 1)
                            Text("o").font(.caption).foregroundStyle(.secondary)
                            Rectangle().fill(Color(.separator)).frame(height: 1)
                        }
                        .padding(.vertical, 4)

                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            let nonce = AppleNonce.random()
                            appleNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = AppleNonce.sha256(nonce)
                        } onCompletion: { result in
                            vm.handleApple(result, rawNonce: appleNonce)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSM))
                        .disabled(vm.isLoading)
                    }

                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Text("¿No tienes cuenta?")
                            Button("Crear una") { goRegister = true }
                                .foregroundStyle(AppTheme.accent)
                        }
                        .font(.subheadline)

                        NavigationLink {
                            ForgotPasswordView()
                        } label: {
                            Text("¿Olvidaste tu contraseña?").underline()
                        }
                        .foregroundStyle(AppTheme.accent)
                        .font(.footnote)

                        Button("Continuar sin cuenta") {
                            vm.session.continueAsGuest()
                        }
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationDestination(isPresented: $goRegister) {
                RegisterView(vm: RegisterViewModel(auth: vm.auth, session: vm.session))
            }
        }
    }
}
