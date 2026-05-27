//
//  VoiceService.swift
//  KafeCam
//
//  Created by Guillermo Lira on 14/05/26.
//
//  Servicios nativos de voz:
//   - SpeechToText: Speech.framework para reconocer español (las lenguas
//                   indígenas no tienen STT nativo; para esas, el usuario
//                   teclea, y el modelo MLX hace la traducción a ES).
//   - VoiceOutput:  Reproduce audios pre-grabados por hablantes nativos
//                   si existen para la clave, o usa AVSpeechSynthesizer
//                   en español como fallback (con aviso "traducción no
//                   disponible en voz").
//

import Foundation
import AVFoundation
import Speech

// MARK: - Speech to Text

@MainActor
final class SpeechToTextService: NSObject, ObservableObject {

    static let shared = SpeechToTextService()

    @Published private(set) var isRecording = false
    @Published private(set) var partialTranscript = ""
    @Published private(set) var authorized = false

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        super.init()
        // Por defecto reconocemos español. Si la lengua del usuario es
        // indígena, igual reconocemos español porque va a hablar/teclear
        // en español o vamos a tomar la entrada vía teclado.
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    }

    func requestAuthorization() async {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        self.authorized = (status == .authorized)
    }

    /// Configura el recognizer para una lengua específica. Las indígenas
    /// caen a es-MX/es-CO automáticamente (via CaficultorLanguage.speechLocale).
    func configure(for language: CaficultorLanguage) {
        self.recognizer = SFSpeechRecognizer(locale: language.speechLocale)
    }

    /// Empieza a grabar y reconocer. Devuelve transcripciones parciales en
    /// .partialTranscript hasta que se llama stop(), que devuelve la final.
    func start() throws {
        guard !isRecording else { return }
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "Speech", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Recognizer no disponible"])
        }

        // Reset
        task?.cancel()
        task = nil
        partialTranscript = ""

        // Audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // Recognition request
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // requiresOnDeviceRecognition cuando esté disponible — para privacidad
        // en zonas rurales sin conexión confiable.
        if #available(iOS 13, *) {
            req.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }
        self.request = req

        // Audio engine tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            req.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.partialTranscript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stop()
                }
            }
        }
    }

    @discardableResult
    func stop() -> String {
        guard isRecording else { return partialTranscript }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        isRecording = false
        return partialTranscript
    }
}

// MARK: - Voice Output

/// Reproduce respuestas en voz alta. Estrategia en cascada:
/// 1. Si existe un audio pre-grabado para la clave, reprodúcelo (es voz
///    nativa de un hablante real, ideal para lenguas indígenas).
/// 2. Si la lengua tiene TTS nativo de Apple (español, inglés), usa
///    AVSpeechSynthesizer.
/// 3. Si la lengua es indígena pero solo hay texto, lee el texto en
///    español con TTS y muestra una etiqueta visual "(audio nativo no
///    disponible)" en la UI.
@MainActor
final class VoiceOutputService: NSObject, ObservableObject {

    static let shared = VoiceOutputService()

    @Published private(set) var isSpeaking = false

    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Reproduce una respuesta. La estrategia depende de si hay audio nativo.
    /// - Parameter audioKey: clave opcional para buscar audio pre-grabado en bundle.
    func speak(text: String, in language: CaficultorLanguage, audioKey: String? = nil) {
        stop()

        // 1. Audio pre-grabado nativo
        if let key = audioKey,
           let url = bundleAudio(for: key, language: language) {
            playFile(url)
            return
        }

        // 2. TTS nativo (solo es/en, las indígenas no tienen voz oficial)
        let speechLang = language.isIndigenous ? "es-MX" : language.speechLocale.identifier
        guard let voice = AVSpeechSynthesisVoice(language: speechLang) else {
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.15

        isSpeaking = true
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        player?.stop()
        player = nil
        isSpeaking = false
    }

    /// Convención de naming en el bundle:
    ///   audio/{lang}/{audioKey}.m4a
    /// Ejemplo: audio/tzo/welcome.greeting.m4a
    private func bundleAudio(for key: String, language: CaficultorLanguage) -> URL? {
        let folder = "audio/\(language.rawValue)"
        return Bundle.main.url(forResource: key, withExtension: "m4a", subdirectory: folder)
            ?? Bundle.main.url(forResource: key, withExtension: "mp3", subdirectory: folder)
    }

    private func playFile(_ url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            isSpeaking = true
            player?.play()
        } catch {
            isSpeaking = false
        }
    }
}

extension VoiceOutputService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

extension VoiceOutputService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                                  successfully flag: Bool) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
