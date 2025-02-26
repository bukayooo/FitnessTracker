//
//  ContentView.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var workoutManager: WorkoutManager
    
    init() {
        // Initialize WorkoutManager with the injected context
        let context = PersistenceController.shared.container.viewContext
        self._workoutManager = StateObject(wrappedValue: WorkoutManager(context: context))
    }
    
    var body: some View {
        TabView {
            TemplatesView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(workoutManager)
                .tabItem {
                    Label("Templates", systemImage: "list.bullet")
                }
            
            WorkoutTabView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(workoutManager)
                .tabItem {
                    Label("Workout", systemImage: "dumbbell")
                }
            
            ProgressTabView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(workoutManager)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
    }
}

// MARK: - Workout Tab View
struct WorkoutTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var showingTemplateSelector = false
    @State private var selectedTemplate: IdentifiableManagedObject?
    
    // Add state for blank workout
    @State private var showingBlankWorkout = false
    @State private var blankWorkout: NSManagedObject?
    
    // Track loading state
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Error alert display
                if let error = errorMessage, showingError {
                    Text(error)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                showingError = false
                            }
                        }
                }
                
                // Start Workout Button row - template selector and blank workout options
                HStack(spacing: 12) {
                    // Template workout button
                    Button {
                        showingTemplateSelector = true
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("From Template")
                                .fontWeight(.semibold)
                                .font(.system(size: 14))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .padding(.horizontal)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    
                    // Blank workout button
                    Button {
                        print("DEBUG: Creating blank workout")
                        createBlankWorkout()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "plus")
                            }
                            Text("Blank Workout")
                                .fontWeight(.semibold)
                                .font(.system(size: 14))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .padding(.horizontal)
                        .background(isLoading ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.top)
                
                if workoutManager.fetchAllTemplates().isEmpty {
                    EmptyStateView(
                        systemImage: "dumbbell",
                        title: "No Templates Yet",
                        message: "Create a workout template in the Templates tab to start tracking your workouts."
                    )
                } else {
                    // Recent Templates
                    VStack(alignment: .leading) {
                        Text("Recent Templates")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Replace horizontal scroll with a 2-column grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(workoutManager.fetchAllTemplates(), id: \.self) { template in
                                TemplateCard(template: template)
                                    .onTapGesture {
                                        selectedTemplate = template.asIdentifiable
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Workout")
            .sheet(isPresented: $showingTemplateSelector) {
                SelectTemplateView(selectedTemplate: $selectedTemplate)
            }
            .sheet(item: $selectedTemplate) { identifiableTemplate in
                // Explicitly create the WorkoutView with all required parameters
                WorkoutView(
                    workout: identifiableTemplate.object,
                    workoutManager: self.workoutManager
                )
                .environment(\.managedObjectContext, viewContext)
                .onDisappear {
                    // Reset selectedTemplate to prevent reuse of stale data
                    selectedTemplate = nil
                }
            }
            .sheet(isPresented: $showingBlankWorkout) {
                if let workout = blankWorkout {
                    WorkoutView(
                        workout: workout,
                        workoutManager: self.workoutManager
                    )
                    .environment(\.managedObjectContext, viewContext)
                    .onDisappear {
                        // Reset blankWorkout to prevent reuse of stale data
                        blankWorkout = nil
                        showingBlankWorkout = false
                    }
                }
            }
        }
    }
    
    private func createBlankWorkout() {
        print("DEBUG: Creating blank workout in WorkoutTabView")
        
        // Set loading state
        isLoading = true
        errorMessage = nil
        showingError = false
        
        // Make sure we're creating fresh instances
        blankWorkout = nil
        showingBlankWorkout = false
        
        // Create the new workout in a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Create workout on background thread
            let workout = self.workoutManager.createBlankWorkout()
            
            // Switch back to main thread for UI updates
            DispatchQueue.main.async {
                print("DEBUG: Blank workout created with ID: \(workout.objectID)")
                
                // Set the blank workout
                self.blankWorkout = workout
                
                // Delay slightly to ensure the context has time to fully process
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isLoading = false
                    self.showingBlankWorkout = true
                }
            }
        }
    }
}

struct TemplateCard: View {
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
        VStack(alignment: .leading, spacing: 8) {
            Text(templateName)
                .font(.headline)
                .lineLimit(1)
            
            Text("\(exerciseCount) exercises")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct SelectTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutManager: WorkoutManager
    @Binding var selectedTemplate: IdentifiableManagedObject?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workoutManager.fetchAllTemplates(), id: \.self) { template in
                    TemplateSelectionRow(template: template)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTemplate = template.asIdentifiable
                            dismiss()
                        }
                }
            }
            .navigationTitle("Select Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TemplateSelectionRow: View {
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
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Helper extension for making NSManagedObject Identifiable
// This wrapper approach avoids extending NSManagedObject directly
struct IdentifiableManagedObject: Identifiable {
    let object: NSManagedObject
    var id: NSManagedObjectID { object.objectID }
}

extension NSManagedObject {
    // Helper to convert to identifiable version
    var asIdentifiable: IdentifiableManagedObject {
        IdentifiableManagedObject(object: self)
    }
    
    // Helper to check if an object is valid
    var isValid: Bool {
        return !isDeleted && managedObjectContext != nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        ContentView()
            .environment(\.managedObjectContext, context)
    }
}

