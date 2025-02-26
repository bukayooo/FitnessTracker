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
            
            ProgressTabView(workoutManager: workoutManager)
                .environment(\.managedObjectContext, viewContext)
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
    
    var body: some View {
        NavigationStack {
            VStack {
                if workoutManager.fetchAllTemplates().isEmpty {
                    EmptyStateView(
                        systemImage: "dumbbell",
                        title: "No Templates Yet",
                        message: "Create a workout template in the Templates tab to start tracking your workouts."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 16) {
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
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            
                            // Blank workout button
                            Button {
                                print("DEBUG: Creating blank workout")
                                createBlankWorkout()
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Blank Workout")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Recent Templates
                        Text("Recent Templates")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(workoutManager.fetchAllTemplates(), id: \.self) { template in
                                    TemplateCard(template: template)
                                        .onTapGesture {
                                            selectedTemplate = template.asIdentifiable
                                            showingTemplateSelector = false
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                    }
                    .padding(.top)
                }
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
            }
            .sheet(isPresented: $showingBlankWorkout) {
                if let workout = blankWorkout {
                    WorkoutView(
                        workout: workout,
                        workoutManager: self.workoutManager
                    )
                    .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }
    
    private func createBlankWorkout() {
        // Use the WorkoutManager to create a blank workout
        print("DEBUG: Creating blank workout")
        let workout = workoutManager.createBlankWorkout()
        
        // Set the blank workout and show it
        self.blankWorkout = workout
        self.showingBlankWorkout = true
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
        .frame(width: 150, height: 100)
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        ContentView()
            .environment(\.managedObjectContext, context)
    }
}

