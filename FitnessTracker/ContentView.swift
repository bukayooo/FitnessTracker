//
//  ContentView.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI
import CoreData
import Intents

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var workoutManager: WorkoutManager
    @StateObject private var session = ActiveWorkoutSession()
    @State private var selectedTab = 0  // Start with Templates tab to avoid interference
    @AppStorage("siriShortcutsEnabled") private var siriShortcutsEnabled = true

    init() {
        // Initialize WorkoutManager with the injected context
        let context = PersistenceController.shared.container.viewContext
        self._workoutManager = StateObject(wrappedValue: WorkoutManager(context: context))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                TemplatesView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(workoutManager)
                    .environmentObject(session)
                    .tabItem {
                        Label("Templates", systemImage: "list.bullet")
                    }
                    .tag(0)

                WorkoutTabView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(workoutManager)
                    .environmentObject(session)
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

            // Floating orb for a minimized workout — visible above every tab, including
            // Settings, since it's rendered here rather than inside any one tab's view.
            if session.isActive && session.isMinimized {
                WorkoutOrbView(session: session)
                    .padding(.trailing, 16)
                    .padding(.bottom, 78)
            }
        }
        // Single source of truth for presenting the active workout, regardless of
        // whether it was started from a template, a blank workout, or Siri. Using a
        // custom Binding (rather than tying isPresented straight to `isMinimized`)
        // means swiping the sheet down also minimizes instead of losing the workout.
        .sheet(isPresented: Binding(
            get: { session.isActive && !session.isMinimized },
            set: { isPresented in
                if !isPresented && session.isActive {
                    session.isMinimized = true
                }
            }
        )) {
            if let workout = session.workout {
                WorkoutView(workout: workout, workoutManager: workoutManager, timerManager: session.timerManager)
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(session)
            }
        }
        .onAppear {
            // Set the default tab to Workout after the view appears
            // This delay allows everything to be properly initialized first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectedTab = 1 // Switch to Workout tab
            }

            if siriShortcutsEnabled {
                SiriShortcutsManager.shared.donateGenericStartWorkoutIntent()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SiriStartWorkout"))) { notification in
            if let templateName = notification.userInfo?["templateName"] as? String {
                print("DEBUG: 🎤 ContentView received Siri start workout request for: \(templateName)")
                handleSiriWorkoutStart(templateName: templateName)
            }
        }
        // Consolidated here (rather than in each tab that can trigger a workout start)
        // so there's exactly one place that owns presenting the active workout sheet.
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StartWorkoutFromTemplate"))) { notification in
            guard let workout = notification.userInfo?["workout"] as? NSManagedObject else {
                print("DEBUG: StartWorkoutFromTemplate notification missing workout")
                return
            }
            guard workout.isValid, let freshWorkout = try? viewContext.existingObject(with: workout.objectID) else {
                print("DEBUG: Failed to load workout data from StartWorkoutFromTemplate notification")
                return
            }
            selectedTab = 1
            session.start(with: freshWorkout)
        }
    }

    private func handleSiriWorkoutStart(templateName: String) {
        guard !session.isActive else {
            print("DEBUG: 🎤 A workout is already in progress, bringing it back into view")
            selectedTab = 1
            session.isMinimized = false
            return
        }
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
    @EnvironmentObject var session: ActiveWorkoutSession
    @State private var showingTemplateSelector = false
    @State private var selectedTemplate: IdentifiableManagedObject?

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
                        if session.isActive {
                            print("DEBUG: Workout already in progress, restoring it instead of creating a blank one")
                            session.isMinimized = false
                        } else {
                            print("DEBUG: Creating blank workout")
                            createBlankWorkout()
                        }
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
                } else if workoutManager.fetchAllTemplates().isEmpty {
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
                            ForEach(workoutManager.fetchAllTemplates(), id: \.self) { template in
                                TemplateCard(template: template)
                                    .id(template.contentVersionID)
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
        }
        }
    }

    private func createBlankWorkout() {
        print("DEBUG: Creating blank workout in WorkoutTabView")

        // Set loading state
        isLoading = true
        errorMessage = nil
        showingError = false

        // workoutManager's context is main-queue-confined (NSPersistentContainer.viewContext),
        // so this must run on the main thread. Dispatching it to a background queue (as this
        // used to do) races with any concurrent main-thread Core Data access — e.g. a template
        // list re-rendering — and corrupts the context, crashing the app.
        let workout = workoutManager.createBlankWorkout()
        print("DEBUG: Blank workout created with ID: \(workout.objectID)")
        isLoading = false
        session.start(with: workout)
    }
}

// MARK: - Floating Workout Orb

/// Small floating button shown when a workout is minimized, so the user can
/// keep browsing other tabs while it keeps running and tap back into it.
struct WorkoutOrbView: View {
    let session: ActiveWorkoutSession
    // Observed directly (not read through `session`) because SwiftUI only re-renders
    // on @Published changes to objects it's directly observing — going through a
    // computed property on `session` wouldn't pick up TimerManager's own @Published
    // ticks, which is why the orb's clock used to appear frozen.
    @ObservedObject var timerManager: TimerManager

    init(session: ActiveWorkoutSession) {
        self.session = session
        self.timerManager = session.timerManager
    }

    private var isInWarmup: Bool {
        timerManager.isWarmupTimerActive
    }

    private var timeLabel: String {
        if isInWarmup {
            let minutes = timerManager.warmupTimeRemaining / 60
            let seconds = timerManager.warmupTimeRemaining % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        return timerManager.formattedWorkoutTime
    }

    var body: some View {
        Button {
            session.isMinimized = false
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isInWarmup ? "flame.fill" : "dumbbell.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(timeLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(.white)
            .frame(width: 60, height: 60)
            .background(Color.fitnessPrimary)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume Workout")
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
            
            Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
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
                ForEach(workoutManager.fetchAllTemplates(), id: \.self) { template in
                    TemplateSelectionRow(template: template)
                        .id(template.contentVersionID)
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
                
                Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
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

    // For WorkoutTemplate objects: an id that changes whenever the template's exercise
    // count changes, even though the object's own identity (objectID) doesn't. ForEach
    // and LazyVGrid reuse rows by id, so without this a template card's exercise count
    // can keep showing a stale number after an exercise is added or removed, since the
    // underlying NSManagedObject is mutated in place rather than replaced.
    var contentVersionID: String {
        let exerciseCount = (value(forKey: "exercises") as? NSSet)?.count ?? 0
        return "\(objectID.uriRepresentation())-\(exerciseCount)"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        ContentView()
            .environment(\.managedObjectContext, context)
    }
}

