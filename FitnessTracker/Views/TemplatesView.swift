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
    
    var body: some View {
        // Use the old style NavigationView with navigationBarItems
        // which has better compatibility
        NavigationView {
            contentView
        }
        .sheet(isPresented: $showingNewTemplate, onDismiss: {
            print("DEBUG: Template creation sheet dismissed")
            refreshToggle.toggle()
        }) {
            CreateTemplateView()
        }
        .sheet(isPresented: $showingTemplateDetail) {
            if let template = selectedTemplate {
                // Use WorkoutView directly with the template
                WorkoutView(workout: template, workoutManager: workoutManager)
            }
        }
        .sheet(isPresented: $showingNewWorkout) {
            if let workout = newWorkoutObject {
                WorkoutView(workout: workout, workoutManager: workoutManager)
                    .onDisappear {
                        // Reset the workout object after viewing
                        newWorkoutObject = nil
                    }
            }
        }
        .onAppear {
            // Set up notification observer for starting workouts from templates
            setupNotificationObserver()
        }
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("StartWorkoutFromTemplate"),
            object: nil,
            queue: .main) { notification in
                print("DEBUG: Received notification to start workout")
                
                if let userInfo = notification.userInfo,
                   let workout = userInfo["workout"] as? NSManagedObject {
                    print("DEBUG: Setting up to show workout: \(workout.objectID)")
                    
                    // Show the workout view with the new workout
                    self.newWorkoutObject = workout
                    self.showingNewWorkout = true
                }
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
        
        // Force a full refresh of the workout manager
        DispatchQueue.main.async {
            // Update the count explicitly 
            let count = self.workoutManager.fetchAllTemplates().count
            print("DEBUG: Final count of templates: \(count)")
        }
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
                
                return TemplateExerciseItem(name: name, order: Int(order))
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
                        ForEach(exercises) { exercise in
                            HStack {
                                Text(exercise.name)
                                
                                Spacer()
                                
                                Text("Sets: 3")
                                    .foregroundColor(.secondary)
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
                            dismiss()
                            // The parent view will handle starting the workout
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
                
                return TemplateExerciseItem(name: name, order: Int(order))
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
        
        // Add the new exercises
        for exercise in exercises {
            _ = workoutManager.addExercise(to: template, name: exercise.name)
        }
    }
} 