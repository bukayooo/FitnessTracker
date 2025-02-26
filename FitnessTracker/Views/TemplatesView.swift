//
//  TemplatesView.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI
import CoreData

struct TemplatesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var workoutManager: WorkoutManager
    
    @State private var showingNewTemplate = false
    @State private var showingTemplateDetail = false
    @State private var selectedTemplate: NSManagedObject?
    @State private var searchText = ""
    
    // Add state for showing newly created workout
    @State private var showingNewWorkout = false
    @State private var newWorkoutObject: NSManagedObject?
    
    // Force view to refresh when templateCount changes
    @State private var refreshToggle = false
    
    // Error handling
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        // Use the old style NavigationView with navigationBarItems
        // which has better compatibility
        NavigationView {
            ZStack {
                contentView
                
                if isLoading {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Loading...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(10)
                }
                
                if let error = errorMessage, showingError {
                    VStack {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(error)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Button("Dismiss") {
                            showingError = false
                        }
                        .padding(.top)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(10)
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingNewTemplate, onDismiss: {
            print("DEBUG: Template creation sheet dismissed")
            // Force a complete refresh of templates from the database
            workoutManager.templates = [] // Clear cache to force refetch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshTemplates() // Call the refresh function with a slight delay
                print("DEBUG: Templates refreshed after sheet dismissed")
            }
        }) {
            CreateTemplateView()
        }
        .sheet(isPresented: $showingTemplateDetail) {
            if let template = selectedTemplate, template.isValid {
                // Show the template detail
                TemplateDetailView(template: template)
                    .environmentObject(workoutManager)
                    .environment(\.managedObjectContext, viewContext)
                    .onDisappear {
                        print("DEBUG: Template detail view disappeared")
                        // Reset selected template
                        selectedTemplate = nil
                    }
            } else {
                // Handle invalid template
                Text("Template is no longer available")
                    .padding()
            }
        }
        .sheet(isPresented: $showingNewWorkout) {
            if let workout = newWorkoutObject, workout.isValid {
                WorkoutView(workout: workout, workoutManager: workoutManager)
                    .environment(\.managedObjectContext, viewContext)
                    .onDisappear {
                        // Reset the workout object after viewing
                        newWorkoutObject = nil
                        showingNewWorkout = false
                    }
            } else {
                // Handle invalid workout
                Text("Workout is no longer available")
                    .padding()
            }
        }
        .onAppear {
            // Set up notification observer for starting workouts from templates
            setupNotificationObserver()
            
            // Refresh templates when view appears
            refreshTemplates()
        }
    }
    
    private func refreshTemplates() {
        // Force refresh templates
        print("DEBUG: Refreshing templates manually")
        workoutManager.templates = [] // Force clearing the cache
        
        // Refresh templates using fetchTemplatesFromStore directly
        DispatchQueue.main.async {
            workoutManager.refreshTemplates()
            
            // Force UI update by toggling refresh state
            self.refreshToggle.toggle()
            print("DEBUG: Templates refreshed, new count: \(self.workoutManager.templateCount)")
        }
    }
    
    private func setupNotificationObserver() {
        // Remove any existing observer first to prevent duplicates
        NotificationCenter.default.removeObserver(self, name: Notification.Name("StartWorkoutFromTemplate"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("TemplateCreated"), object: nil)
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("StartWorkoutFromTemplate"),
            object: nil,
            queue: .main) { notification in
                print("DEBUG: Received notification to start workout")
                
                // Set loading state
                self.isLoading = true
                self.errorMessage = nil
                self.showingError = false
                
                // Get the workout from the notification
                if let userInfo = notification.userInfo,
                   let workout = userInfo["workout"] as? NSManagedObject {
                    print("DEBUG: Setting up to show workout: \(workout.objectID)")
                    
                    // Reset existing workout object
                    self.newWorkoutObject = nil
                    self.showingNewWorkout = false
                    
                    // Verify the workout is valid
                    if workout.isValid {
                        // Ensure workout is properly loaded in context
                        do {
                            // Using guard let for the optional returned by existingObject(with:)
                            guard let freshWorkout = try? viewContext.existingObject(with: workout.objectID) else {
                                self.handleError("Failed to load workout data")
                                return
                            }
                            
                            print("DEBUG: Successfully retrieved fresh workout")
                            
                            // Show the workout view after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.isLoading = false
                                self.newWorkoutObject = freshWorkout // Remove unnecessary cast
                                self.showingNewWorkout = true
                            }
                        }
                    } else {
                        self.handleError("Workout is not valid or has been deleted")
                    }
                } else {
                    self.handleError("No workout data provided")
                }
            }
            
        // Add observer for template creation
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TemplateCreated"),
            object: nil,
            queue: .main) { _ in
                print("DEBUG: Received notification that template was created")
                self.refreshTemplates()
            }
    }
    
    private func handleError(_ message: String) {
        print("DEBUG: Error: \(message)")
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = message
            self.showingError = true
        }
    }
    
    var contentView: some View {
        // Access these to force refresh when they change
        let _ = (workoutManager.templateCount, refreshToggle)
        print("DEBUG: Refreshing templates view with count: \(workoutManager.templateCount)")
        
        let templates = workoutManager.fetchAllTemplates()
        
        return Group {
            if templates.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet",
                    title: "No Templates Yet",
                    message: "Create your first workout template to get started"
                )
            } else {
                List {
                    ForEach(templates, id: \.self) { template in
                        Button {
                            selectedTemplate = template
                            showingTemplateDetail = true
                        } label: {
                            TemplateListRow(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        deleteTemplates(at: indexSet)
                    }
                }
                .searchable(text: $searchText, prompt: "Search templates")
            }
        }
        .navigationTitle("Templates")
        .navigationBarItems(trailing: Button(action: {
            showingNewTemplate = true
        }) {
            Image(systemName: "plus")
        })
    }
    
    private func deleteTemplates(at offsets: IndexSet) {
        let templates = workoutManager.fetchAllTemplates()
        for index in offsets {
            let template = templates[index]
            workoutManager.deleteTemplate(template)
        }
    }
}

struct TemplateListRow: View {
    let template: NSManagedObject
    
    private var templateName: String {
        return template.value(forKey: "name") as? String ?? "Untitled Template"
    }
    
    private var exerciseCount: Int {
        if let exercises = template.value(forKey: "exercises") as? NSSet {
            return exercises.count
        }
        return 0
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(templateName)
                    .font(.headline)
                
                Text("\(exerciseCount) exercises")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

struct CreateTemplateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutManager: WorkoutManager
    
    @State private var templateName = ""
    @State private var exercises: [TemplateExerciseItem] = []
    @State private var showingAddExercise = false
    
    struct TemplateExerciseItem: Identifiable {
        let id = UUID()
        var name: String
        var order: Int
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Template Name")) {
                    TextField("e.g. Upper Body, Leg Day", text: $templateName)
                }
                
                Section(header: Text("Exercises")) {
                    ForEach(exercises) { exercise in
                        HStack {
                            Text(exercise.name)
                            
                            Spacer()
                            
                            Text("Sets: 3")
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteExercise)
                    .onMove(perform: moveExercise)
                    
                    Button {
                        showingAddExercise = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                    }
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTemplate()
                        dismiss()
                    }
                    .disabled(templateName.isEmpty || exercises.isEmpty)
                }
                
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                        .disabled(exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView { exerciseName in
                    let newExercise = TemplateExerciseItem(
                        name: exerciseName,
                        order: exercises.count
                    )
                    exercises.append(newExercise)
                }
            }
        }
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
        
        // Update order after deletion
        for i in 0..<exercises.count {
            exercises[i].order = i
        }
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
        
        // Update order after moving
        for i in 0..<exercises.count {
            exercises[i].order = i
        }
    }
    
    private func saveTemplate() {
        print("DEBUG: Starting template save with name: \(templateName)")
        print("DEBUG: Adding \(exercises.count) exercises")
        
        // Create the template
        let template = workoutManager.createTemplate(name: templateName)
        print("DEBUG: Template created with id: \(template.objectID)")
        
        // Add exercises to the template
        for exercise in exercises {
            let newExercise = workoutManager.addExercise(to: template, name: exercise.name)
            print("DEBUG: Added exercise: \(exercise.name) with id: \(newExercise.objectID)")
        }
        
        print("DEBUG: All template data saved")
        
        // Request the parent view to refresh its templates list when dismissed
        NotificationCenter.default.post(name: Notification.Name("TemplateCreated"), object: nil)
    }
}

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var exerciseName = ""
    @State private var commonExercises = [
        "Bench Press", "Squat", "Deadlift", "Pull-up", "Push-up",
        "Shoulder Press", "Bicep Curl", "Tricep Extension", "Lat Pulldown",
        "Leg Press", "Leg Extension", "Leg Curl", "Calf Raise",
        "Plank", "Sit-up", "Russian Twist", "Lunge"
    ]
    @State private var searchText = ""
    
    let onAddExercise: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                // Custom exercise
                TextField("Exercise name", text: $exerciseName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                Button {
                    if !exerciseName.isEmpty {
                        onAddExercise(exerciseName)
                        dismiss()
                    }
                } label: {
                    Text("Add Custom Exercise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(exerciseName.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .disabled(exerciseName.isEmpty)
                
                // Common exercises
                List {
                    Section(header: Text("Common Exercises")) {
                        ForEach(filteredExercises, id: \.self) { exercise in
                            Button {
                                onAddExercise(exercise)
                                dismiss()
                            } label: {
                                Text(exercise)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
        }
    }
    
    private var filteredExercises: [String] {
        if searchText.isEmpty {
            return commonExercises
        } else {
            return commonExercises.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

struct TemplateDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutManager: WorkoutManager
    
    let template: NSManagedObject
    
    @State private var isEditing = false
    @State private var templateName: String
    @State private var exercises: [TemplateExerciseItem] = []
    @State private var showingAddExercise = false
    
    struct TemplateExerciseItem: Identifiable {
        let id = UUID()
        var name: String
        var order: Int
        var sets: Int = 3 // Add sets property
    }
    
    init(template: NSManagedObject) {
        self.template = template
        
        // Initialize state variables with template values
        let name = template.value(forKey: "name") as? String ?? "Untitled Template"
        _templateName = State(initialValue: name)
        
        if let exercisesSet = template.value(forKey: "exercises") as? NSSet {
            let items = exercisesSet.compactMap { exercise -> TemplateExerciseItem? in
                guard let exercise = exercise as? NSManagedObject,
                      let name = exercise.value(forKey: "name") as? String,
                      let order = exercise.value(forKey: "order") as? Int16 else {
                    return nil
                }
                
                // Get the sets count
                let sets = exercise.value(forKey: "sets") as? Int16 ?? 3
                
                return TemplateExerciseItem(name: name, order: Int(order), sets: Int(sets))
            }
            .sorted { $0.order < $1.order }
            
            _exercises = State(initialValue: items)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Template Name")) {
                    if isEditing {
                        TextField("Template name", text: $templateName)
                    } else {
                        Text(templateName)
                    }
                }
                
                Section(header: Text("Exercises")) {
                    if exercises.isEmpty {
                        Text("No exercises added")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(exercises.indices, id: \.self) { index in
                            HStack {
                                Text(exercises[index].name)
                                
                                Spacer()
                                
                                if isEditing {
                                    Stepper("Sets: \(exercises[index].sets)", value: $exercises[index].sets, in: 1...10)
                                        .labelsHidden()
                                    Text("Sets: \(exercises[index].sets)")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Sets: \(exercises[index].sets)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: isEditing ? deleteExercise : nil)
                        .onMove(perform: isEditing ? moveExercise : nil)
                    }
                    
                    if isEditing {
                        Button {
                            showingAddExercise = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Exercise")
                            }
                        }
                    }
                }
                
                if !isEditing {
                    Section {
                        Button {
                            // Start Workout with this template
                            print("DEBUG: Starting workout from template: \(templateName)")
                            
                            // Show loading indicator to user
                            let loadingAlert = UIAlertController(
                                title: "Starting Workout", 
                                message: "Please wait...", 
                                preferredStyle: .alert
                            )
                            
                            // Get key window using the newer API
                            let windowScene = UIApplication.shared.connectedScenes
                                .first(where: { $0 is UIWindowScene }) as? UIWindowScene
                            let window = windowScene?.windows.first { $0.isKeyWindow }
                            window?.rootViewController?.present(loadingAlert, animated: true)
                            
                            // Create in background to avoid blocking UI
                            DispatchQueue.global(qos: .userInitiated).async {
                                // Create a workout from this template
                                if let workout = workoutManager.startWorkout(from: template) {
                                    print("DEBUG: Created new workout with ID: \(workout.objectID)")
                                    
                                    // Dismiss the loading alert
                                    DispatchQueue.main.async {
                                        loadingAlert.dismiss(animated: true)
                                        
                                        // Dismiss this view
                                        print("DEBUG: Dismissing template view...")
                                        dismiss()
                                        
                                        // Delay posting notification slightly
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            // Post notification to start the workout
                                            NotificationCenter.default.post(
                                                name: Notification.Name("StartWorkoutFromTemplate"),
                                                object: nil,
                                                userInfo: ["workout": workout]
                                            )
                                            print("DEBUG: Posted notification to start workout")
                                        }
                                    }
                                } else {
                                    // Handle the case where workout creation failed
                                    DispatchQueue.main.async {
                                        loadingAlert.dismiss(animated: true)
                                        
                                        // Show error message
                                        let errorAlert = UIAlertController(
                                            title: "Error",
                                            message: "Failed to create workout from template",
                                            preferredStyle: .alert
                                        )
                                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                                        window?.rootViewController?.present(errorAlert, animated: true)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Workout")
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                        }
                        .listRowBackground(Color.blue)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Template" : templateName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "Cancel" : "Close") {
                        if isEditing {
                            // Reset changes
                            isEditing = false
                            
                            // Reload original values
                            templateName = template.value(forKey: "name") as? String ?? "Untitled Template"
                            
                            loadExercises()
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            // Save changes
                            saveChanges()
                            isEditing = false
                        } else {
                            isEditing = true
                        }
                    }
                }
                
                if isEditing {
                    ToolbarItem(placement: .bottomBar) {
                        EditButton()
                            .disabled(exercises.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView { exerciseName in
                    let newExercise = TemplateExerciseItem(
                        name: exerciseName,
                        order: exercises.count
                    )
                    exercises.append(newExercise)
                }
            }
        }
    }
    
    private func loadExercises() {
        if let exercisesSet = template.value(forKey: "exercises") as? NSSet {
            let items = exercisesSet.compactMap { exercise -> TemplateExerciseItem? in
                guard let exercise = exercise as? NSManagedObject,
                      let name = exercise.value(forKey: "name") as? String,
                      let order = exercise.value(forKey: "order") as? Int16 else {
                    return nil
                }
                
                // Get the sets count
                let sets = exercise.value(forKey: "sets") as? Int16 ?? 3
                
                return TemplateExerciseItem(name: name, order: Int(order), sets: Int(sets))
            }
            .sorted { $0.order < $1.order }
            
            exercises = items
        }
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
        
        // Update order after deletion
        for i in 0..<exercises.count {
            exercises[i].order = i
        }
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
        
        // Update order after moving
        for i in 0..<exercises.count {
            exercises[i].order = i
        }
    }
    
    private func saveChanges() {
        // Update the template name
        workoutManager.updateTemplate(template, name: templateName)
        
        // Remove all existing exercises
        if let exercisesSet = template.value(forKey: "exercises") as? NSSet {
            for case let exercise as NSManagedObject in exercisesSet {
                workoutManager.deleteExercise(exercise)
            }
        }
        
        // Add the new exercises with sets count
        for exercise in exercises {
            let newExercise = workoutManager.addExercise(to: template, name: exercise.name)
            // Set the number of sets
            newExercise.setValue(Int16(exercise.sets), forKey: "sets")
        }
        
        // Save the context
        do {
            try viewContext.save()
            print("DEBUG: Template exercises updated with custom set counts")
        } catch {
            print("DEBUG: Error saving exercise set counts: \(error)")
        }
    }
} 