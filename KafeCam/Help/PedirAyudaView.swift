//
//  PedirAyudaView.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Flujo central de "no estás solo": contactar a un técnico extensionista,
//  cooperativa o caficultor con más experiencia. Refuerza la postura
//  de la app: la IA es punto de partida, el humano cierra el ciclo.
//
//  En MVP usa datos mock. Cuando integres Supabase, reemplaza el
//  TecnicosRepository.shared.fetch() con una llamada real al backend.
//

import SwiftUI

// MARK: - Modelo

struct Tecnico: Identifiable, Hashable {
    let id: String
    let nombre: String
    let rol: String           // "Técnico extensionista", "Cooperativa", "Caficultor mentor"
    let region: String
    let idiomas: [String]     // "Español", "Tzotzil", "Náhuatl"
    let telefono: String?
    let whatsapp: String?
    let disponible: Bool
}

@MainActor
final class TecnicosRepository {
    static let shared = TecnicosRepository()
    private init() {}

    // Datos mock para MVP
    func fetch() -> [Tecnico] {
        [
            Tecnico(id: "t1", nombre: "Lucía Méndez", rol: "Técnica extensionista",
                    region: "Altos de Chiapas", idiomas: ["Español", "Tzotzil"],
                    telefono: "+52 967 100 0001", whatsapp: "+529671000001", disponible: true),
            Tecnico(id: "t2", nombre: "Cooperativa Tzeltal Tzotzil", rol: "Cooperativa",
                    region: "San Cristóbal", idiomas: ["Español", "Tzotzil", "Tzeltal"],
                    telefono: "+52 967 100 0010", whatsapp: nil, disponible: true),
            Tecnico(id: "t3", nombre: "Don Manuel Hernández", rol: "Caficultor mentor",
                    region: "Sierra Norte de Puebla", idiomas: ["Español", "Náhuatl"],
                    telefono: nil, whatsapp: "+529671000099", disponible: false),
            Tecnico(id: "t4", nombre: "Centro de Investigación INIFAP",
                    rol: "Asesoría técnica", region: "Nacional",
                    idiomas: ["Español"], telefono: "+52 800 000 0000",
                    whatsapp: nil, disponible: true)
        ]
    }
}

// MARK: - Contexto

enum AyudaContext {
    case diagnosis(diseaseName: String)
    case lesson(_ topic: String)
    case general

    var summary: String {
        switch self {
        case .diagnosis(let d): return "Quiero consultar sobre el diagnóstico de \(d)."
        case .lesson(let t):    return "Tengo dudas sobre la lección: \(t)."
        case .general:          return "Quiero recibir acompañamiento."
        }
    }
}

// MARK: - Vista principal

struct PedirAyudaView: View {
    let context: AyudaContext

    @State private var tecnicos: [Tecnico] = []
    @State private var filterLanguage: String? = nil

    init(context: AyudaContext = .general) {
        self.context = context
    }

    var filteredTecnicos: [Tecnico] {
        guard let lang = filterLanguage else { return tecnicos }
        return tecnicos.filter { $0.idiomas.contains(lang) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Header(context: context)

                LanguageFilter(selected: $filterLanguage,
                               options: availableLanguages)

                Text("Personas que pueden acompañarte")
                    .font(.headline)
                    .padding(.top, 6)

                if filteredTecnicos.isEmpty {
                    Text("No hay alguien disponible con ese idioma en este momento. Quita el filtro o intenta más tarde.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTecnicos) { t in
                            TecnicoCard(tecnico: t, prefilledMessage: context.summary)
                        }
                    }
                }

                Spacer(minLength: 20)

                ReassuranceFooter()
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Pedir ayuda")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tecnicos = TecnicosRepository.shared.fetch()
        }
    }

    private var availableLanguages: [String] {
        Array(Set(tecnicos.flatMap { $0.idiomas })).sorted()
    }
}

// MARK: - Subvistas

private struct Header: View {
    let context: AyudaContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(brown1)
                .accessibilityHidden(true)

            Text("No estás solo en tu cafetal")
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 10) {
                Text("Aquí hay técnicos, cooperativas y otros caficultores que pueden ayudarte a tomar mejores decisiones. La app es una ayuda; ellos son tu red.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                AudioReadButton(text: "Aquí hay técnicos, cooperativas y otros caficultores que pueden ayudarte a tomar mejores decisiones. La app es una ayuda; ellos son tu red.", compact: true)
            }

            if case .diagnosis(let d) = context {
                Label("Contexto: diagnóstico de \(d)", systemImage: "info.circle.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(brown1.opacity(0.12)))
                    .foregroundStyle(brown1)
            }
        }
        .padding(.top, 8)
    }
}

private struct LanguageFilter: View {
    @Binding var selected: String?
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filtrar por idioma")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(label: "Todos", isOn: selected == nil) { selected = nil }
                    ForEach(options, id: \.self) { l in
                        Chip(label: l, isOn: selected == l) {
                            selected = (selected == l) ? nil : l
                        }
                    }
                }
            }
        }
    }
}

private struct Chip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(isOn ? .white : brown1)
                .background(Capsule().fill(isOn ? brown1 : brown1.opacity(0.12)))
        }
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}

private struct TecnicoCard: View {
    let tecnico: Tecnico
    let prefilledMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(tecnico.disponible ? green1 : Color.gray.opacity(0.4))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(initials(tecnico.nombre))
                            .font(.headline)
                            .foregroundStyle(.white)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tecnico.nombre)
                        .font(.headline)
                    Text(tecnico.rol)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(tecnico.region)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if !tecnico.disponible {
                    Text("Hoy ocupado")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.gray.opacity(0.2)))
                        .foregroundStyle(.secondary)
                }
            }

            // Idiomas
            HStack(spacing: 6) {
                Image(systemName: "globe").foregroundStyle(.secondary)
                Text(tecnico.idiomas.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if let wa = tecnico.whatsapp {
                    ActionButton(systemImage: "message.fill",
                                 label: "WhatsApp",
                                 color: green2) {
                        openWhatsApp(number: wa, message: prefilledMessage)
                    }
                }
                if let tel = tecnico.telefono {
                    ActionButton(systemImage: "phone.fill",
                                 label: "Llamar",
                                 color: brown1) {
                        callPhone(number: tel)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .opacity(tecnico.disponible ? 1.0 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tecnico.nombre), \(tecnico.rol), región \(tecnico.region). Idiomas: \(tecnico.idiomas.joined(separator: ", ")). \(tecnico.disponible ? "Disponible." : "Hoy ocupado.")")
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    private func openWhatsApp(number: String, message: String) {
        let cleanNumber = number.filter { "0123456789".contains($0) }
        guard let msg = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://wa.me/\(cleanNumber)?text=\(msg)")
        else { return }
        UIApplication.shared.open(url)
    }

    private func callPhone(number: String) {
        let cleanNumber = number.filter { "+0123456789".contains($0) }
        guard let url = URL(string: "tel://\(cleanNumber)") else { return }
        UIApplication.shared.open(url)
    }
}

private struct ActionButton: View {
    let systemImage: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(label).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(.white)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityLabel(label)
    }
}

private struct ReassuranceFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pedir ayuda es signo de criterio.", systemImage: "heart.fill")
                .font(.subheadline.bold())
                .foregroundStyle(brown1)
            Text("Si alguien te dice que esta app reemplaza al técnico, no es cierto. KafeCam es una herramienta más, como una libreta o una lupa.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(brown1.opacity(0.08))
        )
    }
}

#Preview {
    NavigationStack {
        PedirAyudaView(context: .diagnosis(diseaseName: "Roya"))
    }
}
