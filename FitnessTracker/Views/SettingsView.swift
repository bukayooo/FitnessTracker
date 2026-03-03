//
//  SettingsView.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("weightSuggestionEnabled") private var weightSuggestionEnabled = true

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
                } header: {
                    Text("Workout")
                } footer: {
                    Text("When enabled, an orange number appears in the weight field suggesting a weight based on how hard your last set felt (heat rating).")
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
                    Text("Weights are rounded to the nearest 2.5 lbs.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
