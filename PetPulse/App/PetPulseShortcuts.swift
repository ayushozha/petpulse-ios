import AppIntents

/// Phrases Siri recognizes, also listed in Spotlight and the Shortcuts app with no setup.
struct PetPulseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: VoiceCheckInIntent(),
            phrases: [
                "Check in with \(.applicationName)",
                "Start a voice check-in in \(.applicationName)",
                "Log my pet's day in \(.applicationName)",
                "Tell \(.applicationName) about my pet's day",
            ],
            shortTitle: "Voice Check-in",
            systemImageName: "mic.fill"
        )
    }

    static let shortcutTileColor = ShortcutTileColor.teal
}
