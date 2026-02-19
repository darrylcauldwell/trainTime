//
//  GetHomeView.swift
//  LiveRail
//
//  One-tap route planning from current location to home station.
//  Queries London termini (or nearest stations) via Huxley2 for live departures.
//

import SwiftUI
import CoreLocation

struct GetHomeView: View {
    let journeyService: JourneyPlanningService
    let stationSearch: StationSearchService

    @State private var homeStation: Station? = GetHomeView.loadHomeStation()
    @State private var showHomePicker = false
    @State private var locationService = LocationService()
    @State private var homeOptions: [GetHomeOption] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        homeStationCard
                        getHomeButton

                        if locationService.authorizationStatus == .denied {
                            locationDeniedBanner
                        }

                        if isLoading {
                            ProgressView(String(localized: "Finding routes home…"))
                                .padding(.top, Spacing.jumbo)
                        } else if let error = errorMessage {
                            errorView(error)
                        } else if hasSearched && homeOptions.isEmpty {
                            emptyState
                        } else if !homeOptions.isEmpty {
                            homeOptionsSection(proxy: proxy)
                        }
                    }
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.jumbo)
                }
            }
            .navigationTitle(String(localized: "Get Home"))
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigation()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        NotificationCenter.default.post(name: .navigateToSettings, object: nil)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(String(localized: "Settings"))
                }
            }
            .sheet(isPresented: $showHomePicker) {
                StationPickerView(
                    title: String(localized: "Home Station"),
                    stationSearch: stationSearch
                ) { station in
                    homeStation = station
                    GetHomeView.saveHomeStation(station)
                }
            }
        }
    }

    // MARK: - Subviews

    private var homeStationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            StationSelectionCard(
                label: String(localized: "Home Station"),
                station: homeStation,
                icon: "house.fill",
                color: AppColors.primary
            ) {
                HapticService.lightImpact()
                showHomePicker = true
            }
            if homeStation == nil {
                Text(String(localized: "Set once — saved for every journey home."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.lg)
            }
        }
        .padding(.horizontal)
    }

    private var getHomeButton: some View {
        Button {
            HapticService.lightImpact()
            Task { await fetchHomeOptions() }
        } label: {
            HStack(spacing: Spacing.md) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(.white)
                } else {
                    Image(systemName: "location.fill")
                }
                Text(isLoading
                    ? String(localized: "Finding routes…")
                    : String(localized: "Get Me Home"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.primary)
        .disabled(homeStation == nil || isLoading)
        .padding(.horizontal)
    }

    private var locationDeniedBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.orange)
            Text(String(localized: "Location access is disabled. Enable it in iPhone Settings → Privacy → Location Services."))
                .font(.caption)
            Spacer()
        }
        .padding(Spacing.md)
        .background(.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal)
    }

    private func homeOptionsSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            ForEach(Array(homeOptions.enumerated()), id: \.element.id) { index, option in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // TfL transit directions to terminus (London routes only)
                    if let journey = option.transitJourney, !journey.legs.isEmpty {
                        transitSection(journey, platform: option.services.compactMap(\.platform).first)
                    }

                    // Disruption banner when a transit leg has no live service
                    if let message = option.transitDisruptionMessage {
                        disruptionBanner(message: message, currentOption: option, optionIndex: index, proxy: proxy)
                    }

                    // Train departure header
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "train.side.front.car")
                            .foregroundStyle(AppColors.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.fromStation.name)
                                .font(.headline)
                            if option.transitJourney == nil {
                                Text(String(localized: "~\(option.walkTimeMinutes) min walk"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.xl)

                    // Departure rows
                    VStack(spacing: 0) {
                        ForEach(option.services, id: \.serviceID) { service in
                            GetHomeDepartureRow(service: service)
                            if service.serviceID != option.services.last?.serviceID {
                                Divider().padding(.leading, Spacing.xl)
                            }
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                }
                .id(option.id)
            }
        }
    }

    @ViewBuilder
    private func disruptionBanner(message: String, currentOption: GetHomeOption, optionIndex: Int, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                Spacer()
            }
            // Tappable alternative station suggestion — scrolls directly to that card
            if let alternative = homeOptions.dropFirst(optionIndex + 1).first(where: { !$0.hasTransitDisruption }) {
                let extraMinutes = alternative.walkTimeMinutes - currentOption.walkTimeMinutes
                Button {
                    HapticService.lightImpact()
                    withAnimation {
                        proxy.scrollTo(alternative.id, anchor: .top)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.caption)
                        Text(String(localized: "See \(alternative.fromStation.name) (+\(extraMinutes) min walk) →"))
                            .font(.caption)
                            .underline()
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding(Spacing.md)
        .background(.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func transitSection(_ journey: Journey, platform: String?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(String(localized: "Route to station"), systemImage: "arrow.triangle.turn.up.right.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xl)

            VStack(spacing: 0) {
                ForEach(journey.legs) { leg in
                    let isLastLeg = leg.id == journey.legs.last?.id
                    let platformOverride = isLastLeg && leg.mode == .walk ? platform : nil
                    TransitLegRow(leg: leg, platformOverride: platformOverride)
                    if !isLastLeg {
                        Divider().padding(.leading, Spacing.xl)
                    }
                }
            }
            .glassCard()
            .padding(.horizontal)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "No Trains Found"),
            systemImage: "house.slash",
            description: Text(String(localized: "No trains found from stations near you to \(homeStation?.name ?? "home"). Try again in a moment."))
        )
        .padding(.top, Spacing.jumbo)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label(String(localized: "Couldn't Find Routes"), systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button(String(localized: "Try Again")) {
                Task { await fetchHomeOptions() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
        }
        .padding(.top, Spacing.jumbo)
    }

    // MARK: - Fetch

    private func fetchHomeOptions() async {
        guard let home = homeStation else { return }

        isLoading = true
        errorMessage = nil
        hasSearched = true
        homeOptions = []

        // Request location and wait up to 5 seconds for a fix
        if locationService.currentLocation == nil {
            locationService.requestPermission()
            locationService.startUpdating()
            var waited = 0
            while locationService.currentLocation == nil && waited < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                waited += 1
            }
        }

        guard let location = locationService.currentLocation else {
            errorMessage = String(localized: "Couldn't get your current location. Check that Location Services are enabled for LiveRail in iPhone Settings.")
            isLoading = false
            HapticService.error()
            return
        }

        do {
            homeOptions = try await journeyService.getHomeOptions(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                toStation: home,
                stationSearch: stationSearch
            )
            HapticService.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticService.error()
        }

        isLoading = false
    }

    // MARK: - Home Station Persistence

    static func loadHomeStation() -> Station? {
        guard let data = UserDefaults.standard.data(forKey: "homeStation"),
              let station = try? JSONDecoder().decode(Station.self, from: data) else { return nil }
        return station
    }

    static func saveHomeStation(_ station: Station) {
        if let data = try? JSONEncoder().encode(station) {
            UserDefaults.standard.set(data, forKey: "homeStation")
        }
    }
}

// MARK: - Departure Row

private struct GetHomeDepartureRow: View {
    let service: TrainService

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Scheduled time
            Text(service.std ?? "--:--")
                .font(.title3.bold())
                .monospacedDigit()
                .fixedSize()

            // Status
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)
                if let op = service.operatorName {
                    Text(op)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Platform
            if let platform = service.platform {
                VStack(spacing: 1) {
                    Text(String(localized: "Plt"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(platform)
                        .font(.subheadline.bold())
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var statusText: String {
        if service.isCancelled == true {
            return String(localized: "Cancelled")
        }
        guard let etd = service.etd else { return String(localized: "On time") }
        if etd == "On time" { return String(localized: "On time") }
        if etd == "Cancelled" { return String(localized: "Cancelled") }
        if etd == "Delayed" { return String(localized: "Delayed") }
        return etd  // specific ETD time
    }

    private var statusColor: Color {
        if service.isCancelled == true { return .red }
        switch service.etd {
        case "On time", nil: return .green
        case "Cancelled": return .red
        default: return .orange
        }
    }
}

// MARK: - Transit Leg Row

private struct TransitLegRow: View {
    let leg: JourneyLeg
    var platformOverride: String? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        if leg.mode == .walk {
            walkRow
                .contentShape(Rectangle())
                .onTapGesture { openWalkInMaps() }
        } else {
            transitRow
        }
    }

    private var walkRow: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            if let platform = platformOverride {
                // Last walk leg to the platform — show as a platform indicator
                Image(systemName: "signpost.right.fill")
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 24)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Platform \(platform)"))
                        .font(.subheadline.bold())
                    Text(String(localized: "Allow \(leg.durationFormatted) from underground"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                Image(systemName: leg.mode.iconName)
                    .foregroundStyle(.green)
                    .frame(width: 24)
                    .padding(.top, 2)
                Text(leg.instructions ?? String(localized: "Walk"))
                    .font(.subheadline)
                Spacer()
                HStack(spacing: 4) {
                    Text(leg.durationFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var transitRow: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: leg.mode.iconName)
                .foregroundStyle(leg.disruption != nil ? .orange : modeColor)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(leg.departureTimeFormatted)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(leg.origin.name)
                        .font(.subheadline)
                }
                HStack(spacing: 4) {
                    Text(leg.arrivalTimeFormatted)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(leg.destination.name)
                        .font(.subheadline)
                }
                if let op = leg.operatorName {
                    Text(op)
                        .font(.caption.bold())
                        .foregroundStyle(leg.disruption != nil ? .orange : modeColor)
                }
            }

            Spacer()

            Text(leg.durationFormatted)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private func openWalkInMaps() {
        guard let destLat = leg.destination.latitude,
              let destLon = leg.destination.longitude else { return }
        let urlString: String
        if let originLat = leg.origin.latitude, let originLon = leg.origin.longitude {
            urlString = "maps://?saddr=\(originLat),\(originLon)&daddr=\(destLat),\(destLon)&dirflg=w"
        } else {
            urlString = "maps://?daddr=\(destLat),\(destLon)&dirflg=w"
        }
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    private var modeColor: Color {
        // For tube/rail modes, use official TfL line colours keyed on operator name
        if leg.mode == .tube || leg.mode == .dlr || leg.mode == .overground {
            if let lineName = leg.operatorName?.lowercased() {
                return tflLineColor(lineName)
            }
        }
        switch leg.mode {
        case .walk: return .green
        case .dlr: return Color(red: 0/255, green: 164/255, blue: 167/255)
        case .overground: return Color(red: 238/255, green: 124/255, blue: 14/255)
        default: return AppColors.primary
        }
    }

    /// Official TfL line colours (from tfl.gov.uk brand guidelines)
    private func tflLineColor(_ lineName: String) -> Color {
        switch lineName {
        case let n where n.contains("bakerloo"):
            return Color(red: 179/255, green: 99/255, blue: 5/255)
        case let n where n.contains("central"):
            return Color(red: 227/255, green: 32/255, blue: 23/255)
        case let n where n.contains("circle"):
            return Color(red: 255/255, green: 211/255, blue: 0/255)
        case let n where n.contains("district"):
            return Color(red: 0/255, green: 120/255, blue: 42/255)
        case let n where n.contains("hammersmith"):
            return Color(red: 243/255, green: 169/255, blue: 187/255)
        case let n where n.contains("jubilee"):
            return Color(red: 160/255, green: 165/255, blue: 169/255)
        case let n where n.contains("metropolitan"):
            return Color(red: 155/255, green: 0/255, blue: 86/255)
        case let n where n.contains("northern"):
            return Color(red: 0/255, green: 0/255, blue: 0/255)
        case let n where n.contains("piccadilly"):
            return Color(red: 0/255, green: 54/255, blue: 136/255)
        case let n where n.contains("victoria"):
            return Color(red: 0/255, green: 152/255, blue: 212/255)
        case let n where n.contains("waterloo"):
            return Color(red: 149/255, green: 205/255, blue: 186/255)
        case let n where n.contains("elizabeth"):
            return Color(red: 105/255, green: 80/255, blue: 161/255)
        case let n where n.contains("dlr"):
            return Color(red: 0/255, green: 164/255, blue: 167/255)
        case let n where n.contains("overground"):
            return Color(red: 238/255, green: 124/255, blue: 14/255)
        case let n where n.contains("tram"):
            return Color(red: 132/255, green: 184/255, blue: 23/255)
        default:
            return AppColors.primary
        }
    }
}
