import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    private var formattedElapsedTime: String {
        let minutes = workoutManager.elapsedSeconds / 60
        let seconds = workoutManager.elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 12) {
            if workoutManager.isWorkoutActive {
                Text("Workout Active")
                    .font(.headline)
                Text(formattedElapsedTime)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                Button("End Workout") {
                    workoutManager.endWorkout()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Text("Waiting for a workout to start from Heracle on your iPhone")
                    .font(.body)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchWorkoutManager.shared)
}
