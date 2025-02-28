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
    @EnvironmentObject var workoutManager: WorkoutManager
    
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
                        if searchText.isEmpty {
                            WorkoutHistorySection(
                                selectedWorkout: $selectedWorkout
                            )
                        }
                        
                        ExerciseProgressSection(
                            selectedExercise: $selectedExercise,
                            searchText: searchText
                        )
                    }
                    .listStyle(InsetGroupedListStyle())
                    .searchable(text: $searchText, prompt: "Search exercises")
                    .animation(.easeInOut, value: searchText)
                }
            }
            .navigationTitle("Progress")
            .sheet(item: $selectedWorkout) { identifiableWorkout in
                WorkoutDetailView(workout: identifiableWorkout.object)
            }
            .sheet(item: $selectedExercise) { identifiableExercise in
                ExerciseProgressDetailView(
                    exerciseName: identifiableExercise.value
                )
            }
        }
    }
}

// MARK: - Workout History Section
struct WorkoutHistorySection: View {
    @EnvironmentObject var workoutManager: WorkoutManager
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
            
            NavigationLink(destination: AllWorkoutsView()) {
                Text("See All Workouts")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Exercise Progress Section
struct ExerciseProgressSection: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @Binding var selectedExercise: IdentifiableString?
    @State private var allExercises: [String] = []
    var searchText: String = ""
    
    var filteredExercises: [String] {
        if searchText.isEmpty {
            return allExercises
        } else {
            return allExercises.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        Section(header: Text("Exercise Progress")) {
            VStack(spacing: 16) {
                ForEach(filteredExercises, id: \.self) { exerciseName in
                    ExerciseChartPreview(
                        exerciseName: exerciseName
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedExercise = IdentifiableString(value: exerciseName)
                    }
                }
                
                if filteredExercises.isEmpty && !searchText.isEmpty {
                    Text("No exercises found matching '\(searchText)'")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            allExercises = workoutManager.fetchUniqueExerciseNames()
        }
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
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var weightData: [(date: Date, weight: Double)] = []
    @State private var hasAttemptedLoad = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(exerciseName)
                .font(.headline)
                .lineLimit(1)
            
            if !hasAttemptedLoad {
                ProgressView()
                    .frame(height: 120)
            } else if weightData.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No workout data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            loadChartData()
        }
    }
    
    private func loadChartData() {
        print("DEBUG: Loading chart data for exercise: \(exerciseName)")
        // Find all workouts with this exercise
        let workouts = workoutManager.fetchWorkoutsContainingExercise(named: exerciseName)
        
        var dataPoints: [(date: Date, weight: Double)] = []
        var foundAnyCompletedSets = false
        
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
                    
                    if reps > 0 && weight > 0 {
                        foundAnyCompletedSets = true
                        if weight > maxWeight {
                            maxWeight = weight
                        }
                    }
                }
            }
            
            if maxWeight > 0 {
                dataPoints.append((date: date, weight: maxWeight))
            }
        }
        
        // Sort by date and take up to 10 most recent
        weightData = dataPoints.sorted { $0.date < $1.date }.suffix(10)
        hasAttemptedLoad = true
        
        print("DEBUG: Found \(dataPoints.count) data points for \(exerciseName), any completed sets: \(foundAnyCompletedSets)")
    }
}

// MARK: - All Workouts View
struct AllWorkoutsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
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
    @Environment(\.dismiss) private var dismiss
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
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Exercise Progress Detail View
struct ExerciseProgressDetailView: View {
    let exerciseName: String
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var weightData: [(date: Date, weight: Double)] = []
    @State private var selectedTimeRange: TimeRange = .allTime
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case sixMonths = "6 Months"
        case allTime = "All Time"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if weightData.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Complete more workouts with this exercise to see progress")
                    )
                } else {
                    // Time range picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: selectedTimeRange) { oldValue, newValue in
                        loadChartData()
                    }
                    
                    // Chart
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
                            .annotation(position: .top) {
                                Text("\(Int(dataPoint.weight))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                    .frame(height: 300)
                    .padding()
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis {
                        AxisMarks { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    switch selectedTimeRange {
                                    case .week:
                                        Text(date, format: .dateTime.weekday(.abbreviated))
                                    case .month:
                                        Text(date, format: .dateTime.day())
                                    case .sixMonths:
                                        Text(date, format: .dateTime.month(.abbreviated))
                                    case .allTime:
                                        Text(date, format: .dateTime.month(.narrow))
                                    }
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            if let weight = value.as(Double.self) {
                                AxisValueLabel {
                                    Text("\(Int(weight))")
                                }
                            }
                        }
                    }
                    
                    // Stats view
                    ExerciseStatsView(weightData: weightData)
                        .padding()
                }
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadChartData()
            }
        }
    }
    
    private func loadChartData() {
        // Get cutoff date based on selected time range
        let calendar = Calendar.current
        let now = Date()
        
        let cutoffDate: Date? = {
            switch selectedTimeRange {
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: now)
            case .sixMonths:
                return calendar.date(byAdding: .month, value: -6, to: now)
            case .allTime:
                return nil
            }
        }()
        
        var data: [(date: Date, weight: Double)] = []
        
        for workout in workoutManager.fetchAllWorkouts() {
            guard let workoutDate = workout.value(forKey: "date") as? Date else { continue }
            
            // Skip workouts before cutoff date
            if let cutoff = cutoffDate, workoutDate < cutoff {
                continue
            }
            
            if let exercises = workout.value(forKey: "exercises") as? NSSet {
                for case let exercise as NSManagedObject in exercises {
                    guard let name = exercise.value(forKey: "name") as? String,
                          name == exerciseName else { continue }
                    
                    var maxWeightForExercise = 0.0
                    
                    if let sets = exercise.value(forKey: "sets") as? NSSet {
                        for case let setObj as NSManagedObject in sets {
                            if let weight = setObj.value(forKey: "weight") as? Double,
                               let reps = setObj.value(forKey: "reps") as? Int16,
                               reps > 0 && weight > maxWeightForExercise {
                                maxWeightForExercise = weight
                            }
                        }
                    }
                    
                    if maxWeightForExercise > 0 {
                        // Normalize the date based on selected time range to group data better
                        let normalizedDate: Date
                        if selectedTimeRange == .allTime || selectedTimeRange == .sixMonths {
                            // For longer time ranges, group by day of month
                            normalizedDate = calendar.startOfDay(for: workoutDate)
                        } else {
                            // For shorter time ranges, use exact date and time
                            normalizedDate = workoutDate
                        }
                        
                        data.append((date: normalizedDate, weight: maxWeightForExercise))
                    }
                }
            }
        }
        
        // Sort by date and remove duplicates (keep highest weight for each date)
        let groupedByDate = Dictionary(grouping: data, by: { $0.date })
        let maxWeightByDate = groupedByDate.mapValues { dateWeights in
            dateWeights.max(by: { $0.weight < $1.weight })!
        }
        
        weightData = Array(maxWeightByDate.values).sorted(by: { $0.date < $1.date })
    }
}

// MARK: - Exercise Stats View
struct ExerciseStatsView: View {
    let weightData: [(date: Date, weight: Double)]
    
    private var maxWeight: Double {
        weightData.max(by: { $0.weight < $1.weight })?.weight ?? 0
    }
    
    private var averageWeight: Double {
        guard !weightData.isEmpty else { return 0 }
        let sum = weightData.reduce(0) { $0 + $1.weight }
        return sum / Double(weightData.count)
    }
    
    private var progress: Double {
        guard weightData.count >= 2 else { return 0 }
        let first = weightData.first!.weight
        let last = weightData.last!.weight
        return last - first
    }
    
    private var progressPercentage: Double {
        guard weightData.count >= 2 else { return 0 }
        let first = weightData.first!.weight
        guard first > 0 else { return 0 }
        return (progress / first) * 100
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Stats")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "Max Weight", value: String(format: "%.1f", maxWeight))
                StatCard(title: "Average Weight", value: String(format: "%.1f", averageWeight))
                
                if weightData.count >= 2 {
                    StatCard(
                        title: "Progress",
                        value: String(format: "%+.1f", progress),
                        detail: String(format: "%+.1f%%", progressPercentage)
                    )
                    
                    StatCard(
                        title: "Timespan",
                        value: formatTimespan(
                            from: weightData.first!.date,
                            to: weightData.last!.date
                        )
                    )
                }
            }
        }
    }
    
    private func formatTimespan(from startDate: Date, to endDate: Date) -> String {
        let components = Calendar.current.dateComponents([.day], from: startDate, to: endDate)
        guard let days = components.day else { return "N/A" }
        
        if days < 30 {
            return "\(days) days"
        } else if days < 365 {
            let months = days / 30
            return "\(months) months"
        } else {
            let years = Double(days) / 365.0
            return String(format: "%.1f years", years)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    var detail: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .bold()
            
            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(detail.hasPrefix("+") ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ProgressView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var exerciseNames: [String] = []
    @State private var selectedExerciseName: String?
    @State private var showingExerciseDetail = false
    
    var body: some View {
        NavigationView {
            VStack {
                if exerciseNames.isEmpty {
                    ContentUnavailableView(
                        "No Exercise Data",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Complete workouts to see your progress")
                    )
                } else {
                    List {
                        ForEach(exerciseNames, id: \.self) { name in
                            Button(action: {
                                selectedExerciseName = name
                                showingExerciseDetail = true
                            }) {
                                HStack {
                                    Text(name)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $showingExerciseDetail) {
                        if let exerciseName = selectedExerciseName {
                            ExerciseProgressDetailView(exerciseName: exerciseName)
                        }
                    }
                }
            }
            .navigationTitle("Exercise Progress")
            .onAppear {
                exerciseNames = workoutManager.fetchUniqueExerciseNames()
            }
        }
    }
}
