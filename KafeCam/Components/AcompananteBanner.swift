//
//  AcompananteBanner.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Banner reusable que aparece después de cualquier diagnóstico,
//  recomendación o lección. Encarna la postura central de la app:
//  "la IA acompaña, no decide por ti".
//
//  Uso:
//    AcompananteBanner(context: .diagnosis(diseaseName: "Roya")) {
//        // navegar a PedirAyudaView
//    }
//

import SwiftUI

enum AcompananteContext {
    case diagnosis(diseaseName: String)
    case lesson(topic: String)
    case general

    var headline: LocalizedStringKey {
        switch self {
        case .diagnosis: return "Esto es una sugerencia, no un diagnóstico final."
        case .lesson:    return "¿Te quedan dudas de esta práctica?"
        case .general:   return "Estamos contigo, no sobre ti."
        }
    }

    var body: LocalizedStringKey {
        switch self {
        case .diagnosis(let name):
            return "El modelo detectó signos de \(name), pero tu experiencia en tu cafetal vale más. Antes de aplicar cualquier tratamiento, conviene confirmar con un técnico o con alguien de tu cooperativa."
        case .lesson(let topic):
            return "Puedes conversar este tema sobre \(topic) con un técnico extensionista o con otros caficultores de tu región."
        case .general:
            return "Si en algún paso te sientes inseguro, pide acompañamiento humano. Es señal de criterio, no de debilidad."
        }
    }

    var iconName: String {
        switch self {
        case .diagnosis: return "hand.raised.fill"
        case .lesson:    return "person.2.wave.2.fill"
        case .general:   return "heart.fill"
        }
    }
}

struct AcompananteBanner: View {
    let context: AcompananteContext
    let onRequestHelp: () -> Void

    @ScaledMetric private var iconSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: context.iconName)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(brown1)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(context.headline)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(context.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Button(action: onRequestHelp) {
                HStack(spacing: 10) {
                    Image(systemName: "person.fill.questionmark")
                    Text("Hablar con un técnico")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(brown1)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityLabel("Hablar con un técnico humano")
            .accessibilityHint("Abre la lista de técnicos extensionistas y miembros de tu cooperativa que pueden acompañarte.")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(brown1.opacity(0.15), lineWidth: 1)
                )
        )
        // Combinamos para que VoiceOver lea el banner como una unidad.
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            AcompananteBanner(context: .diagnosis(diseaseName: "Roya")) { }
            AcompananteBanner(context: .lesson(topic: "poda de renovación")) { }
            AcompananteBanner(context: .general) { }
        }
        .padding()
    }
}
