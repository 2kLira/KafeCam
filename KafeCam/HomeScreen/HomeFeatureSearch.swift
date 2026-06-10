//
//  HomeFeatureSearch.swift
//  KafeCam
//
//  Searchable index of the home action cards so the search bar can jump
//  straight to a section (e.g. "detecta", "clima", "progreso").
//

import SwiftUI

enum HomeFeature: String, CaseIterable, Identifiable {
    case anticipa, detecta, informate, consulta, asistente, bitacora, aprende, miCamino

    var id: String { rawValue }

    // Same keys the ActionsGrid cards use, so titles stay in sync with localization.
    var titleKey: String {
        switch self {
        case .anticipa:  return "Anticipa"
        case .detecta:   return "Detecta"
        case .informate: return "Infórmate"
        case .consulta:  return "Consulta"
        case .asistente: return "Asistente"
        case .bitacora:  return "Bitácora"
        case .aprende:   return "Aprende"
        case .miCamino:  return "Mi Camino"
        }
    }

    var subtitleKey: String {
        switch self {
        case .anticipa:  return "Prevé el clima"
        case .detecta:   return "Prevención temprana"
        case .informate: return "Cuida tu cultivo"
        case .consulta:  return "Tus registros siempre"
        case .asistente: return "Pregunta lo que necesites"
        case .bitacora:  return "Tu cuaderno de campo"
        case .aprende:   return "Rutas de capacitación"
        case .miCamino:  return "Tu progreso"
        }
    }

    var systemImage: String {
        switch self {
        case .anticipa:  return "cloud.sun.fill"
        case .detecta:   return "camera.fill"
        case .informate: return "bandage.fill"
        case .consulta:  return "leaf.fill"
        case .asistente: return "bubble.left.and.exclamationmark.bubble.right.fill"
        case .bitacora:  return "book.pages.fill"
        case .aprende:   return "graduationcap.fill"
        case .miCamino:  return "figure.walk.motion"
        }
    }

    var color: Color {
        switch self {
        case .anticipa:  return AppTheme.cardGreen1
        case .detecta:   return AppTheme.cardBrown1
        case .informate: return AppTheme.cardBrown2
        case .consulta:  return AppTheme.cardGreen2
        case .asistente: return AppTheme.cardTeal
        case .bitacora:  return AppTheme.cardTeal
        case .aprende:   return Color.indigo
        case .miCamino:  return Color(red: 0.75, green: 0.45, blue: 0.10)
        }
    }

    // Synonyms a farmer might type that don't appear in the title/subtitle.
    private var keywords: [String] {
        switch self {
        case .anticipa:  return ["clima", "lluvia", "pronóstico", "tiempo", "weather", "forecast", "rain"]
        case .detecta:   return ["cámara", "foto", "diagnóstico", "escanear", "camera", "photo", "scan", "detect"]
        case .informate: return ["enfermedades", "plagas", "guía", "enciclopedia", "diseases", "pests"]
        case .consulta:  return ["historial", "registros", "capturas", "history", "records"]
        case .asistente: return ["ayuda", "chat", "pregunta", "ia", "assistant", "help"]
        case .bitacora:  return ["notas", "cuaderno", "apuntes", "journal", "notes", "logbook"]
        case .aprende:   return ["cursos", "capacitación", "lecciones", "learn", "courses", "training"]
        case .miCamino:  return ["progreso", "logros", "nivel", "avance", "progress", "achievements"]
        }
    }

    func matches(_ query: String) -> Bool {
        var haystack = [
            NSLocalizedString(titleKey, comment: ""),
            NSLocalizedString(subtitleKey, comment: ""),
            titleKey,
            subtitleKey
        ]
        haystack.append(contentsOf: keywords)
        return haystack.contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .anticipa:  AnticipaView()
        case .detecta:   DetectaView()
        case .informate: DiseaseView(diseaseList: diseases)
        case .consulta:  HistoryView()
        case .asistente: AsistenteView()
        case .bitacora:  BitacoraView()
        case .aprende:   AprendeView()
        case .miCamino:  MiCaminoView()
        }
    }
}

struct FeatureMatchesList: View {
    let filtered: [HomeFeature]

    var body: some View {
        if !filtered.isEmpty {
            Text("Secciones").font(.headline)
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(filtered) { feature in
                    NavigationLink { feature.destination } label: {
                        HStack(spacing: 10) {
                            Image(systemName: feature.systemImage)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(feature.color)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey(feature.titleKey))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(LocalizedStringKey(feature.subtitleKey))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: filtered.map(\.id))
        }
    }
}
