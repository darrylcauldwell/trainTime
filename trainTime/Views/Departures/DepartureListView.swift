//
//  DepartureListView.swift
//  trainTime
//
//  Filtered departure board with auto-refresh and offline support
//

import SwiftUI

struct DepartureListView: View {
    let origin: Station
    let destination: Station
    let apiService: HuxleyAPIService
    let stationSearch: StationSearchService

    @Environment(\.modelContext) private var modelContext
    @State private var departures: [TrainService] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOffline = false
    @State private var cachedTime: Date?
    @State private var selectedService: TrainService?
    @State private var refreshCoordinator = RefreshCoordinator()
    @State private var connectivityMonitor = ConnectivityMonitor()
    @State private var showAlternatives = false

    private var cacheService: CacheService {
        CacheService(modelContext: modelContext)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                // Offline banner
                if isOffline, let cachedTime {
                    offlineBanner(cachedTime: cachedTime)
                }

                // Error message
                if let errorMessage, departures.isEmpty {
                    ContentUnavailableView(
                        String(localized: "Unable to Load"),
                        systemImage: "wifi.slash",
                        description: Text(errorMessage)
                    )
                    .padding(.top, Spacing.jumbo)
                } else if departures.isEmpty && !isLoading {
                    ContentUnavailableView(
                        String(localized: "No Direct Trains"),
                        systemImage: "tram.fill",
                        description: Text("No direct services found from \(origin.name) to \(destination.name)")
                    )
                    .padding(.top, Spacing.jumbo)
                } else {
                    // Departure list
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(departures) { service in
                            Button {
                                HapticService.lightImpact()
                                selectedService = service
                            } label: {
                                DepartureRow(service: service)
                            }
                            .buttonStyle(.plain)

                            // Show "Find Alternatives" for cancelled services
                            if service.isCancelled == true {
                                Button {
                                    HapticService.warning()
                                    showAlternatives = true
                                } label: {
                                    Label(String(localized: "Find Alternatives"), systemImage: "arrow.triangle.branch")
                                        .font(.caption.bold())
                                        .foregroundStyle(AppColors.accent)
                                }
                                .padding(.horizontal, Spacing.xl)
                                .padding(.bottom, Spacing.sm)
                                .accessibilityHint("Shows running services on this route")
                            }
                        }
                    }
                }
            }
            .padding(.top, Spacing.sm)
        }
        .refreshable {
            await fetchDepartures()
        }
        .navigationTitle("\(origin.crs) to \(destination.crs)")
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await fetchDepartures() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GetToStationView(station: origin, stationSearch: stationSearch)
                } label: {
                    Image(systemName: "figure.walk.departure")
                }
            }
        }
        .navigationDestination(item: $selectedService) { service in
            if let serviceID = service.serviceID {
                ServiceContainerView(
                    serviceID: serviceID,
                    serviceSummary: service,
                    apiService: apiService,
                    stationSearch: stationSearch
                )
            }
        }
        .sheet(isPresented: $showAlternatives) {
            AlternativeRoutesView(
                origin: origin,
                destination: destination,
                apiService: apiService,
                stationSearch: stationSearch
            )
        }
        .task {
            connectivityMonitor.start()
            connectivityMonitor.onReconnect = { [weak refreshCoordinator] in
                Task { @MainActor in
                    await refreshCoordinator?.triggerRefresh()
                }
            }

            refreshCoordinator.onRefresh = {
                await fetchDepartures()
            }
            refreshCoordinator.startAutoRefresh()

            await fetchDepartures()
        }
        .onDisappear {
            refreshCoordinator.stopAutoRefresh()
            connectivityMonitor.onReconnect = nil
            connectivityMonitor.stop()
        }
    }

    private func fetchDepartures() async {
        isLoading = true
        errorMessage = nil

        do {
            let board = try await apiService.fetchDepartures(from: origin.crs, to: destination.crs)
            departures = board.services
            isOffline = false
            cachedTime = nil
            HapticService.success()

            // Cache the result
            cacheService.cacheDepartures(board, origin: origin.crs, destination: destination.crs)
        } catch {
            // Try cache fallback
            if let cached = cacheService.getCachedDepartures(origin: origin.crs, destination: destination.crs) {
                departures = cached.board.services
                isOffline = true
                cachedTime = cached.fetchedAt
                HapticService.warning()
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func offlineBanner(cachedTime: Date) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Offline - showing data from \(TrainTimeFormatter.relativeTime(from: cachedTime))")
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(AppColors.delayed)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        .padding(.horizontal)
        .accessibilityLabel("Offline - showing data from \(TrainTimeFormatter.relativeTime(from: cachedTime))")
    }
}

// MARK: - Alternative Routes View (for cancelled trains)

struct AlternativeRoutesView: View {
    @Environment(\.dismiss) private var dismiss
    let origin: Station
    let destination: Station
    let apiService: HuxleyAPIService
    let stationSearch: StationSearchService

    @State private var alternatives: [TrainService] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView(String(localized: "Finding alternatives..."))
                        .padding(.top, Spacing.jumbo)
                } else if alternatives.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Alternatives"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(String(localized: "No alternative services found"))
                    )
                } else {
                    VStack(spacing: Spacing.sm) {
                        Text("Running services from \(origin.name) to \(destination.name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()

                        ForEach(alternatives) { service in
                            DepartureRow(service: service)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Alternatives"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
            .glassNavigation()
            .task {
                await findAlternatives()
            }
        }
    }

    private func findAlternatives() async {
        isLoading = true
        do {
            let board = try await apiService.fetchDepartures(from: origin.crs, to: destination.crs, rows: 20)
            alternatives = board.services.filter { $0.isCancelled != true }
        } catch {
            alternatives = []
        }
        isLoading = false
    }
}
