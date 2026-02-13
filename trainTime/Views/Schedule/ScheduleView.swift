//
//  ScheduleView.swift
//  trainTime
//
//  Both-directions schedule with next train highlighted
//

import SwiftUI
import SwiftData

struct ScheduleView: View {
    let stationSearch: StationSearchService
    let apiService: HuxleyAPIService

    @Query(sort: \SavedJourney.createdAt, order: .reverse) private var savedJourneys: [SavedJourney]
    @State private var origin: Station?
    @State private var destination: Station?
    @State private var showOriginPicker = false
    @State private var showDestinationPicker = false
    @State private var outboundServices: [TrainService] = []
    @State private var returnServices: [TrainService] = []
    @State private var isLoading = false
    @State private var refreshCoordinator = RefreshCoordinator()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Route selector
                    routeSelector

                    if origin != nil && destination != nil {
                        if isLoading && outboundServices.isEmpty && returnServices.isEmpty {
                            ProgressView(String(localized: "Loading schedule..."))
                                .padding(.top, Spacing.jumbo)
                        } else {
                            // Outbound
                            scheduleSection(
                                title: "\(String(localized: "To")) \(destination?.name ?? "")",
                                services: outboundServices
                            )

                            Divider()
                                .padding(.horizontal)

                            // Return
                            scheduleSection(
                                title: "\(String(localized: "To")) \(origin?.name ?? "")",
                                services: returnServices
                            )
                        }
                    } else {
                        // Show saved journeys for quick access
                        if !savedJourneys.isEmpty {
                            GlassSectionHeader(String(localized: "Quick Select"), icon: "star.fill")

                            ForEach(savedJourneys) { journey in
                                Button {
                                    origin = stationSearch.station(forCRS: journey.originCRS)
                                    destination = stationSearch.station(forCRS: journey.destinationCRS)
                                    Task { await fetchSchedule() }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("\(journey.originName) to \(journey.destinationName)")
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 4, padding: Spacing.md)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }

                        ContentUnavailableView(
                            String(localized: "Select a Route"),
                            systemImage: "arrow.left.arrow.right",
                            description: Text(String(localized: "Choose origin and destination to see the schedule"))
                        )
                        .padding(.top, Spacing.xl)
                    }
                }
                .padding(.top, Spacing.sm)
            }
            .refreshable {
                await fetchSchedule()
            }
            .navigationTitle(String(localized: "Schedule"))
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigation()
            .sheet(isPresented: $showOriginPicker) {
                StationPickerView(title: String(localized: "From"), stationSearch: stationSearch) { station in
                    origin = station
                    if destination != nil { Task { await fetchSchedule() } }
                }
            }
            .sheet(isPresented: $showDestinationPicker) {
                StationPickerView(title: String(localized: "To"), stationSearch: stationSearch) { station in
                    destination = station
                    if origin != nil { Task { await fetchSchedule() } }
                }
            }
            .task {
                refreshCoordinator.refreshInterval = 60
                refreshCoordinator.onRefresh = {
                    await fetchSchedule()
                }
                refreshCoordinator.startAutoRefresh()
            }
            .onDisappear {
                refreshCoordinator.stopAutoRefresh()
                refreshCoordinator.onRefresh = nil
            }
        }
    }

    private var routeSelector: some View {
        HStack(spacing: Spacing.sm) {
            Button { showOriginPicker = true } label: {
                VStack(alignment: .leading) {
                    Text(String(localized: "From"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(origin?.name ?? String(localized: "Select"))
                        .font(.subheadline.bold())
                        .foregroundStyle(origin != nil ? .primary : .tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(material: .thin, cornerRadius: CornerRadius.sm, shadowRadius: 2, padding: Spacing.sm)
            }
            .buttonStyle(.plain)

            Image(systemName: "arrow.left.arrow.right")
                .foregroundStyle(AppColors.primary)

            Button { showDestinationPicker = true } label: {
                VStack(alignment: .leading) {
                    Text(String(localized: "To"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(destination?.name ?? String(localized: "Select"))
                        .font(.subheadline.bold())
                        .foregroundStyle(destination != nil ? .primary : .tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(material: .thin, cornerRadius: CornerRadius.sm, shadowRadius: 2, padding: Spacing.sm)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private func scheduleSection(title: String, services: [TrainService]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            GlassSectionHeader(title, icon: "tram.fill")

            if services.isEmpty {
                Text(String(localized: "No services found"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                    if index == 0 {
                        // Next train - prominent card
                        nextTrainCard(service: service)
                    } else {
                        // Compact row
                        compactScheduleRow(service: service)
                    }
                }
            }
        }
    }

    private func nextTrainCard(service: TrainService) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                GlassChip(String(localized: "NEXT"), icon: "clock.fill", color: AppColors.nextTrain)
                Spacer()
                StatusBadge(status: service.status)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(service.departureTime)
                    .font(.title.bold().monospacedDigit())

                Spacer()

                if let platform = service.platform {
                    VStack {
                        Text(String(localized: "Platform"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(platform)
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.platform)
                    }
                }
            }

            Text(service.destinationName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let countdown = TrainTimeFormatter.minutesUntil(service.std), countdown > 0 {
                Text("in \(countdown) min")
                    .font(.caption.bold())
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding(Spacing.lg)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(AppColors.nextTrain, lineWidth: BorderWidth.emphasis)
        )
        .glassCard(material: .regular, cornerRadius: CornerRadius.lg, shadowRadius: 8, padding: 0)
        .padding(.horizontal)
    }

    private func compactScheduleRow(service: TrainService) -> some View {
        HStack(spacing: Spacing.md) {
            Text(service.departureTime)
                .font(.subheadline.bold().monospacedDigit())
                .frame(minWidth: 45, alignment: .leading)
                .fixedSize()

            Circle()
                .fill(service.status == .onTime ? AppColors.onTime :
                        service.status == .delayed ? AppColors.delayed : AppColors.cancelled)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(service.destinationName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            if let platform = service.platform {
                Text("P\(platform)")
                    .font(.caption.bold())
                    .foregroundStyle(AppColors.platform)
            }

            Text(service.status.displayText)
                .font(.caption2)
                .foregroundStyle(service.status == .onTime ? AppColors.onTime :
                                    service.status == .delayed ? AppColors.delayed : AppColors.cancelled)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.xs)
    }

    private func fetchSchedule() async {
        guard let origin, let destination else { return }
        isLoading = true

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                if let board = try? await apiService.fetchScheduleDepartures(from: origin.crs, to: destination.crs) {
                    await MainActor.run { outboundServices = board.services }
                }
            }
            group.addTask {
                if let board = try? await apiService.fetchScheduleDepartures(from: destination.crs, to: origin.crs) {
                    await MainActor.run { returnServices = board.services }
                }
            }
        }

        isLoading = false
    }
}
