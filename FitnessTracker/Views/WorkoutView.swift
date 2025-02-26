//
//  WorkoutView.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI
import CoreData
import Combine

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var workoutManager: WorkoutManager
    
    let workout: NSManagedObject
    
    @ObservedObject private var timerManager: TimerManager
    @State private var setValues: [UUID: [String: String]] = [:]
    @State private var showingCancelAlert = false
    @State private var showingCompletionAlert = false
    @State private var timerConnection: AnyCancellable?
    
    // Add template editing state variables
    @State private var isEditing = false
    @State private var editedTemplateName = ""
    @State private var showingAddExercise = false
    
    // Make this a proper stored property of the view
    @State private var isTemplateView = false
    
    init(workout: NSManagedObject, workoutManager: WorkoutManager) {
        self.workout = workout
        self.workoutManager = workoutManager
        self._timerManager = ObservedObject(wrappedValue: TimerManager())
        self._editedTemplateName = State(initialValue: workout.value(forKey: "name") as? String ?? "Untitled")
        // Initialize isTemplateView here
        self._isTemplateView = State(initialValue: workout.entity.name == "WorkoutTemplate")
    }
    
    private var templateName: String {
        print("DEBUG: Getting template name for workout of type: \(type(of: workout))")
        
        // Check if it's a Workout instance first
        if let workoutObj = workout as? Workout {
            print("DEBUG: Accessing typed Workout object")
            return workoutObj.templateName
        }
        
        // Fallback to KVC for WorkoutTemplate
        if let templateObj = workout as? WorkoutTemplate {
            print("DEBUG: Accessing WorkoutTemplate directly")
            return templateObj.templateName
        }
        
        // Last resort KVC with extra safety
        print("DEBUG: Using KVC as last resort for: \(workout)")
        if workout.entity.name == "Workout" && workout.entity.attributesByName["template"] != nil {
            if let template = workout.value(forKey: "template") as? NSManagedObject {
                return template.value(forKey: "name") as? String ?? "Workout"
            }
        } else if workout.entity.name == "WorkoutTemplate" {
            return workout.value(forKey: "name") as? String ?? "Workout"
        }
        
        return "Workout"
    }
    
    private var exercises: [NSManagedObject] {
        print("DEBUG: Getting exercises for object of type: \(type(of: workout))")
        
        // Check for Workout type first
        if let workoutObj = workout as? Workout {
            print("DEBUG: Accessing exercises from Workout object")
            return workoutObj.exerciseArray
        }
        
        // Check for WorkoutTemplate type
        if let templateObj = workout as? WorkoutTemplate {
            print("DEBUG: Accessing exercises from WorkoutTemplate object")
            return templateObj.exerciseArray
        }
        
        // Fallback to KVC
        print("DEBUG: Falling back to KVC for exercises")
        if let exercisesSet = workout.value(forKey: "exercises") as? NSSet {
            let exercises = exercisesSet.allObjects as? [NSManagedObject] ?? []
            return exercises.sorted { 
                let order1 = $0.value(forKey: "order") as? Int16 ?? 0
                let order2 = $1.value(forKey: "order") as? Int16 ?? 0
                return order1 < order2
            }
        }
        
        print("DEBUG: No exercises found")
        return []
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Only show timer for actual workouts, not templates
                if !isTemplateView {
                    // Timer header
                    VStack(spacing: 8) {
                        Text("\(timerManager.formattedWorkoutTime)")
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
                            Button {
                                // Reset timer
                                let _ = timerManager.stopWorkoutTimer()
                                timerManager.startWorkoutTimer()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                            }
                            .disabled(timerManager.workoutElapsedSeconds == 0)
                            
                            Button {
                                if timerManager.isRestTimerActive {
                                    let _ = timerManager.stopWorkoutTimer()
                                } else {
                                    timerManager.startWorkoutTimer()
                                }
                            } label: {
                                Image(systemName: timerManager.isRestTimerActive ? "pause.fill" : "play.fill")
                                    .font(.title2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.systemGroupedBackground))
                }
                
                // Exercise list
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Template name editing field when in edit mode
                        if isTemplateView && isEditing {
                            TextField("Template Name", text: $editedTemplateName)
                                .font(.title2.bold())
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    
                        ForEach(exercises, id: \.self) { exercise in
                            ExerciseCard(
                                exercise: exercise,
                                workoutManager: workoutManager,
                                timerManager: timerManager,
                                setValues: $setValues,
                                isTemplateView: isTemplateView,
                                isEditing: isEditing,
                                onDelete: isEditing ? { deleteExercise(exercise) } : nil
                            )
                            .padding(.horizontal)
                        }
                        
                        // Add exercise button - show for templates in edit mode OR for blank workouts
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
                    
                    // Start workout button for template view - only show when not editing
                    if isTemplateView && !isEditing {
                        Button {
                            // Start workout from this template
                            print("DEBUG: Starting workout from template: \(templateName)")
                            let newWorkout = workoutManager.startWorkout(from: workout)
                            print("DEBUG: Created new workout with ID: \(newWorkout.objectID)")
                            
                            // Instead of just dismissing, we need to navigate to the workout
                            // First dismiss this view
                            print("DEBUG: Dismissing template view...")
                            dismiss()
                            
                            // The TemplatesView will need to handle showing the new workout
                            NotificationCenter.default.post(
                                name: Notification.Name("StartWorkoutFromTemplate"),
                                object: nil,
                                userInfo: ["workout": newWorkout]
                            )
                            print("DEBUG: Posted notification to start workout")
                        } label: {
                            Text("Start Workout")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding()
                        .padding(.bottom, 40)
                    } else if !isTemplateView {
                        // Bottom spacer for button area
                        Spacer(minLength: 80)
                    }
                }
                
                // Control buttons - only show for actual workouts
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
            .navigationTitle(templateName)
            .navigationBarTitleDisplayMode(.inline)
            // Add all toolbar items in a single toolbar modifier with explicit placements
            .toolbar {
                // Leading toolbar item (Back/Cancel button)
                ToolbarItem(placement: .navigationBarLeading) {
                    if isTemplateView {
                        Button(isEditing ? "Cancel" : "Back") {
                            if isEditing {
                                // Cancel editing
                                isEditing = false
                                // Reset edited name
                                editedTemplateName = workout.value(forKey: "name") as? String ?? "Untitled"
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
                
                // Trailing toolbar item (Edit/Save/Finish button)
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isTemplateView {
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                // Save changes
                                workoutManager.updateTemplate(workout, name: editedTemplateName)
                                isEditing = false
                            } else {
                                // Enter edit mode
                                isEditing = true
                            }
                        }
                    } else {
                        // Workout view toolbar items
                        Button {
                            showingCompletionAlert = true
                        } label: {
                            Text("Finish")
                        }
                    }
                }
                
                // Bottom bar item (Reorder button)
                ToolbarItem(placement: .bottomBar) {
                    if isTemplateView && isEditing {
                        Button("Reorder Exercises") {
                            // Implement reordering functionality
                            print("DEBUG: Reorder exercises tapped")
                        }
                        .disabled(exercises.isEmpty)
                    } else {
                        // Empty spacer when button is not needed
                        Spacer()
                    }
                }
            }
            .alert("Cancel Workout", isPresented: $showingCancelAlert) {
                Button("Cancel Workout", role: .destructive) {
                    workoutManager.deleteWorkout(workout)
                    dismiss()
                }
                Button("Continue Workout", role: .cancel) {}
            } message: {
                Text("Are you sure you want to cancel this workout? All progress will be lost.")
            }
            .alert("Complete Workout", isPresented: $showingCompletionAlert) {
                Button("Complete", role: .none) {
                    let duration = timerManager.workoutElapsedSeconds
                    workoutManager.completeWorkout(workout, duration: duration)
                    dismiss()
                }
                Button("Continue Workout", role: .cancel) {}
            } message: {
                Text("Have you completed all your exercises? The workout will be saved to your history.")
            }
            .onAppear {
                print("DEBUG: WorkoutView appeared for \(type(of: workout)), entity: \(workout.entity.name ?? "unknown")")
                print("DEBUG: isTemplateView = \(isTemplateView)")
                // Only start timer for actual workouts, not templates
                if !isTemplateView {
                    timerManager.startWorkoutTimer()
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                // Add exercise sheet - support adding to either templates or workouts
                AddExerciseView { exerciseName in
                    if isTemplateView {
                        // Add exercise to template
                        let _ = workoutManager.addExercise(to: workout, name: exerciseName)
                    } else {
                        // Add exercise to workout
                        addExerciseToWorkout(name: exerciseName)
                    }
                }
            }
        }
    }
    
    // Helper method to add an exercise to a workout
    private func addExerciseToWorkout(name: String) {
        print("DEBUG: Adding exercise '\(name)' to workout")
        
        guard let entity = NSEntityDescription.entity(forEntityName: "WorkoutExercise", in: workout.managedObjectContext!) else {
            print("DEBUG: Failed to find WorkoutExercise entity")
            return
        }
        
        // Get highest order
        let exercises = self.exercises
        let highestOrder = exercises.isEmpty ? -1 : 
            (exercises.last?.value(forKey: "order") as? Int16 ?? -1)
        
        // Create workout exercise
        let workoutExercise = NSManagedObject(entity: entity, insertInto: workout.managedObjectContext)
        workoutExercise.setValue(name, forKey: "name")
        workoutExercise.setValue(Int16(highestOrder + 1), forKey: "order")
        workoutExercise.setValue(workout, forKey: "workout")
        
        // Create default sets (e.g., 3 sets)
        for i in 0..<3 {
            guard let setEntity = NSEntityDescription.entity(forEntityName: "ExerciseSet", in: workout.managedObjectContext!) else {
                print("DEBUG: Failed to find ExerciseSet entity")
                return
            }
            
            let exerciseSet = NSManagedObject(entity: setEntity, insertInto: workout.managedObjectContext)
            exerciseSet.setValue(Int16(i), forKey: "setNumber")
            exerciseSet.setValue(workoutExercise, forKey: "workoutExercise")
        }
        
        // Save changes
        do {
            try workout.managedObjectContext?.save()
            print("DEBUG: Exercise added to workout successfully")
        } catch {
            print("DEBUG: Error adding exercise to workout: \(error)")
        }
    }
    
    // Helper methods for template editing
    private func deleteExercise(_ exercise: NSManagedObject) {
        workoutManager.deleteExercise(exercise)
    }
}

// MARK: - Exercise Card
struct ExerciseCard: View {
    let exercise: NSManagedObject
    let workoutManager: WorkoutManager
    let timerManager: TimerManager
    @Binding var setValues: [UUID: [String: String]]
    
    // Add editing mode parameters
    var isTemplateView: Bool = false
    var isEditing: Bool = false
    var onDelete: (() -> Void)? = nil
    
    @State private var activeSetIndex: Int?
    
    private var exerciseName: String {
        print("DEBUG: Getting exercise name for type: \(type(of: exercise)), entity: \(exercise.entity.name ?? "unknown")")
        return exercise.value(forKey: "name") as? String ?? "Unknown Exercise"
    }
    
    private var sets: [NSManagedObject] {
        print("DEBUG: Getting sets for exercise type: \(type(of: exercise)), entity: \(exercise.entity.name ?? "unknown")")
        
        // If we're in template view mode, return empty array (no sets to show/edit)
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
            // Exercise name with edit controls if in edit mode
            HStack {
                Text(exerciseName)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Show delete button in edit mode
                if isTemplateView && isEditing && onDelete != nil {
                    Button {
                        onDelete?()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Sets & Reps controls
            if isTemplateView && isEditing {
                // Set count editor for template exercises
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
                    // Headers
                    HStack {
                        Text("Set")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                        
                        Text("Previous")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .leading)
                        
                        Text("Reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("")
                            .frame(width: 50)
                    }
                    
                    Divider()
                    
                    // Set rows
                    ForEach(Array(sets.enumerated()), id: \.element) { index, set in
                        SetRow(
                            timerManager: timerManager,
                            set: set,
                            setNumber: index + 1,
                            isActive: activeSetIndex == index,
                            setValues: $setValues,
                            activateNextSet: {
                                if index < sets.count - 1 {
                                    activeSetIndex = index + 1
                                } else {
                                    activeSetIndex = nil
                                }
                            },
                            workoutManager: workoutManager
                        )
                        
                        if index < sets.count - 1 {
                            Divider()
                        }
                    }
                    
                    // Add set button - Only show for actual workouts
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
                        // For template view, show set count
                        let setCount = exercise.value(forKey: "sets") as? Int16 ?? 3
                        Text("\(setCount) sets")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            } else {
                // For template view, show set count
                let setCount = exercise.value(forKey: "sets") as? Int16 ?? 3
                Text("\(setCount) sets")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Set Row
struct SetRow: View {
    let timerManager: TimerManager
    let set: NSManagedObject
    let setNumber: Int
    let isActive: Bool
    @Binding var setValues: [UUID: [String: String]]
    let activateNextSet: () -> Void
    let workoutManager: WorkoutManager
    
    @State private var repsText = ""
    @State private var weightText = ""
    @State private var showingRestTimer = false
    @FocusState private var isRepsFocused: Bool
    @FocusState private var isWeightFocused: Bool
    
    private var setId: UUID {
        UUID(uuidString: set.objectID.uriRepresentation().absoluteString) ?? UUID()
    }
    
    private var previousData: (reps: Int16, weight: Double)? {
        if let workoutExercise = set.value(forKey: "workoutExercise") as? NSManagedObject,
           let exercise = workoutExercise.value(forKey: "exercise") as? NSManagedObject {
            
            // Find previous workout
            if let workouts = exercise.value(forKey: "workoutExercises") as? NSSet,
               let previousExercise = (workouts.allObjects as? [NSManagedObject])?.first(where: { 
                   ($0.value(forKey: "workout") as? NSManagedObject) != (workoutExercise.value(forKey: "workout") as? NSManagedObject)
               }),
               let sets = previousExercise.value(forKey: "sets") as? NSSet,
               let setNumber = set.value(forKey: "setNumber") as? Int16,
               let previousSet = (sets.allObjects as? [NSManagedObject])?.first(where: { 
                   ($0.value(forKey: "setNumber") as? Int16) == setNumber
               }) {
                
                let reps = previousSet.value(forKey: "reps") as? Int16 ?? 0
                let weight = previousSet.value(forKey: "weight") as? Double ?? 0.0
                
                return (reps, weight)
            }
        }
        return nil
    }
    
    private var previousDataText: String {
        if let data = previousData, data.reps > 0 || data.weight > 0 {
            return "\(data.reps) × \(String(format: "%.1f", data.weight))"
        }
        return "-"
    }
    
    var body: some View {
        HStack(alignment: .center) {
            // Set number
            Text("\(setNumber)")
                .font(.body)
                .foregroundColor(.primary)
                .frame(width: 40, alignment: .leading)
            
            // Previous values
            Text(previousDataText)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            
            // Reps input
            TextField("0", text: Binding(
                get: {
                    if let value = setValues[setId]?["reps"] {
                        return value
                    }
                    let reps = set.value(forKey: "reps") as? Int16 ?? 0
                    return reps > 0 ? "\(reps)" : ""
                },
                set: { newValue in
                    var values = setValues[setId] ?? [:]
                    values["reps"] = newValue
                    setValues[setId] = values
                    
                    // Update in Core Data if valid
                    if let reps = Int16(newValue), reps >= 0 {
                        let weight = Double(setValues[setId]?["weight"] ?? "") ?? (set.value(forKey: "weight") as? Double ?? 0.0)
                        workoutManager.updateSet(set, reps: reps, weight: weight)
                    }
                }
            ))
            .keyboardType(.numberPad)
            .focused($isRepsFocused)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Weight input
            TextField("0.0", text: Binding(
                get: {
                    if let value = setValues[setId]?["weight"] {
                        return value
                    }
                    let weight = set.value(forKey: "weight") as? Double ?? 0.0
                    return weight > 0 ? String(format: "%.1f", weight) : ""
                },
                set: { newValue in
                    var values = setValues[setId] ?? [:]
                    values["weight"] = newValue
                    setValues[setId] = values
                    
                    // Update in Core Data if valid
                    if let weight = Double(newValue.replacingOccurrences(of: ",", with: ".")), weight >= 0 {
                        let reps = Int16(setValues[setId]?["reps"] ?? "") ?? (set.value(forKey: "reps") as? Int16 ?? 0)
                        workoutManager.updateSet(set, reps: reps, weight: weight)
                    }
                }
            ))
            .keyboardType(.decimalPad)
            .focused($isWeightFocused)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Rest timer button
            Button {
                if isRepsFocused || isWeightFocused {
                    isRepsFocused = false
                    isWeightFocused = false
                    
                    // Give time for keyboard to dismiss before showing timer
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingRestTimer = true
                    }
                } else {
                    showingRestTimer = true
                }
            } label: {
                Image(systemName: "timer")
                    .foregroundColor(.blue)
            }
            .frame(width: 50, alignment: .center)
            .buttonStyle(.plain)
            .sheet(isPresented: $showingRestTimer, onDismiss: {
                activateNextSet()
            }) {
                RestTimerView(showingRestTimer: $showingRestTimer)
            }
            .disabled(
                (setValues[setId]?["reps"] ?? "").isEmpty && 
                (set.value(forKey: "reps") as? Int16 ?? 0) == 0
            )
        }
        .padding(.vertical, 6)
        .background(isActive ? Color(.systemGray6) : Color.clear)
        .cornerRadius(8)
    }
}

// Rest Timer View
struct RestTimerView: View {
    @Binding var showingRestTimer: Bool
    @State private var restSeconds = 90
    @State private var timeRemaining = 90
    @State private var isRunning = false
    @State private var timerTask: Task<Void, Error>?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text(isRunning ? "Rest Time" : "Set Rest Timer")
                    .font(.title)
                    .fontWeight(.bold)
                
                if isRunning {
                    // Timer display
                    Text(formatSeconds(timeRemaining))
                        .font(.system(size: 70, weight: .bold, design: .monospaced))
                        .padding()
                    
                    // Control buttons
                    HStack(spacing: 40) {
                        Button(action: {
                            stopTimer()
                            showingRestTimer = false
                        }) {
                            Text("Skip")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(width: 120)
                        
                        Button(action: {
                            restartTimer()
                        }) {
                            Text("Restart")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(width: 120)
                    }
                } else {
                    // Timer selector
                    HStack(spacing: 20) {
                        presetButton(seconds: 60, label: "1:00")
                        presetButton(seconds: 90, label: "1:30")
                        presetButton(seconds: 120, label: "2:00")
                        presetButton(seconds: 180, label: "3:00")
                    }
                    
                    Button(action: {
                        startTimer()
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
                trailing: Button("Close") {
                    stopTimer()
                    showingRestTimer = false
                }
            )
            .onDisappear {
                stopTimer()
            }
        }
    }
    
    private func presetButton(seconds: Int, label: String) -> some View {
        Button(action: {
            restSeconds = seconds
            timeRemaining = seconds
        }) {
            Text(label)
                .fontWeight(.medium)
                .frame(minWidth: 60)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(restSeconds == seconds ? Color.blue : Color(.systemGray5))
                .foregroundColor(restSeconds == seconds ? .white : .primary)
                .cornerRadius(8)
        }
    }
    
    private func startTimer() {
        timeRemaining = restSeconds
        isRunning = true
        
        timerTask = Task {
            do {
                while isRunning && timeRemaining > 0 {
                    try await Task.sleep(for: .seconds(1))
                    if !Task.isCancelled {
                        await MainActor.run {
                            timeRemaining -= 1
                            if timeRemaining <= 0 {
                                isRunning = false
                                showingRestTimer = false
                            }
                        }
                    }
                }
            } catch {
                // Task was cancelled
            }
        }
    }
    
    private func stopTimer() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }
    
    private func restartTimer() {
        stopTimer()
        startTimer()
    }
    
    private func formatSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    Text("WorkoutView Preview") // Not fully previewable due to Core Data dependencies
} 