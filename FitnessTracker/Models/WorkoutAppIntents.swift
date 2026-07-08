import AppIntents
import Foundation

/// Runs in-process when Siri, Spotlight, or a Shortcuts automation invokes "Start Workout" -
/// no Shortcuts app round-trip required.
struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var description = IntentDescription("Starts a workout in Heracle.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Template Name")
    var templateName: String?

    init() {}

    init(templateName: String?) {
        self.templateName = templateName
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: Notification.Name("SiriStartWorkout"),
            object: nil,
            userInfo: ["templateName": templateName ?? "Workout"]
        )
        return .result()
    }
}

/// Donated when a workout completes so any Shortcuts automation the user has bound to
/// "End Workout" fires silently in the background.
struct EndWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "End Workout"
    static var description = IntentDescription("Signals that a workout finished in Heracle.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Template Name")
    var templateName: String?

    init() {}

    init(templateName: String?) {
        self.templateName = templateName
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct FitnessTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start Workout in \(.applicationName)",
                "Start my workout in \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: EndWorkoutIntent(),
            phrases: [
                "End Workout in \(.applicationName)",
                "Finish my workout in \(.applicationName)"
            ],
            shortTitle: "End Workout",
            systemImageName: "checkmark.circle"
        )
    }
}
