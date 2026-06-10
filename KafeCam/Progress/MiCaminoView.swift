//
//  MiCaminoView.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Vista de progreso. Celebra el avance del caficultor en lecciones,
//  entradas de bitácora y prácticas. Gamificación suave, sin medallas
//  agresivas ni rankings — esto no es un juego de competencia.
//

import SwiftUI

struct MiCaminoView: View {
    @AppStorage("completedLessonIDs") private var completedLessonIDsRaw: String = ""
    @ObservedObject private var bitacora = BitacoraStore.shared

    private var completedIDs: Set<String> {
        Set(completedLessonIDsRaw.split(separator: ",").map(String.init))
    }

    private var allRoutes: [LearningRoute] { LearningRoutesRepository.shared.routes }
    private var totalLessons: Int { allRoutes.reduce(0) { $0 + $1.lessons.count } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Header()
                    .kafeSoftEntry(0)

                OverviewCard(
                    completedLessons: completedIDs.count,
                    totalLessons: totalLessons,
                    journalEntries: bitacora.entries.count
                )
                .kafeSoftEntry(1)

                RoutesProgressSection(routes: allRoutes, completedIDs: completedIDs)
                    .kafeSoftEntry(2)

                PracticesSection(entries: bitacora.entries)
                    .kafeSoftEntry(3)

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Mi Camino")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subvistas

private struct Header: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mi camino")
                .font(.largeTitle.bold())
                .foregroundStyle(brown1)

            Text("Lo que has aprendido y lo que has hecho. Sin prisa, sin comparaciones.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct OverviewCard: View {
    let completedLessons: Int
    let totalLessons: Int
    let journalEntries: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                StatBlock(value: "\(completedLessons)", label: "Lecciones", subLabel: "completadas",
                          icon: "graduationcap.fill", color: green1)
                StatBlock(value: "\(journalEntries)", label: "Entradas", subLabel: "en bitácora",
                          icon: "book.pages.fill", color: brown1)
            }
            if totalLessons > 0 {
                AnimatedProgressBar(
                    value: Double(completedLessons),
                    total: Double(totalLessons),
                    tint: green1
                )
                Text("\(completedLessons) de \(totalLessons) lecciones del programa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Has completado \(completedLessons) de \(totalLessons) lecciones y tienes \(journalEntries) entradas en tu bitácora.")
    }
}

private struct StatBlock: View {
    let value: String
    let label: String
    let subLabel: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(color))
                .accessibilityHidden(true)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Text(subLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }
}

private struct RoutesProgressSection: View {
    let routes: [LearningRoute]
    let completedIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tus rutas")
                .font(.title3.bold())

            ForEach(routes) { route in
                let done = route.lessons.filter { completedIDs.contains($0.id) }.count
                let total = route.lessons.count
                let pct = total > 0 ? Double(done) / Double(total) : 0

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: route.iconSF)
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(route.colorTag.color))
                            .accessibilityHidden(true)
                        Text(route.title)
                            .font(.headline)
                        Spacer()
                        if done == total && total > 0 {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(green1)
                                .accessibilityLabel("Completada")
                        } else {
                            Text("\(done)/\(total)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    AnimatedProgressBar(value: pct, total: 1, tint: route.colorTag.color)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Ruta \(route.title): \(done) de \(total) lecciones completadas")
            }
        }
    }
}

private struct PracticesSection: View {
    let entries: [BitacoraEntry]

    private var actionEntries: [BitacoraEntry] {
        entries.filter { $0.kind == .action }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prácticas que has aplicado")
                .font(.title3.bold())

            if actionEntries.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(brown1)
                        .accessibilityHidden(true)
                    Text("Cuando apliques algo nuevo en tu cafetal —un biopreparado, una poda, una observación— registralo en tu bitácora como Acción. Aquí aparecerá.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(brown1.opacity(0.08))
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(actionEntries.prefix(5)) { e in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(green2)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.title).font(.subheadline.bold())
                                Text(dateString(e.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
            }
        }
    }

    private func dateString(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = LanguageManager.shared.currentLocale
        fmt.dateStyle = .medium
        return fmt.string(from: d)
    }
}

// MARK: - Animated Progress Bar
/// Progress bar that fills from zero with a smooth spring when it first appears.
/// Honors Reduce Motion (renders at final value without movement).
struct AnimatedProgressBar: View {
    let value: Double
    let total: Double
    let tint: Color

    @State private var animatedValue: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ProgressView(value: animatedValue, total: total)
            .tint(tint)
            .onAppear {
                if reduceMotion {
                    animatedValue = value
                } else {
                    // Small delay so the fill reads as a deliberate moment,
                    // landing right after the block's soft entry.
                    withAnimation(AppTheme.springSmooth.delay(0.25)) {
                        animatedValue = value
                    }
                }
            }
            .onChange(of: value) { _, new in
                withAnimation(AppTheme.springSmooth) { animatedValue = new }
            }
    }
}

#Preview {
    MiCaminoView()
}
