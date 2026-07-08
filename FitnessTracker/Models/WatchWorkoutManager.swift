import Foundation
import HealthKit
import WatchConnectivity

/// Drives a workout session on the paired Apple Watch (via Heracle's watchOS companion app).
/// HKHealthStore.startWatchApp/handle(_:) proved unreliable in testing (completion reports
/// success but the Watch's delegate is never actually invoked), so the Watch is instead woken
/// via WatchConnectivity, and the Watch starts its own HKWorkoutSession and links it back with
/// session.startMirroringToCompanionDevice(), which hands this phone a mirrored session via
/// workoutSessionMirroringStartHandler that can be used to end the real session on the Watch.
class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    private let healthStore = HKHealthStore()
    private var mirroredSession: HKWorkoutSession?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func startWatchWorkout(activityType: HKWorkoutActivityType) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("DEBUG: 🍎⌚️ Health data not available on this device")
            return
        }

        // requestAuthorization's completion only reports whether the system was able to
        // show/resolve the request, not whether the user actually granted it (HealthKit
        // hides per-type grant status for privacy) - so we always proceed to startWatchApp
        // after this completes, but critically we must WAIT for it, since calling
        // startWatchApp before the user has answered the permission prompt reliably fails.
        healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: []) { [weak self] success, error in
            if let error = error {
                print("DEBUG: 🍎⌚️ HealthKit authorization error: \(error)")
            }
            DispatchQueue.main.async {
                self?.beginWatchApp(activityType: activityType)
            }
        }
    }

    private func beginWatchApp(activityType: HKWorkoutActivityType) {
        healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            print("DEBUG: 🍎⌚️ Received mirrored workout session")
            self?.mirroredSession = mirroredSession
            mirroredSession.delegate = self
        }

        // Primary path: wake/notify the Watch via WatchConnectivity. transferUserInfo is
        // queued and delivered (launching the Watch app in the background if needed) even
        // if the Watch isn't reachable at this exact instant.
        if WCSession.default.activationState == .activated {
            WCSession.default.transferUserInfo(["activityTypeRawValue": activityType.rawValue])
            print("DEBUG: 🍎⌚️ Sent workout request to Watch via WatchConnectivity")
        } else {
            print("DEBUG: 🍎⌚️ WCSession not activated (state: \(WCSession.default.activationState.rawValue)), cannot notify Watch via WatchConnectivity")
        }

        // Kept as a redundant secondary attempt in case this starts working correctly.
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor

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

extension WatchWorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("DEBUG: 🍎⌚️ WCSession activation error: \(error)")
        } else {
            print("DEBUG: 🍎⌚️ WCSession activated: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
