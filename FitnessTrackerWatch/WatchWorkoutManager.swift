import Foundation
import HealthKit
import WatchConnectivity

class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?

    @Published var isWorkoutActive = false
    @Published var elapsedSeconds: Int = 0

    // Set when starting fails specifically because the app was backgrounded (HealthKit
    // requires the app be in the foreground to start a session) - retried once the app
    // becomes active, since the user opening the Watch is the natural recovery moment.
    private var pendingConfiguration: HKWorkoutConfiguration?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: []) { success, error in
            if let error = error {
                print("DEBUG: ⌚️ HealthKit authorization error: \(error)")
            } else {
                print("DEBUG: ⌚️ HealthKit authorization granted: \(success)")
            }
        }
    }

    func startWorkout(configuration: HKWorkoutConfiguration) async throws {
        print("DEBUG: ⌚️ Starting workout session for activity type: \(configuration.activityType.rawValue)")

        session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        builder = session?.associatedWorkoutBuilder()

        session?.delegate = self
        builder?.delegate = self
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        // Must happen before startActivity - this is what actually notifies the iPhone's
        // workoutSessionMirroringStartHandler. Without it, the Watch runs its own independent
        // session and the phone never hears about it, even though startWatchApp reports success.
        try await session?.startMirroringToCompanionDevice()

        let startDate = Date()
        session?.startActivity(with: startDate)
        try await builder?.beginCollection(at: startDate)

        await MainActor.run {
            self.isWorkoutActive = true
            self.startTimer(from: startDate)
        }
    }

    /// Attempts to start `configuration`, remembering it as pending if it fails only
    /// because the app was backgrounded, so it can be retried once the app becomes active.
    private func attemptStartWorkout(configuration: HKWorkoutConfiguration) {
        Task {
            do {
                try await startWorkout(configuration: configuration)
                pendingConfiguration = nil
                print("DEBUG: ⌚️ Successfully started workout")
            } catch let error as HKError where error.code == .errorNotPermittedWhileInBackground {
                pendingConfiguration = configuration
                print("DEBUG: ⌚️ Deferred workout start until app is foregrounded: \(error)")
            } catch {
                print("DEBUG: ⌚️ Failed to start workout: \(error)")
            }
        }
    }

    /// Call when the app becomes active (e.g. the user opens/looks at the Watch) to retry
    /// a workout start that was deferred because the app was previously in the background.
    func retryPendingWorkoutIfNeeded() {
        guard let configuration = pendingConfiguration else { return }
        pendingConfiguration = nil
        print("DEBUG: ⌚️ Retrying deferred workout start now that the app is active")
        attemptStartWorkout(configuration: configuration)
    }

    func endWorkout() {
        guard let session, session.state == .running || session.state == .paused else {
            print("DEBUG: ⌚️ No active workout session to end")
            return
        }
        print("DEBUG: ⌚️ Ending workout session (manual)")
        session.stopActivity(with: Date())
        session.end()
    }

    private func startTimer(from startDate: Date) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedSeconds = Int(Date().timeIntervalSince(startDate))
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("DEBUG: ⌚️ Workout session state changed: \(fromState.rawValue) -> \(toState.rawValue)")

        DispatchQueue.main.async {
            self.isWorkoutActive = (toState == .running)
        }

        guard toState == .ended else { return }

        builder?.endCollection(withEnd: date) { [weak self] success, error in
            if let error = error {
                print("DEBUG: ⌚️ Failed to end collection: \(error)")
            }
            self?.builder?.finishWorkout { workout, error in
                if let error = error {
                    print("DEBUG: ⌚️ Failed to finish workout: \(error)")
                } else {
                    print("DEBUG: ⌚️ Workout finished and saved")
                }
                DispatchQueue.main.async {
                    self?.stopTimer()
                    self?.elapsedSeconds = 0
                    self?.session = nil
                    self?.builder = nil
                }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("DEBUG: ⌚️ Workout session failed: \(error)")
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

extension WatchWorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("DEBUG: ⌚️ WCSession activation error: \(error)")
        } else {
            print("DEBUG: ⌚️ WCSession activated: \(activationState.rawValue)")
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        print("DEBUG: ⌚️ Received user info via WatchConnectivity: \(userInfo)")
        guard let rawValue = userInfo["activityTypeRawValue"] as? UInt,
              let activityType = HKWorkoutActivityType(rawValue: rawValue) else {
            print("DEBUG: ⌚️ Could not parse activity type from WatchConnectivity payload")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor

        Task {
            do {
                try await self.startWorkout(configuration: configuration)
                print("DEBUG: ⌚️ Successfully started workout via WatchConnectivity")
            } catch {
                print("DEBUG: ⌚️ Failed to start workout via WatchConnectivity: \(error)")
            }
        }
    }
}
