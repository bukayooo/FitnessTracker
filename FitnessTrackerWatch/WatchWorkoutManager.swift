import Foundation
import HealthKit

class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?

    @Published var isWorkoutActive = false
    @Published var elapsedSeconds: Int = 0

    private override init() {
        super.init()
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

    func startWorkout(configuration: HKWorkoutConfiguration) {
        print("DEBUG: ⌚️ Starting workout session for activity type: \(configuration.activityType.rawValue)")

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            print("DEBUG: ⌚️ Failed to create workout session: \(error)")
            return
        }

        session?.delegate = self
        builder?.delegate = self
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        let startDate = Date()
        session?.startActivity(with: startDate)
        builder?.beginCollection(withStart: startDate) { success, error in
            if let error = error {
                print("DEBUG: ⌚️ Failed to begin collection: \(error)")
            }
        }

        DispatchQueue.main.async {
            self.isWorkoutActive = true
            self.startTimer(from: startDate)
        }
    }

    func endWorkout() {
        print("DEBUG: ⌚️ Ending workout session (manual)")
        session?.stopActivity(with: Date())
        session?.end()
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
