//
//  CallingPointRow.swift
//  trainTime
//
//  Single calling point row with progress indicator
//

import SwiftUI

struct CallingPointRow: View {
    let callingPoint: CallingPoint
    let isCurrentStation: Bool
    let isPassed: Bool
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Timeline indicator
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? .clear : (isPassed ? AppColors.onTime : AppColors.inactive.opacity(0.3)))
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)

                ZStack {
                    Circle()
                        .fill(circleColor)
                        .frame(width: isCurrentStation ? 16 : 12, height: isCurrentStation ? 16 : 12)

                    if isCurrentStation {
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                    }

                    if isPassed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Rectangle()
                    .fill(isLast ? .clear : (isPassed ? AppColors.onTime : AppColors.inactive.opacity(0.3)))
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            .accessibilityHidden(true)

            // Station info
            VStack(alignment: .leading, spacing: 2) {
                Text(callingPoint.locationName ?? String(localized: "Unknown"))
                    .font(isCurrentStation ? .headline : .subheadline)
                    .fontWeight(isCurrentStation ? .bold : .regular)

                HStack(spacing: Spacing.sm) {
                    // Scheduled time
                    Text(TrainTimeFormatter.displayTime(callingPoint.st))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    // Status
                    Text(callingPoint.statusText)
                        .font(.caption2.bold())
                        .foregroundStyle(statusColor)
                }
            }

            Spacer()

            // Actual/expected time
            if callingPoint.hasDeparted {
                Text(TrainTimeFormatter.displayTime(callingPoint.at))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(AppColors.onTime)
            } else if let et = callingPoint.et, et != "On time", et != "Cancelled", et != "Delayed" {
                Text(TrainTimeFormatter.displayTime(et))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(AppColors.delayed)
            }
        }
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append(callingPoint.locationName ?? String(localized: "Unknown"))
        parts.append(TrainTimeFormatter.displayTime(callingPoint.st))
        parts.append(callingPoint.statusText)
        if isPassed {
            parts.append(String(localized: "Departed"))
        }
        return parts.joined(separator: ", ")
    }

    private var circleColor: Color {
        if callingPoint.isCancelled == true || callingPoint.et == "Cancelled" {
            return AppColors.cancelled
        }
        if isCurrentStation { return AppColors.primary }
        if isPassed { return AppColors.onTime }
        return AppColors.inactive.opacity(0.3)
    }

    private var statusColor: Color {
        let text = callingPoint.statusText
        if text == String(localized: "On time") || text == String(localized: "Departed") { return AppColors.onTime }
        if text == String(localized: "Cancelled") { return AppColors.cancelled }
        if text.hasPrefix("Exp") || text == String(localized: "Delayed") { return AppColors.delayed }
        return .secondary
    }
}
