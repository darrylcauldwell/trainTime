//
//  TrainMapView.swift
//  LiveRail
//
//  MapKit live train tracking with station annotations and interpolated position
//

import SwiftUI
import MapKit

struct TrainMapView: View {
    let serviceDetail: ServiceDetail
    let stationSearch: StationSearchService

    @State private var trainPosition: TrainPosition?
    @State private var cameraPosition: MapCameraPosition = .automatic
    // Memoized station annotations to avoid N+1 lookups every render
    @State private var cachedAnnotations: [(station: Station, callingPoint: CallingPoint)] = []

    var body: some View {
        Map(position: $cameraPosition) {
            // Station markers
            ForEach(cachedAnnotations, id: \.station.id) { item in
                Annotation(item.callingPoint.locationName ?? item.station.name, coordinate: item.station.coordinate) {
                    stationDot(for: item.callingPoint)
                }
            }

            // Route polyline
            let coords = cachedAnnotations.map(\.station.coordinate)
            if coords.count >= 2 {
                MapPolyline(coordinates: coords)
                    .stroke(AppColors.routeLine.opacity(0.5), lineWidth: 3)
            }

            // Train position marker
            if let trainPosition {
                Annotation(String(localized: "Train"), coordinate: trainPosition.coordinate) {
                    trainMarker
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .overlay(alignment: .bottom) {
            trainInfoOverlay
        }
        .onAppear {
            buildAnnotations()
            updatePosition()
        }
        .task {
            // Use structured concurrency instead of Timer for proper cancellation
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                updatePosition()
            }
        }
    }

    private func buildAnnotations() {
        cachedAnnotations = serviceDetail.allCallingPoints.compactMap { point in
            guard let crs = point.crs,
                  let station = stationSearch.station(forCRS: crs) else { return nil }
            return (station, point)
        }
    }

    private func stationDot(for point: CallingPoint) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
            Circle()
                .fill(point.hasDeparted ? AppColors.onTime : AppColors.inactive.opacity(0.5))
                .frame(width: 10, height: 10)
        }
    }

    private var trainMarker: some View {
        ZStack {
            Circle()
                .fill(AppColors.primary.opacity(0.3))
                .frame(width: 32, height: 32)
            Circle()
                .fill(AppColors.primary)
                .frame(width: 20, height: 20)
            Image(systemName: "tram.fill")
                .font(.caption2)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var trainInfoOverlay: some View {
        if let position = trainPosition {
            HStack(spacing: Spacing.md) {
                Image(systemName: "tram.fill")
                    .foregroundStyle(AppColors.primary)

                if let current = position.currentStationName {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From \(current)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let next = position.nextStationName {
                            Text("Next: \(next)")
                                .font(.caption.bold())
                        }
                    }
                }

                Spacer()
            }
            .padding(Spacing.md)
            .glassCard(material: .thick, cornerRadius: CornerRadius.md, shadowRadius: 8, padding: 0)
            .padding()
        }
    }

    private func updatePosition() {
        let position = TrainPositionCalculator.calculatePosition(
            callingPoints: serviceDetail.allCallingPoints,
            stations: stationSearch.allStations
        )

        withAnimation(.easeInOut(duration: 4.5)) {
            trainPosition = position
        }
    }
}
