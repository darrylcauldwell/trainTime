//
//  ScheduleView.swift
//  LiveRail
//
//  Both-directions schedule with next train highlighted
//

import SwiftUI
import SwiftData

struct ScheduleView: View {
    let stationSearch: StationSearchService
    let apiService: HuxleyAPIService

    @Query(sort: \RecentRoute.searchedAt, order: .reverse) private var recentRoutes: [RecentRoute]
    @Environment(\.modelContext) private var modelContext
    @State private var origin: Station?
    @State private var destination: Station?
    @State private var showOriginPicker = false
    @State private var showDestinationPicker = false
    @State private var outboundServices: [TrainService] = []
    @State private var returnServices: [TrainService] = []
    @State private var isLoading = false
    @State private var refreshCoordinator = RefreshCoordinator()

    // Date/Time planning
    @State private var outboundDate: Date = Date()
    @State private var outboundTime: Date = Date()
    @State private var includeReturn: Bool = false
    @State private var returnDate: Date = Date()
    @State private var returnTime: Date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Route selector
                    routeSelector

                    // Date/Time Planning Section
                    if origin != nil && destination != nil {
                        planningControls
                    }

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
                        // Recent routes with pin/unpin (shared with Live tab)
                        if !recentRoutes.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                // Pinned routes
                                let pinnedRoutes = recentRoutes.filter { $0.isPinned }.sorted { ($0.pinnedAt ?? Date()) > ($1.pinnedAt ?? Date()) }
                                let unpinnedRoutes = recentRoutes.filter { !$0.isPinned }.prefix(5)

                                if !pinnedRoutes.isEmpty {
                                    GlassSectionHeader(String(localized: "Pinned"), icon: "star.fill")

                                    ForEach(pinnedRoutes) { route in
                                        routeRow(route)
                                    }
                                }

                                if !unpinnedRoutes.isEmpty {
                                    GlassSectionHeader(String(localized: "Recent"), icon: "clock.arrow.circlepath")

                                    ForEach(unpinnedRoutes) { route in
                                        routeRow(route)
                                    }
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                String(localized: "Select a Route"),
                                systemImage: "arrow.left.arrow.right",
                                description: Text(String(localized: "Choose origin and destination to plan your journey"))
                            )
                            .padding(.top, Spacing.xl)
                        }
                    }
                }
                .padding(.top, Spacing.sm)
            }
            .refreshable {
                await fetchSchedule()
            }
            .navigationTitle(String(localized: "Plan"))
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigation()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        resetPlanForm()
                    } label: {
                        Label(String(localized: "Reset"), systemImage: "arrow.counterclockwise")
                    }
                    .disabled(origin == nil && destination == nil)
                }
            }
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
                // Plan view doesn't need auto-refresh since users are planning ahead
                // Auto-refresh disabled for better UX
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

    private var planningControls: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Outbound Section
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(String(localized: "Outbound"))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .padding(.horizontal)

                HStack(spacing: Spacing.md) {
                    // Date Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Date"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $outboundDate, in: Date()...Date().addingTimeInterval(7*24*60*60), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 2, padding: Spacing.sm)

                    // Time Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "After"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $outboundTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 2, padding: Spacing.sm)
                }
                .padding(.horizontal)
            }

            // Return Journey Toggle
            Toggle(String(localized: "Include return journey"), isOn: $includeReturn)
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.vertical, Spacing.sm)
                .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 2, padding: Spacing.sm)
                .padding(.horizontal)

            // Return Section (conditional)
            if includeReturn {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(String(localized: "Return"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .padding(.horizontal)

                    HStack(spacing: Spacing.md) {
                        // Date Picker
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Date"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $returnDate, in: outboundDate...outboundDate.addingTimeInterval(7*24*60*60), displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }
                        .frame(maxWidth: .infinity)
                        .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 2, padding: Spacing.sm)

                        // Time Picker
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "After"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $returnTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }
                        .frame(maxWidth: .infinity)
                        .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 2, padding: Spacing.sm)
                    }
                    .padding(.horizontal)
                }
            }

            // Search Button
            Button {
                Task { await fetchSchedule() }
            } label: {
                Label(String(localized: "Find Trains"), systemImage: "magnifyingglass")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal)
        }
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

        // Track this route in recent history (shared with Live tab)
        trackRoute()

        // Combine date and time for outbound
        let outboundDateTime = combineDateAndTime(date: outboundDate, time: outboundTime)

        // Combine date and time for return (if included)
        let returnDateTime = includeReturn ? combineDateAndTime(date: returnDate, time: returnTime) : nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                if let board = try? await apiService.fetchScheduleDepartures(from: origin.crs, to: destination.crs, at: outboundDateTime) {
                    await MainActor.run { outboundServices = board.services }
                }
            }
            if includeReturn {
                group.addTask {
                    if let board = try? await apiService.fetchScheduleDepartures(from: destination.crs, to: origin.crs, at: returnDateTime) {
                        await MainActor.run { returnServices = board.services }
                    }
                }
            } else {
                // Clear return services if not included
                await MainActor.run { returnServices = [] }
            }
        }

        isLoading = false
    }

    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? Date()
    }

    private func resetPlanForm() {
        HapticService.lightImpact()

        // Reset stations
        origin = nil
        destination = nil

        // Reset dates/times to now
        outboundDate = Date()
        outboundTime = Date()
        returnDate = Date()
        returnTime = Date()

        // Reset return toggle
        includeReturn = false

        // Clear results
        outboundServices = []
        returnServices = []
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

    private func routeRow(_ route: RecentRoute) -> some View {
        HStack(spacing: Spacing.md) {
            Button {
                origin = stationSearch.station(forCRS: route.originCRS)
                destination = stationSearch.station(forCRS: route.destinationCRS)
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "tram.fill")
                        .foregroundStyle(AppColors.primary)

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
                }
            }
            .buttonStyle(.plain)

            // Star button to pin/unpin
            Button {
                HapticService.lightImpact()
                route.togglePin()
            } label: {
                Image(systemName: route.isPinned ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(route.isPinned ? AppColors.delayed : .secondary)
            }
            .buttonStyle(.plain)
        }
        .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 4, padding: Spacing.md)
        .padding(.horizontal)
    }
}
