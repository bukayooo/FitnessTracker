//
//  SettingsView.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @AppStorage("weightSuggestionEnabled") private var weightSuggestionEnabled = true
    @AppStorage("uniformWeightSuggestionEnabled") private var uniformWeightSuggestionEnabled = false
    @AppStorage("siriShortcutsEnabled") private var siriShortcutsEnabled = true
    @AppStorage("timerChimeEnabled") private var timerChimeEnabled = true
    @AppStorage("showWorkoutDetailsAfterCompletion") private var showWorkoutDetailsAfterCompletion = false
    @AppStorage("dailyScheduleEnabled") private var dailyScheduleEnabled = false
    @State private var currentIconName: String? = UIApplication.shared.alternateIconName

    private func setIcon(_ name: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(name) { error in
            if let error = error {
                print("Error switching icon: \(error.localizedDescription)")
            } else {
                currentIconName = name
            }
        }
    }

    @ViewBuilder
    private func iconRow(label: String, iconName: String?) -> some View {
        Button {
            setIcon(iconName)
        } label: {
            HStack {
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
                if currentIconName == iconName {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $dailyScheduleEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Schedule")
                                .font(.body)
                            Text("Show only today's assigned template on the workout screen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if dailyScheduleEnabled {
                        NavigationLink("Configure Schedule") {
                            DailyScheduleView()
                        }
                    }
                } header: {
                    Text("Workout Screen")
                }

                Section {
                    Toggle(isOn: $weightSuggestionEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight Suggestions")
                                .font(.body)
                            Text("Show suggested weight based on your previous heat rating")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Toggle(isOn: $uniformWeightSuggestionEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Uniform Weight Suggestion")
                                .font(.body)
                            Text("Show the same weight suggestion for all sets of an exercise, based on the highest suggestion across all your sets from the previous workout")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(!weightSuggestionEnabled)
                    Toggle(isOn: $siriShortcutsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Siri Shortcuts")
                                .font(.body)
                            Text("Automatically run Siri shortcuts when you start and finish a workout. They must be named \"Start Workout\" and \"End Workout.\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Toggle(isOn: $showWorkoutDetailsAfterCompletion) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show Progress After Workout")
                                .font(.body)
                            Text("Automatically show progress charts for the exercises you just trained after you complete a workout")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Toggle(isOn: $timerChimeEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Timer Chime")
                                .font(.body)
                            Text("Play a chime when the warmup or rest timer finishes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Workout")
                } 

                Section {
                    iconRow(label: "Default", iconName: nil)
                    iconRow(label: "Achilles", iconName: "Icon2")
                    iconRow(label: "Perseus", iconName: "Icon3")
                } header: {
                    Text("App Icon")
                }

                Section {
                    HStack {
                        Text("1–2")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Easy → +15%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("3–4")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Somewhat easy → +12%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("5–6")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Moderate effort → +8%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("7")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Hard, completed with difficulty → +5%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("8")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Barely completed all reps with full range of motion → +3%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("9")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Last few reps weren't full range of motion → hold weight")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("10")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Couldn't complete all reps → hold weight")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Heat Rating Scale")
                } footer: {
                    Text("Sitting comfortably at a heat rating of 7-8 is when you know you should incrase the weight; try to always be gettings 9s or 10s. Weight suggestions are rounded to the nearest 2.5 lbs.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct DailyScheduleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var assignments: [String: String] = [:]

    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    private func fetchTemplates() -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutTemplate")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    private func templateName(_ t: NSManagedObject) -> String {
        t.value(forKey: "name") as? String ?? "Untitled"
    }

    private func saveAssignments() {
        UserDefaults.standard.set(assignments, forKey: "dailyScheduleAssignments")
        // Incrementing this key triggers @AppStorage("dailyScheduleAssignmentsVersion")
        // in WorkoutTabView to update, which causes todayAssignedTemplate to re-evaluate.
        let v = UserDefaults.standard.integer(forKey: "dailyScheduleAssignmentsVersion")
        UserDefaults.standard.set(v + 1, forKey: "dailyScheduleAssignmentsVersion")
    }

    var body: some View {
        let templates = fetchTemplates()
        List {
            ForEach(1...7, id: \.self) { weekday in
                let key = String(weekday)
                Picker(dayNames[weekday - 1], selection: Binding(
                    get: { assignments[key] ?? "" },
                    set: { newValue in
                        if newValue.isEmpty {
                            assignments.removeValue(forKey: key)
                        } else {
                            assignments[key] = newValue
                        }
                        saveAssignments()
                    }
                )) {
                    Text("None").tag("")
                    ForEach(templates, id: \.objectID) { template in
                        Text(templateName(template))
                            .tag(template.objectID.uriRepresentation().absoluteString)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationTitle("Daily Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            assignments = UserDefaults.standard.dictionary(forKey: "dailyScheduleAssignments") as? [String: String] ?? [:]
        }
    }
}

#Preview {
    SettingsView()
}
