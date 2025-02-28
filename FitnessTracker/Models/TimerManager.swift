//
//  TimerManager.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import Foundation
import Combine
import SwiftUI

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
    @Published var warmupDurations: [Int] = []
    
    // Default rest timer duration (1:41 = 101 seconds)
    let restDuration: Int = 101
    // Default warmup timer duration (15 seconds)
    let defaultWarmupDuration: Int = 15
    
    private var workoutTimer: AnyCancellable?
    private var restTimer: AnyCancellable?
    private var warmupTimer: AnyCancellable?
    private var workoutStartTime: Date?
    private var pausedElapsedTime: Int = 0
    private var appPhaseObserver: AnyCancellable?
    
    init() {
        // Check if we have saved timer state from a previous session
        restoreTimerStateIfNeeded()
        
        // Subscribe to app phase change notifications
        appPhaseObserver = NotificationCenter.default.publisher(for: .appScenePhaseChanged)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let phase = userInfo["phase"] as? ScenePhase else {
                    return
                }
                
                switch phase {
                case .active:
                    self.handleAppBecameActive()
                case .background:
                    self.handleAppWentToBackground()
                default:
                    break
                }
            }
    }
    
    // MARK: - Workout Timer Methods
    func startWorkoutTimer() {
        workoutStartTime = Date()
        isWorkoutTimerActive = true
        saveTimerState()
        
        workoutTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateWorkoutElapsedTime()
            }
    }
    
    func updateWorkoutElapsedTime() {
        guard let startTime = workoutStartTime else { return }
        workoutElapsedSeconds = Int(Date().timeIntervalSince(startTime)) + pausedElapsedTime
    }
    
    func pauseWorkoutTimer() {
        workoutTimer?.cancel()
        workoutTimer = nil
        isWorkoutTimerActive = false
        
        // Store current elapsed time
        if let startTime = workoutStartTime {
            pausedElapsedTime += Int(Date().timeIntervalSince(startTime))
        }
        workoutStartTime = nil
        saveTimerState()
    }
    
    func resumeWorkoutTimer() {
        workoutStartTime = Date()
        isWorkoutTimerActive = true
        saveTimerState()
        
        workoutTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateWorkoutElapsedTime()
            }
    }
    
    func stopWorkoutTimer() -> Int {
        workoutTimer?.cancel()
        workoutTimer = nil
        isWorkoutTimerActive = false
        
        // Calculate final duration
        var totalDuration = pausedElapsedTime
        if let startTime = workoutStartTime {
            totalDuration += Int(Date().timeIntervalSince(startTime))
        }
        
        // Reset the timer
        workoutElapsedSeconds = 0
        workoutStartTime = nil
        pausedElapsedTime = 0
        saveTimerState()
        
        return totalDuration
    }
    
    // MARK: - Timer State Persistence
    
    private func saveTimerState() {
        // Save workout timer state
        UserDefaults.standard.set(isWorkoutTimerActive, forKey: "workout_timer_active")
        UserDefaults.standard.set(pausedElapsedTime, forKey: "workout_paused_time")
        
        // Save start time if active
        if let startTime = workoutStartTime {
            UserDefaults.standard.set(startTime.timeIntervalSince1970, forKey: "workout_start_time")
        } else {
            UserDefaults.standard.removeObject(forKey: "workout_start_time")
        }
        
        print("DEBUG: Saved timer state: active=\(isWorkoutTimerActive), pausedTime=\(pausedElapsedTime)")
    }
    
    private func restoreTimerStateIfNeeded() {
        // Restore workout timer state
        if UserDefaults.standard.bool(forKey: "workout_timer_active") {
            isWorkoutTimerActive = true
            pausedElapsedTime = UserDefaults.standard.integer(forKey: "workout_paused_time")
            
            // Restore start time if it exists
            if let startTimeInterval = UserDefaults.standard.object(forKey: "workout_start_time") as? TimeInterval {
                workoutStartTime = Date(timeIntervalSince1970: startTimeInterval)
                
                // Setup timer again
                workoutTimer = Timer.publish(every: 0.5, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self = self else { return }
                        self.updateWorkoutElapsedTime()
                    }
                
                // Update elapsed time immediately
                updateWorkoutElapsedTime()
            }
            
            print("DEBUG: Restored timer state: active=\(isWorkoutTimerActive), pausedTime=\(pausedElapsedTime)")
        }
    }
    
    // Method to handle app coming back to foreground
    func handleAppBecameActive() {
        print("DEBUG: TimerManager - App became active")
        restoreTimerStateIfNeeded()
        
        if isWorkoutTimerActive, workoutStartTime != nil {
            updateWorkoutElapsedTime()
            print("DEBUG: TimerManager - Updated elapsed time to \(workoutElapsedSeconds)")
        }
    }
    
    // Method to handle app going to background
    func handleAppWentToBackground() {
        print("DEBUG: TimerManager - App went to background")
        saveTimerState()
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
    func startWarmupTimer(warmups: [String], durations: [Int] = []) {
        self.warmups = warmups
        if warmups.isEmpty {
            print("DEBUG: ⏱️ No warmups to start timer with")
            return
        }
        
        print("DEBUG: ⏱️ Starting warmup timer with \(warmups.count) warmups")
        print("DEBUG: ⏱️ Provided durations: \(durations)")
        
        // Store the durations, or use defaults if none provided
        if durations.isEmpty || durations.count != warmups.count {
            print("DEBUG: ⏱️ Using default durations because: isEmpty=\(durations.isEmpty), count mismatch=\(durations.count != warmups.count)")
            self.warmupDurations = Array(repeating: defaultWarmupDuration, count: warmups.count)
        } else {
            print("DEBUG: ⏱️ Using custom durations: \(durations)")
            self.warmupDurations = durations
        }
        
        currentWarmupIndex = 0
        warmupTimeRemaining = self.warmupDurations[0]
        print("DEBUG: ⏱️ Starting first warmup '\(warmups[0])' with duration: \(warmupTimeRemaining)s")
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
            // Move to the next warmup with its duration
            warmupTimeRemaining = warmupDurations[currentWarmupIndex]
            print("DEBUG: ⏱️ Moving to next warmup '\(warmups[currentWarmupIndex])' with duration: \(warmupTimeRemaining)s")
        } else {
            // All warmups are completed
            print("DEBUG: ⏱️ All warmups completed")
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
        warmupDurations = []
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
        appPhaseObserver?.cancel()
    }
}