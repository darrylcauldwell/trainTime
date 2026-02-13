//
//  GetToStationView.swift
//  trainTime
//
//  Transit directions from current GPS location to departure station
//

import SwiftUI
import CoreLocation

struct GetToStationView: View {
    let station: Station
    let stationSearch: StationSearchService

    // Use @State with initial value for @Observable reference types
    // SwiftUI will maintain the identity across view updates
    @State private var locationService: LocationService
    @State private var navigationService: NavigationService
    @State private var hasRequestedDirections = false

    init(station: Station, stationSearch: StationSearchService) {
        self.station = station
        self.stationSearch = stationSearch
        self._locationService = State(initialValue: LocationService())
        self._navigationService = State(initialValue: NavigationService())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Station destination card
                destinationCard

                if !locationService.isAuthorized {
                    locationPermissionView
                } else if navigationService.isLoading {
                    ProgressView(String(localized: "Getting directions..."))
                        .padding(.top, Spacing.jumbo)
                } else if let result = navigationService.navigationResult {
                    directionsView(result)
                } else if let error = navigationService.error {
                    ContentUnavailableView(
                        String(localized: "Directions Unavailable"),
                        systemImage: "location.slash",
                        description: Text(error)
                    )
                    .padding(.top, Spacing.xl)
                }

                // Open in Apple Maps button
                Button {
                    navigationService.openInAppleMaps(to: station)
                } label: {
                    Label(String(localized: "Open in Apple Maps"), systemImage: "map.fill")
                        .font(.headline)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
            }
            .padding(.top, Spacing.sm)
        }
        .navigationTitle(String(localized: "Get to Station"))
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .onAppear {
            locationService.requestPermission()
        }
        .onDisappear {
            locationService.stopUpdating()
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            guard let location = newLocation, !hasRequestedDirections else { return }
            hasRequestedDirections = true
            Task {
                await navigationService.getDirections(
                    from: location.coordinate,
                    to: station
                )
            }
        }
    }

    private var destinationCard: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "tram.fill")
                .font(.title)
                .foregroundStyle(AppColors.primary)
            Text(station.name)
                .font(.title2.bold())
            Text(station.crs)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .glassCard(material: .regular, cornerRadius: CornerRadius.lg, shadowRadius: 8)
        .padding(.horizontal)
    }

    private var locationPermissionView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "location.circle")
                .font(.largeTitle)
                .foregroundStyle(AppColors.primary)
            Text(String(localized: "Location Access Needed"))
                .font(.headline)
            Text("Enable location services to get directions to \(station.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(String(localized: "Enable Location")) {
                locationService.requestPermission()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }

    private func directionsView(_ result: NavigationResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Summary
            HStack(spacing: Spacing.xl) {
                GlassStatCard(
                    title: String(localized: "Journey Time"),
                    value: formatDuration(result.totalDuration),
                    icon: "clock.fill",
                    tint: AppColors.primary
                )
                GlassStatCard(
                    title: String(localized: "Arrival"),
                    value: formatArrival(result.arrivalTime),
                    icon: "flag.checkered",
                    tint: AppColors.onTime
                )
            }
            .padding(.horizontal)

            // Steps
            GlassSectionHeader(String(localized: "Directions"), icon: "arrow.triangle.turn.up.right.diamond.fill")

            VStack(spacing: 0) {
                ForEach(Array(result.steps.enumerated()), id: \.element.id) { index, step in
                    directionStepRow(step, isLast: index == result.steps.count - 1)
                }
            }
            .padding(.horizontal)
        }
    }

    private func directionStepRow(_ step: NavigationStep, isLast: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            // Mode icon
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(modeColor(step.transportType).opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: modeIcon(step.transportType))
                        .font(.caption)
                        .foregroundStyle(modeColor(step.transportType))
                }

                if !isLast {
                    Rectangle()
                        .fill(AppColors.inactive.opacity(0.3))
                        .frame(width: 2, height: 24)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(step.instruction)
                    .font(.subheadline)

                HStack(spacing: Spacing.sm) {
                    if step.distance > 0 {
                        Text(formatDistance(step.distance))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let lineName = step.lineName {
                        GlassChip(lineName, color: modeColor(step.transportType))
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }

    private func modeIcon(_ mode: NavigationStep.TransportMode) -> String {
        switch mode {
        case .walk: return "figure.walk"
        case .tube: return "tram.fill"
        case .bus: return "bus.fill"
        case .rail: return "train.side.front.car"
        case .other: return "arrow.right"
        }
    }

    private func modeColor(_ mode: NavigationStep.TransportMode) -> Color {
        switch mode {
        case .walk: return AppColors.onTime
        case .tube: return AppColors.primary
        case .bus: return AppColors.delayed
        case .rail: return AppColors.accent
        case .other: return AppColors.inactive
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    private func formatArrival(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 { return "\(Int(meters))m" }
        return String(format: "%.1f km", meters / 1000)
    }
}
