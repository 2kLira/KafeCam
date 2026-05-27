//
//  AsistenteView.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  UI del asistente conversacional. Demuestra el flujo completo:
//  texto o voz → Brain → respuesta + cita de fuentes + audio.
//
//  Esta vista es opcional como pantalla nueva, o puedes integrar el
//  Brain en pantallas existentes (DetectaView, AprendeView, etc).
//

import SwiftUI

struct AsistenteView: View {

    @StateObject private var brain = CaficultorBrain.shared
    @StateObject private var stt = SpeechToTextService.shared
    @StateObject private var translator = MLXTranslator.shared

    @State private var input: String = ""
    @State private var turns: [BrainTurnResult] = []
    @State private var error: String? = nil
    @FocusState private var inputFocused: Bool

    /// Pregunta opcional con la que arranca la conversación (ej. desde Detecta).
    private let initialQuestion: String

    init(initialQuestion: String = "") {
        self.initialQuestion = initialQuestion
    }

    var body: some View {
            VStack(spacing: 0) {
                ReadinessBar(brain: brain, translator: translator)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if turns.isEmpty {
                                EmptyState()
                                    .padding(.top, 60)
                            } else {
                                ForEach(turns.indices, id: \.self) { i in
                                    TurnBubble(turn: turns[i])
                                        .id(i)
                                }
                            }

                            if brain.isProcessing {
                                ProcessingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: turns.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(turns.count - 1, anchor: .bottom)
                        }
                    }
                }

                InputBar(
                    text: $input,
                    isRecording: stt.isRecording,
                    isProcessing: brain.isProcessing,
                    onMicTap: handleMic,
                    onSend: handleSend
                )
                .focused($inputFocused)
            }
            .navigationTitle("Asistente")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await stt.requestAuthorization()
                stt.configure(for: brain.activeLanguage)
                await brain.warmUp()

                if !initialQuestion.isEmpty && turns.isEmpty {
                    input = initialQuestion
                    handleSend()
                }
            }
            .onChange(of: stt.partialTranscript) { _, new in
                if !new.isEmpty { input = new }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
    }

    // MARK: - Acciones

    private func handleSend() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        inputFocused = false

        Task {
            do {
                let result = try await brain.processAndSpeak(userText: text)
                turns.append(result)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func handleMic() {
        if stt.isRecording {
            input = stt.stop()
        } else {
            do {
                stt.configure(for: brain.activeLanguage)
                try stt.start()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Subvistas

private struct ReadinessBar: View {
    @ObservedObject var brain: CaficultorBrain
    @ObservedObject var translator: MLXTranslator

    var body: some View {
        Group {
            switch brain.readiness {
            case .ready:
                EmptyView()
            case .partial(let missing):
                Banner(
                    icon: "exclamationmark.triangle.fill",
                    text: "Funciona limitado. Falta: \(missing.joined(separator: ", "))",
                    color: .orange
                )
            case .notReady:
                Banner(
                    icon: "moon.zzz.fill",
                    text: "Preparando asistente…",
                    color: .gray
                )
            }
        }
        .animation(.easeInOut, value: brain.readiness)
    }

    private struct Banner: View {
        let icon: String
        let text: String
        let color: Color
        var body: some View {
            HStack {
                Image(systemName: icon)
                Text(text).font(.footnote)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
        }
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.brown)
                .accessibilityHidden(true)

            Text("Pregúntame sobre tu cafetal")
                .font(.title3.bold())

            Text("Puedes hablar o escribir en tu lengua. Yo busco información en lo que ya sé y te respondo. Recuerda: soy una herramienta, no reemplazo a tu técnico.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
    }
}

private struct ProcessingIndicator: View {
    @State private var phase: Double = 0
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(.brown)
                    .opacity(phase == Double(i) ? 1 : 0.3)
            }
            Text("Pensando…").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .onAppear {
            Task {
                while true {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    await MainActor.run { phase = (phase + 1).truncatingRemainder(dividingBy: 3) }
                }
            }
        }
    }
}

private struct TurnBubble: View {
    let turn: BrainTurnResult
    @StateObject private var voiceOut = VoiceOutputService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Usuario
            HStack {
                Spacer()
                Text(turn.userTextOriginal)
                    .padding(12)
                    .background(Color.brown.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 280, alignment: .trailing)
            }

            // Asistente
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.brown))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(turn.responseInUserLanguage)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    if let action = turn.response.actionSuggestion {
                        Label(action, systemImage: "arrow.forward.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.brown)
                    }

                    if turn.response.recommendHumanCheck {
                        Label("Antes de actuar, conviene confirmar con un técnico.",
                              systemImage: "person.fill.questionmark")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                    }

                    if !turn.citedPassages.isEmpty {
                        CitationsRow(passages: turn.citedPassages)
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            voiceOut.speak(text: turn.responseInUserLanguage,
                                           in: CaficultorBrain.shared.activeLanguage)
                        }) {
                            Image(systemName: voiceOut.isSpeaking
                                  ? "speaker.wave.2.circle.fill"
                                  : "speaker.wave.2.circle")
                                .font(.title3)
                        }
                        .accessibilityLabel("Escuchar la respuesta")

                        if turn.intent.confidence < 0.6 {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.orange)
                                .accessibilityLabel("El asistente tiene baja confianza en esta respuesta")
                        }

                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

private struct CitationsRow: View {
    let passages: [KnowledgePassage]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fuentes:")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            ForEach(passages) { p in
                Text("• \(p.title)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray3), lineWidth: 0.5)
        )
    }
}

private struct InputBar: View {
    @Binding var text: String
    let isRecording: Bool
    let isProcessing: Bool
    let onMicTap: () -> Void
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onMicTap) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(isRecording ? .red : .brown)
            }
            .accessibilityLabel(isRecording ? "Detener grabación" : "Hablar")

            TextField("Escribe o habla…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(text.isEmpty ? .gray : .brown)
            }
            .disabled(text.isEmpty || isProcessing)
            .accessibilityLabel("Enviar")
        }
        .padding(12)
        .background(.bar)
    }
}

#Preview {
    NavigationStack {
        AsistenteView()
    }
}
