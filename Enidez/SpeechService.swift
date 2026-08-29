//
//  SpeechService.swift
//  Enidez
//
//  La voix est l'entrée principale. On appuie, on parle, ça s'arrête quand on
//  a fini — et le texte reconnu revient pour être interprété.
//
//  Reconnaissance sur l'appareil quand c'est possible (hors ligne, rien ne
//  sort du téléphone). Si le micro ou la reconnaissance sont refusés /
//  indisponibles, on échoue en silence : l'app reste utilisable au doigt.
//
//  Pour activer les vraies données, la cible a besoin de deux descriptions
//  d'usage dans l'Info.plist (déjà ajoutées côté build settings) :
//   - NSMicrophoneUsageDescription
//   - NSSpeechRecognitionUsageDescription
//

import Foundation
import AVFoundation
#if canImport(Speech)
import Speech
#endif

@MainActor
@Observable
final class SpeechService {

    enum Status: Equatable {
        case idle          // au repos
        case listening     // micro ouvert
        case denied        // micro ou reconnaissance refusés
        case unavailable   // pas de reconnaissance sur cet appareil
    }

    private(set) var status: Status = .idle

    /// Ce qui est reconnu, mis à jour en direct pendant qu'on parle.
    private(set) var transcript: String = ""

    #if canImport(Speech)
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    #endif

    /// Ouvre le micro et commence à transcrire. Sans effet si déjà en écoute.
    func start() async {
        guard status != .listening else { return }
        transcript = ""

        // Dans le canvas de preview, on ne touche pas au micro.
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            status = .unavailable
            return
        }

        #if canImport(Speech) && !targetEnvironment(macCatalyst)
        guard Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") != nil,
              Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil,
              let recognizer, recognizer.isAvailable else {
            status = .unavailable
            return
        }

        guard await isAuthorized() else {
            status = .denied
            return
        }

        do {
            try startEngine(with: recognizer)
            status = .listening
        } catch {
            stopEngine()
            status = .unavailable
        }
        #else
        status = .unavailable
        #endif
    }

    /// Ferme le micro et renvoie le texte final (peut être vide).
    @discardableResult
    func stop() -> String {
        #if canImport(Speech)
        stopEngine()
        #endif
        status = .idle
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Détails

    #if canImport(Speech)
    private func isAuthorized() async -> Bool {
        let speech: Bool = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }

        return await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    private func startEngine(with recognizer: SFSpeechRecognizer) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        // Le tap tourne sur un thread audio temps réel ; `append` est sûr à
        // appeler de là. On capture la requête directement.
        nonisolated(unsafe) let sink = request
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            sink.append(buffer)
        }

        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let finished = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = text }
                if finished { self.stopEngine() }
            }
        }
    }

    private func stopEngine() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    #endif
}
