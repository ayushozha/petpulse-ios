import Observation

/// Set by `VoiceCheckInIntent` and cleared by the app once it has opened the voice check-in.
///
/// The intent can run before any view exists, such as on a cold launch from Siri, so the request
/// waits here until `MainView` is on screen to act on it.
@MainActor @Observable
final class VoiceCheckInRequest {
    static let shared = VoiceCheckInRequest()

    var isPending = false
}
