//
//  ServiceContainerView.swift
//  LiveRail
//
//  Swipeable TabView(page) containing ServiceDetailView and TrainMapView
//

import SwiftUI

struct ServiceContainerView: View {
    let serviceID: String
    let serviceSummary: TrainService
    let apiService: HuxleyAPIService
    let stationSearch: StationSearchService

    @Environment(\.modelContext) private var modelContext
    @State private var serviceDetail: ServiceDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPage = 0
    @State private var refreshCoordinator = RefreshCoordinator()
    @State private var isOffline = false
    @State private var cachedTime: Date?
    @State private var connectivityMonitor = ConnectivityMonitor()
    @State private var liveActivityService = LiveActivityService()
    @State private var hspAPIService = NetworkRailHSPService()

    private var cacheService: CacheService {
        CacheService(modelContext: modelContext)
    }

    /// Check if train has departed based on scheduled departure time
    private var trainHasDeparted: Bool {
        guard let std = serviceSummary.std else { return false }

        // Parse the scheduled departure time (format: "HH:mm")
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current

        guard let scheduledTime = formatter.date(from: std) else { return false }

        // Get current time components
        let calendar = Calendar.current
        let now = Date()

        // Get scheduled time components
        let scheduledComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)

        // Create today's departure time
        var todayDeparture = DateComponents()
        todayDeparture.year = calendar.component(.year, from: now)
        todayDeparture.month = calendar.component(.month, from: now)
        todayDeparture.day = calendar.component(.day, from: now)
        todayDeparture.hour = scheduledComponents.hour
        todayDeparture.minute = scheduledComponents.minute

        guard let departureDate = calendar.date(from: todayDeparture) else { return false }

        // Train has departed if current time is past departure time
        return now >= departureDate
    }

    var body: some View {
        VStack(spacing: 0) {
            // Offline banner
            if isOffline, let cachedTime {
                offlineBanner(cachedTime: cachedTime)
                    .padding(.horizontal)
                    .padding(.top, Spacing.sm)
            }

            // Page selector
            HStack(spacing: 0) {
                pageTab(String(localized: "Calling Points"), icon: "list.bullet", index: 0)
                pageTab(String(localized: "Live Map"), icon: "map.fill", index: 1)
            }
            .padding(.horizontal)
            .padding(.top, Spacing.sm)

            if isLoading && serviceDetail == nil {
                Spacer()
                ProgressView(String(localized: "Loading service details..."))
                Spacer()
            } else if let errorMessage, serviceDetail == nil {
                Spacer()
                // Show basic information from departure board instead of error
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text(String(localized: "Limited Information"))
                        .font(.title2.bold())

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        InfoRow(label: "Destination", value: serviceSummary.destinationName)
                        if let operatorName = serviceSummary.operatorName {
                            InfoRow(label: "Operator", value: operatorName)
                        }
                        if let platform = serviceSummary.platform {
                            InfoRow(label: "Platform", value: platform)
                        }
                        InfoRow(label: "Departure", value: serviceSummary.departureTime)
                        InfoRow(label: "Status", value: serviceSummary.status.displayText)
                    }
                    .glassCard(material: .thin, cornerRadius: CornerRadius.lg, shadowRadius: 6, padding: Spacing.lg)
                    .padding(.horizontal)
                }
                Spacer()
            } else if let detail = serviceDetail {
                TabView(selection: $selectedPage) {
                    ServiceDetailView(
                        serviceDetail: detail,
                        stationSearch: stationSearch
                    )
                    .tag(0)

                    TrainMapView(
                        serviceDetail: detail,
                        stationSearch: stationSearch
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle(serviceSummary.destinationName)
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if liveActivityService.isTracking {
                        liveActivityService.stopTracking()
                    } else if let detail = serviceDetail {
                        liveActivityService.startTracking(
                            service: serviceSummary,
                            detail: detail,
                            apiService: apiService,
                            stationSearch: stationSearch
                        )
                    }
                } label: {
                    Label(
                        liveActivityService.isTracking ? String(localized: "Stop") : String(localized: "Track"),
                        systemImage: liveActivityService.isTracking ? "stop.circle.fill" : "location.circle"
                    )
                }
                .disabled(!liveActivityService.isTracking && !trainHasDeparted)
            }
        }
        .task {
            connectivityMonitor.start()
            connectivityMonitor.onReconnect = { [weak refreshCoordinator] in
                Task { @MainActor in
                    await refreshCoordinator?.triggerRefresh()
                }
            }

            refreshCoordinator.onRefresh = { [self] in
                await fetchDetail()
            }
            refreshCoordinator.startAutoRefresh()
            await fetchDetail()
        }
        .onDisappear {
            refreshCoordinator.stopAutoRefresh()
            connectivityMonitor.onReconnect = nil
            connectivityMonitor.stop()
        }
    }

    private func pageTab(_ title: String, icon: String, index: Int) -> some View {
        Button {
            HapticService.selection()
            withAnimation { selectedPage = index }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.caption)
                    Text(title)
                        .font(.subheadline.bold())
                }
                Rectangle()
                    .fill(selectedPage == index ? AppColors.primary : .clear)
                    .frame(height: 2)
            }
            .foregroundStyle(selectedPage == index ? AppColors.primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(selectedPage == index ? .isSelected : [])
        .accessibilityHint(selectedPage == index ? "" : title)
    }

    private func fetchDetail() async {
        do {
            print("Fetching service detail for ID: \(serviceID)")
            let detail = try await apiService.fetchServiceDetail(serviceID: serviceID)
            serviceDetail = detail
            isLoading = false
            isOffline = false
            cachedTime = nil

            // Cache
            cacheService.cacheServiceDetail(detail, serviceID: serviceID)
        } catch {
            print("Error fetching service detail: \(error)")

            // Try cache first
            if let cached = cacheService.getCachedServiceDetail(serviceID: serviceID) {
                serviceDetail = cached.detail
                isOffline = true
                cachedTime = cached.fetchedAt
                HapticService.warning()
                isLoading = false
                return
            }

            // Try Network Rail HSP or RealTimeTrains API as fallback (for departed trains)
            if let apiError = error as? APIError,
               case .httpError(let code) = apiError,
               code == 500 {
                print("Trying alternative APIs for departed train...")
                await tryHistoricalDataFallback()
            } else {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func tryHistoricalDataFallback() async {
        // Try Network Rail HSP (direct access to UK rail data)
        await tryHSPFallback()

        // If HSP failed, show error
        if serviceDetail == nil {
            if hspAPIService.username.isEmpty {
                errorMessage = "Service details unavailable for departed trains.\n\nRegister at opendata.nationalrail.co.uk and add your credentials in Settings to view historical data."
            } else {
                errorMessage = "Service not found in historical data."
            }
            isLoading = false
        }
    }

    private func tryHSPFallback() async {
        // Check if credentials are configured
        guard !hspAPIService.username.isEmpty && !hspAPIService.password.isEmpty else {
            print("Network Rail credentials not configured")
            return
        }

        // Extract origin and destination from service summary
        guard let originCRS = serviceSummary.origin?.first?.crs,
              let destinationCRS = serviceSummary.destination?.first?.crs,
              let departureTime = serviceSummary.std else {
            print("Missing origin, destination, or departure time")
            return
        }

        do {
            print("Trying Network Rail HSP API...")

            // Parse departure time to create search window
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            guard let depTime = formatter.date(from: departureTime) else {
                print("Failed to parse departure time: \(departureTime)")
                return
            }

            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: depTime)
            let minute = calendar.component(.minute, from: depTime)

            // Search from 30 minutes before to 30 minutes after
            let fromTime = String(format: "%02d%02d", max(0, hour * 60 + minute - 30) / 60, max(0, hour * 60 + minute - 30) % 60)
            let toTime = String(format: "%02d%02d", min(23, (hour * 60 + minute + 30) / 60), min(59, (hour * 60 + minute + 30) % 60))

            // Search for services (using serviceMetrics endpoint)
            let metricsResponse = try await hspAPIService.searchServices(
                from: originCRS,
                to: destinationCRS,
                fromDate: Date(),
                toDate: Date(),
                fromTime: fromTime,
                toTime: toTime
            )

            // Find matching service by scheduled departure time
            guard let match = findMatchingHSPService(in: metricsResponse.Services ?? [], targetTime: departureTime) else {
                print("No matching service found in HSP")
                return
            }

            let rid = match.rid
            print("Found matching RID: \(rid)")

            // Fetch detailed service from HSP
            let hspDetail = try await hspAPIService.fetchServiceByRID(rid)

            // Convert HSP data to our ServiceDetail format
            serviceDetail = hspDetail.toServiceDetail(originCRS: originCRS, destinationCRS: destinationCRS)
            isLoading = false
            print("✅ Successfully loaded service from Network Rail HSP API")
        } catch {
            print("HSP API error: \(error)")
        }
    }

    private func findMatchingHSPService(in services: [HSPMetricsService], targetTime: String) -> (service: HSPMetricsService, rid: String)? {
        guard !targetTime.isEmpty else {
            // Return first service with a valid RID
            if let first = services.first,
               let metrics = first.serviceAttributesMetrics,
               let rids = metrics.rids,
               let firstRID = rids.first {
                return (first, firstRID)
            }
            return nil
        }

        // Find service with matching scheduled departure time
        for service in services {
            guard let metrics = service.serviceAttributesMetrics,
                  let hspDeparture = metrics.gbtt_ptd,
                  let rids = metrics.rids,
                  let rid = rids.first else {
                continue
            }

            // Compare times (both should be in HH:mm or HHmm format)
            let hspTime = hspDeparture.replacingOccurrences(of: ":", with: "")
            let targetTimeClean = targetTime.replacingOccurrences(of: ":", with: "")

            if hspTime == targetTimeClean {
                return (service, rid)
            }
        }

        return nil
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
    }
}

// MARK: - Info Row Helper

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }
}
