import ActivityKit
import Foundation

/// Identical copy of the definition in the main app target.
/// ActivityKit matches the main-app Activity to this widget by type name.
struct FitnessTimerAttributes: ActivityAttributes {
    enum TimerType: String, Codable, Hashable {
        case warmup
        case rest
    }

    var timerType: TimerType

    struct ContentState: Codable, Hashable {
        var endTime: Date
        var label: String
        var stepIndex: Int
        var totalSteps: Int
    }
}
