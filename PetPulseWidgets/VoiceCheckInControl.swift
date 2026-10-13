import SwiftUI
import WidgetKit

/// A button for Control Center, the Lock Screen and the Action Button that opens the voice check-in.
struct VoiceCheckInControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.petpulse.app.voice-check-in") {
            ControlWidgetButton(action: VoiceCheckInIntent()) {
                Label("Voice Check-in", systemImage: "mic.fill")
            }
        }
        .displayName("Voice Check-in")
        .description("Describe your pet's day out loud.")
    }
}
