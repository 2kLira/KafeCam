//
//  LessonDetailView.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Detalle de ruta y de lección. Una lección se navega paso a paso,
//  con audio (TTS), tip destacado y, al final, una pregunta de reflexión
//  que el usuario puede mandar a su Bitácora.
//

import SwiftUI

// MARK: - Detalle de ruta

struct RouteDetailView: View {
    let route: LearningRoute
    @AppStorage("completedLessonIDs") private var completedLessonIDsRaw: String = ""

    private var completedIDs: Set<String> {
        Set(completedLessonIDsRaw.split(separator: ",").map(String.init))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeroHeader(route: route)

                Text("Lecciones")
                    .font(.title3.bold())
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    ForEach(Array(route.lessons.enumerated()), id: \.element.id) { idx, lesson in
                        NavigationLink {
                            LessonView(route: route, lesson: lesson)
                        } label: {
                            LessonRow(
                                index: idx + 1,
                                lesson: lesson,
                                isDone: completedIDs.contains(lesson.id),
                                tint: route.colorTag.color
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HeroHeader: View {
    let route: LearningRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: route.iconSF)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(route.colorTag.color)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityHidden(true)

            Text(route.title)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 10) {
                Text(route.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                AudioReadButton(text: route.summary, compact: true)
            }
        }
        .padding(.top, 8)
    }
}

private struct LessonRow: View {
    let index: Int
    let lesson: Lesson
    let isDone: Bool
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(isDone ? tint : tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                if isDone {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .font(.headline)
                } else {
                    Text("\(index)")
                        .font(.headline)
                        .foregroundStyle(tint)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(lesson.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lección \(index): \(lesson.title), \(lesson.durationMinutes) minutos\(isDone ? ", completada" : "")")
    }
}

// MARK: - Vista de lección (paso a paso)

struct LessonView: View {
    let route: LearningRoute
    let lesson: Lesson

    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: Int = -1   // -1 = intro, n = step n, count = reflexión/cierre
    @AppStorage("completedLessonIDs") private var completedLessonIDsRaw: String = ""
    @State private var showHelpFlow: Bool = false
    @State private var reflectionText: String = ""
    @State private var isCompleted: Bool = false

    private var totalSlides: Int { 1 + lesson.steps.count + (lesson.reflection != nil ? 1 : 0) }
    private var progress: Double {
        if isCompleted { return 1.0 }
        let i = max(0, currentStep + 1)
        return Double(i + 1) / Double(totalSlides + 1)
    }

    private var nextLesson: Lesson? {
        guard let idx = route.lessons.firstIndex(where: { $0.id == lesson.id }),
              idx + 1 < route.lessons.count else { return nil }
        return route.lessons[idx + 1]
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: progress)
                .tint(route.colorTag.color)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if currentStep == -1 {
                        IntroBlock(lesson: lesson)
                    } else if currentStep < lesson.steps.count {
                        StepBlock(step: lesson.steps[currentStep], tint: route.colorTag.color)
                    } else {
                        ClosingBlock(
                            lesson: lesson,
                            reflectionText: $reflectionText,
                            onAskHuman: { showHelpFlow = true }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }

            // Barra de navegación inferior
            if isCompleted {
                VStack(spacing: 10) {
                    if let next = nextLesson {
                        NavigationLink {
                            LessonView(route: route, lesson: next)
                        } label: {
                            HStack(spacing: 8) {
                                Text("Siguiente lección")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(route.colorTag.color)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityLabel("Ir a la siguiente lección: \(next.title)")
                    }
                    Button {
                        dismiss()
                    } label: {
                        Text(nextLesson == nil ? "Listo" : "Volver a la ruta")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(route.colorTag.color)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(route.colorTag.color, lineWidth: 1.5)
                            )
                    }
                    .accessibilityLabel(nextLesson == nil ? "Terminar y volver" : "Volver a la lista de lecciones")
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                HStack(spacing: 12) {
                    if currentStep > -1 {
                        Button {
                            withAnimation { currentStep -= 1 }
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.title3.bold())
                                .frame(width: 54, height: 54)
                                .foregroundStyle(brown1)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(brown1, lineWidth: 1.5)
                                )
                        }
                        .accessibilityLabel("Paso anterior")
                    }

                    Button {
                        if currentStep < lesson.steps.count {
                            withAnimation { currentStep += 1 }
                        } else {
                            markComplete()
                        }
                    } label: {
                        Text(currentStep < lesson.steps.count ? "Continuar" : "Terminar lección")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(route.colorTag.color)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityLabel(currentStep < lesson.steps.count ? "Ir al siguiente paso" : "Marcar lección como completada")
                }
                .padding()
            }
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHelpFlow) {
            // Asumiendo que tienes PedirAyudaView, ver Help/PedirAyudaView.swift
            NavigationStack { PedirAyudaView(context: .lesson(lesson.title)) }
        }
    }

    private func markComplete() {
        var set = Set(completedLessonIDsRaw.split(separator: ",").map(String.init))
        set.insert(lesson.id)
        completedLessonIDsRaw = set.joined(separator: ",")

        // Si hay reflexión escrita, guardarla en bitácora (clave simple).
        if !reflectionText.trimmingCharacters(in: .whitespaces).isEmpty,
           let q = lesson.reflection {
            BitacoraStore.shared.add(
                BitacoraEntry(
                    id: UUID().uuidString,
                    date: Date(),
                    kind: .reflection,
                    title: "Reflexión: \(lesson.title)",
                    body: "Pregunta: \(q)\n\nRespuesta: \(reflectionText)",
                    imageData: nil
                )
            )
        }

        NotificationCenter.default.post(name: .lessonCompleted, object: lesson.id)
        withAnimation(.easeOut(duration: 0.25)) { isCompleted = true }
    }
}

extension Notification.Name {
    static let lessonCompleted = Notification.Name("kafe.lessonCompleted")
}

// MARK: - Bloques de contenido

private struct IntroBlock: View {
    let lesson: Lesson
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(lesson.title)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 10) {
                Text(lesson.intro)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                AudioReadButton(text: lesson.intro)
            }
        }
    }
}

private struct StepBlock: View {
    let step: LessonStep
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step.title)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)

            if let asset = step.imageAsset {
                Image(asset)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
            }

            HStack(alignment: .top, spacing: 10) {
                Text(step.body)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                AudioReadButton(text: step.body)
            }

            if let tip = step.tip {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(tint))
                        .accessibilityHidden(true)
                    Text(tip)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.10))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Consejo: \(tip)")
            }
        }
    }
}

private struct ClosingBlock: View {
    let lesson: Lesson
    @Binding var reflectionText: String
    let onAskHuman: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(green1)
                .accessibilityHidden(true)

            Text("Terminaste la lección")
                .font(.title.bold())

            if let reflection = lesson.reflection {
                VStack(alignment: .leading, spacing: 10) {
                    Text(reflection)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    TextEditor(text: $reflectionText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                        .accessibilityLabel("Tu respuesta a la pregunta de reflexión")

                    Text("Si escribes, se guardará en tu bitácora.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            AcompananteBanner(context: .lesson(topic: lesson.title), onRequestHelp: onAskHuman)
        }
    }
}

#Preview {
    NavigationStack {
        RouteDetailView(route: LearningRoutesRepository.shared.routes[0])
    }
}
