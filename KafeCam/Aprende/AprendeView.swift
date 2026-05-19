//
//  AprendeView.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Sección Aprende. Listado de rutas de capacitación que el caficultor
//  puede tomar a su ritmo. Pensada como tab principal (sustituyendo o
//  acompañando "Favoritos" en el TabView de HomeView).
//

import SwiftUI

struct AprendeView: View {
    @State private var routes: [LearningRoute] = LearningRoutesRepository.shared.routes
    @State private var selectedRoute: LearningRoute? = nil
    @AppStorage("completedLessonIDs") private var completedLessonIDsRaw: String = ""

    private var completedIDs: Set<String> {
        Set(completedLessonIDsRaw.split(separator: ",").map(String.init))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Header()

                    // Continuar (si hay lección en curso, ver MiCaminoView)
                    if !completedIDs.isEmpty {
                        ContinueCard(completed: completedIDs.count,
                                     total: totalLessons)
                    }

                    Text("Rutas de aprendizaje")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .padding(.top, 4)

                    LazyVStack(spacing: 14) {
                        ForEach(routes) { route in
                            Button {
                                selectedRoute = route
                            } label: {
                                RouteCard(
                                    route: route,
                                    completedCount: completedCount(in: route)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(accessibilityLabel(for: route))
                            .accessibilityHint("Toca para abrir la ruta y ver sus lecciones.")
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationDestination(item: $selectedRoute) { route in
                RouteDetailView(route: route)
            }
        }
    }

    private var totalLessons: Int {
        routes.reduce(0) { $0 + $1.lessons.count }
    }

    private func completedCount(in route: LearningRoute) -> Int {
        route.lessons.filter { completedIDs.contains($0.id) }.count
    }

    private func accessibilityLabel(for route: LearningRoute) -> String {
        let done = completedCount(in: route)
        return "\(route.title). \(route.lessons.count) lecciones, \(done) completadas. Aproximadamente \(route.estimatedMinutes) minutos en total."
    }
}

// MARK: - Subvistas

private struct Header: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aprende")
                .font(.largeTitle.bold())
                .foregroundStyle(brown1)

            Text("Prácticas, conocimiento y conversaciones de otros caficultores. A tu ritmo, sin prisa.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct ContinueCard: View {
    let completed: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(green1))
                Text("Tu camino")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(completed) de \(total)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.9))
            }

            ProgressView(value: progress)
                .tint(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(green1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tu camino: \(completed) lecciones completadas de \(total) en total.")
    }
}

private struct RouteCard: View {
    let route: LearningRoute
    let completedCount: Int

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: route.iconSF)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(route.colorTag.color)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(route.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(route.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Label("\(route.lessons.count) lecciones", systemImage: "book.fill")
                    Label("\(route.estimatedMinutes) min", systemImage: "clock")
                    if completedCount > 0 {
                        Label("\(completedCount) hechas", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(green1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    AprendeView()
}
