//
//  AudioReadButton.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Botón reusable que lee en voz alta cualquier texto.
//  Esencial para usuarios con alfabetización variable o baja visión.
//  Usa AVSpeechSynthesizer (nativo, sin red, sin dependencias).
//
//  Uso:
//    AudioReadButton(text: "Buenos días, hoy es buen día para revisar la roya.")
//

import SwiftUI
import AVFoundation

/// Singleton ligero para que solo una lectura suene a la vez en toda la app.
final class KafeSpeaker: ObservableObject {
    static let shared = KafeSpeaker()
    private let synth = AVSpeechSynthesizer()
    @Published private(set) var isSpeaking: Bool = false
    private var currentText: String = ""

    private init() {}

    /// Reproduce el texto. Si ya está hablando lo mismo, detiene.
    /// El locale se infiere del LanguageManager para que pronuncie en el idioma actual.
    func toggle(_ text: String) {
        if synth.isSpeaking && currentText == text {
            stop()
            return
        }
        stop()
        currentText = text

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92 // un poco más lento
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.1

        // Selección de voz por idioma activo
        let code = LanguageManager.shared.appLanguage
        let voiceLocale: String
        switch code {
        case "en": voiceLocale = "en-US"
        case "tzo", "nah": voiceLocale = "es-MX" // sin voz TTS nativa, usar español como fallback
        default:   voiceLocale = "es-MX"
        }
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLocale)

        synth.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentText = ""
    }
}

/// Botón circular grande (mínimo 44pt) que dispara lectura del texto.
/// Si VoiceOver está activo, se oculta del árbol de accesibilidad
/// porque VoiceOver ya lee el texto adjunto.
struct AudioReadButton: View {
    let text: String
    var compact: Bool = false

    @StateObject private var speaker = KafeSpeaker.shared
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn

    var body: some View {
        Button(action: { speaker.toggle(text) }) {
            Image(systemName: speaker.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                .font(.system(size: compact ? 28 : 36, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(brown1)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityHidden(voiceOverOn) // VoiceOver ya lee el texto
        .accessibilityLabel(speaker.isSpeaking ? "Detener lectura" : "Escuchar este texto en voz alta")
        .accessibilityHint("El teléfono leerá el texto que aparece junto a este botón.")
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(alignment: .top, spacing: 12) {
            Text("Buenos días, hoy es buen día para revisar la roya en las hojas más viejas de tu cafetal.")
                .font(.body)
            AudioReadButton(text: "Buenos días, hoy es buen día para revisar la roya en las hojas más viejas de tu cafetal.")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding()
    }
}
