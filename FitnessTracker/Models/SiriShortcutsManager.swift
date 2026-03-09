import Foundation
import Intents
import SwiftUI

class SiriShortcutsManager: ObservableObject {
    static let shared = SiriShortcutsManager()
    
    private init() {}
    
    // MARK: - UserActivity Donation (Simpler Approach)
    
    /// Donates a "Start Workout" user activity to Siri when a workout is started
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
    
    /// Executes a custom shortcut in the background when a workout starts
    func executeBackgroundShortcut(for templateName: String) {
        // Execute the shortcut without leaving the app
        executeShortcut(named: "Start Workout", parameters: ["workoutName": templateName])
    }
    
    private func executeShortcut(named shortcutName: String, parameters: [String: Any] = [:]) {
        print("DEBUG: 🎤 Attempting to execute shortcut: \(shortcutName)")
        
        // Create the shortcut URL with x-callback-url to return to our app
        let encodedShortcutName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedParameters = encodeParameters(parameters)
        let appBundleId = Bundle.main.bundleIdentifier ?? "Spruce.FitnessTracker"
        
        // Use x-callback-url pattern to execute shortcut and return to app
        guard let url = URL(string: "shortcuts://x-callback-url/run-shortcut?name=\(encodedShortcutName)&input=\(encodedParameters)&x-success=\(appBundleId)://&x-cancel=\(appBundleId)://&x-error=\(appBundleId)://") else {
            print("DEBUG: 🎤 Invalid shortcut URL")
            return
        }
        
        // Execute on main thread but with minimal app switching
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
                print("DEBUG: 🎤 Cannot open shortcut URL - Shortcuts app may not be available")
                // Fall back to a notification-based approach
                self.sendNotificationInstead(shortcutName: shortcutName, parameters: parameters)
            }
        }
    }
    
    private func sendNotificationInstead(shortcutName: String, parameters: [String: Any]) {
        // Send a local notification as a fallback
        print("DEBUG: 🎤 Sending notification fallback for shortcut: \(shortcutName)")
        NotificationCenter.default.post(
            name: Notification.Name("WorkoutShortcutExecuted"),
            object: nil,
            userInfo: ["shortcutName": shortcutName, "parameters": parameters]
        )
    }
    
    private func encodeParameters(_ parameters: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: parameters),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
}