import SwiftUI
import CoreData
import Combine

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    
    @ObservedObject var workoutManager: WorkoutManager
    @StateObject var timerManager = TimerManager()
    
    let workout: NSManagedObject
    
    @State private var showingAddExercise = false
    @State private var showingCancelAlert = false
    @State private var showingCompletionAlert = false
    @State private var showingCompletedWorkoutDetails = false
    @State private var isEditing = false
    @State private var isTemplateView: Bool
    @State private var editedTemplateName: String = ""
    
    @State private var setValues: [String: (reps: Int16, weight: Double)] = [:]
    @State private var showingRestTimer = false

    // Warmup states
    @State private var isShowingWarmupTimer = false
    @State private var warmups: [String] = []
    @State private var warmupDurations: [Int] = []
    @State private var warmupsLoaded = false
    @State private var hasLoggedOnAppear = false
    @State private var hasLoggedMainWorkoutAppear = false
    @State private var hasLoggedWarmupTimerAppear = false
    @State private var hasLoggedNotification = false
    @State private var hasLoggedWorkoutTimer = false
    @State private var hasLoggedWarmupStart = false
    @State private var hasLoggedWarmupLoading = false
    @AppStorage("siriShortcutsEnabled") private var siriShortcutsEnabled = true
    @AppStorage("showWorkoutDetailsAfterCompletion") private var showWorkoutDetailsAfterCompletion = false
    
    init(workout: NSManagedObject, workoutManager: WorkoutManager) {
        
        self.workout = workout
        self._workoutManager = ObservedObject(wrappedValue: workoutManager)
        
        let isTemplate = workout.entity.name == "WorkoutTemplate"
        self._isTemplateView = State(initialValue: isTemplate)
        
        if isTemplate {
            self._editedTemplateName = State(initialValue: workout.value(forKey: "name") as? String ?? "Untitled")
        } else {
            if workout.entity.relationshipsByName["template"] != nil && workout.value(forKey: "template") != nil {
                if let template = workout.value(forKey: "template") as? NSManagedObject {
                    self._editedTemplateName = State(initialValue: template.value(forKey: "name") as? String ?? "Workout")
                } else {
                    self._editedTemplateName = State(initialValue: "Workout")
                }
            } else {
                self._editedTemplateName = State(initialValue: "Workout")
            }
        }
    }
    
    private var templateName: String {
        switch workout.entity.name {
        case "Workout":
            if let workoutObj = workout as? Workout {
                return workoutObj.templateName
            }
            if workout.entity.relationshipsByName["template"] != nil {
                if let template = workout.value(forKey: "template") as? NSManagedObject {
                    return template.value(forKey: "name") as? String ?? "Workout"
                }
            }
        case "WorkoutTemplate":
            if let templateObj = workout as? WorkoutTemplate {
                return templateObj.templateName
            }
            return workout.value(forKey: "name") as? String ?? "Workout"
        default:
            break
        }
        return "Workout"
    }
    
    private var exercises: [NSManagedObject] {
        switch workout.entity.name {
        case "Workout":
            if let workoutObj = workout as? Workout {
                return workoutObj.exerciseArray
            }
            if let exercisesSet = workout.value(forKey: "exercises") as? NSSet {
                let exercises = exercisesSet.allObjects as? [NSManagedObject] ?? []
                return exercises.sorted {
                    let order1 = $0.value(forKey: "order") as? Int16 ?? 0
                    let order2 = $1.value(forKey: "order") as? Int16 ?? 0
                    return order1 < order2
                }
            }
        case "WorkoutTemplate":
            if let templateObj = workout as? WorkoutTemplate {
                return templateObj.exerciseArray
            }
            if let exercisesSet = workout.value(forKey: "exercises") as? NSSet {
                let exercises = exercisesSet.allObjects as? [NSManagedObject] ?? []
                return exercises.sorted {
                    let order1 = $0.value(forKey: "order") as? Int16 ?? 0
                    let order2 = $1.value(forKey: "order") as? Int16 ?? 0
                    return order1 < order2
                }
            }
        default:
            break
        }
        return []
    }
    
    @ViewBuilder
    private func timerHeader() -> some View {
        if !isTemplateView {
            VStack(spacing: 8) {
                Text("\(timerManager.formattedWorkoutTime)")
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    Button {
                        let _ = timerManager.stopWorkoutTimer()
                        timerManager.startWorkoutTimer()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                    }
                    .disabled(timerManager.workoutElapsedSeconds == 0)
                    
                    Button {
                        if timerManager.isWorkoutTimerActive {
                            timerManager.pauseWorkoutTimer()
                        } else {
                            if timerManager.workoutElapsedSeconds == 0 {
                                timerManager.startWorkoutTimer()
                            } else {
                                timerManager.resumeWorkoutTimer()
                            }
                        }
                    } label: {
                        Image(systemName: timerManager.isWorkoutTimerActive ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    @ViewBuilder
    private func exerciseList() -> some View {
        LazyVStack(spacing: 20) {
            if isTemplateView && isEditing {
                TextField("Template Name", text: $editedTemplateName)
                    .font(.title2.bold())
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            
            ForEach(exercises, id: \.objectID) { exercise in
                ExerciseCard(
                    exercise: exercise,
                    workoutManager: workoutManager,
                    timerManager: timerManager,
                    setValues: $setValues,
                    showingRestTimer: $showingRestTimer,
                    isTemplateView: isTemplateView,
                    isEditing: isEditing,
                    onDelete: isEditing ? { deleteExercise(exercise) } : nil
                )
                .padding(.horizontal)
            }
            
            if (isTemplateView && isEditing) || (!isTemplateView && workout.entity.name == "Workout") {
                Button {
                    showingAddExercise = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Exercise")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal)
                .padding(.top, 10)
            }
        }
        .padding(.vertical)
    }
    
    @ViewBuilder
    private func workoutControls() -> some View {
        if !isTemplateView {
            HStack {
                Button {
                    showingCancelAlert = true
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button {
                    showingCompletionAlert = true
                } label: {
                    Text("Finish Workout")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            )
        }
    }
    
    var body: some View {
        ZStack {
            if isShowingWarmupTimer {
                WarmupTimerView(timerManager: timerManager)
                    .onAppear {
                        if !hasLoggedWarmupTimerAppear {
                            print("DEBUG: 🎯 WarmupTimerView appeared")
                            hasLoggedWarmupTimerAppear = true
                        }
                    }
            } else {
                mainWorkoutView
                    .onAppear {
                        if !hasLoggedMainWorkoutAppear {
                            print("DEBUG: 🎯 mainWorkoutView appeared")
                            hasLoggedMainWorkoutAppear = true
                        }
                    }
            }
        }
        .onAppear {
            if !hasLoggedOnAppear {
                print("DEBUG: 🚀 WorkoutView.onAppear called for \(isTemplateView ? "template" : "workout")")
                print("DEBUG: 🚀 warmupsLoaded: \(warmupsLoaded), isTemplateView: \(isTemplateView)")
                hasLoggedOnAppear = true
            }
            // Load warmups when the view appears for actual workouts
            if !isTemplateView && !warmupsLoaded {
                if !hasLoggedOnAppear {
                    print("DEBUG: 🚀 About to call loadWarmupsAndStartTimerIfNeeded from onAppear")
                }
                loadWarmupsAndStartTimerIfNeeded()
                warmupsLoaded = true

                if siriShortcutsEnabled && !isTemplateView {
                    SiriShortcutsManager.shared.executeBackgroundShortcut(for: templateName)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartWorkoutFromTemplate"))) { notification in
            if !hasLoggedNotification {
                print("DEBUG: 🎯 Received StartWorkoutFromTemplate notification")
                hasLoggedNotification = true
            }
            
            print("DEBUG: 🎤 StartWorkoutFromTemplate - isTemplateView: \(isTemplateView), templateName: '\(templateName)'")

            if siriShortcutsEnabled && !isTemplateView {
                SiriShortcutsManager.shared.executeBackgroundShortcut(for: templateName)
            }
            
            if !isTemplateView && !warmupsLoaded {
                if !hasLoggedNotification {
                    print("DEBUG: 🎯 About to call loadWarmupsAndStartTimerIfNeeded from notification")
                }
                loadWarmupsAndStartTimerIfNeeded()
                warmupsLoaded = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SiriStartWorkout"))) { notification in
            // Handle Siri-initiated workout starts
            if let templateName = notification.userInfo?["templateName"] as? String {
                print("DEBUG: 🎤 Received Siri start workout request for: \(templateName)")
                // Find matching template and start workout
                startWorkoutFromSiri(templateName: templateName)
            }
        }
        // Single, leak-free observer replacing the two addObserver calls in loadWarmupsAndStartTimerIfNeeded.
        // onReceive auto-cancels when the view disappears, so it never accumulates.
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WarmupTimerComplete"))) { _ in
            guard !isTemplateView else { return }
            print("DEBUG: 🏃‍♂️ Warmup complete, starting workout timer")
            isShowingWarmupTimer = false
            timerManager.startWorkoutTimer()
        }
        // NOTE: TimerManager already subscribes to .appScenePhaseChanged (posted by
        // FitnessTrackerApp) and calls handleAppBecameActive/WentToBackground itself.
        // Do NOT duplicate those calls here — it causes double timer recalculations
        // and double UserDefaults writes on every app-foreground/background transition.
    }
    
    private var mainWorkoutView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                timerHeader()
                
                ScrollView {
                    exerciseList()
                    
                    if isTemplateView && !isEditing {
                        Button {
                            let newWorkout = workoutManager.startWorkout(from: workout)
                            dismiss()
                            NotificationCenter.default.post(
                                name: Notification.Name("StartWorkoutFromTemplate"),
                                object: nil,
                                userInfo: ["workout": newWorkout as Any]
                            )
                        } label: {
                            Text("Start Workout")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding()
                        .padding(.bottom, 40)
                    } else if !isTemplateView {
                        Spacer(minLength: 80)
                    }
                }
                
                workoutControls()
            }
            .navigationTitle(templateName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isTemplateView {
                        Button(isEditing ? "Cancel" : "Back") {
                            if isEditing {
                                isEditing = false
                                editedTemplateName = workout.value(forKey: "name") as? String ?? "Untitled"
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isTemplateView {
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                workoutManager.updateTemplate(workout, name: editedTemplateName)
                                isEditing = false
                            } else {
                                isEditing = true
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    if isTemplateView && isEditing {
                        Button("Reorder Exercises") {
                            print("DEBUG: Reorder exercises tapped")
                        }
                        .disabled(exercises.isEmpty)
                    } else {
                        Spacer()
                    }
                }
            }
            .sheet(isPresented: $showingRestTimer) {
                RestTimerView(showingRestTimer: $showingRestTimer)
                    .environmentObject(timerManager)
            }
            .alert("Cancel Workout", isPresented: $showingCancelAlert) {
                Button("Cancel Workout", role: .destructive) {
                    workoutManager.deleteWorkout(workout)
                    
                    if viewContext.hasChanges {
                        do {
                            try viewContext.save()
                            print("DEBUG: Saved context after deleting workout")
                        } catch {
                            print("DEBUG: Error saving context after deleting workout: \(error)")
                        }
                    }
                    
                    NotificationCenter.default.post(
                        name: Notification.Name("WorkoutWasDeleted"),
                        object: nil
                    )
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
                Button("Continue Workout", role: .cancel) {}
            } message: {
                Text("Are you sure you want to cancel this workout? All progress will be lost.")
            }
            .alert("Complete Workout", isPresented: $showingCompletionAlert) {
                Button("Complete", role: .none) {
                    let duration = timerManager.workoutElapsedSeconds
                    workoutManager.completeWorkout(workout, duration: duration)
                    if showWorkoutDetailsAfterCompletion {
                        showingCompletedWorkoutDetails = true
                    } else {
                        donateEndWorkoutShortcutIfEnabled()
                        dismiss()
                    }
                }
                Button("Continue Workout", role: .cancel) {}
            } message: {
                Text("Have you completed all your exercises? The workout will be saved to your history.")
            }
            .sheet(isPresented: $showingCompletedWorkoutDetails, onDismiss: {
                donateEndWorkoutShortcutIfEnabled()
                dismiss()
            }) {
                WorkoutDetailView(workout: workout)
            }
            .onAppear {
                if !isTemplateView && !isShowingWarmupTimer {
                    if !hasLoggedWorkoutTimer {
                        print("DEBUG: 🏃‍♂️ Starting workout timer (not in warmup mode)")
                        hasLoggedWorkoutTimer = true
                    }
                    timerManager.startWorkoutTimer()
                } else if isShowingWarmupTimer {
                    if !hasLoggedWorkoutTimer {
                        print("DEBUG: 🏃‍♂️ Skipping workout timer start - in warmup mode")
                        hasLoggedWorkoutTimer = true
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView { exerciseName in
                    if isTemplateView {
                        let _ = workoutManager.addExercise(to: workout, name: exerciseName)
                    } else {
                        addExerciseToWorkout(name: exerciseName)
                    }
                }
            }
        }
    }
    
    private func addExerciseToWorkout(name: String) {
        print("DEBUG: Adding exercise '\(name)' to workout")
        
        guard let entity = NSEntityDescription.entity(forEntityName: "WorkoutExercise", in: workout.managedObjectContext!) else {
            print("DEBUG: Failed to find WorkoutExercise entity")
            return
        }
        
        let exercises = self.exercises
        let highestOrder = exercises.isEmpty ? -1 : (exercises.last?.value(forKey: "order") as? Int16 ?? -1)
        
        let workoutExercise = NSManagedObject(entity: entity, insertInto: workout.managedObjectContext)
        workoutExercise.setValue(name, forKey: "name")
        workoutExercise.setValue(Int16(highestOrder + 1), forKey: "order")
        workoutExercise.setValue(workout, forKey: "workout")
        
        for i in 0..<3 {
            guard let setEntity = NSEntityDescription.entity(forEntityName: "ExerciseSet", in: workout.managedObjectContext!) else {
                print("DEBUG: Failed to find ExerciseSet entity")
                return
            }
            
            let exerciseSet = NSManagedObject(entity: setEntity, insertInto: workout.managedObjectContext)
            exerciseSet.setValue(Int16(i), forKey: "setNumber")
            exerciseSet.setValue(workoutExercise, forKey: "workoutExercise")
        }
        
        do {
            try workout.managedObjectContext?.save()
            print("DEBUG: Exercise added to workout successfully")
        } catch {
            print("DEBUG: Error adding exercise to workout: \(error)")
        }
    }
    
    private func deleteExercise(_ exercise: NSManagedObject) {
        workoutManager.deleteExercise(exercise)
    }

    private func donateEndWorkoutShortcutIfEnabled() {
        if siriShortcutsEnabled {
            SiriShortcutsManager.shared.executeEndWorkoutBackgroundShortcut(for: templateName)
        }
    }
    
    private func loadWarmupsAndStartTimerIfNeeded() {
        print("DEBUG: ===== WARMUP LOADING CALLED =====")
        if !isTemplateView {
            print("DEBUG: 🏋️‍♂️ Attempting to load warmups for workout")
            // Only show warmups when starting an actual workout (not when viewing a template)
            if let templateObj = workout.value(forKey: "template") as? NSManagedObject {
                print("DEBUG: 🏋️‍♂️ Found template object: \(templateObj.objectID)")
                print("DEBUG: 🏋️‍♂️ Template URI: \(templateObj.objectID.uriRepresentation().absoluteString)")
                print("DEBUG: 🏋️‍♂️ Template name: \(templateObj.value(forKey: "name") as? String ?? "unknown")")
                
                // Get warmups from the workout's template
                warmups = workoutManager.getWarmups(for: templateObj)
                warmupDurations = workoutManager.getWarmupDurations(for: templateObj)
                
                print("DEBUG: 🏋️‍♂️ Loaded \(warmups.count) warmups: \(warmups)")
                print("DEBUG: 🏋️‍♂️ Loaded \(warmupDurations.count) durations: \(warmupDurations)")
                
                // Ensure we have durations for each warmup
                if warmupDurations.count != warmups.count {
                    print("DEBUG: 🏋️‍♂️ Duration count mismatch! Creating default durations")
                    warmupDurations = Array(repeating: 15, count: warmups.count)
                }
                
                if !warmups.isEmpty {
                    if !hasLoggedWarmupLoading {
                        print("DEBUG: 🏋️‍♂️ Starting warmup timer with durations: \(warmupDurations)")
                        print("DEBUG: 🔍 WorkoutView TimerManager instance: \(ObjectIdentifier(timerManager))")
                        hasLoggedWarmupLoading = true
                    }
                    // Start warmup timer with loaded warmups and durations
                    timerManager.startWarmupTimer(warmups: warmups, durations: warmupDurations)
                    if !hasLoggedWarmupStart {
                        print("DEBUG: 🎯 Setting isShowingWarmupTimer = true")
                        isShowingWarmupTimer = true
                        print("DEBUG: 🎯 isShowingWarmupTimer set to: \(isShowingWarmupTimer)")
                        hasLoggedWarmupStart = true
                    } else {
                        isShowingWarmupTimer = true
                    }
                    
                } else {
                    print("DEBUG: 🏋️‍♂️ No warmups found, showing empty warmup screen for user awareness")
                    // Show warmup timer with empty warmups so user knows warmups are supported
                    timerManager.startWarmupTimer(warmups: [], durations: [])
                    isShowingWarmupTimer = true
                }
            } else {
                print("DEBUG: 🏋️‍♂️ No template found for this workout")
            }
        } else {
            print("DEBUG: 🏋️‍♂️ In template view mode, skipping warmups")
        }
    }
    
    private func startWorkoutFromSiri(templateName: String) {
        // This method would need access to WorkoutManager and template data
        // For now, we'll just handle the basic case
        print("DEBUG: 🎤 Starting workout from Siri for template: \(templateName)")
        
        // If this is a template view, we can start the workout directly
        if isTemplateView && workout.value(forKey: "name") as? String == templateName {
            let newWorkout = workoutManager.startWorkout(from: workout)
            dismiss()
            NotificationCenter.default.post(
                name: Notification.Name("StartWorkoutFromTemplate"),
                object: nil,
                userInfo: ["workout": newWorkout as Any]
            )
        }
    }
}

// MARK: - Exercise Card
struct ExerciseCard: View {
    let exercise: NSManagedObject
    let workoutManager: WorkoutManager
    let timerManager: TimerManager
    @Binding var setValues: [String: (reps: Int16, weight: Double)]
    @Binding var showingRestTimer: Bool

    var isTemplateView: Bool = false
    var isEditing: Bool = false
    var onDelete: (() -> Void)? = nil
    
    @State private var activeSetIndex: Int?
    @AppStorage("uniformWeightSuggestionEnabled") private var uniformWeightSuggestionEnabled = false
    @State private var uniformSuggestion: Double? = nil

    private var exerciseName: String {
        return exercise.value(forKey: "name") as? String ?? "Unknown Exercise"
    }
    
    private var sets: [NSManagedObject] {
        
        if isTemplateView || exercise.entity.name == "Exercise" {
            print("DEBUG: In template view mode, not showing sets")
            return []
        }
        
        if let setsSet = exercise.value(forKey: "sets") as? NSSet {
            let allSets = setsSet.allObjects as? [NSManagedObject] ?? []
            return allSets.sorted {
                let num1 = $0.value(forKey: "setNumber") as? Int16 ?? 0
                let num2 = $1.value(forKey: "setNumber") as? Int16 ?? 0
                return num1 < num2
            }
        }
        return []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exerciseName)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                if isTemplateView && isEditing && onDelete != nil {
                    Button {
                        onDelete?()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            
            if isTemplateView && isEditing {
                if let exerciseObj = exercise as? Exercise {
                    Stepper(
                        value: Binding(
                            get: { Int(exerciseObj.sets) },
                            set: {
                                exerciseObj.sets = Int16($0)
                                workoutManager.updateExercise(exercise, name: exerciseObj.name ?? "", sets: exerciseObj.sets)
                            }
                        ),
                        in: 1...10
                    ) {
                        Text("Sets: \(Int(exerciseObj.sets))")
                    }
                } else {
                    let setCount = exercise.value(forKey: "sets") as? Int16 ?? 3
                    Text("\(setCount) sets")
                        .foregroundColor(.secondary)
                }
            } else if !isTemplateView && exercise.entity.name != "Exercise" {
                VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: 12)
                            
                        Text("Set")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 55, alignment: .leading)
                        
                        Spacer()
                            .frame(width: 66)
                        
                        Text("Reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .center)
                        
                        Spacer()
                            .frame(width: 32)
                        
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .center)

                        Spacer()
                            .frame(width: 12)

                        Text("Heat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 36, alignment: .center)

                        Spacer()
                    }
                    
                    Divider()
                    
                    ForEach(Array(sets.enumerated()), id: \.element) { index, set in
                        SetRow(
                            set: set,
                            setNumber: index,
                            isActive: activeSetIndex == index,
                            setValues: $setValues,
                            showingRestTimer: $showingRestTimer,
                            activateNextSet: {
                                if index < sets.count - 1 {
                                    activeSetIndex = index + 1
                                } else {
                                    activeSetIndex = nil
                                }
                            },
                            workoutManager: workoutManager,
                            timerManager: timerManager,
                            uniformSuggestion: uniformSuggestion
                        )
                        
                        if index < sets.count - 1 {
                            Divider()
                        }
                    }
                    
                    if !isTemplateView && exercise.entity.name == "WorkoutExercise" {
                        Button {
                            print("DEBUG: Adding set to: \(type(of: exercise))")
                            _ = workoutManager.addSet(to: exercise)
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Set")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.top, 8)
                    } else if isTemplateView || exercise.entity.name == "Exercise" {
                        let setCount = exercise.value(forKey: "sets") as? Int16 ?? 3
                        Text("\(setCount) sets")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            } else {
                let setCount = exercise.value(forKey: "sets") as? Int16 ?? 3
                Text("\(setCount) sets")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            guard !isTemplateView, exercise.entity.name != "Exercise" else { return }
            if uniformWeightSuggestionEnabled {
                uniformSuggestion = workoutManager.getUniformWeightSuggestion(for: exercise)
            }
        }
        .onChange(of: uniformWeightSuggestionEnabled) { enabled in
            guard !isTemplateView, exercise.entity.name != "Exercise" else { return }
            uniformSuggestion = enabled ? workoutManager.getUniformWeightSuggestion(for: exercise) : nil
        }
    }
}

// MARK: - Set Row
struct SetRow: View {
    let set: NSManagedObject
    let setNumber: Int
    let isActive: Bool
    @Binding var setValues: [String: (reps: Int16, weight: Double)]
    @Binding var showingRestTimer: Bool
    let activateNextSet: () -> Void
    let workoutManager: WorkoutManager
    let timerManager: TimerManager
    var uniformSuggestion: Double? = nil

    @State private var showRestButton = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var previousSetData: (reps: Int16, weight: Double)? = nil
    @State private var heatRating: Int = 0          // 0 = unrated, 1-10 = effort level
    @State private var previousHeatRating: Int = 0  // last session's heat for this set
    @State private var showingHeatPicker = false

    private var setId: String {
        return set.objectID.uriRepresentation().absoluteString
    }

    private func heatColor(_ rating: Int) -> Color {
        switch rating {
        case 1...3: return .green
        case 4...6: return .orange
        case 7...8: return Color(red: 1.0, green: 0.4, blue: 0.0)
        default:    return .red
        }
    }

    // Heat scale reference:
    //   9 = barely completed all reps (TARGET — hold weight)
    //   8 = completed with difficulty (still below target → small increase)
    //   7 = moderate effort (below target → moderate increase)
    //  ≤6 = too easy → larger increases
    //  10 = couldn't complete all reps → hold weight (same as 9)
    @AppStorage("weightSuggestionEnabled") private var weightSuggestionEnabled = true

    private var suggestedWeight: Double? {
        guard weightSuggestionEnabled else { return nil }
        if let uniform = uniformSuggestion { return uniform }
        guard let prev = previousSetData, prev.weight > 0, previousHeatRating > 0 else { return nil }
        let multiplier: Double
        switch previousHeatRating {
        case 1...2: multiplier = 1.15   // very easy → +15%
        case 3...4: multiplier = 1.12   // easy → +12%
        case 5...6: multiplier = 1.08   // somewhat easy → +8%
        case 7:     multiplier = 1.05   // moderate, below target → +5%
        case 8:     multiplier = 1.03   // hard but below target → +3%
        case 9:     multiplier = 1.00   // target: barely completed → hold
        default:    multiplier = 1.00   // heat 10: couldn't finish all reps → hold weight
        }
        return ((prev.weight * multiplier) / 2.5).rounded() * 2.5
    }
    
    private var isSetComplete: Bool {
        get {
            if set.entity.propertiesByName["isComplete"] != nil {
                return set.value(forKey: "isComplete") as? Bool ?? false
            }
            return UserDefaults.standard.bool(forKey: "set_complete_\(setId)")
        }
        set {
            if set.entity.propertiesByName["isComplete"] != nil {
                set.setValue(newValue, forKey: "isComplete")
            } else {
                UserDefaults.standard.set(newValue, forKey: "set_complete_\(setId)")
            }
            do {
                try set.managedObjectContext?.save()
            } catch {
                print("DEBUG: Error saving set completion state: \(error)")
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text("Set \(setNumber + 1)")
                    .frame(width: 55, alignment: .leading)
                    .foregroundColor(isActive ? .primary : .secondary)
                
                // Remove the previous data display column but keep the previous data variable for use in text fields
                Spacer()
                    .frame(width: 50)
                
                ZStack(alignment: .center) {
                    // Use a space instead of "0" as placeholder when there's a previous value
                    let placeholder = (previousSetData?.reps ?? 0) > 0 ? " " : "0"
                    
                    TextField(placeholder, text: Binding(
                        get: {
                            if let values = setValues[setId] {
                                return values.reps > 0 ? "\(values.reps)" : ""
                            }
                            let reps = set.value(forKey: "reps") as? Int16 ?? 0
                            return reps > 0 ? "\(reps)" : ""
                        },
                        set: { newValue in
                            var values = setValues[setId] ?? (reps: 0, weight: 0.0)
                            values.reps = Int16(newValue) ?? 0
                            setValues[setId] = values
                            if let reps = Int16(newValue), reps >= 0 {
                                let weight = setValues[setId]?.weight ?? (set.value(forKey: "weight") as? Double ?? 0.0)
                                workoutManager.updateSet(set, reps: reps, weight: weight)
                            } else if newValue.isEmpty {
                                // Explicitly set to 0 when field is emptied
                                values.reps = 0
                                setValues[setId] = values
                                workoutManager.updateSet(set, reps: 0, weight: setValues[setId]?.weight ?? (set.value(forKey: "weight") as? Double ?? 0.0))
                            }
                        }
                    ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(
                        (setValues[setId]?.reps ?? 0) == 0 && (set.value(forKey: "reps") as? Int16 ?? 0) == 0
                            ? Color(.systemGray6).opacity(0.7)
                            : Color(.systemGray6)
                    )
                    .cornerRadius(8)
                    .frame(width: 60)
                    .focused($isTextFieldFocused)
                    .overlay {
                        if let previousData = previousSetData,
                           previousData.reps > 0,
                           (setValues[setId]?.reps ?? 0) == 0 && (set.value(forKey: "reps") as? Int16 ?? 0) == 0 {
                            Text("\(previousData.reps)")
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .font(.body.weight(.medium))
                        }
                    }
                }
                
                Text("×")
                    .foregroundColor(.secondary)
                
                ZStack(alignment: .center) {
                    // Use a space instead of "0" as placeholder when there's a previous value
                    let placeholder = (previousSetData?.weight ?? 0) > 0 ? " " : "0"
                    
                    TextField(placeholder, text: Binding(
                        get: {
                            if let values = setValues[setId] {
                                return values.weight > 0 ? "\(Int(values.weight))" : ""
                            }
                            let weight = set.value(forKey: "weight") as? Double ?? 0.0
                            return weight > 0 ? "\(Int(weight))" : ""
                        },
                        set: { newValue in
                            var values = setValues[setId] ?? (reps: 0, weight: 0.0)
                            values.weight = Double(newValue) ?? 0.0
                            setValues[setId] = values
                            if let weight = Double(newValue), weight >= 0 {
                                let reps = setValues[setId]?.reps ?? (set.value(forKey: "reps") as? Int16 ?? 0)
                                workoutManager.updateSet(set, reps: reps, weight: weight)
                            } else if newValue.isEmpty {
                                // Explicitly set to 0 when field is emptied
                                values.weight = 0.0
                                setValues[setId] = values
                                workoutManager.updateSet(set, reps: setValues[setId]?.reps ?? (set.value(forKey: "reps") as? Int16 ?? 0), weight: 0.0)
                            }
                        }
                    ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(
                        (setValues[setId]?.weight ?? 0) == 0 && (set.value(forKey: "weight") as? Double ?? 0.0) == 0
                            ? Color(.systemGray6).opacity(0.7)
                            : Color(.systemGray6)
                    )
                    .cornerRadius(8)
                    .frame(width: 60)
                    .focused($isTextFieldFocused)
                    .overlay {
                        if (setValues[setId]?.weight ?? 0) == 0 && (set.value(forKey: "weight") as? Double ?? 0.0) == 0 {
                            if let suggested = suggestedWeight {
                                Text("\(Int(suggested))")
                                    .foregroundColor(.orange.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .font(.body.weight(.medium))
                            } else if let previousData = previousSetData, previousData.weight > 0 {
                                Text("\(Int(previousData.weight))")
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .font(.body.weight(.medium))
                            }
                        }
                    }
                }
                
                Button {
                    showingHeatPicker.toggle()
                } label: {
                    if heatRating > 0 {
                        Text("\(heatRating)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(heatColor(heatRating))
                            .frame(width: 36, height: 32)
                            .background(heatColor(heatRating).opacity(0.12))
                            .cornerRadius(7)
                    } else {
                        Image(systemName: "flame")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary.opacity(0.4))
                            .frame(width: 36, height: 32)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    let newCompletionStatus = !isSetComplete
                    workoutManager.updateSetCompletion(set, isComplete: newCompletionStatus)
                    if newCompletionStatus && set.entity.name != "TemplateSet" {
                        showRestButton = true
                        activateNextSet()
                    } else {
                        showRestButton = false
                    }
                } label: {
                    Image(systemName: isSetComplete ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isActive ? .green : .secondary)
                        .font(.title2)
                }
                .disabled(
                    (setValues[setId]?.reps ?? 0) == 0 &&
                    (set.value(forKey: "reps") as? Int16 ?? 0) == 0
                )
            }
            .padding(.vertical, 6)
            .opacity(isActive ? 1.0 : 0.6)
            .onAppear {
                if let exerciseObj = set.value(forKey: "workoutExercise") as? NSManagedObject,
                   let exercise = exerciseObj.value(forKey: "exercise") as? NSManagedObject {
                    let setNum = set.value(forKey: "setNumber") as? Int16 ?? 0
                    print("DEBUG: Fetching previous data for exercise: \(exercise.value(forKey: "name") ?? "unknown"), set: \(setNum)")
                    previousSetData = workoutManager.getLastWorkoutSetData(for: exercise, setNumber: setNum)
                    previousHeatRating = workoutManager.getLastWorkoutHeatRating(for: exercise, setNumber: setNum)
                }
                // Restore any rating already entered this session (survives re-renders)
                let stored = UserDefaults.standard.integer(forKey: "heat_\(setId)")
                if stored > 0 { heatRating = stored }
            }

            if showingHeatPicker {
                HeatPickerView(
                    selectedRating: $heatRating,
                    isPresented: $showingHeatPicker,
                    onSelect: { rating in
                        UserDefaults.standard.set(rating > 0 ? rating : nil, forKey: "heat_\(setId)")
                        if rating > 0 {
                            UserDefaults.standard.set(rating, forKey: "heat_\(setId)")
                        } else {
                            UserDefaults.standard.removeObject(forKey: "heat_\(setId)")
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.horizontal, 4)
            }
            
            if showRestButton && isSetComplete {
                Button {
                    showingRestTimer = true
                } label: {
                    HStack {
                        Image(systemName: "timer")
                        Text("Rest Timer")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.fitnessBronze.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Heat Picker View
struct HeatPickerView: View {
    @Binding var selectedRating: Int
    @Binding var isPresented: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                Text("1")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Easy")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Hard")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("10")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 5) {
                ForEach(1...10, id: \.self) { n in
                    Button {
                        let newRating = selectedRating == n ? 0 : n
                        selectedRating = newRating
                        onSelect(newRating)
                        isPresented = false
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selectedRating == n ? .white : colorFor(n))
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(selectedRating == n ? colorFor(n) : colorFor(n).opacity(0.13))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func colorFor(_ n: Int) -> Color {
        switch n {
        case 1...3: return .green
        case 4...6: return .orange
        case 7...8: return Color(red: 1.0, green: 0.4, blue: 0.0)
        default:    return .red
        }
    }
}

// MARK: - Rest Timer View
struct RestTimerView: View {
    @Binding var showingRestTimer: Bool
    @State private var selectedDuration: Int = 60  // Default to 1:00
    @EnvironmentObject var timerManager: TimerManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text(timerManager.isRestTimerActive ? "Rest Time" : "Set Rest Timer")
                    .font(.title)
                    .fontWeight(.bold)
                
                if timerManager.isRestTimerActive {
                    Text(timerManager.formattedRestTime)
                        .font(.system(size: 70, weight: .bold, design: .monospaced))
                        .padding()
                    
                    HStack(spacing: 40) {
                        Button(action: {
                            timerManager.stopRestTimer(manualStop: true)
                            showingRestTimer = false
                        }) {
                            Text("Skip")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(width: 120)
                        
                        Button(action: {
                            timerManager.stopRestTimer(manualStop: true)
                            timerManager.startRestTimer(duration: selectedDuration)
                        }) {
                            Text("Restart")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(width: 120)
                    }
                }
                
                if !timerManager.isRestTimerActive {
                    HStack(spacing: 20) {
                        presetButton(seconds: 60, label: "1:00")
                        presetButton(seconds: 101, label: "1:41")
                        presetButton(seconds: 120, label: "2:00")
                        presetButton(seconds: 180, label: "3:00")
                    }
                    
                    Button(action: {
                        timerManager.startRestTimer(duration: selectedDuration)
                    }) {
                        Text("Start Rest")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                }
            }
            .padding()
            .navigationBarItems(
                trailing: Group {
                    // Only show Close button when not actively timing
                    if !timerManager.isRestTimerActive {
                        Button("Close") {
                            showingRestTimer = false
                        }
                    }
                }
            )
            .interactiveDismissDisabled(timerManager.isRestTimerActive)
            .onDisappear {
                // Don't stop the timer when view disappears
                // Let it continue in the background
            }
            .onAppear {
                // Set default duration to 1:00 (60 seconds)
                selectedDuration = 60
                print("DEBUG: ⏱️ RestTimerView appeared, isRestTimerActive=\(timerManager.isRestTimerActive)")
            }
            // onReceive auto-cancels when the view disappears, preventing observer accumulation
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestTimerComplete"))) { notification in
                print("DEBUG: ⏱️ Received RestTimerComplete notification")
                if let userInfo = notification.userInfo,
                   let manualStop = userInfo["manualStop"] as? Bool {
                    print("DEBUG: ⏱️ manualStop=\(manualStop)")
                    if !manualStop {
                        print("DEBUG: ⏱️ Timer completed naturally, dismissing sheet immediately")
                        showingRestTimer = false
                    } else {
                        print("DEBUG: ⏱️ Timer was manually stopped, not auto-dismissing")
                    }
                }
            }
        }
    }
    
    private func presetButton(seconds: Int, label: String) -> some View {
        Button(action: {
            selectedDuration = seconds
            if timerManager.isRestTimerActive {
                timerManager.stopRestTimer(manualStop: true)
                timerManager.startRestTimer(duration: seconds)
            }
        }) {
            Text(label)
                .fontWeight(.medium)
                .frame(minWidth: 60)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(selectedDuration == seconds ? Color.fitnessPrimary : Color(.systemGray5))
                .foregroundColor(selectedDuration == seconds ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

#Preview {
    Text("WorkoutView Preview") // Not fully previewable due to Core Data dependencies
}
