import SwiftUI
import HealthKit
import WatchKit

class ExtensionDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        print("DEBUG: ⌚️ Received remote workout configuration: \(workoutConfiguration.activityType.rawValue)")
        WatchWorkoutManager.shared.startWorkout(configuration: workoutConfiguration)
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
