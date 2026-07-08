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
        let activity = NSUserActivity(activityType: "com.spruce.fitnessTracker.startWorkout")
        activity.title = "Start \(templateName) workout"
        activity.userInfo = ["templateName": templateName]
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.suggestedInvocationPhrase = "Start my \(templateName) workout"
        
        activity.becomeCurrent()
        
        print("DEBUG: 🎤 Successfully donated user activity for '\(templateName)' workout")
    }
    
    /// Donates a generic "Start Workout" user activity
    func donateGenericStartWorkoutIntent() {
        let activity = NSUserActivity(activityType: "com.spruce.fitnessTracker.startWorkout")
        activity.title = "Start workout"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.suggestedInvocationPhrase = "Start my workout"
        
        activity.becomeCurrent()
        
        print("DEBUG: 🎤 Successfully donated generic user activity")
    }
    
    /// Donates an "End Workout" user activity to Siri when a workout is completed
    func donateEndWorkoutIntent(templateName: String) {
        let activity = NSUserActivity(activityType: "com.spruce.fitnessTracker.endWorkout")
        activity.title = "End \(templateName) workout"
        activity.userInfo = ["templateName": templateName]
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.suggestedInvocationPhrase = "End my \(templateName) workout"

        activity.becomeCurrent()

        print("DEBUG: 🎤 Successfully donated end-workout user activity for '\(templateName)' workout")
    }

    // MARK: - UserActivity Handling
    
    /// Handles a "Start Workout" user activity by posting a notification to start the workout
    func handleStartWorkoutActivity(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == "com.spruce.fitnessTracker.startWorkout" else { return }
        
        let templateName = userActivity.userInfo?["templateName"] as? String ?? "Workout"
        
        // Post notification to start the workout
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("SiriStartWorkout"),
                object: nil,
                userInfo: ["templateName": templateName]
            )
        }
        
        print("DEBUG: 🎤 Handled user activity for workout: \(templateName)")
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

    /// Executes a custom "End Workout" shortcut in the background when a workout is completed
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
