//
//  AppColors.swift
//  trainTime
//
//  Train-themed adaptive colour system
//  Adapted from TetraTrack's design system
//

import SwiftUI
import UIKit

// MARK: - Adaptive Color Provider

struct AppColors {

    // MARK: - Primary Railway Theme

    /// Railway blue - primary brand colour
    static var primary: Color {
        Color(light: .init(red: 0.0, green: 0.27, blue: 0.53),
              dark: .init(red: 0.25, green: 0.55, blue: 0.90))
    }

    /// Secondary blue
    static var secondary: Color {
        Color(light: .init(red: 0.4, green: 0.65, blue: 0.95),
              dark: .init(red: 0.5, green: 0.7, blue: 1.0))
    }

    /// Accent blue - brighter for highlights
    static var accent: Color {
        Color(light: .init(red: 0.0, green: 0.5, blue: 1.0),
              dark: .init(red: 0.3, green: 0.7, blue: 1.0))
    }

    // MARK: - Train Status Colors

    /// On time - green
    static var onTime: Color {
        Color(light: .init(red: 0.2, green: 0.7, blue: 0.4),
              dark: .init(red: 0.35, green: 0.85, blue: 0.5))
    }

    /// Delayed - amber
    static var delayed: Color {
        Color(light: .init(red: 0.95, green: 0.65, blue: 0.15),
              dark: .init(red: 1.0, green: 0.75, blue: 0.35))
    }

    /// Cancelled - red
    static var cancelled: Color {
        Color(light: .init(red: 0.9, green: 0.25, blue: 0.25),
              dark: .init(red: 1.0, green: 0.4, blue: 0.4))
    }

    // MARK: - Semantic Aliases

    static var active: Color { onTime }
    static var warning: Color { delayed }
    static var error: Color { cancelled }
    static var success: Color { onTime }
    static var destructive: Color { cancelled }

    /// Inactive - muted
    static var inactive: Color {
        Color(light: .init(red: 0.5, green: 0.55, blue: 0.65),
              dark: .init(red: 0.45, green: 0.5, blue: 0.6))
    }

    // MARK: - Surface Colors

    /// Card background - subtle blue tint
    static var cardBackground: Color {
        Color(light: .init(red: 0.94, green: 0.96, blue: 0.99),
              dark: .init(red: 0.12, green: 0.14, blue: 0.18))
    }

    /// Elevated surface
    static var elevatedSurface: Color {
        Color(light: .init(red: 0.97, green: 0.98, blue: 1.0),
              dark: .init(red: 0.16, green: 0.18, blue: 0.22))
    }

    // MARK: - Platform Colors

    /// Platform indicator
    static var platform: Color {
        Color(light: .init(red: 0.3, green: 0.2, blue: 0.7),
              dark: .init(red: 0.5, green: 0.4, blue: 0.9))
    }

    /// Route line colour
    static var routeLine: Color {
        Color(light: .init(red: 0.15, green: 0.6, blue: 0.7),
              dark: .init(red: 0.3, green: 0.75, blue: 0.85))
    }

    /// Next train badge
    static var nextTrain: Color {
        Color(light: .init(red: 0.0, green: 0.5, blue: 1.0),
              dark: .init(red: 0.3, green: 0.7, blue: 1.0))
    }
}

// MARK: - Color Extension for Light/Dark

extension Color {
    /// Creates a color that adapts to light and dark mode
    init(light: Color.Resolved, dark: Color.Resolved) {
        self.init(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(
                    red: CGFloat(dark.red),
                    green: CGFloat(dark.green),
                    blue: CGFloat(dark.blue),
                    alpha: CGFloat(dark.opacity)
                )
            } else {
                return UIColor(
                    red: CGFloat(light.red),
                    green: CGFloat(light.green),
                    blue: CGFloat(light.blue),
                    alpha: CGFloat(light.opacity)
                )
            }
        })
    }
}

// MARK: - ShapeStyle Extension

extension ShapeStyle where Self == Color {
    static var appCardBackground: Color { AppColors.cardBackground }
}
