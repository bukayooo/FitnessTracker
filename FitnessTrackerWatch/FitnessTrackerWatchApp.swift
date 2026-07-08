import SwiftUI
import HealthKit
import WatchKit

class ExtensionDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        print("DEBUG: ⌚️ Received remote workout configuration: \(workoutConfiguration.activityType.rawValue)")
        Task {
            do {
                try await WatchWorkoutManager.shared.startWorkout(configuration: workoutConfiguration)
                print("DEBUG: ⌚️ Successfully started workout")
            } catch {
                print("DEBUG: ⌚️ Failed to start workout: \(error)")
            }
        }
    }
}

@main
struct FitnessTrackerWatchApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) private var appDelegate
    @StateObject private var workoutManager = WatchWorkoutManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
        }
    }
}
