//
//  ActiveWorkoutSession.swift
//  FitnessTracker
//

import Foundation
import CoreData

/// Tracks the workout currently in progress so it can be minimized into a
/// floating orb and resumed from any tab, instead of being tied to a sheet
/// owned by whichever screen started it. Owns the single TimerManager used
/// for the active workout so timers keep running while minimized.
final class ActiveWorkoutSession: ObservableObject {
    @Published private(set) var workout: NSManagedObject?
    @Published var isMinimized: Bool = false
    let timerManager = TimerManager()

    var isActive: Bool { workout != nil }

    /// Begins tracking a new workout. If a workout is already in progress,
    /// this just brings it back into view instead of replacing it, since
    /// starting a second workout on top of a running one would orphan its
    /// timer state.
    func start(with workout: NSManagedObject) {
        guard !isActive else {
            isMinimized = false
            return
        }
        timerManager.resetAll()
        self.workout = workout
        isMinimized = false
    }

    /// Ends the active workout session (cancel or complete) and stops its timers.
    func end() {
        timerManager.resetAll()
        workout = nil
        isMinimized = false
    }
}
