import ActivityKit
import Foundation

/// ActivityAttributes shared by both the main app and the FitnessTrackerWidget extension.
/// The struct must have identical definitions in both targets — ActivityKit matches them by type name.
struct FitnessTimerAttributes: ActivityAttributes {
    enum TimerType: String, Codable, Hashable {
        case warmup
        case rest
    }

    /// Static content set when the activity is created.
    var timerType: TimerType

    /// Dynamic content that can be updated while the activity is live.
    struct ContentState: Codable, Hashable {
        /// The absolute date when this timer step ends.
        /// Using a Date lets Live Activity views render a self-updating countdown with
        /// `Text(timerInterval:)` — no frequent pushes needed.
        var endTime: Date
        /// Display label: the warmup exercise name, or "Rest Timer".
        var label: String
        /// Which step is currently active (1-based, for display).
        var stepIndex: Int
        /// Total number of steps — used to show "Step 2 of 4" for warmups.
        var totalSteps: Int
    }
}
