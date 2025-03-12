//
//  TimerManager.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import Foundation
import Combine
import SwiftUI
import UserNotifications

class TimerManager: ObservableObject {
    // MARK: - Properties
    @Published var workoutElapsedSeconds: Int = 0
    @Published var restTimeRemaining: Int = 0
    @Published var isRestTimerActive: Bool = false
    @Published var isWorkoutTimerActive: Bool = false
    
    // Warmup timer properties
    @Published var warmupTimeRemaining: Int = 0
    @Published var isWarmupTimerActive: Bool = false
    @Published var isWarmupTimerPaused: Bool = true
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
    private var restStartTime: Date?
    private var initialRestDuration: Int = 0
    private var pausedElapsedTime: Int = 0
    private var appPhaseObserver: AnyCancellable?
    
    init() {
        // Request notification authorization with more options
        print("DEBUG: 🔔 Requesting notification authorization")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
            if granted {
                print("DEBUG: 🔔 Notification permission granted")
                
                // Immediately check and log current settings
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    print("DEBUG: 🔔 Initial notification settings:")
                    print("DEBUG: 🔔 - Authorization status: \(settings.authorizationStatus.rawValue)")
                    print("DEBUG: 🔔 - Alert setting: \(settings.alertSetting.rawValue)")
                    print("DEBUG: 🔔 - Sound setting: \(settings.soundSetting.rawValue)")
                    print("DEBUG: 🔔 - Badge setting: \(settings.badgeSetting.rawValue)")
                    print("DEBUG: 🔔 - Notification center setting: \(settings.notificationCenterSetting.rawValue)")
                }
                
                // Register notification categories
                let category = UNNotificationCategory(
                    identifier: "REST_TIMER",
                    actions: [],
                    intentIdentifiers: [],
                    options: .customDismissAction
                )
                
                UNUserNotificationCenter.current().setNotificationCategories([category])
                print("DEBUG: 🔔 Notification categories registered")
            } else if let error = error {
                print("DEBUG: 🔔 ❌ Notification permission error: \(error)")
            } else {
                print("DEBUG: 🔔 ❌ Notification permission denied")
            }
        }
        
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
        
        // Save rest timer state
        UserDefaults.standard.set(isRestTimerActive, forKey: "rest_timer_active")
        UserDefaults.standard.set(restTimeRemaining, forKey: "rest_time_remaining")
        UserDefaults.standard.set(initialRestDuration, forKey: "initial_rest_duration")
        
        if let restStart = restStartTime {
            UserDefaults.standard.set(restStart.timeIntervalSince1970, forKey: "rest_start_time")
        } else {
            UserDefaults.standard.removeObject(forKey: "rest_start_time")
        }
        
        print("DEBUG: Saved timer state: workout_active=\(isWorkoutTimerActive), rest_active=\(isRestTimerActive), rest_remaining=\(restTimeRemaining)")
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
            
            print("DEBUG: Restored workout timer state: active=\(isWorkoutTimerActive), pausedTime=\(pausedElapsedTime)")
        }
        
        // Restore rest timer state
        if UserDefaults.standard.bool(forKey: "rest_timer_active") {
            isRestTimerActive = true
            initialRestDuration = UserDefaults.standard.integer(forKey: "initial_rest_duration")
            
            // Restore start time and calculate remaining time
            if let restStartInterval = UserDefaults.standard.object(forKey: "rest_start_time") as? TimeInterval {
                restStartTime = Date(timeIntervalSince1970: restStartInterval)
                let elapsedTime = Int(Date().timeIntervalSince(restStartTime!))
                restTimeRemaining = max(0, initialRestDuration - elapsedTime)
                
                // Only restart timer if there's time remaining
                if restTimeRemaining > 0 {
                    restTimer = Timer.publish(every: 1, on: .main, in: .common)
                        .autoconnect()
                        .sink { [weak self] _ in
                            guard let self = self else { return }
                            if self.restTimeRemaining > 0 {
                                self.restTimeRemaining -= 1
                                if self.restTimeRemaining % 10 == 0 {
                                    print("DEBUG: ⏱️ Rest timer remaining: \(self.restTimeRemaining)s")
                                }
                            } else {
                                print("DEBUG: 🔔 Rest timer completed")
                                self.stopRestTimer()
                            }
                        }
                    
                    print("DEBUG: Restored rest timer state: active=true, remaining=\(restTimeRemaining)s")
                } else {
                    // Timer should have completed while in background
                    print("DEBUG: Rest timer would have completed in background, stopping")
                    stopRestTimer()
                }
            }
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
        print("DEBUG: 📱 App transitioning to background")
        print("DEBUG: 📱 Timer states - Rest timer active: \(isRestTimerActive), Workout timer active: \(isWorkoutTimerActive)")
        saveTimerState()
        
        // If rest timer is active, ensure notification is scheduled
        if isRestTimerActive {
            print("DEBUG: 📱 Rest timer is active, scheduling notification before background")
            print("DEBUG: 📱 Rest timer remaining time: \(restTimeRemaining)s")
            scheduleRestTimerNotification()
        } else {
            print("DEBUG: 📱 Rest timer not active, no notification needed")
        }
    }
    
    // MARK: - Rest Timer Methods
    func startRestTimer(duration: Int? = nil) {
        print("DEBUG: 🔔 Starting rest timer with duration \(duration ?? restDuration)s")
        initialRestDuration = duration ?? restDuration
        restTimeRemaining = initialRestDuration
        restStartTime = Date()
        isRestTimerActive = true
        print("DEBUG: 🔔 Rest timer active state set to: \(isRestTimerActive)")
        
        // Schedule local notification for rest timer completion
        scheduleRestTimerNotification()
        
        restTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.restTimeRemaining > 0 {
                    self.restTimeRemaining -= 1
                    
                    // Log remaining time at intervals
                    if self.restTimeRemaining % 10 == 0 {
                        print("DEBUG: ⏱️ Rest timer remaining: \(self.restTimeRemaining)s")
                    }
                } else {
                    print("DEBUG: 🔔 Rest timer completed naturally")
                    self.stopRestTimer()
                }
            }
        
        // Save state immediately when starting
        saveTimerState()
    }
    
    func stopRestTimer() {
        print("DEBUG: 🔔 Stopping rest timer")
        print("DEBUG: 🔔 Current state - remaining: \(restTimeRemaining)s, active: \(isRestTimerActive)")
        
        // Remove pending notifications when timer is stopped
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["restTimer"])
        print("DEBUG: 🔔 Removed pending notifications")
        
        restTimer?.cancel()
        restTimer = nil
        isRestTimerActive = false
        restTimeRemaining = 0
        restStartTime = nil
        initialRestDuration = 0
        print("DEBUG: 🔔 Rest timer stopped - active: \(isRestTimerActive)")
        
        // Post notification that rest timer is complete
        NotificationCenter.default.post(name: NSNotification.Name("RestTimerComplete"), object: nil)
        
        // Save state immediately when stopping
        saveTimerState()
    }
    
    private func scheduleRestTimerNotification() {
        print("DEBUG: 🔔 Beginning notification scheduling process")
        
        // Remove any existing notifications first
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["restTimer"])
        print("DEBUG: 🔔 Removed existing pending notifications")
        
        let content = UNMutableNotificationContent()
        content.title = "Rest Timer Complete"
        content.body = "Time to start your next set!"
        content.sound = .default
        content.categoryIdentifier = "REST_TIMER"
        
        // Calculate time remaining based on start time if available, otherwise use restTimeRemaining
        let timeRemaining: TimeInterval
        if let startTime = restStartTime {
            timeRemaining = TimeInterval(max(0, initialRestDuration - Int(Date().timeIntervalSince(startTime))))
            print("DEBUG: 🔔 Calculated remaining time from start time: \(timeRemaining)s")
        } else {
            timeRemaining = TimeInterval(restTimeRemaining)
            print("DEBUG: 🔔 Using direct remaining time: \(timeRemaining)s")
        }
        
        print("DEBUG: 🔔 Scheduling notification for \(timeRemaining) seconds from now")
        print("DEBUG: 🔔 Initial duration was: \(initialRestDuration)s")
        
        // Only schedule if we have time remaining
        guard timeRemaining > 0 else {
            print("DEBUG: 🔔 No time remaining, skipping notification scheduling")
            return
        }
        
        // Schedule notification to fire when rest timer completes
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeRemaining, repeats: false)
        let request = UNNotificationRequest(identifier: "restTimer", content: content, trigger: trigger)
        
        // Check current notification settings before scheduling
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("DEBUG: 🔔 Pre-schedule notification settings check:")
            print("DEBUG: 🔔 - Authorization status: \(settings.authorizationStatus.rawValue)")
            print("DEBUG: 🔔 - Alert setting: \(settings.alertSetting.rawValue)")
            print("DEBUG: 🔔 - Sound setting: \(settings.soundSetting.rawValue)")
            print("DEBUG: 🔔 - Notification center setting: \(settings.notificationCenterSetting.rawValue)")
            
            if settings.authorizationStatus == .authorized {
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("DEBUG: 🔔 ❌ Error scheduling notification: \(error)")
                    } else {
                        print("DEBUG: 🔔 ✅ Notification scheduled successfully")
                        
                        // Verify the scheduled notification
                        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                            print("DEBUG: 🔔 Pending notifications after scheduling: \(requests.count)")
                            for request in requests {
                                if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                                    print("DEBUG: 🔔 Pending notification details:")
                                    print("DEBUG: 🔔 - Identifier: \(request.identifier)")
                                    print("DEBUG: 🔔 - Time interval: \(trigger.timeInterval)s")
                                    print("DEBUG: 🔔 - Next trigger date: \(trigger.nextTriggerDate()?.description ?? "unknown")")
                                }
                            }
                        }
                    }
                }
            } else {
                print("DEBUG: 🔔 ❌ Cannot schedule notification - not authorized (status: \(settings.authorizationStatus.rawValue))")
            }
        }
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
        isWarmupTimerActive = true
        isWarmupTimerPaused = true
        print("DEBUG: ⏱️ First warmup '\(warmups[0])' ready to start with duration: \(warmupTimeRemaining)s")
    }
    
    func startCurrentWarmup() {
        guard isWarmupTimerActive && isWarmupTimerPaused else { return }
        
        isWarmupTimerPaused = false
        print("DEBUG: ⏱️ Starting warmup timer for '\(currentWarmupName ?? "unknown")'")
        
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
        warmupTimer?.cancel()
        warmupTimer = nil
        currentWarmupIndex += 1
        
        if currentWarmupIndex < warmups.count {
            // Move to the next warmup with its duration
            warmupTimeRemaining = warmupDurations[currentWarmupIndex]
            isWarmupTimerPaused = true
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