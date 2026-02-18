//
//  JourneyCard.swift
//  LiveRail
//
//  Journey summary card component
//

import SwiftUI

struct JourneyCard: View {
    let journey: Journey

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Journey times and duration
            HStack(alignment: .top, spacing: Spacing.lg) {
                // Departure time
                VStack(alignment: .leading, spacing: 2) {
                    Text(journey.departureTimeFormatted)
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(journey.origin.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Duration with arrow
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(journey.totalDurationFormatted)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Arrival time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(journey.arrivalTimeFormatted)
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(journey.destination.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()

            // Journey metadata
            HStack(spacing: Spacing.md) {
                // Changes indicator
                HStack(spacing: 4) {
                    Image(systemName: journey.numberOfChanges == 0 ? "checkmark.circle.fill" : "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundStyle(journey.numberOfChanges == 0 ? AppColors.onTime : AppColors.primary)
                    Text(journey.changesText)
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Transport mode icons
                HStack(spacing: 6) {
                    ForEach(Array(journey.uniqueModes.prefix(3)), id: \.self) { mode in
                        Image(systemName: mode.iconName)
                            .font(.caption)
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 20, height: 20)
                    }
                    if journey.uniqueModes.count > 3 {
                        Text("+\(journey.uniqueModes.count - 3)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .glassCard(material: .regular, cornerRadius: CornerRadius.lg, shadowRadius: 6, padding: 0)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append("Departs \(journey.departureTimeFormatted) from \(journey.origin.name)")
        parts.append("Arrives \(journey.arrivalTimeFormatted) at \(journey.destination.name)")
        parts.append("Duration \(journey.totalDurationFormatted)")
        parts.append(journey.changesText)
        return parts.joined(separator: ", ")
    }
}
