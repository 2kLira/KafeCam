//
//  WelcomeOnboardingView.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Pantalla de bienvenida única (se muestra la primera vez que se abre la app
//  y desde Perfil > "Ver bienvenida de nuevo"). Comunica el manifiesto de la
//  app: KafeCam es una herramienta de acompañamiento, no un sustituto del
//  conocimiento del caficultor ni del técnico humano.
//

import SwiftUI

struct WelcomeOnboardingView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    @AppStorage("appLanguage") private var appLanguage: String = "es"

    @State private var step: Int = 0
    private let totalSteps = 3

    var body: some View {
        ZStack {
            // Fondo cálido degradado, suave
            LinearGradient(
                colors: [Color(.systemBackground), brown2.opacity(0.08)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Indicador de progreso accesible
                ProgressDots(current: step, total: totalSteps)
                    .padding(.top, 20)
                    .accessibilityLabel("Paso \(step + 1) de \(totalSteps)")

                TabView(selection: $step) {
                    StepView(
                        artworkSF: "leaf.circle.fill",
                        title: "Bienvenido a KafeCam",
                        subtitle: "Una herramienta hecha para acompañarte en tu cafetal.",
                        copy: "KafeCam te ayuda a entender mejor lo que pasa en tus plantas, aprender prácticas nuevas y estar en contacto con técnicos y otros caficultores. Tú decides, nosotros acompañamos."
                    )
                    .tag(0)

                    StepView(
                        artworkSF: "hand.raised.circle.fill",
                        title: "No te reemplazamos",
                        subtitle: "La inteligencia artificial es una sugerencia. Tu experiencia y la de tu técnico, la decisión.",
                        copy: "Cuando la app te diga que detectó una enfermedad o te recomiende algo, recuérdalo: es una opinión que viene de fotos y datos. Antes de aplicar un tratamiento, conviene confirmar con alguien de confianza."
                    )
                    .tag(1)

                    StepView(
                        artworkSF: "globe.americas.fill",
                        title: "En tu idioma",
                        subtitle: "Elige cómo quieres usar la app. Puedes cambiar después en Perfil.",
                        copy: nil,
                        extra: AnyView(LanguagePicker(selected: $appLanguage))
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))

                ActionBar(
                    isLast: step == totalSteps - 1,
                    onBack: { withAnimation { step = max(0, step - 1) } },
                    onNext: {
                        if step < totalSteps - 1 {
                            withAnimation { step += 1 }
                        } else {
                            hasSeenWelcome = true
                        }
                    },
                    canGoBack: step > 0
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Subvistas

private struct ProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? brown1 : brown1.opacity(0.25))
                    .frame(width: i == current ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
    }
}

private struct StepView: View {
    let artworkSF: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    // Renombrado de `body` a `copy` para no chocar con `var body: some View`.
    let copy: LocalizedStringKey?
    var extra: AnyView? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: artworkSF)
                    .font(.system(size: 110, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(brown1)
                    .padding(.top, 30)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)

                if let copy {
                    HStack(alignment: .top, spacing: 10) {
                        Text(copy)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        AudioReadButton(text: localizedString(copy), compact: true)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, 20)
                }

                if let extra { extra }
            }
            .padding(.bottom, 40)
        }
    }

    // Pequeño helper para sacar el String del LocalizedStringKey actual.
    // Necesario porque AVSpeechSynthesizer espera String puro.
    private func localizedString(_ key: LocalizedStringKey) -> String {
        let mirror = Mirror(reflecting: key)
        return mirror.children.first(where: { $0.label == "key" })?.value as? String ?? ""
    }
}

private struct LanguagePicker: View {
    @Binding var selected: String

    private let options: [(code: String, name: String, native: String)] = [
        ("es",  "Español",  "Español"),
        ("en",  "English",  "English"),
        ("tzo", "Tzotzil",  "Bats’i k’op"),
        ("nah", "Náhuatl",  "Nāhuatl")
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.code) { opt in
                Button {
                    selected = opt.code
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(brown1, lineWidth: 2)
                                .frame(width: 26, height: 26)
                            if selected == opt.code {
                                Circle().fill(brown1).frame(width: 16, height: 16)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(opt.native)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if opt.native != opt.name {
                                Text(opt.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected == opt.code ? brown1.opacity(0.08) : Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selected == opt.code ? brown1 : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(opt.native), \(opt.name)")
                .accessibilityAddTraits(selected == opt.code ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct ActionBar: View {
    let isLast: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let canGoBack: Bool

    var body: some View {
        HStack(spacing: 12) {
            if canGoBack {
                Button(action: onBack) {
                    Text("Atrás")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(brown1)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(brown1, lineWidth: 1.5)
                        )
                }
                .accessibilityLabel("Volver al paso anterior")
            }

            Button(action: onNext) {
                Text(isLast ? "Empezar" : "Continuar")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(brown1)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityLabel(isLast ? "Empezar a usar KafeCam" : "Ir al siguiente paso")
        }
    }
}

#Preview {
    WelcomeOnboardingView()
}
