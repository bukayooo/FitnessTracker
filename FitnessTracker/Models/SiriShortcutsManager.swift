import AppIntents
import Foundation
import UIKit

class SiriShortcutsManager: ObservableObject {
    static let shared = SiriShortcutsManager()

    private init() {}

    // MARK: - App Intent Donation
    //
    // Donating lets Siri predict/suggest the action and exposes it as an action other
    // Shortcuts can call, and lets voice invocation ("Hey Siri, Start Workout in Heracle")
    // work. It does NOT create a Personal Automation trigger - custom app intents only
    // show up under "Do", not "When", in the Shortcuts automation editor.

    /// Donates a "Start Workout" app intent when a workout is started
    func donateStartWorkoutIntent(templateName: String) {
        let intent = StartWorkoutIntent(templateName: templateName)
        Task {
            do {
                try await IntentDonationManager.shared.donate(intent: intent)
                print("DEBUG: 🎤 Donated Start Workout app intent for '\(templateName)'")
            } catch {
                print("DEBUG: 🎤 Failed to donate Start Workout app intent: \(error)")
            }
        }
    }

    /// Donates an "End Workout" app intent when a workout is completed
    func donateEndWorkoutIntent(templateName: String) {
        let intent = EndWorkoutIntent(templateName: templateName)
        Task {
            do {
                try await IntentDonationManager.shared.donate(intent: intent)
                print("DEBUG: 🎤 Donated End Workout app intent for '\(templateName)'")
            } catch {
                print("DEBUG: 🎤 Failed to donate End Workout app intent: \(error)")
            }
        }
    }

    // MARK: - Background Execution
    //
    // Runs a user-authored Shortcut immediately via the shortcuts:// x-callback-url,
    // so a Shortcut named "Start Workout" / "End Workout" (e.g. containing Apple Watch
    // actions) actually executes when this app starts/finishes a workout. This briefly
    // switches to the Shortcuts app and back - there is no way to run arbitrary
    // user-authored Shortcut content without either this or a Personal Automation.

    func executeBackgroundShortcut(for templateName: String) {
        executeShortcut(named: "Start Workout", parameters: ["workoutName": templateName])
    }

    func executeEndWorkoutBackgroundShortcut(for templateName: String) {
        executeShortcut(named: "End Workout", parameters: ["workoutName": templateName])
    }

    private func executeShortcut(named shortcutName: String, parameters: [String: Any] = [:]) {
        print("DEBUG: 🎤 Attempting to execute shortcut: \(shortcutName)")

        let encodedShortcutName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedParameters = encodeParameters(parameters)
        let appBundleId = Bundle.main.bundleIdentifier ?? "Spruce.FitnessTracker"

        guard let url = URL(string: "shortcuts://x-callback-url/run-shortcut?name=\(encodedShortcutName)&input=\(encodedParameters)&x-success=\(appBundleId)://&x-cancel=\(appBundleId)://&x-error=\(appBundleId)://") else {
            print("DEBUG: 🎤 Invalid shortcut URL")
            return
        }

        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        print("DEBUG: 🎤 Successfully triggered shortcut: \(shortcutName)")
                    } else {
                        print("DEBUG: 🎤 Failed to trigger shortcut: \(shortcutName)")
                    }
                }
            } else {
                print("DEBUG: 🎤 Cannot open shortcut URL - Shortcuts app may not be available, or no shortcut named '\(shortcutName)' exists")
            }
        }
    }

    private func encodeParameters(_ parameters: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: parameters),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
}
