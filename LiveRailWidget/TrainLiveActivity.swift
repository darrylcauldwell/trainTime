//
//  TrainLiveActivity.swift
//  trainTimeWidget
//
//  Lock screen and Dynamic Island views for live train tracking
//

import ActivityKit
import SwiftUI
import WidgetKit

struct TrainLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainActivityAttributes.self) { context in
            // Lock Screen view
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.originCRS)
                            .font(.caption2.bold())
                        Text("→")
                            .font(.caption2)
                        Text(context.attributes.destinationCRS)
                            .font(.caption2.bold())
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        ProgressView(value: context.state.progress)
                            .tint(context.state.delayMinutes > 0 ? .orange : .green)
                        if let next = context.state.nextStop {
                            Text("Next: \(next)")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let eta = context.state.eta {
                            Text(eta)
                                .font(.caption.bold().monospacedDigit())
                        }
                        Text(context.state.delayMinutes > 0 ? "+\(context.state.delayMinutes)m" : "On time")
                            .font(.caption2)
                            .foregroundStyle(context.state.delayMinutes > 0 ? .orange : .green)
                    }
                }
            } compactLeading: {
                Image(systemName: "tram.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                if let eta = context.state.eta {
                    Text(eta)
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(context.state.delayMinutes > 0 ? .orange : .green)
                }
            } minimal: {
                Image(systemName: "tram.fill")
                    .foregroundStyle(.blue)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<TrainActivityAttributes>) -> some View {
        VStack(spacing: 8) {
            // Route
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundStyle(.blue)
                Text("\(context.attributes.originName) → \(context.attributes.destinationName)")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                if !context.attributes.operatorName.isEmpty {
                    Text(context.attributes.operatorName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            ProgressView(value: context.state.progress)
                .tint(context.state.delayMinutes > 0 ? .orange : .green)

            // Status row
            HStack {
                if let current = context.state.currentStation {
                    Text(current)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let next = context.state.nextStop {
                    Text("→ \(next)")
                        .font(.caption.bold())
                }
            }

            // ETA and platform
            HStack {
                if let eta = context.state.eta {
                    Text("ETA \(eta)")
                        .font(.caption.bold().monospacedDigit())
                }
                if context.state.delayMinutes > 0 {
                    Text("+\(context.state.delayMinutes) min")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
                Spacer()
                if let platform = context.state.platform {
                    Text("P\(platform)")
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding()
    }
}
