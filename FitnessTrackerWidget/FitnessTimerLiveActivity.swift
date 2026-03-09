import ActivityKit
import WidgetKit
import SwiftUI

struct FitnessTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FitnessTimerAttributes.self) { context in
            // Lock screen / notification banner view
            LockScreenTimerView(context: context)
                .activityBackgroundTint(Color(red: 0.08, green: 0.08, blue: 0.10))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                Image(systemName: timerIconName(for: context.attributes.timerType))
                    .foregroundStyle(timerAccentColor(for: context.attributes.timerType))
                    .font(.caption.bold())
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: timerIconName(for: context.attributes.timerType))
                    .foregroundStyle(timerAccentColor(for: context.attributes.timerType))
            }
            .keylineTint(timerAccentColor(for: context.attributes.timerType))
        }
    }
}

// MARK: - Helpers (prefixed to avoid conflict with SwiftUI's View.accentColor)

private func timerIconName(for type: FitnessTimerAttributes.TimerType) -> String {
    type == .warmup ? "flame.fill" : "timer"
}

private func timerAccentColor(for type: FitnessTimerAttributes.TimerType) -> Color {
    type == .warmup ? .orange : .green
}

// MARK: - Lock Screen View

private struct LockScreenTimerView: View {
    let context: ActivityViewContext<FitnessTimerAttributes>

    var body: some View {
        HStack(spacing: 14) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(timerAccentColor(for: context.attributes.timerType).opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: timerIconName(for: context.attributes.timerType))
                    .foregroundStyle(timerAccentColor(for: context.attributes.timerType))
                    .font(.title2.bold())
            }

            // Label + step indicator — maxWidth: .infinity forces it to consume all
            // remaining space, which pushes the countdown to the far right edge
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.label)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if context.attributes.timerType == .warmup && context.state.totalSteps > 1 {
                    Text("Step \(context.state.stepIndex) of \(context.state.totalSteps)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text(context.attributes.timerType == .warmup ? "Warmup Timer" : "Rest Timer")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Countdown
            Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                .monospacedDigit()
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(timerAccentColor(for: context.attributes.timerType))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Expanded Dynamic Island Regions

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<FitnessTimerAttributes>

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: timerIconName(for: context.attributes.timerType))
                .foregroundStyle(timerAccentColor(for: context.attributes.timerType))
                .font(.subheadline.bold())
            Text(context.attributes.timerType == .warmup ? "Warmup" : "Rest")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 4)
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<FitnessTimerAttributes>

    var body: some View {
        if context.attributes.timerType == .warmup && context.state.totalSteps > 1 {
            Text("\(context.state.stepIndex)/\(context.state.totalSteps)")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
        }
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<FitnessTimerAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(context.state.label)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(context.attributes.timerType == .warmup ? "Warmup" : "Rest Timer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                .monospacedDigit()
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(timerAccentColor(for: context.attributes.timerType))
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}
