import Foundation
import NaturalLanguage
import WhisperKit

/// Records from the microphone and transcribes on the device with OpenAI's open-source Whisper model.
///
/// Audio never leaves the phone. The only network use is the one-time model download.
@MainActor @Observable
final class SpeechTranscriber {
    enum Phase: Equatable {
        case idle, preparing, listening, finishing, done
        case failed(String)
    }

    /// Bars drawn on each side of the microphone.
    static let bars = 12
    /// One Whisper window. Plenty for a daily check-in, and it keeps each live pass fast.
    static let maxSeconds = 30

    private(set) var phase = Phase.idle
    private(set) var transcript = ""
    /// Recent microphone energy, 0...1, newest last.
    private(set) var levels: [Float] = []

    /// The loaded model, kept so reopening the screen does not load it again.
    private static var kit: WhisperKit?
    private var work: Task<Void, Never>?
    /// Bumped on every start and cancel so an older recording stops touching state.
    private var session = 0

    /// Starts a fresh recording, discarding any earlier one.
    func start() {
        session += 1
        let mine = session, previous = work
        Self.kit?.audioProcessor.stopRecording()
        phase = .preparing
        transcript = ""
        levels = []
        work = Task {
            await previous?.value
            do {
                guard await AudioProcessor.requestRecordPermission() else {
                    throw Failure("Microphone access is off. Turn it on for PetPulse in Settings.")
                }
                let kit = try await Self.loadModel()
                guard mine == session else { return }
                try kit.audioProcessor.startRecordingLive(inputDeviceID: nil, callback: nil)
                phase = .listening
                await listen(kit, session: mine)
            } catch {
                guard mine == session else { return }
                phase = .failed((error as? Failure)?.message ?? "Couldn't start listening. Check your connection and try again.")
            }
        }
    }

    /// Stops recording and waits for the final transcript.
    func finish() async {
        guard phase == .listening || phase == .finishing else { return }
        phase = .finishing
        await work?.value
    }

    func cancel() {
        session += 1
        Self.kit?.audioProcessor.stopRecording()
        phase = .idle
    }

    private func listen(_ kit: WhisperKit, session mine: Int) async {
        let meter = Task {
            while !Task.isCancelled {
                levels = Array(kit.audioProcessor.relativeEnergy.suffix(Self.bars))
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
        defer { meter.cancel() }

        // Re-transcribe the whole clip as it grows, so earlier words are corrected with later context.
        var heard = 0
        while mine == session, phase == .listening {
            let count = kit.audioProcessor.audioSamples.count
            if count >= Self.maxSeconds * WhisperKit.sampleRate {
                phase = .finishing
            } else if count - heard >= WhisperKit.sampleRate {
                heard = count
                let text = await transcribe(kit)
                if mine == session, phase == .listening, let text { transcript = text }
            } else {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        guard mine == session, phase == .finishing else { return }
        kit.audioProcessor.stopRecording()
        let text = await transcribe(kit)
        guard mine == session else { return }
        if let text { transcript = text }
        phase = .done
    }

    private func transcribe(_ kit: WhisperKit) async -> String? {
        let samples = Array(kit.audioProcessor.audioSamples)
        let options = DecodingOptions(language: "en", skipSpecialTokens: true, withoutTimestamps: true)
        guard !samples.isEmpty,
              let results = try? await kit.transcribe(audioArray: samples, decodeOptions: options) else { return nil }
        // Whisper marks non-speech as "[BLANK_AUDIO]" or "(silence)".
        return results.map(\.text).joined(separator: " ")
            .replacing(#/\[[^\]]*\]|\([^)]*\)/#, with: "")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Downloads the model on first use, then loads it from disk.
    private static func loadModel() async throws -> WhisperKit {
        if let kit { return kit }
        // WHISPER_MODEL build setting, surfaced through Info.plist. Empty means WhisperKit's pick for this device.
        let name = (Bundle.main.object(forInfoDictionaryKey: "WhisperModel") as? String).flatMap { $0.isEmpty ? nil : $0 }
        do {
            let loaded = try await WhisperKit(WhisperKitConfig(model: name, verbose: false, load: true))
            kit = loaded
            return loaded
        } catch {
            throw Failure("Couldn't load the voice model. The first use needs an internet connection to download it.")
        }
    }

    private struct Failure: Error {
        var message: String
        init(_ message: String) { self.message = message }
    }
}

/// Apple's on-device sentence embedding, used to match phrasing the parser has no keyword for.
enum SentenceEmbedding {
    private static let model = NLEmbedding.sentenceEmbedding(for: .english)

    static func similarity(_ a: String, _ b: String) -> Double? {
        guard let model else { return nil }
        let distance = model.distance(between: a, and: b, distanceType: .cosine)
        // An out-of-vocabulary input comes back as a huge sentinel distance.
        return distance <= 2 ? 1 - distance : nil
    }
}
