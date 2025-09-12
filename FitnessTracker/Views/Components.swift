//
//  Components.swift
//  FitnessTracker
//
//  Created by Bukayo Odedele on 2/25/25.
//

import SwiftUI

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(isEnabled ? Color.fitnessPrimary : Color.gray.opacity(0.5))
            .foregroundColor(.white)
            .font(.headline)
            .fontWeight(.semibold)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Color.fitnessSecondary.opacity(0.15))
            .foregroundColor(.fitnessSecondary)
            .font(.headline)
            .fontWeight(.medium)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.fitnessSecondary.opacity(0.5), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Color.fitnessError)
            .foregroundColor(.white)
            .font(.headline)
            .fontWeight(.semibold)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Rest Timer View
struct RestTimerButton: View {
    @Binding var isActive: Bool
    let timeRemaining: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isActive ? "timer" : "timer.circle")
                    .font(.system(size: 16, weight: .semibold))
                
                if isActive {
                    Text(formatTime(seconds: timeRemaining))
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                } else {
                    Text("Rest")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isActive ? Color.fitnessBronze.opacity(0.15) : Color.gray.opacity(0.15))
            .foregroundColor(isActive ? .fitnessBronze : .primary)
            .cornerRadius(20)
        }
    }
    
    private func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Card Views
struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Input Fields
struct NumberField: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    let keyboard: UIKeyboardType
    
    init(label: String, value: Binding<String>, placeholder: String = "", keyboard: UIKeyboardType = .numberPad) {
        self.label = label
        self._value = value
        self.placeholder = placeholder
        self.keyboard = keyboard
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $value)
                .keyboardType(keyboard)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .font(.system(size: 16, weight: .medium, design: .rounded))
        }
    }
}

// MARK: - Section Headers
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Empty State Views
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Warmup Timer View
struct WarmupTimerView: View {
    @ObservedObject var timerManager: TimerManager
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                Text("Warmup")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.primary)
                
                if let warmupName = timerManager.currentWarmupName {
                    Text(warmupName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Text("\(timerManager.warmupTimeRemaining)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.fitnessBronze)
                    .monospacedDigit()
                
                HStack(spacing: 16) {
                    Button(action: {
                        timerManager.stopWarmupTimer()
                    }) {
                        Text("Skip All")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(Color.fitnessError)
                            .cornerRadius(12)
                    }
                    
                    if timerManager.isWarmupTimerPaused {
                        Button(action: {
                            timerManager.startCurrentWarmup()
                        }) {
                            Text("Start")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Color.fitnessSuccess)
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: {
                            timerManager.moveToNextWarmup()
                        }) {
                            Text(timerManager.isLastWarmup ? "Finish" : "Next")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Color.fitnessPrimary)
                                .cornerRadius(12)
                        }
                    }
                }
                
                Text("Warmup \(timerManager.currentWarmupIndex + 1) of \(timerManager.warmups.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if timerManager.isWarmupTimerPaused {
                    Text("Get ready for this warmup!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
    }
} 