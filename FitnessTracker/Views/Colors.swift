//
//  Colors.swift
//  FitnessTracker
//
//  Custom color scheme based on app icon
//

import SwiftUI

extension Color {
    // MARK: - Primary Colors (from app icon)
    
    /// Deep slate blue - primary dark color from the app icon
    static let fitnessNavy = Color(red: 0.18, green: 0.25, blue: 0.35)
    
    /// Warm bronze/copper - accent color from the app icon
    static let fitnessBronze = Color(red: 0.72, green: 0.55, blue: 0.42)
    
    /// Lighter slate blue - mid-tone from the app icon
    static let fitnessSlate = Color(red: 0.32, green: 0.42, blue: 0.52)
    
    // MARK: - Supporting Colors
    
    /// Light bronze for subtle accents
    static let fitnessLightBronze = Color(red: 0.82, green: 0.70, blue: 0.60)
    
    /// Very light slate for backgrounds
    static let fitnessLightSlate = Color(red: 0.88, green: 0.90, blue: 0.92)
    
    /// Dark navy for strong contrasts
    static let fitnessDarkNavy = Color(red: 0.12, green: 0.18, blue: 0.25)
    
    // MARK: - Semantic Colors
    
    /// Primary action color
    static let fitnessPrimary = fitnessBronze
    
    /// Secondary action color  
    static let fitnessSecondary = fitnessSlate
    
    /// Success/completion color (slightly warmer bronze)
    static let fitnessSuccess = Color(red: 0.78, green: 0.62, blue: 0.45)
    
    /// Warning color (warmer bronze tone)
    static let fitnessWarning = Color(red: 0.85, green: 0.65, blue: 0.35)
    
    /// Error color (keeping red but muted to match palette)
    static let fitnessError = Color(red: 0.78, green: 0.35, blue: 0.35)
    
    // MARK: - Background Colors
    
    /// Primary background
    static let fitnessBackground = Color(.systemBackground)
    
    /// Secondary background with slight tint
    static let fitnessSecondaryBackground = Color(.secondarySystemGroupedBackground)
    
    /// Card/elevated background
    static let fitnessCardBackground = Color(.systemGroupedBackground)
}

// MARK: - Button Styles

struct FitnessPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.fitnessPrimary)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
            .foregroundColor(.white)
            .fontWeight(.semibold)
    }
}

struct FitnessSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.fitnessSecondary.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.fitnessSecondary, lineWidth: 1.5)
                    )
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
            .foregroundColor(.fitnessSecondary)
            .fontWeight(.medium)
    }
}

struct FitnessTimerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.fitnessBronze.opacity(0.1))
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
            .foregroundColor(.fitnessBronze)
            .fontWeight(.medium)
    }
}