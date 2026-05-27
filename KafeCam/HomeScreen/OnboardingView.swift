//
//  OnboardingView.swift
//  KafeCam
//
//  Aparece una sola vez, la primera vez que el usuario accede tras registrarse.
//  Usa AppStorage("hasSeenOnboarding") para no repetirse.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "leaf.fill",
            iconColor: Color(red: 88/255, green: 129/255, blue: 87/255),
            title: "Bienvenido a KafeCam",
            body: "Tu aliado para cuidar el cafetal. En pocos pasos aprende a usarlo."
        ),
        OnboardingPage(
            icon: "camera.fill",
            iconColor: Color(red: 139/255, green: 90/255, blue: 43/255),
            title: "Detecta enfermedades",
            body: "Toma una foto de una hoja de café y el análisis te dice si hay roya, minador u otras enfermedades — sin necesitar internet."
        ),
        OnboardingPage(
            icon: "cloud.sun.fill",
            iconColor: Color(red: 74/255, green: 144/255, blue: 226/255),
            title: "Anticipa el clima",
            body: "Consulta el pronóstico y recibe alertas cuando las condiciones favorezcan la aparición de enfermedades."
        ),
        OnboardingPage(
            icon: "photo.stack.fill",
            iconColor: Color(red: 88/255, green: 129/255, blue: 87/255),
            title: "Guarda tu historial",
            body: "Todos tus diagnósticos quedan guardados. Puedes revisarlos aunque no tengas señal."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { i in
                    PageView(page: pages[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            Button(action: handleButton) {
                Text(currentPage == pages.count - 1 ? "Comenzar" : "Siguiente")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 88/255, green: 129/255, blue: 87/255))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .animation(.none, value: currentPage)
        }
        .background(Color(.systemBackground))
    }

    private func handleButton() {
        if currentPage < pages.count - 1 {
            withAnimation { currentPage += 1 }
        } else {
            onFinish()
        }
    }
}

// MARK: - Page

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
}

private struct PageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(page.iconColor)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
