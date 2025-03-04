import SwiftUI
import CoreData
import Combine

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    
    @ObservedObject var workoutManager: WorkoutManager
    @ObservedObject var timerManager = TimerManager()
    
    let workout: NSManagedObject
    
    @State private var showingAddExercise = false
    @State private var showingCancelAlert = false
    @State private var showingCompletionAlert = false
    @State private var isEditing = false
    @State private var isTemplateView: Bool
    @State private var editedTemplateName: String = ""
    
    @State private var setValues: [String: (reps: Int16, weight: Double)] = [:]
    
    // Warmup states
    @State private var isShowingWarmupTimer = false
    @State private var warmups: [String] = []
    @State private var warmupDurations: [Int] = []
    
    init(workout: NSManagedObject, workoutManager: WorkoutManager) {
        print("DEBUG: ⭐️ WorkoutView initializing with entity: \(workout.entity.name ?? "unknown")")
        print("DEBUG: ⭐️ Workout object ID: \(workout.objectID)")
        
        let attributes = workout.entity.attributesByName
        print("DEBUG: ⭐️ Available attributes: \(attributes.keys.joined(separator: ", "))")
        
        let relationships = workout.entity.relationshipsByName
        print("DEBUG: ⭐️ Available relationships: \(relationships.keys.joined(separator: ", "))")
        
        self.workout = workout
        self._workoutManager = ObservedObject(wrappedValue: workoutManager)
        
        let isTemplate = workout.entity.name == "WorkoutTemplate"
        self._isTemplateView = State(initialValue: isTemplate)
        
        if isTemplate {
            print("DEBUG: ⭐️ Initializing as template with name: \(workout.value(forKey: "name") as? String ?? "nil")")
            self._editedTemplateName = State(initialValue: workout.value(forKey: "name") as? String ?? "Untitled")
        } else {
            print("DEBUG: ⭐️ Initializing as workout")
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
        
        print("DEBUG: ⭐️ isTemplateView = \(workout.entity.name == "WorkoutTemplate")")
    }
    
    private var templateName: String {
        print("DEBUG: ⭐️ Getting template name for workout of type: \(type(of: workout))")
        print("DEBUG: ⭐️ Entity name: \(workout.entity.name ?? "unknown")")
        
        switch workout.entity.name {
        case "Workout":
            if let workoutObj = workout as? Workout {
                let name = workoutObj.templateName
                print("DEBUG: ⭐️ Got template name: \(name)")
                return name
            }
            if workout.entity.relationshipsByName["template"] != nil {
                if let template = workout.value(forKey: "template") as? NSManagedObject {
                    let name = template.value(forKey: "name") as? String ?? "Workout"
                    print("DEBUG: ⭐️ Retrieved template name via KVC: \(name)")
                    return name
                }
            }
        case "WorkoutTemplate":
            if let templateObj = workout as? WorkoutTemplate {
                let name = templateObj.templateName
                print("DEBUG: ⭐️ Got template name: \(name)")
                return name
            }
            let name = workout.value(forKey: "name") as? String ?? "Workout"
            print("DEBUG: ⭐️ Retrieved template name via KVC: \(name)")
            return name
        default:
            break
        }
        print("DEBUG: ⭐️ Failed to get template name, defaulting to 'Workout'")
        return "Workout"
    }
    
    private var exercises: [NSManagedObject] {
        print("DEBUG: ⭐️ Getting exercises for object of type: \(type(of: workout))")
        print("DEBUG: ⭐️ Entity name: \(workout.entity.name ?? "unknown")")
        
        switch workout.entity.name {
        case "Workout":
            if let workoutObj = workout as? Workout {
                let exArray = workoutObj.exerciseArray
                print("DEBUG: ⭐️ Found \(exArray.count) exercises from typed object")
                return exArray
            }
            if let exercisesSet = workout.value(forKey: "exercises") as? NSSet {
                let exercises = exercisesSet.allObjects as? [NSManagedObject] ?? []
                print("DEBUG: ⭐️ Found \(exercises.count) exercises via KVC for Workout")
                return exercises.sorted {
                    let order1 = $0.value(forKey: "order") as? Int16 ?? 0
                    let order2 = $1.value(forKey: "order") as? Int16 ?? 0
                    return order1 < order2
                }
            }
        case "WorkoutTemplate":
            if let templateObj = workout as? WorkoutTemplate {
                let exArray = templateObj.exerciseArray
                print("DEBUG: ⭐️ Found \(exArray.count) exercises from typed template")
                return exArray
            }
            if let exercisesSet = workout.value(forKey: "exercises") as? NSSet {
                let exercises = exercisesSet.allObjects as? [NSManagedObject] ?? []
                print("DEBUG: ⭐️ Found \(exercises.count) exercises via KVC for WorkoutTemplate")
                for (index, ex) in exercises.enumerated() {
                    print("DEBUG: ⭐️   Exercise \(index): \(ex.value(forKey: "name") as? String ?? "unnamed")")
                }
                return exercises.sorted {
                    let order1 = $0.value(forKey: "order") as? Int16 ?? 0
                    let order2 = $1.value(forKey: "order") as? Int16 ?? 0
                    return order1 < order2
                }
            }
        default:
            break
        }
        print("DEBUG: ⭐️ No exercises found")
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
                    .onDisappear {
                        // When warmup timer view disappears, stop its timer
                        timerManager.stopWarmupTimer()
                    }
            } else {
                mainWorkoutView
            }
        }
        .onAppear {
            // Load warmups when the view appears
            loadWarmupsAndStartTimerIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // App came back to foreground
                print("DEBUG: WorkoutView - App became active")
                timerManager.handleAppBecameActive()
            case .background:
                // App went to background
                print("DEBUG: WorkoutView - App went to background")
                timerManager.handleAppWentToBackground()
            case .inactive:
                // App became inactive (but not yet in background)
                print("DEBUG: WorkoutView - App became inactive")
            @unknown default:
                break
            }
        }
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
                    dismiss()
                }
                Button("Continue Workout", role: .cancel) {}
            } message: {
                Text("Have you completed all your exercises? The workout will be saved to your history.")
            }
            .onAppear {
                if !isTemplateView {
                    timerManager.startWorkoutTimer()
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
    
    private func loadWarmupsAndStartTimerIfNeeded() {
        if !isTemplateView {
            print("DEBUG: 🏋️‍♂️ Attempting to load warmups for workout")
            // Only show warmups when starting an actual workout (not when viewing a template)
            if let templateObj = workout.value(forKey: "template") as? NSManagedObject {
                print("DEBUG: 🏋️‍♂️ Found template object: \(templateObj.objectID)")
                
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
                    print("DEBUG: 🏋️‍♂️ Starting warmup timer with durations: \(warmupDurations)")
                    // Start warmup timer with loaded warmups and durations
                    timerManager.startWarmupTimer(warmups: warmups, durations: warmupDurations)
                    isShowingWarmupTimer = true
                    
                    // Listen for when all warmups are completed
                    NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("WarmupTimerComplete"),
                        object: nil,
                        queue: .main
                    ) { _ in
                        isShowingWarmupTimer = false
                    }
                } else {
                    print("DEBUG: 🏋️‍♂️ No warmups found, skipping timer")
                }
            } else {
                print("DEBUG: 🏋️‍♂️ No template found for this workout")
            }
        } else {
            print("DEBUG: 🏋️‍♂️ In template view mode, skipping warmups")
        }
    }
}

// MARK: - Exercise Card
struct ExerciseCard: View {
    let exercise: NSManagedObject
    let workoutManager: WorkoutManager
    let timerManager: TimerManager
    @Binding var setValues: [String: (reps: Int16, weight: Double)]
    
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
                    }
                    
                    Divider()
                    
                    ForEach(Array(sets.enumerated()), id: \.element) { index, set in
                        SetRow(
                            set: set,
                            setNumber: index,
                            isActive: activeSetIndex == index,
                            setValues: $setValues,
                            activateNextSet: {
                                if index < sets.count - 1 {
                                    activeSetIndex = index + 1
                                } else {
                                    activeSetIndex = nil
                                }
                            },
                            workoutManager: workoutManager,
                            timerManager: timerManager
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
    }
}

// MARK: - Set Row
struct SetRow: View {
    let set: NSManagedObject
    let setNumber: Int
    let isActive: Bool
    @Binding var setValues: [String: (reps: Int16, weight: Double)]
    let activateNextSet: () -> Void
    let workoutManager: WorkoutManager
    let timerManager: TimerManager
    
    @State private var showingRestTimer = false
    @State private var showRestButton = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var previousSetData: (reps: Int16, weight: Double)? = nil
    
    private var setId: String {
        return set.objectID.uriRepresentation().absoluteString
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
                        if let previousData = previousSetData,
                           previousData.weight > 0,
                           (setValues[setId]?.weight ?? 0) == 0 && (set.value(forKey: "weight") as? Double ?? 0.0) == 0 {
                            Text("\(Int(previousData.weight))")
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .font(.body.weight(.medium))
                        }
                    }
                }
                
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
                // Fetch previous workout data when the set row appears
                if let exerciseObj = set.value(forKey: "workoutExercise") as? NSManagedObject,
                   let exercise = exerciseObj.value(forKey: "exercise") as? NSManagedObject {
                    let setNum = set.value(forKey: "setNumber") as? Int16 ?? 0
                    print("DEBUG: Fetching previous data for exercise: \(exercise.value(forKey: "name") ?? "unknown"), set: \(setNum)")
                    previousSetData = workoutManager.getLastWorkoutSetData(for: exercise, setNumber: setNum)
                    print("DEBUG: Previous data: \(String(describing: previousSetData))")
                }
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
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .sheet(isPresented: $showingRestTimer) {
                    RestTimerView(showingRestTimer: $showingRestTimer)
                        .environmentObject(timerManager)
                }
            }
        }
    }
}

// MARK: - Rest Timer View
struct RestTimerView: View {
    @Binding var showingRestTimer: Bool
    @State private var selectedDuration: Int = 101  // Default to 1:41
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
                            timerManager.stopRestTimer()
                            showingRestTimer = false
                        }) {
                            Text("Skip")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(width: 120)
                        
                        Button(action: {
                            timerManager.stopRestTimer()
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
                trailing: Button("Close") {
                    if timerManager.isRestTimerActive {
                        timerManager.stopRestTimer()
                    }
                    showingRestTimer = false
                }
            )
            .onDisappear {
                // Don't stop the timer when view disappears
                // Let it continue in the background
            }
            .onAppear {
                // Set default duration to 1:41 (101 seconds)
                selectedDuration = 101
            }
        }
    }
    
    private func presetButton(seconds: Int, label: String) -> some View {
        Button(action: {
            selectedDuration = seconds
            if timerManager.isRestTimerActive {
                timerManager.stopRestTimer()
                timerManager.startRestTimer(duration: seconds)
            }
        }) {
            Text(label)
                .fontWeight(.medium)
                .frame(minWidth: 60)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(selectedDuration == seconds ? Color.blue : Color(.systemGray5))
                .foregroundColor(selectedDuration == seconds ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

#Preview {
    Text("WorkoutView Preview") // Not fully previewable due to Core Data dependencies
}