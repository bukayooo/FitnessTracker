//
//  TimerManager.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import Foundation
import Combine

class TimerManager: ObservableObject {
    // MARK: - Properties
    @Published var workoutElapsedSeconds: Int = 0
    @Published var restTimeRemaining: Int = 0
    @Published var isRestTimerActive: Bool = false
    
    // Default rest timer duration (1:41 = 101 seconds)
    let restDuration: Int = 101
    
    private var workoutTimer: AnyCancellable?
    private var restTimer: AnyCancellable?
    private var startTime: Date?
    
    // MARK: - Workout Timer Methods
    func startWorkoutTimer() {
        startTime = Date()
        workoutTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if let startTime = self.startTime {
                    self.workoutElapsedSeconds = Int(Date().timeIntervalSince(startTime))
                }
            }
    }
    
    func stopWorkoutTimer() -> Int {
        workoutTimer?.cancel()
        workoutTimer = nil
        
        // Return the total duration in seconds
        let totalDuration = workoutElapsedSeconds
        workoutElapsedSeconds = 0
        startTime = nil
        return totalDuration
    }
    
    // MARK: - Rest Timer Methods
    func startRestTimer() {
        restTimeRemaining = restDuration
        isRestTimerActive = true
        
        restTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.restTimeRemaining > 0 {
                    self.restTimeRemaining -= 1
                } else {
                    self.stopRestTimer()
                }
            }
    }
    
    func stopRestTimer() {
        restTimer?.cancel()
        restTimer = nil
        isRestTimerActive = false
        restTimeRemaining = 0
    }
    
    // MARK: - Formatted Strings
    var formattedWorkoutTime: String {
        formatTime(seconds: workoutElapsedSeconds)
    }
    
    var formattedRestTime: String {
        formatTime(seconds: restTimeRemaining)
    }
    
    private func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    // MARK: - Cleanup
    deinit {
        workoutTimer?.cancel()
        restTimer?.cancel()
    }
} 