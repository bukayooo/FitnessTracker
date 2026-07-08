import Foundation
import HealthKit

/// Drives a workout session on the paired Apple Watch (via Heracle's watchOS companion app)
/// using HealthKit workout-session mirroring - HKHealthStore.startWatchApp launches the watch
/// app, and workoutSessionMirroringStartHandler hands back a mirrored session on the phone that
/// can be used to end the real session running on the Watch.
class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    private let healthStore = HKHealthStore()
    private var mirroredSession: HKWorkoutSession?

    private override init() {
        super.init()
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: []) { success, error in
            if let error = error {
                print("DEBUG: 🍎⌚️ HealthKit authorization error: \(error)")
            } else {
                print("DEBUG: 🍎⌚️ HealthKit authorization granted: \(success)")
            }
        }
    }

    func startWatchWorkout(activityType: HKWorkoutActivityType) {
        requestAuthorization()

        healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            print("DEBUG: 🍎⌚️ Received mirrored workout session")
            self?.mirroredSession = mirroredSession
            mirroredSession.delegate = self
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .unknown

        healthStore.startWatchApp(with: configuration) { success, error in
            if let error = error {
                print("DEBUG: 🍎⌚️ Failed to start watch app: \(error)")
            } else {
                print("DEBUG: 🍎⌚️ startWatchApp success: \(success)")
            }
        }
    }

    func endWatchWorkout() {
        guard let mirroredSession = mirroredSession else {
            print("DEBUG: 🍎⌚️ No active mirrored workout session to end")
            return
        }
        mirroredSession.stopActivity(with: Date())
        mirroredSession.end()
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("DEBUG: 🍎⌚️ Mirrored session state changed: \(fromState.rawValue) -> \(toState.rawValue)")
        if toState == .ended {
            mirroredSession = nil
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("DEBUG: 🍎⌚️ Mirrored session failed: \(error)")
    }
}
