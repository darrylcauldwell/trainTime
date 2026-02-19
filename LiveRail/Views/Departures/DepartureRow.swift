//
//  DepartureRow.swift
//  LiveRail
//
//  Single departure: time, status, platform, destination
//

import SwiftUI

struct DepartureRow: View {
    let service: TrainService

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Departure time
            VStack(spacing: 2) {
                Text(service.departureTime)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.primary)

                if service.status == .delayed,
                   let etd = service.expectedDeparture as String?,
                   etd != service.departureTime {
                    Text(etd)
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(AppColors.delayed)
                }
            }
            .frame(minWidth: 50)
            .fixedSize()

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            // Destination and operator
            VStack(alignment: .leading, spacing: 2) {
                Text(service.destinationName)
                    .font(.headline)
                    .lineLimit(1)

                if let operatorName = service.operatorName {
                    Text(operatorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if service.status == .cancelled, let reason = service.cancelReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(AppColors.cancelled)
                        .lineLimit(2)
                }

                if service.status == .delayed, let reason = service.delayReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(AppColors.delayed)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Platform
            VStack(spacing: 2) {
                if let platform = service.platform {
                    Text(String(localized: "Plat"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(platform)
                        .font(.headline.bold())
                        .foregroundStyle(AppColors.platform)
                }
            }
            .frame(minWidth: 35)
            .fixedSize()

            // Status badge
            StatusBadge(status: service.status)
        }
        .padding(Spacing.md)
        .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 4, padding: 0)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier("departure-row")
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append("\(service.departureTime) to \(service.destinationName)")
        parts.append(service.status.displayText)
        if let platform = service.platform {
            parts.append("Platform \(platform)")
        }
        if service.status == .delayed, let reason = service.delayReason {
            parts.append(reason)
        }
        if service.status == .cancelled, let reason = service.cancelReason {
            parts.append(reason)
        }
        return parts.joined(separator: ", ")
    }

    private var statusColor: Color {
        switch service.status {
        case .onTime: return AppColors.onTime
        case .delayed: return AppColors.delayed
        case .cancelled: return AppColors.cancelled
        }
    }
}

struct StatusBadge: View {
    let status: ServiceStatus

    var body: some View {
        Text(status.displayText)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .onTime: return AppColors.onTime
        case .delayed: return AppColors.delayed
        case .cancelled: return AppColors.cancelled
        }
    }
}
