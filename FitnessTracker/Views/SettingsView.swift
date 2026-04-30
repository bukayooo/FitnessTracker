//
//  SettingsView.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("weightSuggestionEnabled") private var weightSuggestionEnabled = true
    @AppStorage("uniformWeightSuggestionEnabled") private var uniformWeightSuggestionEnabled = false
    @AppStorage("siriShortcutsEnabled") private var siriShortcutsEnabled = true
    @AppStorage("timerChimeEnabled") private var timerChimeEnabled = true
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
                            Text("Automatically start a Siri shortcut when you start a workout. It must be named \"Start Workout.\"")
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
                    iconRow(label: "Alternate", iconName: "Icon1")
                } header: {
                    Text("App Icon")
                }

                Section {
                    HStack {
                        Text("1–2")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Very easy → +15%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("3–4")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Easy → +12%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("5–6")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Somewhat easy → +8%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("7")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Moderate effort → +5%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("8")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Hard, completed with difficulty → +3%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("9")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .leading)
                        Text("Barely completed all reps → hold weight")
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
                    Text("Weight suggestions are rounded to the nearest 2.5 lbs.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
