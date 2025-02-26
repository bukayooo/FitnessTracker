//
//  ProgressView.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI
import CoreData
import Charts

// Create a wrapper for String to use with sheet(item:)
struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}

struct ProgressTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var workoutManager: WorkoutManager
    
    @State private var selectedWorkout: IdentifiableManagedObject?
    @State private var selectedExercise: IdentifiableString?
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if workoutManager.fetchAllWorkouts().isEmpty {
                    // Empty state
                    EmptyStateView(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "No Workouts Yet",
                        message: "Complete your first workout to start tracking your progress."
                    )
                } else {
                    // Progress sections
                    List {
                        WorkoutHistorySection(
                            workoutManager: workoutManager,
                            selectedWorkout: $selectedWorkout
                        )
                        
                        ExerciseProgressSection(
                            workoutManager: workoutManager,
                            selectedExercise: $selectedExercise
                        )
                    }
                    .listStyle(InsetGroupedListStyle())
                    .searchable(text: $searchText, prompt: "Search workouts")
                }
            }
            .navigationTitle("Progress")
            .sheet(item: $selectedWorkout) { identifiableWorkout in
                WorkoutDetailView(workout: identifiableWorkout.object)
            }
            .sheet(item: $selectedExercise) { identifiableExercise in
                ExerciseProgressDetailView(
                    exerciseName: identifiableExercise.value,
                    workoutManager: workoutManager
                )
            }
        }
    }
}

// MARK: - Workout History Section
struct WorkoutHistorySection: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Binding var selectedWorkout: IdentifiableManagedObject?
    
    var body: some View {
        Section(header: Text("Workout History")) {
            ForEach(workoutManager.fetchAllWorkouts().prefix(5), id: \.self) { workout in
                WorkoutHistoryRow(workout: workout)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedWorkout = workout.asIdentifiable
                    }
            }
            
            NavigationLink(destination: AllWorkoutsView(workoutManager: workoutManager)) {
                Text("See All Workouts")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Exercise Progress Section
struct ExerciseProgressSection: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Binding var selectedExercise: IdentifiableString?
    @State private var allExercises: [String] = []
    
    var body: some View {
        Section(header: Text("Exercise Progress")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(getUniqueExerciseNames(), id: \.self) { exerciseName in
                        ExerciseChartPreview(
                            exerciseName: exerciseName,
                            workoutManager: workoutManager
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedExercise = IdentifiableString(value: exerciseName)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .frame(height: 200)
        }
    }
    
    private func getUniqueExerciseNames() -> [String] {
        // Get all unique exercise names from workout history
        var uniqueNames = Set<String>()
        
        for workout in workoutManager.fetchAllWorkouts() {
            if let exercises = workout.value(forKey: "exercises") as? NSSet {
                for case let exercise as NSManagedObject in exercises {
                    if let name = exercise.value(forKey: "name") as? String {
                        uniqueNames.insert(name)
                    }
                }
            }
        }
        
        return Array(uniqueNames).sorted()
    }
}

// MARK: - Workout History Row
struct WorkoutHistoryRow: View {
    let workout: NSManagedObject
    
    private var templateName: String {
        if let template = workout.value(forKey: "template") as? NSManagedObject {
            return template.value(forKey: "name") as? String ?? "Custom Workout"
        }
        return "Custom Workout"
    }
    
    private var exerciseCount: Int {
        if let exercises = workout.value(forKey: "exercises") as? NSSet {
            return exercises.count
        }
        return 0
    }
    
    private var formattedDate: String {
        if let date = workout.value(forKey: "date") as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "Unknown date"
    }
    
    private var formattedDuration: String {
        let totalSeconds = Int(workout.value(forKey: "duration") as? Int32 ?? 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(templateName)
                .font(.headline)
            
            HStack {
                Label("\(exerciseCount) exercises", systemImage: "dumbbell")
                
                Spacer()
                
                Label(formattedDate, systemImage: "calendar")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            HStack {
                Spacer()
                Label(formattedDuration, systemImage: "timer")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Exercise Chart Preview
struct ExerciseChartPreview: View {
    let exerciseName: String
    let workoutManager: WorkoutManager
    @State private var weightData: [(date: Date, weight: Double)] = []
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(exerciseName)
                .font(.headline)
                .lineLimit(1)
            
            if weightData.isEmpty {
                ProgressView()
                    .frame(height: 120)
            } else {
                Chart {
                    ForEach(weightData, id: \.date) { dataPoint in
                        LineMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Weight", dataPoint.weight)
                        )
                        .foregroundStyle(.blue)
                        
                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Weight", dataPoint.weight)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 120)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .frame(width: 200)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            loadChartData()
        }
    }
    
    private func loadChartData() {
        // Find all workouts with this exercise
        let workouts = workoutManager.fetchWorkoutsContainingExercise(named: exerciseName)
        
        var dataPoints: [(date: Date, weight: Double)] = []
        
        for workout in workouts {
            guard let date = workout.value(forKey: "date") as? Date,
                  let exercises = workout.value(forKey: "exercises") as? NSSet else {
                continue
            }
            
            // Find the maximum weight used for this exercise in the workout
            var maxWeight = 0.0
            
            for case let workoutExercise as NSManagedObject in exercises {
                guard let name = workoutExercise.value(forKey: "name") as? String,
                      name == exerciseName,
                      let sets = workoutExercise.value(forKey: "sets") as? NSSet else {
                    continue
                }
                
                for case let set as NSManagedObject in sets {
                    let weight = set.value(forKey: "weight") as? Double ?? 0.0
                    let reps = set.value(forKey: "reps") as? Int16 ?? 0
                    
                    if reps > 0 && weight > maxWeight {
                        maxWeight = weight
                    }
                }
            }
            
            if maxWeight > 0 {
                dataPoints.append((date: date, weight: maxWeight))
            }
        }
        
        // Sort by date and take up to 10 most recent
        weightData = dataPoints.sorted { $0.date < $1.date }.suffix(10)
    }
}

// MARK: - All Workouts View
struct AllWorkoutsView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @State private var selectedWorkout: IdentifiableManagedObject?
    @State private var searchText = ""
    
    var body: some View {
        List {
            ForEach(filteredWorkouts, id: \.self) { workout in
                WorkoutHistoryRow(workout: workout)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedWorkout = workout.asIdentifiable
                    }
            }
        }
        .navigationTitle("All Workouts")
        .sheet(item: $selectedWorkout) { identifiableWorkout in
            WorkoutDetailView(workout: identifiableWorkout.object)
        }
    }
    
    private var filteredWorkouts: [NSManagedObject] {
        let workouts = workoutManager.fetchAllWorkouts()
        
        if searchText.isEmpty {
            return workouts
        } else {
            return workouts.filter { workout in
                if let template = workout.value(forKey: "template") as? NSManagedObject,
                   let name = template.value(forKey: "name") as? String {
                    return name.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }
    }
}

// MARK: - Workout Detail View
struct WorkoutDetailView: View {
    let workout: NSManagedObject
    
    private var templateName: String {
        if let template = workout.value(forKey: "template") as? NSManagedObject {
            return template.value(forKey: "name") as? String ?? "Custom Workout"
        }
        return "Custom Workout"
    }
    
    private var formattedDate: String {
        if let date = workout.value(forKey: "date") as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "Unknown date"
    }
    
    private var formattedDuration: String {
        let totalSeconds = Int(workout.value(forKey: "duration") as? Int32 ?? 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private var exercises: [NSManagedObject] {
        if let exercisesSet = workout.value(forKey: "exercises") as? NSSet {
            let exercises = exercisesSet.allObjects as? [NSManagedObject] ?? []
            return exercises.sorted { 
                let order1 = $0.value(forKey: "order") as? Int16 ?? 0
                let order2 = $1.value(forKey: "order") as? Int16 ?? 0
                return order1 < order2
            }
        }
        return []
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Workout summary
                Section(header: Text("Workout Summary")) {
                    HStack {
                        Text("Template")
                        Spacer()
                        Text(templateName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(formattedDate)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formattedDuration)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Exercises
                ForEach(exercises, id: \.self) { exercise in
                    Section(header: Text(exercise.value(forKey: "name") as? String ?? "")) {
                        if let sets = exercise.value(forKey: "sets") as? NSSet {
                            let sortedSets = (sets.allObjects as? [NSManagedObject] ?? []).sorted {
                                let num1 = $0.value(forKey: "setNumber") as? Int16 ?? 0
                                let num2 = $1.value(forKey: "setNumber") as? Int16 ?? 0
                                return num1 < num2
                            }
                            
                            ForEach(sortedSets, id: \.self) { set in
                                HStack {
                                    Text("Set \(set.value(forKey: "setNumber") as? Int16 ?? 0 + 1)")
                                    Spacer()
                                    Text("\(set.value(forKey: "reps") as? Int16 ?? 0) reps × \(String(format: "%.1f", set.value(forKey: "weight") as? Double ?? 0.0))")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // No action needed, sheet will dismiss
                    }
                }
            }
        }
    }
}

// MARK: - Exercise Progress Detail View
struct ExerciseProgressDetailView: View {
    let exerciseName: String
    let workoutManager: WorkoutManager
    
    @State private var timeRange: TimeRange = .allTime
    @State private var weightData: [(date: Date, weight: Double)] = []
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth = "1 Month"
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case oneYear = "1 Year"
        case allTime = "All Time"
        
        var id: String { self.rawValue }
        
        var daysBack: Int? {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            case .allTime: return nil
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Time range picker
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Chart
                if weightData.isEmpty {
                    Text("No data available for this exercise")
                        .foregroundColor(.secondary)
                        .frame(maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading) {
                        Text("Maximum Weight Progression")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(weightData, id: \.date) { dataPoint in
                                LineMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Weight", dataPoint.weight)
                                )
                                .foregroundStyle(.blue)
                                
                                PointMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Weight", dataPoint.weight)
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                        .frame(height: 300)
                        .padding()
                        .chartYScale(domain: .automatic(includesZero: false))
                    }
                    
                    // Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statistics")
                            .font(.headline)
                        
                        HStack {
                            StatCard(
                                title: "Current Max",
                                value: String(format: "%.1f", weightData.last?.weight ?? 0)
                            )
                            
                            StatCard(
                                title: "Best",
                                value: String(format: "%.1f", weightData.max(by: { $0.weight < $1.weight })?.weight ?? 0)
                            )
                        }
                        
                        HStack {
                            StatCard(
                                title: "Progress",
                                value: calculateProgressPercentage()
                            )
                            
                            StatCard(
                                title: "Workouts",
                                value: "\(weightData.count)"
                            )
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // No action needed, sheet will dismiss
                    }
                }
            }
            .onChange(of: timeRange) { oldValue, newValue in
                loadChartData()
            }
            .onAppear {
                loadChartData()
            }
        }
    }
    
    private func loadChartData() {
        // Filter workouts by exercise name
        let workouts = workoutManager.fetchWorkoutsContainingExercise(named: exerciseName)
        
        var dataPoints: [(date: Date, weight: Double)] = []
        
        for workout in workouts {
            guard let date = workout.value(forKey: "date") as? Date,
                  let exercises = workout.value(forKey: "exercises") as? NSSet else {
                continue
            }
            
            // Filter by time range
            if let daysBack = timeRange.daysBack {
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date())!
                if date < cutoffDate {
                    continue
                }
            }
            
            // Find the maximum weight for this exercise
            var maxWeight = 0.0
            
            for case let workoutExercise as NSManagedObject in exercises {
                guard let name = workoutExercise.value(forKey: "name") as? String,
                      name == exerciseName,
                      let sets = workoutExercise.value(forKey: "sets") as? NSSet else {
                    continue
                }
                
                for case let set as NSManagedObject in sets {
                    let weight = set.value(forKey: "weight") as? Double ?? 0.0
                    let reps = set.value(forKey: "reps") as? Int16 ?? 0
                    
                    if reps > 0 && weight > maxWeight {
                        maxWeight = weight
                    }
                }
            }
            
            if maxWeight > 0 {
                dataPoints.append((date: date, weight: maxWeight))
            }
        }
        
        // Sort by date
        weightData = dataPoints.sorted { $0.date < $1.date }
    }
    
    private func calculateProgressPercentage() -> String {
        guard weightData.count >= 2 else {
            return "N/A"
        }
        
        let firstWeight = weightData.first?.weight ?? 0
        let lastWeight = weightData.last?.weight ?? 0
        
        if firstWeight == 0 {
            return "N/A"
        }
        
        let percentage = ((lastWeight - firstWeight) / firstWeight) * 100
        return String(format: "%.1f%%", percentage)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
} 