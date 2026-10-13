import AppIntents

/// Opens PetPulse straight to the voice check-in.
///
/// Siri, Spotlight and the Shortcuts app reach it through `PetPulseShortcuts`, and the Control Center
/// and Lock Screen control runs it too, so it is compiled into both the app and the widget extension.
/// Because it opens the app, the system runs `perform()` in the app, where the UI picks up the request.
struct VoiceCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "Voice Check-in"
    static let description = IntentDescription("Opens PetPulse and starts listening, so you can describe your pet's day out loud.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        VoiceCheckInRequest.shared.isPending = true
        return .result()
    }
}
