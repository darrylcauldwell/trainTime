//
//  HistoryView.swift
//  LiveRail
//
//  Browse departures at any station around a chosen time.
//  Uses Huxley2 (Darwin) for live and recent data (within ±2 hours).
//  Tapping a service opens ServiceContainerView with full calling points
//  and actual times — the same detail shown for live services.
//

import SwiftUI

struct HistoryView: View {
    let stationSearch: StationSearchService
    let apiService: HuxleyAPIService

    @State private var station: Station?
    @State private var selectedDate = Date()
    @State private var showStationPicker = false
    @State private var services: [TrainService] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedService: TrainService?
    @State private var hasSearched = false

    // Darwin/Huxley2 only supports ±120 minutes from now
    private var minutesFromNow: Int {
        Int(selectedDate.timeIntervalSinceNow / 60)
    }

    private var isWithinAPIRange: Bool {
        abs(minutesFromNow) <= 120
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    searchControls
                        .padding(.top, Spacing.sm)

                    if !isWithinAPIRange {
                        outOfRangeBanner
                    } else if isLoading {
                        ProgressView(String(localized: "Loading services..."))
                            .padding(.top, Spacing.jumbo)
                    } else if let errorMessage {
                        ContentUnavailableView(
                            String(localized: "Unable to Load"),
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorMessage)
                        )
                        .padding(.top, Spacing.xl)
                    } else if hasSearched && services.isEmpty {
                        ContentUnavailableView(
                            String(localized: "No Services Found"),
                            systemImage: "tram",
                            description: Text(String(localized: "No services found at this station for the selected time."))
                        )
                        .padding(.top, Spacing.xl)
                    } else if !services.isEmpty {
                        servicesList
                    } else {
                        emptyPrompt
                    }
                }
                .padding(.bottom, Spacing.jumbo)
            }
            .refreshable {
                await fetchServices()
            }
            .navigationTitle(String(localized: "History"))
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigation()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedDate = Date()
                        if station != nil { Task { await fetchServices() } }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel(String(localized: "Reset to now"))
                }
            }
            .sheet(isPresented: $showStationPicker) {
                StationPickerView(
                    title: String(localized: "Select Station"),
                    stationSearch: stationSearch
                ) { picked in
                    station = picked
                    Task { await fetchServices() }
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
        }
    }

    // MARK: - Search Controls

    private var searchControls: some View {
        VStack(spacing: Spacing.md) {
            // Station selector
            Button {
                showStationPicker = true
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Station"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(station?.name ?? String(localized: "Select a station"))
                            .font(.headline)
                            .foregroundStyle(station != nil ? .primary : .tertiary)
                    }

                    Spacer()

                    if let crs = station?.crs {
                        Text(crs)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .glassCard(material: .thin, cornerRadius: CornerRadius.lg, shadowRadius: 6, padding: Spacing.lg)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            // Date + time pickers
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Date"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .onChange(of: selectedDate) { _, _ in
                            if station != nil && isWithinAPIRange {
                                Task { await fetchServices() }
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 2, padding: Spacing.sm)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Time"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .onChange(of: selectedDate) { _, _ in
                            if station != nil && isWithinAPIRange {
                                Task { await fetchServices() }
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 2, padding: Spacing.sm)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Out of Range Banner

    private var outOfRangeBanner: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(AppColors.delayed)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Outside Available Range"))
                        .font(.subheadline.bold())
                    Text(String(localized: "Live data is only available within 2 hours of now. Use the clock button to return to the current time."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Spacing.md)
            .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 4, padding: 0)
            .padding(.horizontal)
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Empty Prompt

    private var emptyPrompt: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "tram.circle")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.primary.opacity(0.6))
                .padding(.top, Spacing.jumbo)

            VStack(spacing: Spacing.sm) {
                Text(String(localized: "Browse Departures"))
                    .font(.title3.bold())
                Text(String(localized: "Select a station and time to see all services. Tap any service for full calling points with actual arrival and departure times."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                featureRow("clock.arrow.circlepath", String(localized: "Live and recent services (within 2 hours)"))
                featureRow("list.bullet.rectangle", String(localized: "All calling points with scheduled times"))
                featureRow("checkmark.circle", String(localized: "Actual times for services underway or completed"))
                featureRow("arrow.triangle.branch", String(localized: "Platform numbers and status"))
            }
            .padding(Spacing.md)
            .glassCard(material: .thin, cornerRadius: CornerRadius.lg, shadowRadius: 6, padding: 0)
            .padding(.horizontal)
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(AppColors.primary)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Services List

    private var servicesList: some View {
        LazyVStack(spacing: Spacing.sm) {
            Text(timeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            ForEach(services) { service in
                Button {
                    HapticService.lightImpact()
                    selectedService = service
                } label: {
                    DepartureRow(service: service)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timeLabel: String {
        let mins = minutesFromNow
        if abs(mins) < 5 { return String(localized: "Showing services now") }
        if mins < 0 { return String(localized: "Showing services from \(abs(mins)) minutes ago") }
        return String(localized: "Showing services in \(mins) minutes")
    }

    // MARK: - Fetch

    private func fetchServices() async {
        guard let station, isWithinAPIRange else { return }
        isLoading = true
        errorMessage = nil
        hasSearched = true

        do {
            let board = try await apiService.fetchAllDepartures(
                from: station.crs,
                timeOffset: minutesFromNow
            )
            services = board.services
            HapticService.success()
        } catch {
            errorMessage = error.localizedDescription
            services = []
        }

        isLoading = false
    }
}
