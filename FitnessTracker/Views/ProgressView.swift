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
                    .foregroundColor(.fitnessPrimary)
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
                Label("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")", systemImage: "dumbbell")
                
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

// MARK: - Volume Metric
/// Progress charts track **volume** rather than top-set weight, so adding reps at
/// the same weight still registers as progress.
///
/// Bodyweight exercises (pull-ups, dips, push-ups) are logged with a weight of 0,
/// which would make weight × reps collapse to zero for every session. For those,
/// volume falls back to total reps — the only load signal available — and the
/// charts relabel their unit to match.
enum VolumeMetric {
    enum Unit {
        case pounds
        case reps

        /// Short label for chart subtitles and captions.
        var label: String {
            switch self {
            case .pounds: return "lbs"
            case .reps: return "reps"
            }
        }

        /// Longer description of how the number is derived.
        var description: String {
            switch self {
            case .pounds: return "Volume (weight × reps, lbs)"
            case .reps: return "Volume (total reps)"
            }
        }
    }

    /// Whether an exercise is tracked in pounds or reps, decided from its whole
    /// history: if it has ever been logged with added weight it is a weighted
    /// exercise, otherwise it is bodyweight.
    ///
    /// Deciding once per exercise (rather than per workout) keeps the y-axis in a
    /// single unit — mixing lbs and reps in one series would make the line
    /// meaningless.
    static func unit(of exerciseName: String, across workouts: [NSManagedObject]) -> Unit {
        for workout in workouts {
            guard let exercises = workout.value(forKey: "exercises") as? NSSet else { continue }

            for case let workoutExercise as NSManagedObject in exercises {
                guard let name = workoutExercise.value(forKey: "name") as? String,
                      name == exerciseName,
                      let sets = workoutExercise.value(forKey: "sets") as? NSSet else {
                    continue
                }

                for case let setObj as NSManagedObject in sets {
                    let weight = setObj.value(forKey: "weight") as? Double ?? 0.0
                    let reps = setObj.value(forKey: "reps") as? Int16 ?? 0

                    if reps > 0 && weight > 0 {
                        return .pounds
                    }
                }
            }
        }
        return .reps
    }

    /// Total volume for `exerciseName` within a single workout, in `unit`. Sets
    /// with zero reps are skipped, and an exercise appearing more than once in a
    /// workout has its entries summed.
    static func volume(of exerciseName: String, in workout: NSManagedObject, unit: Unit) -> Double {
        guard let exercises = workout.value(forKey: "exercises") as? NSSet else { return 0 }

        var total = 0.0
        for case let workoutExercise as NSManagedObject in exercises {
            guard let name = workoutExercise.value(forKey: "name") as? String,
                  name == exerciseName,
                  let sets = workoutExercise.value(forKey: "sets") as? NSSet else {
                continue
            }

            for case let setObj as NSManagedObject in sets {
                let weight = setObj.value(forKey: "weight") as? Double ?? 0.0
                let reps = setObj.value(forKey: "reps") as? Int16 ?? 0

                guard reps > 0 else { continue }

                switch unit {
                case .pounds:
                    if weight > 0 {
                        total += weight * Double(reps)
                    }
                case .reps:
                    total += Double(reps)
                }
            }
        }
        return total
    }

    /// Full value with thousands separators, e.g. "4,050".
    static func format(_ volume: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: volume)) ?? String(Int(volume))
    }

    /// Space-constrained value for chart annotations and axis labels, e.g. "4.1k".
    static func formatCompact(_ volume: Double) -> String {
        if volume >= 10_000 {
            return String(format: "%.0fk", volume / 1_000)
        } else if volume >= 1_000 {
            return String(format: "%.1fk", volume / 1_000)
        }
        return String(Int(volume))
    }
}

// MARK: - Exercise Chart Preview
struct ExerciseChartPreview: View {
    let exerciseName: String
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var volumeData: [(date: Date, volume: Double)] = []
    @State private var unit: VolumeMetric.Unit = .pounds
    @State private var hasAttemptedLoad = false

    var body: some View {
        VStack(alignment: .leading) {
            Text(exerciseName)
                .font(.headline)
                .lineLimit(1)

            Text("Volume (\(unit.label))")
                .font(.caption)
                .foregroundColor(.secondary)

            if !hasAttemptedLoad {
                // Fully qualified: this file also declares a type named ProgressView,
                // which would otherwise shadow the SwiftUI spinner.
                SwiftUI.ProgressView()
                    .frame(height: 120)
            } else if volumeData.isEmpty {
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
                    ForEach(volumeData, id: \.date) { dataPoint in
                        LineMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Volume", dataPoint.volume)
                        )
                        .foregroundStyle(Color.fitnessPrimary)

                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Volume", dataPoint.volume)
                        )
                        .foregroundStyle(Color.fitnessPrimary)
                    }
                }
                .frame(height: 120)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let volume = value.as(Double.self) {
                                Text(VolumeMetric.formatCompact(volume))
                            }
                        }
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
        let resolvedUnit = VolumeMetric.unit(of: exerciseName, across: workouts)
        unit = resolvedUnit

        var dataPoints: [(date: Date, volume: Double)] = []

        for workout in workouts {
            guard let date = workout.value(forKey: "date") as? Date else { continue }

            let volume = VolumeMetric.volume(of: exerciseName, in: workout, unit: resolvedUnit)
            if volume > 0 {
                dataPoints.append((date: date, volume: volume))
            }
        }

        // Sort by date and take up to 10 most recent
        volumeData = dataPoints.sorted { $0.date < $1.date }.suffix(10)
        hasAttemptedLoad = true

        print("DEBUG: Found \(dataPoints.count) volume data points for \(exerciseName)")
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

    private func heatColor(_ rating: Int) -> Color {
        switch rating {
        case 1...3: return .green
        case 4...6: return .orange
        case 7...8: return Color(red: 1.0, green: 0.4, blue: 0.0)
        default:    return .red
        }
    }

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
                                let heat = UserDefaults.standard.integer(
                                    forKey: "heat_\(set.objectID.uriRepresentation().absoluteString)"
                                )
                                HStack {
                                    Text("Set \((set.value(forKey: "setNumber") as? Int16 ?? 0) + 1)")
                                    Spacer()
                                    Text("\(set.value(forKey: "reps") as? Int16 ?? 0) reps × \(String(format: "%.1f", set.value(forKey: "weight") as? Double ?? 0.0)) lbs")
                                        .foregroundColor(.secondary)
                                    if heat > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "flame.fill")
                                                .font(.caption2)
                                            Text("\(heat)")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(heatColor(heat))
                                    }
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

// MARK: - Post-Workout Progress View
/// Shown right after completing a workout: the same "Exercise Progress" charts
/// from the Progress tab, filtered to just the exercises in the workout that was
/// finished, so today's numbers can be seen against the recent past.
struct WorkoutProgressSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var workoutManager: WorkoutManager
    let workout: NSManagedObject

    @State private var selectedExercise: IdentifiableString?

    /// Exercise names in the order they appear in the completed workout, de-duplicated.
    private var exerciseNames: [String] {
        guard let exercisesSet = workout.value(forKey: "exercises") as? NSSet,
              let exercises = exercisesSet.allObjects as? [NSManagedObject] else {
            return []
        }

        let sorted = exercises.sorted {
            let order1 = $0.value(forKey: "order") as? Int16 ?? 0
            let order2 = $1.value(forKey: "order") as? Int16 ?? 0
            return order1 < order2
        }

        var seen = Set<String>()
        var names: [String] = []
        for exercise in sorted {
            guard let name = exercise.value(forKey: "name") as? String, !name.isEmpty else { continue }
            if seen.insert(name).inserted {
                names.append(name)
            }
        }
        return names
    }

    var body: some View {
        NavigationStack {
            Group {
                if exerciseNames.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("This workout didn't record any exercises to chart.")
                    )
                } else {
                    List {
                        Section {
                            VStack(spacing: 16) {
                                ForEach(exerciseNames, id: \.self) { exerciseName in
                                    VStack(spacing: 0) {
                                        ExerciseChartPreview(exerciseName: exerciseName)

                                        TodaysResultCaption(
                                            exerciseName: exerciseName,
                                            completedWorkout: workout
                                        )
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedExercise = IdentifiableString(value: exerciseName)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        } header: {
                            Text("Exercise Progress")
                        } footer: {
                            Text("Tap an exercise to see its full history.")
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedExercise) { identifiableExercise in
                ExerciseProgressDetailView(exerciseName: identifiableExercise.value)
                    .environmentObject(workoutManager)
            }
        }
    }
}

// MARK: - Today's Result Caption
/// One-line comparison of today's volume against the previous time this exercise
/// was trained.
private struct TodaysResultCaption: View {
    let exerciseName: String
    let completedWorkout: NSManagedObject

    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var todaysVolume: Double = 0
    @State private var previousVolume: Double?
    @State private var unit: VolumeMetric.Unit = .pounds
    @State private var hasLoaded = false

    private var delta: Double? {
        guard let previous = previousVolume, previous > 0 else { return nil }
        return todaysVolume - previous
    }

    private var deltaPercentage: Double? {
        guard let previous = previousVolume, previous > 0, let delta = delta else { return nil }
        return (delta / previous) * 100
    }

    var body: some View {
        Group {
            if todaysVolume > 0 {
                HStack(spacing: 6) {
                    Text("Today: \(VolumeMetric.format(todaysVolume)) \(unit.label)")
                        .fontWeight(.semibold)

                    if hasLoaded, let delta = delta, let percentage = deltaPercentage {
                        if delta > 0 {
                            Label(
                                "\(VolumeMetric.format(delta)) (\(String(format: "%+.0f%%", percentage)))",
                                systemImage: "arrow.up.right"
                            )
                            .foregroundColor(.green)
                        } else if delta < 0 {
                            Label(
                                "\(VolumeMetric.format(abs(delta))) (\(String(format: "%+.0f%%", percentage)))",
                                systemImage: "arrow.down.right"
                            )
                            .foregroundColor(.red)
                        } else {
                            Label("Same as last time", systemImage: "equal")
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .font(.caption)
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .onAppear(perform: loadVolumes)
    }

    private func loadVolumes() {
        guard !hasLoaded else { return }

        let workouts = workoutManager.fetchWorkoutsContainingExercise(named: exerciseName)
        let resolvedUnit = VolumeMetric.unit(of: exerciseName, across: workouts)
        unit = resolvedUnit
        todaysVolume = VolumeMetric.volume(of: exerciseName, in: completedWorkout, unit: resolvedUnit)

        // fetchWorkoutsContainingExercise returns newest first; skip the workout
        // that was just completed so we compare against the previous session.
        for workout in workouts {
            if workout.objectID == completedWorkout.objectID { continue }

            let volume = VolumeMetric.volume(of: exerciseName, in: workout, unit: resolvedUnit)
            if volume > 0 {
                previousVolume = volume
                break
            }
        }

        hasLoaded = true
    }
}

// MARK: - Exercise Progress Detail View
struct ExerciseProgressDetailView: View {
    let exerciseName: String
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var volumeData: [(date: Date, volume: Double)] = []
    @State private var unit: VolumeMetric.Unit = .pounds
    @State private var selectedTimeRange: TimeRange = .allTime

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case sixMonths = "6 Months"
        case allTime = "All Time"
        
        var id: String { self.rawValue }
    }
    
    /// Empty ranges are common (a "Week" view with no sessions in it), so the copy
    /// distinguishes an empty range from an exercise with no history at all.
    private var emptyStateMessage: String {
        selectedTimeRange == .allTime
            ? "Complete more workouts with this exercise to see progress"
            : "No sets recorded for this exercise in the selected time range. Try a longer range."
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Time range picker stays outside the empty check — hiding it left
                // the user stranded on an empty range with no way back.
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

                if volumeData.isEmpty {
                    Spacer()

                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text(emptyStateMessage)
                    )

                    Spacer()
                } else {
                    Text(unit.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Chart
                    Chart {
                        ForEach(volumeData, id: \.date) { dataPoint in
                            LineMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Volume", dataPoint.volume)
                            )
                            .foregroundStyle(Color.fitnessPrimary)

                            PointMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Volume", dataPoint.volume)
                            )
                            .annotation(position: .top) {
                                Text(VolumeMetric.formatCompact(dataPoint.volume))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundStyle(Color.fitnessPrimary)
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
                            if let volume = value.as(Double.self) {
                                AxisValueLabel {
                                    Text(VolumeMetric.formatCompact(volume))
                                }
                            }
                        }
                    }

                    // Stats view
                    ExerciseStatsView(volumeData: volumeData, unit: unit)
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
        
        var data: [(date: Date, volume: Double)] = []

        let allWorkouts = workoutManager.fetchAllWorkouts()

        // Resolve the unit from the full history, not the selected range, so that
        // narrowing to a range of bodyweight-only sessions doesn't flip a weighted
        // exercise over to reps.
        let resolvedUnit = VolumeMetric.unit(of: exerciseName, across: allWorkouts)
        unit = resolvedUnit

        for workout in allWorkouts {
            guard let workoutDate = workout.value(forKey: "date") as? Date else { continue }

            // Skip workouts before cutoff date
            if let cutoff = cutoffDate, workoutDate < cutoff {
                continue
            }

            let volume = VolumeMetric.volume(of: exerciseName, in: workout, unit: resolvedUnit)
            guard volume > 0 else { continue }

            // Normalize the date based on selected time range to group data better
            let normalizedDate: Date
            if selectedTimeRange == .allTime || selectedTimeRange == .sixMonths {
                // For longer time ranges, group by day of month
                normalizedDate = calendar.startOfDay(for: workoutDate)
            } else {
                // For shorter time ranges, use exact date and time
                normalizedDate = workoutDate
            }

            data.append((date: normalizedDate, volume: volume))
        }

        // Collapse duplicate dates by summing — two sessions on one day means the
        // day's total volume, not the larger of the two.
        let groupedByDate = Dictionary(grouping: data, by: { $0.date })
        let volumeByDate = groupedByDate.map { date, entries in
            (date: date, volume: entries.reduce(0) { $0 + $1.volume })
        }

        volumeData = volumeByDate.sorted(by: { $0.date < $1.date })
    }
}

// MARK: - Exercise Stats View
struct ExerciseStatsView: View {
    let volumeData: [(date: Date, volume: Double)]
    let unit: VolumeMetric.Unit

    private var maxVolume: Double {
        volumeData.max(by: { $0.volume < $1.volume })?.volume ?? 0
    }

    private var averageVolume: Double {
        guard !volumeData.isEmpty else { return 0 }
        let sum = volumeData.reduce(0) { $0 + $1.volume }
        return sum / Double(volumeData.count)
    }

    private var progress: Double {
        guard volumeData.count >= 2 else { return 0 }
        let first = volumeData.first!.volume
        let last = volumeData.last!.volume
        return last - first
    }

    private var progressPercentage: Double {
        guard volumeData.count >= 2 else { return 0 }
        let first = volumeData.first!.volume
        guard first > 0 else { return 0 }
        return (progress / first) * 100
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Stats")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "Best Volume (\(unit.label))", value: VolumeMetric.format(maxVolume))
                StatCard(title: "Average Volume (\(unit.label))", value: VolumeMetric.format(averageVolume))

                if volumeData.count >= 2 {
                    StatCard(
                        title: "Progress",
                        value: (progress >= 0 ? "+" : "-") + VolumeMetric.format(abs(progress)),
                        detail: String(format: "%+.1f%%", progressPercentage)
                    )

                    StatCard(
                        title: "Timespan",
                        value: formatTimespan(
                            from: volumeData.first!.date,
                            to: volumeData.last!.date
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
