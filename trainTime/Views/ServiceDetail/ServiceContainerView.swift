//
//  ServiceContainerView.swift
//  trainTime
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

    private var cacheService: CacheService {
        CacheService(modelContext: modelContext)
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
                ContentUnavailableView(
                    String(localized: "Unable to Load"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
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
            let detail = try await apiService.fetchServiceDetail(serviceID: serviceID)
            serviceDetail = detail
            isLoading = false
            isOffline = false
            cachedTime = nil

            // Cache
            cacheService.cacheServiceDetail(detail, serviceID: serviceID)
        } catch {
            // Try cache
            if let cached = cacheService.getCachedServiceDetail(serviceID: serviceID) {
                serviceDetail = cached.detail
                isOffline = true
                cachedTime = cached.fetchedAt
                HapticService.warning()
            } else {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
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
