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
    @Published var isWorkoutTimerActive: Bool = false
    
    // Warmup timer properties
    @Published var warmupTimeRemaining: Int = 0
    @Published var isWarmupTimerActive: Bool = false
    @Published var currentWarmupIndex: Int = 0
    @Published var warmups: [String] = []
    
    // Default rest timer duration (1:41 = 101 seconds)
    let restDuration: Int = 101
    // Default warmup timer duration (15 seconds)
    let warmupDuration: Int = 15
    
    private var workoutTimer: AnyCancellable?
    private var restTimer: AnyCancellable?
    private var warmupTimer: AnyCancellable?
    private var startTime: Date?
    private var pausedElapsedTime: Int = 0
    
    // MARK: - Workout Timer Methods
    func startWorkoutTimer() {
        startTime = Date()
        isWorkoutTimerActive = true
        workoutTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if let startTime = self.startTime {
                    self.workoutElapsedSeconds = Int(Date().timeIntervalSince(startTime))
                }
            }
    }
    
    func pauseWorkoutTimer() {
        workoutTimer?.cancel()
        workoutTimer = nil
        isWorkoutTimerActive = false
        pausedElapsedTime = workoutElapsedSeconds
    }
    
    func resumeWorkoutTimer() {
        // Set startTime to account for the elapsed time before pause
        startTime = Date().addingTimeInterval(-Double(pausedElapsedTime))
        isWorkoutTimerActive = true
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
        isWorkoutTimerActive = false
        
        // Return the total duration in seconds
        let totalDuration = workoutElapsedSeconds
        workoutElapsedSeconds = 0
        startTime = nil
        pausedElapsedTime = 0
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
    
    // MARK: - Warmup Timer Methods
    func startWarmupTimer(warmups: [String]) {
        self.warmups = warmups
        if warmups.isEmpty {
            return
        }
        
        currentWarmupIndex = 0
        warmupTimeRemaining = warmupDuration
        isWarmupTimerActive = true
        
        warmupTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.warmupTimeRemaining > 0 {
                    self.warmupTimeRemaining -= 1
                } else {
                    self.moveToNextWarmup()
                }
            }
    }
    
    func moveToNextWarmup() {
        currentWarmupIndex += 1
        
        if currentWarmupIndex < warmups.count {
            // Move to the next warmup
            warmupTimeRemaining = warmupDuration
        } else {
            // All warmups are completed
            stopWarmupTimer()
        }
    }
    
    func stopWarmupTimer() {
        warmupTimer?.cancel()
        warmupTimer = nil
        isWarmupTimerActive = false
        warmupTimeRemaining = 0
        currentWarmupIndex = 0
        
        // Post notification that warmup timer is complete
        NotificationCenter.default.post(name: NSNotification.Name("WarmupTimerComplete"), object: nil)
        
        warmups = []
    }
    
    var currentWarmupName: String? {
        guard currentWarmupIndex < warmups.count else { return nil }
        return warmups[currentWarmupIndex]
    }
    
    var isLastWarmup: Bool {
        return currentWarmupIndex == warmups.count - 1
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
        warmupTimer?.cancel()
    }
} 