import SwiftUI

/// Speak a check-in, review what was understood, then hand it to the form.
struct VoiceCheckInView: View {
    var pet: Pet
    var onUse: (VoiceCheckIn) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var transcriber = SpeechTranscriber()
    @State private var detected = VoiceCheckIn()

    private var isListening: Bool { transcriber.phase == .listening }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Tell us how \(pet.name) is doing today.").font(.pp(15)).foregroundStyle(PP.subtext)
                hero
                microphone
                status
                results
                HStack(spacing: 12) {
                    PrimaryButton("Use This", leadingImage: "checkmark", action: use)
                        .disabled(detected.transcript.isEmpty)
                        .opacity(detected.transcript.isEmpty ? 0.5 : 1)
                    SecondaryButton("Try Again", leadingImage: "arrow.counterclockwise") { transcriber.start() }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .screen("Voice Check-in")
        .onAppear { transcriber.start() }
        .onDisappear { transcriber.cancel() }
        .onChange(of: transcriber.transcript) { _, text in
            detected = VoiceParser.parse(text, similarity: SentenceEmbedding.similarity)
        }
    }

    // MARK: Pieces

    private var hero: some View {
        Color.clear
            .frame(height: 150)
            .overlay { Image("cat_closeup").resizable().scaledToFill() }
            .clipped()
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.2),
                                       .init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topTrailing) {
                HStack(alignment: .bottom, spacing: 3) {
                    Text("Just\nspeak\nnaturally").font(.handwriting(17)).multilineTextAlignment(.center)
                    Image(systemName: "heart").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(PP.teal)
                .rotationEffect(.degrees(-8))
                .padding(.top, 16)
            }
            .padding(.horizontal, -20)
    }

    private var microphone: some View {
        HStack(spacing: 14) {
            waveform(transcriber.levels)
            Button(action: toggle) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 100, height: 100)
                    .background(PP.buttonGradient, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .padding(12)
                    .background(PP.tealLight.opacity(isListening ? 0.25 : 0.1), in: Circle())
                    .shadow(color: PP.teal.opacity(0.3), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isListening ? "Stop listening" : "Start listening")
            waveform(transcriber.levels.reversed())
        }
        .padding(.top, -44)
    }

    /// Bars that follow the microphone level; the loudest recent moment sits next to the button.
    private func waveform(_ levels: [Float]) -> some View {
        let padded = Array(repeating: Float(0), count: max(0, SpeechTranscriber.bars - levels.count)) + levels
        return HStack(spacing: 4) {
            ForEach(Array(padded.enumerated()), id: \.offset) { bar in
                Capsule()
                    .fill(PP.tealLight)
                    .frame(width: 4, height: 6 + CGFloat(min(max(bar.element, 0), 1)) * 40)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .animation(.easeOut(duration: 0.1), value: padded)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var status: some View {
        switch transcriber.phase {
        case .idle: statusText("Tap the mic to start")
        case .preparing: statusText("Preparing voice model…")
        case .listening: statusText("Listening…")
        case .finishing: statusText("Finishing up…")
        case .done: statusText("Got it")
        case .failed(let message): Text(message).font(.pp(14)).foregroundStyle(PP.red).multilineTextAlignment(.center)
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text).font(.pp(18, .semibold)).foregroundStyle(PP.teal)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                badge("text.bubble.fill")
                Text("Live Transcription").font(.pp(16, .semibold)).foregroundStyle(PP.navy)
                Spacer()
                if isListening {
                    Label("Recording…", systemImage: "circle.fill")
                        .font(.pp(13))
                        .foregroundStyle(PP.red)
                        .imageScale(.small)
                }
            }
            Text(detected.transcript.isEmpty ? "Try: “\(pet.name) ate less dry food today and was a little less active.”" : detected.transcript)
                .font(.pp(15))
                .foregroundStyle(detected.transcript.isEmpty ? PP.subtext : PP.text)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .padding(14)
                .background(PP.blueSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack {
                SectionTitle("Detected Information")
                Spacer()
                Button(action: use) {
                    Label("Edit Manually", systemImage: "pencil").font(.pp(13, .medium)).foregroundStyle(PP.teal)
                }
                .disabled(detected.transcript.isEmpty)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                chip(.metric(.dryFood), "Food & Feeding", detected.label([.dryFood, .wetFood], unit: "g"))
                chip(.metric(.water), "Water", detected.label([.water], unit: "ml"))
                chip(.metric(.stool), "Stool & Urination", detected.stoolLabel)
                chip(.metric(.activity), "Activity & Behavior", detected.label([.activity]))
            }
            if !detected.transcript.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    badge("note.text")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notes").font(.pp(13, .semibold)).foregroundStyle(PP.navy)
                        Text("Added by voice").font(.pp(12)).foregroundStyle(PP.subtext)
                    }
                    Text("“\(detected.transcript)”")
                        .font(.pp(12)).italic()
                        .foregroundStyle(PP.subtext)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(PP.mint.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .card(radius: 20)
    }

    private func badge(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(PP.teal)
            .frame(width: 36, height: 36)
            .background(PP.mint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func chip(_ kind: IconKind, _ title: String, _ value: String?) -> some View {
        HStack(spacing: 8) {
            IconBadge(kind: kind, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.pp(12, .semibold)).foregroundStyle(PP.navy)
                Text(value ?? "Not mentioned").font(.pp(12)).foregroundStyle(PP.subtext)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(kind.soft.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(value == nil ? 0.6 : 1)
    }

    // MARK: Actions

    private func toggle() {
        switch transcriber.phase {
        case .listening: Task { await transcriber.finish() }
        case .preparing, .finishing: break
        case .idle, .done, .failed: transcriber.start()
        }
    }

    /// Waits for the final transcript so the form gets the corrected text, not the last live pass.
    private func use() {
        Task {
            await transcriber.finish()
            onUse(VoiceParser.parse(transcriber.transcript, similarity: SentenceEmbedding.similarity))
            dismiss()
        }
    }
}
