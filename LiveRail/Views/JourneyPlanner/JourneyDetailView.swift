//
//  JourneyDetailView.swift
//  LiveRail
//
//  Detailed leg-by-leg journey breakdown
//

import SwiftUI

struct JourneyDetailView: View {
    let journey: Journey

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Journey summary header
                    journeySummaryHeader()
                        .padding(.horizontal)
                        .padding(.top, Spacing.md)

                    // Journey legs
                    VStack(spacing: Spacing.md) {
                        ForEach(Array(journey.legs.enumerated()), id: \.element.id) { index, leg in
                            // Leg card
                            legView(leg, index: index)
                                .padding(.horizontal)

                            // Change indicator between legs
                            if index < journey.legs.count - 1 {
                                changeIndicator()
                            }
                        }
                    }
                }
                .padding(.bottom, Spacing.xl)
            }
            .navigationTitle(String(localized: "Journey Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        HapticService.lightImpact()
                        dismiss()
                    }
                }
            }
            .glassNavigation()
        }
    }

    // MARK: - Journey Summary Header

    @ViewBuilder
    private func journeySummaryHeader() -> some View {
        VStack(spacing: Spacing.md) {
            // Route
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(journey.origin.name)
                        .font(.title3.bold())
                    Text(journey.departureTimeFormatted)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(journey.destination.name)
                        .font(.title3.bold())
                    Text(journey.arrivalTimeFormatted)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Metadata
            HStack {
                Label(journey.totalDurationFormatted, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Label(journey.changesText, systemImage: journey.numberOfChanges == 0 ? "checkmark.circle.fill" : "arrow.triangle.branch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.md)
        .glassCard(material: .regular, cornerRadius: CornerRadius.lg, shadowRadius: 6, padding: 0)
    }

    // MARK: - Leg View

    @ViewBuilder
    private func legView(_ leg: JourneyLeg, index: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Mode and operator
            HStack {
                Image(systemName: leg.mode.iconName)
                    .font(.title3)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(leg.mode.displayName)
                        .font(.headline)
                    if let operatorName = leg.operatorName {
                        Text(operatorName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(leg.durationFormatted)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Departure
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(leg.departureTimeFormatted)
                        .font(.title3.bold().monospacedDigit())
                    Text(leg.origin.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let platform = leg.platform {
                        Label(String(localized: "Platform \(platform)"), systemImage: "signpost.right")
                            .font(.caption)
                            .foregroundStyle(AppColors.platform)
                    }
                }
                Spacer()
            }

            // Arrow
            Image(systemName: "arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Arrival
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(leg.arrivalTimeFormatted)
                        .font(.title3.bold().monospacedDigit())
                    Text(leg.destination.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Walking instructions
            if let instructions = leg.instructions {
                Divider()
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.secondary)
                    Text(instructions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Train service hint
            if leg.mode == .train && leg.serviceIdentifier != nil {
                Divider()
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(AppColors.primary)
                    Text(String(localized: "Tap for live service detail"))
                        .font(.caption.italic())
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .padding(Spacing.md)
        .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 4, padding: 0)
        .contentShape(Rectangle())
    }

    // MARK: - Change Indicator

    @ViewBuilder
    private func changeIndicator() -> some View {
        HStack {
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(width: 1, height: 20)
            VStack(spacing: 2) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.caption2)
                Text(String(localized: "CHANGE"))
                    .font(.caption2.bold())
            }
            .foregroundStyle(.secondary)
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(width: 1, height: 20)
        }
        .frame(maxWidth: .infinity)
    }
}
