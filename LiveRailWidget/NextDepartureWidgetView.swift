//
//  NextDepartureWidgetView.swift
//  trainTimeWidget
//
//  Small and medium widget views showing next departure
//

import SwiftUI
import WidgetKit

struct NextDepartureWidgetView: View {
    let entry: NextDepartureEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundStyle(.blue)
                Spacer()
                if let status = entry.status {
                    Text(status)
                        .font(.caption2.bold())
                        .foregroundStyle(statusColor)
                }
            }

            if let time = entry.departureTime {
                Text(time)
                    .font(.title.bold().monospacedDigit())
            } else {
                Text("--:--")
                    .font(.title.bold().monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let dest = entry.destinationCRS {
                Text(dest)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let platform = entry.platform {
                HStack(spacing: 4) {
                    Text("P\(platform)")
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                }
            }
        }
        .widgetURL(widgetURL)
    }

    private var mediumWidget: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "tram.fill")
                        .foregroundStyle(.blue)
                    Text("LiveRail")
                        .font(.caption.bold())
                }

                if let time = entry.departureTime {
                    Text(time)
                        .font(.title.bold().monospacedDigit())
                } else {
                    Text("--:--")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let origin = entry.originName, let dest = entry.destinationName {
                    Text("\(origin) → \(dest)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let status = entry.status {
                    Text(status)
                        .font(.caption.bold())
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.15))
                        .clipShape(Capsule())
                }

                if let platform = entry.platform {
                    VStack(spacing: 2) {
                        Text("Platform")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(platform)
                            .font(.title3.bold())
                            .foregroundStyle(.purple)
                    }
                }
            }
        }
        .widgetURL(widgetURL)
    }

    private var statusColor: Color {
        guard let status = entry.status else { return .secondary }
        switch status {
        case "On time": return .green
        case "Delayed": return .orange
        case "Cancelled": return .red
        default: return .secondary
        }
    }

    private var widgetURL: URL? {
        guard let origin = entry.originCRS, let dest = entry.destinationCRS else { return nil }
        return URL(string: "traintime://departures/\(origin)/\(dest)")
    }
}
