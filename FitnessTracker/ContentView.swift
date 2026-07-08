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
    @State private var selectedTab = 0  // Start with Templates tab to avoid interference

    init() {
        // Initialize WorkoutManager with the injected context
        let context = PersistenceController.shared.container.viewContext
        self._workoutManager = StateObject(wrappedValue: WorkoutManager(context: context))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TemplatesView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(workoutManager)
                .tabItem {
                    Label("Templates", systemImage: "list.bullet")
                }
                .tag(0)
            
            WorkoutTabView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(workoutManager)
                .tabItem {
                    Label("Workout", systemImage: "dumbbell")
                }
                .tag(1)
            
            ProgressTabView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(workoutManager)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            // Set the default tab to Workout after the view appears
            // This delay allows everything to be properly initialized first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectedTab = 1 // Switch to Workout tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SiriStartWorkout"))) { notification in
            if let templateName = notification.userInfo?["templateName"] as? String {
                print("DEBUG: 🎤 ContentView received Siri start workout request for: \(templateName)")
                handleSiriWorkoutStart(templateName: templateName)
            }
        }
    }

    private func handleSiriWorkoutStart(templateName: String) {
        let templates = workoutManager.fetchAllTemplates()
        if let matchingTemplate = templates.first(where: { template in
            let name = template.value(forKey: "name") as? String ?? ""
            return name.lowercased() == templateName.lowercased()
        }) {
            print("DEBUG: 🎤 Found matching template: \(templateName)")
            if let newWorkout = workoutManager.startWorkout(from: matchingTemplate) {
                selectedTab = 1
                NotificationCenter.default.post(
                    name: Notification.Name("StartWorkoutFromTemplate"),
                    object: nil,
                    userInfo: ["workout": newWorkout]
                )
            }
        } else {
            print("DEBUG: 🎤 No matching template found for: \(templateName)")
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

    @AppStorage("workoutHeaderImageIndex") private var headerImageIndex: Int = 0
    @AppStorage("dailyScheduleEnabled") private var dailyScheduleEnabled = false
    @AppStorage("dailyScheduleAssignmentsVersion") private var assignmentsVersion = 0

    private var headerImageName: String {
        headerImageIndex == 0 ? "AchillesHeader" : "DestructionHeader"
    }

    private var todayAssignedTemplate: NSManagedObject? {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let assignments = UserDefaults.standard.dictionary(forKey: "dailyScheduleAssignments") as? [String: String] ?? [:]
        guard let uriString = assignments[String(weekday)],
              let uri = URL(string: uriString),
              let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri),
              let template = try? viewContext.existingObject(with: objectID) else { return nil }
        return template
    }

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 16) {
                // Error alert display
                if let error = errorMessage, showingError {
                    Text(error)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.fitnessError)
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
                        .background(Color.fitnessPrimary)
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
                        .background(isLoading ? Color.gray : Color.fitnessSuccess)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.top)

                if dailyScheduleEnabled {
                    // Daily schedule mode — show only today's template.
                    // .id(assignmentsVersion) forces re-creation whenever
                    // assignments are saved, ensuring todayAssignedTemplate
                    // is re-evaluated without needing an app restart.
                    VStack(alignment: .leading) {
                        Text("Today's Workout")
                            .font(.headline)
                            .padding(.horizontal)
                        if let template = todayAssignedTemplate {
                            TemplateCard(template: template)
                                .padding(.horizontal)
                                .onTapGesture {
                                    selectedTemplate = template.asIdentifiable
                                }
                        } else {
                            Text("No workout scheduled for today. Configure in Settings.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }
                    .id(assignmentsVersion)
                } else if workoutManager.templates.isEmpty {
                    EmptyStateView(
                        systemImage: "dumbbell",
                        title: "No Templates Yet",
                        message: "Create a workout template in the Templates tab to start tracking your workouts."
                    )
                } else {
                    // Recent Templates grid
                    VStack(alignment: .leading) {
                        Text("Recent Templates")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(workoutManager.templates, id: \.self) { template in
                                TemplateCard(template: template)
                                    .onTapGesture {
                                        selectedTemplate = template.asIdentifiable
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Alternating image (changes each app launch)
                // Use Color.clear as layout base so the image's scaled size
                // doesn't affect frame layout (fixes left-overflow on wide images)
                Color.clear
                    .overlay(
                        Image(headerImageName)
                            .resizable()
                            .scaledToFill()
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Text("\"Sing, O goddess, the anger of Achilles son of Peleus, that brought countless ills upon the Achaeans. Many a brave soul did it send hurrying down to Hades, and many a hero did it yield a prey to dogs and vultures, for so were the counsels of Jove fulfilled from the day on which the son of Atreus, king of men, and great Achilles, first fell out with one another.\"")
                    .font(.footnote)
                    .italic()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .navigationTitle("Workout")
            .sheet(isPresented: $showingTemplateSelector) {
                SelectTemplateView(selectedTemplate: $selectedTemplate)
            }
            .sheet(item: $selectedTemplate) { identifiableTemplate in
                TemplateDetailView(template: identifiableTemplate.object)
                    .environment(\.managedObjectContext, viewContext)
                    .onDisappear {
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
        .background(Color.fitnessCardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fitnessLightSlate.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SelectTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutManager: WorkoutManager
    @Binding var selectedTemplate: IdentifiableManagedObject?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workoutManager.templates, id: \.self) { template in
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

