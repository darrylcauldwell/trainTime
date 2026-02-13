//
//  JourneySearchView.swift
//  trainTime
//
//  Origin + destination picker with search button
//

import SwiftUI
import SwiftData

struct JourneySearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecentRoute.searchedAt, order: .reverse) private var recentRoutes: [RecentRoute]
    let stationSearch: StationSearchService
    let apiService: HuxleyAPIService

    @State private var origin: Station?
    @State private var destination: Station?
    @State private var showOriginPicker = false
    @State private var showDestinationPicker = false
    @State private var navigateToDepartures = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Header
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "tram.fill")
                            .font(.largeTitle)
                            .foregroundStyle(AppColors.primary)
                        Text("trainTime")
                            .font(.largeTitle.bold())
                        Text(String(localized: "Search by route, not by station"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Spacing.jumbo)

                    // Station selection cards
                    VStack(spacing: Spacing.md) {
                        StationSelectionCard(
                            label: String(localized: "From"),
                            station: origin,
                            icon: "arrow.up.circle.fill",
                            color: AppColors.primary
                        ) {
                            showOriginPicker = true
                        }

                        // Swap button
                        Button {
                            HapticService.lightImpact()
                            let temp = origin
                            origin = destination
                            destination = temp
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppColors.primary)
                                .padding(Spacing.sm)
                        }
                        .disabled(origin == nil && destination == nil)
                        .accessibilityLabel(String(localized: "Swap origin and destination"))

                        StationSelectionCard(
                            label: String(localized: "To"),
                            station: destination,
                            icon: "arrow.down.circle.fill",
                            color: AppColors.accent
                        ) {
                            showDestinationPicker = true
                        }
                    }
                    .padding(.horizontal)

                    // Search button
                    Button {
                        HapticService.lightImpact()
                        trackRoute()
                        navigateToDepartures = true
                    } label: {
                        Label(String(localized: "Find Trains"), systemImage: "magnifyingglass")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(origin == nil || destination == nil)
                    .padding(.horizontal)

                    // Save journey button
                    if origin != nil && destination != nil {
                        Button {
                            HapticService.success()
                            saveJourney()
                        } label: {
                            Label(String(localized: "Save Journey"), systemImage: "star")
                                .font(.subheadline)
                        }
                        .buttonStyle(GlassButtonStyle())
                    }

                    // Recent routes
                    if !recentRoutes.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            GlassSectionHeader("Recent", icon: "clock.arrow.circlepath")

                            ForEach(recentRoutes.prefix(5)) { route in
                                Button {
                                    origin = stationSearch.station(forCRS: route.originCRS)
                                    destination = stationSearch.station(forCRS: route.destinationCRS)
                                } label: {
                                    HStack(spacing: Spacing.md) {
                                        Image(systemName: "clock")
                                            .foregroundStyle(.secondary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: Spacing.sm) {
                                                Text(route.originName)
                                                    .font(.subheadline.bold())
                                                Image(systemName: "arrow.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text(route.destinationName)
                                                    .font(.subheadline.bold())
                                            }
                                            Text("\(route.originCRS) - \(route.destinationCRS)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 4, padding: Spacing.md)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: Spacing.jumbo)
                }
            }
            .navigationTitle(String(localized: "Search"))
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigation()
            .sheet(isPresented: $showOriginPicker) {
                StationPickerView(title: String(localized: "From Station"), stationSearch: stationSearch) { station in
                    origin = station
                }
            }
            .sheet(isPresented: $showDestinationPicker) {
                StationPickerView(title: String(localized: "To Station"), stationSearch: stationSearch) { station in
                    destination = station
                }
            }
            .navigationDestination(isPresented: $navigateToDepartures) {
                if let origin, let destination {
                    DepartureListView(
                        origin: origin,
                        destination: destination,
                        apiService: apiService,
                        stationSearch: stationSearch
                    )
                }
            }
        }
    }

    private func saveJourney() {
        guard let origin, let destination else { return }
        let journey = SavedJourney(
            originCRS: origin.crs,
            originName: origin.name,
            destinationCRS: destination.crs,
            destinationName: destination.name
        )
        modelContext.insert(journey)

        // Sync to widget
        let widgetJourney = WidgetJourney(
            originCRS: origin.crs,
            originName: origin.name,
            destinationCRS: destination.crs,
            destinationName: destination.name
        )
        widgetJourney.save()
    }

    private func trackRoute() {
        guard let origin, let destination else { return }
        let routeKey = "\(origin.crs)-\(destination.crs)"

        // Upsert: update timestamp if exists, otherwise insert
        if let existing = recentRoutes.first(where: { $0.routeKey == routeKey }) {
            existing.searchedAt = Date()
        } else {
            let route = RecentRoute(
                originCRS: origin.crs,
                originName: origin.name,
                destinationCRS: destination.crs,
                destinationName: destination.name
            )
            modelContext.insert(route)
        }

        // Prune to 15 most recent
        if recentRoutes.count > 15 {
            let toDelete = recentRoutes.suffix(from: 15)
            for route in toDelete {
                modelContext.delete(route)
            }
        }
    }
}

// MARK: - Station Selection Card

struct StationSelectionCard: View {
    let label: String
    let station: Station?
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let station {
                        Text(station.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(station.crs)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(localized: "Select station"))
                            .font(.headline)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .glassCard(material: .thin, cornerRadius: CornerRadius.lg, shadowRadius: 6, padding: Spacing.lg)
        }
        .buttonStyle(.plain)
    }
}
