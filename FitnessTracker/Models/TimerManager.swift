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
import AVFoundation
import ActivityKit

class TimerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
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
    
    // Default rest timer duration (1:00 = 60 seconds)
    let restDuration: Int = 60
    // Default warmup timer duration (15 seconds)
    let defaultWarmupDuration: Int = 15
    
    private var workoutTimer: AnyCancellable?
    private var restTimer: AnyCancellable?
    private var warmupTimer: AnyCancellable?
    private var workoutStartTime: Date?
    private var restStartTime: Date?
    private var warmupStartTime: Date?   // Tracks when the current warmup step began
    private var initialRestDuration: Int = 0
    private var pausedElapsedTime: Int = 0
    private var appPhaseObserver: AnyCancellable?
    private var audioPlayer: AVAudioPlayer?

    // Live Activity handles
    private var restTimerActivity: Activity<FitnessTimerAttributes>?
    private var warmupTimerActivity: Activity<FitnessTimerAttributes>?
    
    override init() {
        super.init()
        // Request notification authorization with more options
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
            if granted {
                // Notification permission granted
                
                // Register notification categories
                let category = UNNotificationCategory(
                    identifier: "REST_TIMER",
                    actions: [],
                    intentIdentifiers: [],
                    options: .customDismissAction
                )
                
                UNUserNotificationCenter.current().setNotificationCategories([category])
                // Notification categories registered
            } else {
                // Notification permission denied or error
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

        // BATTERY OPTIMIZATION: Changed from 0.5s to 1s
        // For a 1-hour workout, this reduces timer firings from 7,200 to 3,600 (50% reduction)
        // Users don't need sub-second precision for workout duration
        workoutTimer = Timer.publish(every: 1.0, on: .main, in: .common)
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

        // BATTERY OPTIMIZATION: Changed from 0.5s to 1s (same as startWorkoutTimer)
        workoutTimer = Timer.publish(every: 1.0, on: .main, in: .common)
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
    
    // MARK: - Audio

    private func playTimerChime() {
        guard let url = Bundle.main.url(forResource: "FitnessTracker_Timer_chime_01", withExtension: "wav") else {
            print("DEBUG: 🔔 FitnessTracker_Timer_chime_01.wav not found in bundle")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [])
            try session.setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("DEBUG: 🔔 Failed to play timer chime: \(error)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("DEBUG: 🔔 Failed to deactivate audio session: \(error)")
        }
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
                // BATTERY OPTIMIZATION: Changed from 0.5s to 1s
                workoutTimer = Timer.publish(every: 1.0, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self = self else { return }
                        self.updateWorkoutElapsedTime()
                    }
                
                // Update elapsed time immediately
                updateWorkoutElapsedTime()
            }
            
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
                            } else {
                                self.handleRestTimerCompletion()
                            }
                        }
                    
                } else {
                    // Timer should have completed while in background
                    stopRestTimer()
                }
            }
        }
    }
    
    // Method to handle app coming back to foreground
    func handleAppBecameActive() {
        print("DEBUG: TimerManager - App became active")

        // Restore workout/rest timer state (handles app-kill + relaunch)
        restoreTimerStateIfNeeded()

        // Update workout timer if active
        if isWorkoutTimerActive, workoutStartTime != nil {
            updateWorkoutElapsedTime()
            print("DEBUG: TimerManager - Updated elapsed time to \(workoutElapsedSeconds)")
        }

        // Recalculate rest timer if active (handles sleep/background cases)
        if isRestTimerActive, let startTime = restStartTime {
            let elapsedTime = Int(Date().timeIntervalSince(startTime))
            let newTimeRemaining = max(0, initialRestDuration - elapsedTime)
            print("DEBUG: ⏱️ Recalculating rest timer: elapsed=\(elapsedTime)s, remaining=\(newTimeRemaining)s")
            if newTimeRemaining > 0 {
                restTimeRemaining = newTimeRemaining
            } else {
                print("DEBUG: ⏱️ Rest timer completed while app was inactive")
                handleRestTimerCompletion()
            }
        }

        // Recalculate warmup timer if it was running before backgrounding
        recalculateWarmupIfNeeded()
    }

    // Method to handle app going to background
    func handleAppWentToBackground() {
        print("DEBUG: 📱 App transitioning to background")
        print("DEBUG: 📱 Timer states - Rest: \(isRestTimerActive), Workout: \(isWorkoutTimerActive), Warmup: \(isWarmupTimerActive)")
        saveTimerState()

        if isRestTimerActive {
            print("DEBUG: 📱 Rest timer active — scheduling background notification")
            scheduleRestTimerNotification()
        }

        if isWarmupTimerActive && !isWarmupTimerPaused {
            print("DEBUG: 📱 Warmup timer active — scheduling background notification")
            scheduleWarmupCompletionNotification()
        }
    }

    /// Recalculates warmup progress after the app returns from background.
    /// Uses the in-memory `warmupStartTime` that was set when the current step began.
    private func recalculateWarmupIfNeeded() {
        guard isWarmupTimerActive, !isWarmupTimerPaused, let startTime = warmupStartTime else { return }

        // Cancel the paused in-app timer so we can restart it from the right position
        warmupTimer?.cancel()
        warmupTimer = nil

        var elapsedSinceStepStart = Int(Date().timeIntervalSince(startTime))
        var stepIndex = currentWarmupIndex

        // Advance through any steps that finished while the app was backgrounded
        while stepIndex < warmups.count {
            let stepDuration = warmupDurations[stepIndex]
            if elapsedSinceStepStart < stepDuration {
                // Still inside this step — update state and restart
                currentWarmupIndex = stepIndex
                warmupTimeRemaining = stepDuration - elapsedSinceStepStart
                warmupStartTime = Date().addingTimeInterval(-TimeInterval(elapsedSinceStepStart))
                print("DEBUG: ⏱️ Warmup resumed at step \(stepIndex), \(warmupTimeRemaining)s remaining")

                // Update Live Activity with new end time
                updateWarmupLiveActivity()

                // Restart the in-app countdown
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
                return
            }
            // This step is done — advance
            elapsedSinceStepStart -= stepDuration
            stepIndex += 1
        }

        // All steps completed while in background
        print("DEBUG: ⏱️ All warmup steps completed while in background")
        stopWarmupTimer()
    }
    
    // MARK: - Rest Timer Methods
    func startRestTimer(duration: Int? = nil) {
        // Clean up any existing timer first to ensure fresh start
        if isRestTimerActive {
            stopRestTimer(manualStop: true)
        }

        initialRestDuration = duration ?? restDuration
        restTimeRemaining = initialRestDuration
        restStartTime = Date()
        isRestTimerActive = true

        print("DEBUG: ⏱️ Starting rest timer: duration=\(initialRestDuration)s, startTime=\(restStartTime!)")

        // Schedule local notification for rest timer completion
        scheduleRestTimerNotification()

        // Start Live Activity
        startRestTimerLiveActivity(duration: initialRestDuration)

        restTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.restTimeRemaining > 0 {
                    self.restTimeRemaining -= 1
                } else {
                    self.handleRestTimerCompletion()
                }
            }

        // Save state immediately when starting
        saveTimerState()
    }
    
    private func handleRestTimerCompletion() {
        playTimerChime()

        // Check if app is active to show in-app notification
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            
            // App is active, show in-app alert
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Rest Timer Complete",
                    message: "Time to start your next set!",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                })
                
                window.rootViewController?.present(alert, animated: true)
            }
        }
        
        // Always stop the timer after handling completion
        stopRestTimer()
    }
    
    func stopRestTimer(manualStop: Bool = false) {
        print("DEBUG: ⏱️ Stopping rest timer: manualStop=\(manualStop), wasActive=\(isRestTimerActive)")

        // Remove pending notifications when timer is stopped
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["restTimer"])

        restTimer?.cancel()
        restTimer = nil
        isRestTimerActive = false
        restTimeRemaining = 0
        restStartTime = nil
        initialRestDuration = 0

        // End Live Activity
        endRestTimerLiveActivity()

        // Post notification that rest timer is complete with manual stop flag
        NotificationCenter.default.post(
            name: NSNotification.Name("RestTimerComplete"),
            object: nil,
            userInfo: ["manualStop": manualStop]
        )

        print("DEBUG: ⏱️ Posted RestTimerComplete notification with manualStop=\(manualStop)")

        // Save state immediately when stopping
        saveTimerState()
    }
    
    private func scheduleRestTimerNotification() {
        
        // Remove any existing notifications first
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["restTimer"])
        
        let content = UNMutableNotificationContent()
        content.title = "Rest Timer Complete"
        content.body = "Time to start your next set!"
        content.sound = .default
        content.categoryIdentifier = "REST_TIMER"
        
        // Calculate time remaining based on start time if available, otherwise use restTimeRemaining
        let timeRemaining: TimeInterval
        if let startTime = restStartTime {
            timeRemaining = TimeInterval(max(0, initialRestDuration - Int(Date().timeIntervalSince(startTime))))
        } else {
            timeRemaining = TimeInterval(restTimeRemaining)
        }
        
        
        // Only schedule if we have time remaining
        guard timeRemaining > 0 else {
            return
        }
        
        // Schedule notification to fire when rest timer completes
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeRemaining, repeats: false)
        let request = UNNotificationRequest(identifier: "restTimer", content: content, trigger: trigger)
        
        // Check current notification settings before scheduling
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            
            if settings.authorizationStatus == .authorized {
                UNUserNotificationCenter.current().add(request) { error in
                    if error != nil {
                        // Error scheduling notification
                    } else {
                        // Notification scheduled successfully
                        
                        // Verify the scheduled notification
                        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                            for request in requests {
                                if request.trigger is UNTimeIntervalNotificationTrigger {
                                }
                            }
                        }
                    }
                }
            } else {
            }
        }
    }
    
    // MARK: - Warmup Timer Methods
    func startWarmupTimer(warmups: [String], durations: [Int] = []) {
        print("DEBUG: 🟢 startWarmupTimer() called with \(warmups.count) warmups: \(warmups)")
        DispatchQueue.main.async {
            self.warmups = warmups
            print("DEBUG: 🟢 TimerManager.warmups set to: \(self.warmups) on main thread")
            
            if warmups.isEmpty {
                print("DEBUG: ⏱️ Starting warmup timer with no warmups (empty state)")
                self.warmupDurations = []
                self.currentWarmupIndex = 0
                self.warmupTimeRemaining = 0
                self.isWarmupTimerActive = true
                self.isWarmupTimerPaused = true
                return
            }
            
            print("DEBUG: ⏱️ Starting warmup timer with \(warmups.count) warmups")
            print("DEBUG: ⏱️ Provided durations: \(durations)")
            
            // Store the durations, or use defaults if none provided
            if durations.isEmpty || durations.count != warmups.count {
                print("DEBUG: ⏱️ Using default durations because: isEmpty=\(durations.isEmpty), count mismatch=\(durations.count != warmups.count)")
                self.warmupDurations = Array(repeating: self.defaultWarmupDuration, count: warmups.count)
            } else {
                print("DEBUG: ⏱️ Using custom durations: \(durations)")
                self.warmupDurations = durations
            }
            
            self.currentWarmupIndex = 0
            self.warmupTimeRemaining = self.warmupDurations[0]
            self.isWarmupTimerActive = true
            self.isWarmupTimerPaused = true
            print("DEBUG: ⏱️ First warmup '\(warmups[0])' ready to start with duration: \(self.warmupTimeRemaining)s")
        }
    }
    
    func startCurrentWarmup() {
        guard isWarmupTimerActive && isWarmupTimerPaused else { return }

        isWarmupTimerPaused = false
        warmupStartTime = Date()
        print("DEBUG: ⏱️ Starting warmup timer for '\(currentWarmupName ?? "unknown")'")

        // Start Live Activity for this warmup step
        startWarmupLiveActivity()

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
        warmupStartTime = nil
        playTimerChime()
        currentWarmupIndex += 1

        if currentWarmupIndex < warmups.count {
            warmupTimeRemaining = warmupDurations[currentWarmupIndex]
            isWarmupTimerPaused = true
            print("DEBUG: ⏱️ Moving to next warmup '\(warmups[currentWarmupIndex])' with duration: \(warmupTimeRemaining)s")
            // End the Live Activity — it will restart when user taps Start for the next step
            endWarmupLiveActivity()
        } else {
            print("DEBUG: ⏱️ All warmups completed")
            stopWarmupTimer()
        }
    }
    
    func stopWarmupTimer() {
        print("DEBUG: 🛑 stopWarmupTimer() called - clearing \(warmups.count) warmups")
        print("DEBUG: 🛑 Current warmups before clearing: \(warmups)")

        warmupTimer?.cancel()
        warmupTimer = nil
        warmupStartTime = nil
        isWarmupTimerActive = false
        warmupTimeRemaining = 0
        currentWarmupIndex = 0

        // Cancel background notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["warmupTimer"])

        // End Live Activity
        endWarmupLiveActivity()

        // Post notification that warmup timer is complete
        NotificationCenter.default.post(name: NSNotification.Name("WarmupTimerComplete"), object: nil)

        warmups = []
        warmupDurations = []
        print("DEBUG: 🛑 Warmups cleared, new count: \(warmups.count)")
    }
    
    var currentWarmupName: String? {
        guard !warmups.isEmpty && currentWarmupIndex < warmups.count else { return nil }
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
    
    // MARK: - Warmup Background Notification

    private func scheduleWarmupCompletionNotification() {
        guard let startTime = warmupStartTime, currentWarmupIndex < warmupDurations.count else { return }

        // Fire when the CURRENT step ends — same pattern as the rest timer.
        // The user can tap the notification to return to the app and start the next step.
        let elapsedInCurrentStep = Int(Date().timeIntervalSince(startTime))
        let remainingInCurrentStep = max(0, warmupDurations[currentWarmupIndex] - elapsedInCurrentStep)

        guard remainingInCurrentStep > 0 else { return }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["warmupTimer"])

        let content = UNMutableNotificationContent()
        let isLastStep = currentWarmupIndex == warmups.count - 1
        if isLastStep {
            content.title = "Warmup Complete"
            content.body = "Time to start your workout!"
        } else {
            let nextStepName = warmups[currentWarmupIndex + 1]
            content.title = "Warmup Step Complete"
            content.body = "Tap to start \(nextStepName)."
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(remainingInCurrentStep), repeats: false)
        let request = UNNotificationRequest(identifier: "warmupTimer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("DEBUG: ⏱️ Failed to schedule warmup notification: \(error)")
            }
        }
    }

    // MARK: - Live Activities

    private func startRestTimerLiveActivity(duration: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let endTime = Date().addingTimeInterval(TimeInterval(duration))
        let attributes = FitnessTimerAttributes(timerType: .rest)
        let state = FitnessTimerAttributes.ContentState(
            endTime: endTime,
            label: "Rest Timer",
            stepIndex: 1,
            totalSteps: 1
        )
        do {
            restTimerActivity = try Activity<FitnessTimerAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endTime.addingTimeInterval(5))
            )
            print("DEBUG: 🟢 Rest timer Live Activity started")
        } catch {
            print("DEBUG: 🔴 Failed to start rest timer Live Activity: \(error)")
        }
    }

    private func endRestTimerLiveActivity() {
        Task {
            await restTimerActivity?.end(nil, dismissalPolicy: .immediate)
            restTimerActivity = nil
        }
    }

    private func startWarmupLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard currentWarmupIndex < warmups.count else { return }

        // End any existing warmup activity before starting a new one
        Task { await warmupTimerActivity?.end(nil, dismissalPolicy: .immediate) }

        let endTime = Date().addingTimeInterval(TimeInterval(warmupTimeRemaining))
        let attributes = FitnessTimerAttributes(timerType: .warmup)
        let state = FitnessTimerAttributes.ContentState(
            endTime: endTime,
            label: warmups[currentWarmupIndex],
            stepIndex: currentWarmupIndex + 1,
            totalSteps: warmups.count
        )
        do {
            warmupTimerActivity = try Activity<FitnessTimerAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endTime.addingTimeInterval(5))
            )
            print("DEBUG: 🟢 Warmup Live Activity started for '\(warmups[currentWarmupIndex])'")
        } catch {
            print("DEBUG: 🔴 Failed to start warmup Live Activity: \(error)")
        }
    }

    private func updateWarmupLiveActivity() {
        guard let activity = warmupTimerActivity else { return }
        guard currentWarmupIndex < warmups.count else { return }

        let endTime = Date().addingTimeInterval(TimeInterval(warmupTimeRemaining))
        let state = FitnessTimerAttributes.ContentState(
            endTime: endTime,
            label: warmups[currentWarmupIndex],
            stepIndex: currentWarmupIndex + 1,
            totalSteps: warmups.count
        )
        Task {
            await activity.update(.init(state: state, staleDate: endTime.addingTimeInterval(5)))
        }
    }

    private func endWarmupLiveActivity() {
        Task {
            await warmupTimerActivity?.end(nil, dismissalPolicy: .immediate)
            warmupTimerActivity = nil
        }
    }

    // MARK: - Cleanup
    deinit {
        workoutTimer?.cancel()
        restTimer?.cancel()
        warmupTimer?.cancel()
        appPhaseObserver?.cancel()
    }
}