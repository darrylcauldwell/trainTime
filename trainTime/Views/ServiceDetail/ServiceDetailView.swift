//
//  ServiceDetailView.swift
//  trainTime
//
//  Calling points timeline with times and status
//

import SwiftUI

struct ServiceDetailView: View {
    let serviceDetail: ServiceDetail
    let stationSearch: StationSearchService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Service info header
                serviceHeader

                // Calling points timeline
                VStack(spacing: 0) {
                    let points = serviceDetail.allCallingPoints
                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        CallingPointRow(
                            callingPoint: point,
                            isCurrentStation: point.crs == serviceDetail.crs,
                            isPassed: point.hasDeparted,
                            isFirst: index == 0,
                            isLast: index == points.count - 1
                        )
                    }
                }
                .padding(.horizontal)

                // Cancel/delay reason
                if let reason = serviceDetail.cancelReason {
                    reasonBanner(reason, color: AppColors.cancelled, icon: "xmark.circle.fill")
                }
                if let reason = serviceDetail.delayReason {
                    reasonBanner(reason, color: AppColors.delayed, icon: "exclamationmark.triangle.fill")
                }
            }
        }
    }

    private var serviceHeader: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                if let op = serviceDetail.operatorName {
                    GlassChip(op, icon: "tram.fill", color: AppColors.primary)
                }
                if let length = serviceDetail.length {
                    GlassChip("\(length) \(String(localized: "coaches"))", icon: "train.side.front.car", color: AppColors.secondary)
                }
                Spacer()
            }

            if let platform = serviceDetail.platform {
                HStack {
                    Text(String(localized: "Platform"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(platform)
                        .font(.title2.bold())
                        .foregroundStyle(AppColors.platform)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, Spacing.sm)
    }

    private func reasonBanner(_ reason: String, color: Color, icon: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
            Text(reason)
                .font(.caption)
        }
        .foregroundStyle(color)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        .padding(.horizontal)
    }
}
