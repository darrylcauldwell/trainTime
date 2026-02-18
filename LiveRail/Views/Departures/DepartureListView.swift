//
//  DepartureListView.swift
//  LiveRail
//
//  Filtered departure board with auto-refresh and offline support
//

import SwiftUI

struct DepartureListView: View {
    let origin: Station
    let destination: Station
    let apiService: HuxleyAPIService
    let stationSearch: StationSearchService
    let journeyService: JourneyPlanningService

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
    @State private var earlierTrainsCount = 4
    @State private var laterTrainsCount = 4
    @State private var showJourneyPlanner = false
    @State private var journeys: [Journey] = []
    @State private var isLoadingJourneys = false
    @State private var journeyError: String?
    @State private var selectedJourney: Journey?

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
                    VStack(spacing: Spacing.lg) {
                        // Journey planning results (auto-loaded when no direct trains)
                        if isLoadingJourneys {
                            VStack(spacing: Spacing.md) {
                                ProgressView(String(localized: "Searching for connecting journeys..."))
                                    .padding(.top, Spacing.jumbo)
                                Text(String(localized: "No direct trains found. Checking for routes with changes."))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        } else if !journeys.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                HStack {
                                    Image(systemName: "arrow.triangle.branch")
                                        .foregroundStyle(AppColors.primary)
                                    Text(String(localized: "Journeys with Changes"))
                                        .font(.headline)
                                    Spacer()
                                    Button(String(localized: "All Options")) {
                                        HapticService.lightImpact()
                                        showJourneyPlanner = true
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.primary)
                                }
                                .padding(.horizontal)
                                .padding(.top, Spacing.md)

                                ForEach(journeys) { journey in
                                    Button {
                                        HapticService.lightImpact()
                                        selectedJourney = journey
                                    } label: {
                                        JourneyCard(journey: journey)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                String(localized: "No Trains Found"),
                                systemImage: "tram.fill",
                                description: Text("No services found from \(origin.name) to \(destination.name). Try a different time.")
                            )
                            .padding(.top, Spacing.jumbo)

                            if let journeyError {
                                Text(journeyError)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }

                            Button {
                                HapticService.lightImpact()
                                showJourneyPlanner = true
                            } label: {
                                Label(String(localized: "Open Journey Planner"), systemImage: "arrow.triangle.branch")
                                    .font(.headline)
                            }
                            .buttonStyle(GlassButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // Split into departed and upcoming trains
                    let (departedTrains, upcomingTrains) = splitTrains(departures)

                    LazyVStack(spacing: Spacing.sm) {
                        // Earlier (departed) trains section
                        if !departedTrains.isEmpty {
                            let visibleDeparted = Array(departedTrains.suffix(earlierTrainsCount))

                            if departedTrains.count > earlierTrainsCount {
                                Button {
                                    earlierTrainsCount += 4
                                } label: {
                                    HStack {
                                        Image(systemName: "chevron.up")
                                        Text(String(localized: "Show Earlier Trains"))
                                        Spacer()
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(AppColors.primary)
                                    .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 4, padding: Spacing.md)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }

                            ForEach(visibleDeparted) { service in
                                Button {
                                    HapticService.lightImpact()
                                    selectedService = service
                                } label: {
                                    DepartureRow(service: service)
                                }
                                .buttonStyle(.plain)

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
                                }
                            }

                            // Divider between departed and upcoming
                            HStack {
                                Rectangle()
                                    .fill(.secondary.opacity(0.3))
                                    .frame(height: 1)
                                Text(String(localized: "NOW"))
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Rectangle()
                                    .fill(.secondary.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, Spacing.sm)
                        }

                        // Upcoming trains section
                        let visibleUpcoming = Array(upcomingTrains.prefix(laterTrainsCount))

                        ForEach(visibleUpcoming) { service in
                            Button {
                                HapticService.lightImpact()
                                selectedService = service
                            } label: {
                                DepartureRow(service: service)
                            }
                            .buttonStyle(.plain)

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
                            }
                        }

                        if upcomingTrains.count > laterTrainsCount {
                            Button {
                                laterTrainsCount += 4
                            } label: {
                                HStack {
                                    Image(systemName: "chevron.down")
                                    Text(String(localized: "Show Later Trains"))
                                    Spacer()
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(AppColors.primary)
                                .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 4, padding: Spacing.md)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
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
        .sheet(isPresented: $showJourneyPlanner) {
            JourneyPlannerView(
                origin: origin,
                destination: destination,
                journeyService: journeyService,
                cacheService: cacheService
            )
        }
        .sheet(item: $selectedJourney) { journey in
            NavigationStack {
                JourneyDetailView(journey: journey)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Close")) {
                                selectedJourney = nil
                            }
                        }
                    }
            }
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

    /// Split trains into departed and upcoming based on current time
    private func splitTrains(_ trains: [TrainService]) -> (departed: [TrainService], upcoming: [TrainService]) {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current

        var departed: [TrainService] = []
        var upcoming: [TrainService] = []

        for service in trains {
            guard let std = service.std,
                  let scheduledTime = formatter.date(from: std) else {
                upcoming.append(service)
                continue
            }

            // Create today's departure time
            let calendar = Calendar.current
            var todayDeparture = DateComponents()
            todayDeparture.year = calendar.component(.year, from: now)
            todayDeparture.month = calendar.component(.month, from: now)
            todayDeparture.day = calendar.component(.day, from: now)
            let scheduledComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
            todayDeparture.hour = scheduledComponents.hour
            todayDeparture.minute = scheduledComponents.minute

            guard let departureDate = calendar.date(from: todayDeparture) else {
                upcoming.append(service)
                continue
            }

            if now >= departureDate {
                departed.append(service)
            } else {
                upcoming.append(service)
            }
        }

        return (departed, upcoming)
    }

    private func fetchDepartures() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch both departed trains (last hour) and upcoming trains
            async let departedBoard = apiService.fetchScheduleDepartures(
                from: origin.crs,
                to: destination.crs,
                at: Date().addingTimeInterval(-60 * 60) // 1 hour ago
            )
            async let upcomingBoard = apiService.fetchDepartures(
                from: origin.crs,
                to: destination.crs
            )

            // Combine results
            let (departed, upcoming) = try await (departedBoard, upcomingBoard)

            // Merge and deduplicate by serviceID
            var allServices: [String: TrainService] = [:]
            for service in departed.services {
                if let id = service.serviceID {
                    allServices[id] = service
                }
            }
            for service in upcoming.services {
                if let id = service.serviceID {
                    allServices[id] = service
                }
            }

            // Sort by scheduled departure time
            departures = allServices.values.sorted { s1, s2 in
                guard let std1 = s1.std, let std2 = s2.std else { return false }
                return std1 < std2
            }

            isOffline = false
            cachedTime = nil
            HapticService.success()

            // Cache the current board
            cacheService.cacheDepartures(upcoming, origin: origin.crs, destination: destination.crs)

            // Auto-search for connecting journeys when no direct trains found
            if departures.isEmpty {
                await fetchJourneys()
            }
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

    private func fetchJourneys() async {
        isLoadingJourneys = true
        journeyError = nil
        journeys = []

        do {
            journeys = try await journeyService.planJourney(
                from: origin.crs,
                to: destination.crs
            )
        } catch {
            journeyError = error.localizedDescription
        }

        isLoadingJourneys = false
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
