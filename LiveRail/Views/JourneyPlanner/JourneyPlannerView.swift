//
//  JourneyPlannerView.swift
//  LiveRail
//
//  Journey planning interface with multiple route options
//

import SwiftUI

struct JourneyPlannerView: View {
    let origin: Station
    let destination: Station
    let journeyService: JourneyPlanningService
    let cacheService: CacheService

    @Environment(\.dismiss) private var dismiss
    @State private var journeys: [Journey] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedJourney: Journey?
    @State private var departureTime = Date()
    @State private var isOffline = false
    @State private var cachedTime: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    // Provider indicator
                    if journeyService.provider == .smartAlgorithm {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundStyle(AppColors.primary)
                            Text(String(localized: "Using Smart Algorithm (Free)"))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, Spacing.sm)
                    }

                    // Departure time picker
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(String(localized: "Departure Time"))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            String(localized: "Departure"),
                            selection: $departureTime,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: departureTime) {
                            Task {
                                await fetchJourneys()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, Spacing.md)

                    // Offline banner
                    if isOffline, let cachedTime {
                        offlineBanner(cachedTime: cachedTime)
                    }

                    // Content area
                    if isLoading {
                        ProgressView(String(localized: "Finding journeys..."))
                            .padding(.top, Spacing.jumbo)
                    } else if let errorMessage {
                        errorView(message: errorMessage)
                    } else if journeys.isEmpty {
                        emptyStateView()
                    } else {
                        // Journey list
                        LazyVStack(spacing: Spacing.sm) {
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
                        .padding(.top, Spacing.sm)
                    }
                }
            }
            .navigationTitle("\(origin.crs) to \(destination.crs)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        HapticService.lightImpact()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticService.lightImpact()
                        Task {
                            await fetchJourneys()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .glassNavigation()
            .sheet(item: $selectedJourney) { journey in
                JourneyDetailView(journey: journey)
            }
            .task {
                await fetchJourneys()
            }
        }
    }

    // MARK: - Fetch Journeys

    private func fetchJourneys() async {
        isLoading = true
        errorMessage = nil
        isOffline = false
        cachedTime = nil

        do {
            let fetchedJourneys = try await journeyService.planJourney(
                from: origin.crs,
                to: destination.crs,
                departureTime: departureTime
            )

            journeys = fetchedJourneys
            cacheService.cacheJourney(fetchedJourneys, origin: origin.crs, destination: destination.crs, departureTime: departureTime)
            HapticService.success()

        } catch let error as JourneyPlanningError {
            // Handle specific journey planning errors
            switch error {
            case .noAPIConfigured, .authenticationRequired, .quotaExceeded:
                // These errors don't warrant cache fallback
                errorMessage = error.localizedDescription
            default:
                // Try cache fallback for other errors
                if let cached = cacheService.getCachedJourney(
                    origin: origin.crs,
                    destination: destination.crs,
                    departureTime: departureTime
                ) {
                    journeys = cached.journeys
                    cachedTime = cached.fetchedAt
                    isOffline = true
                    HapticService.warning()
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        } catch {
            // Try cache fallback for generic errors
            if let cached = cacheService.getCachedJourney(
                origin: origin.crs,
                destination: destination.crs,
                departureTime: departureTime
            ) {
                journeys = cached.journeys
                cachedTime = cached.fetchedAt
                isOffline = true
                HapticService.warning()
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            ContentUnavailableView(
                String(localized: "Journey Planning Unavailable"),
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            .padding(.top, Spacing.jumbo)

            // Show API coverage info if only TfL is configured
            if journeyService.hasTfLAPI && !journeyService.hasTransportAPI {
                VStack(spacing: Spacing.sm) {
                    Text(String(localized: "Limited Coverage"))
                        .font(.subheadline.bold())
                    Text(String(localized: "TfL API only covers London and South East UK. For routes like Walkden→Euston, add TransportAPI credentials in Settings."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, Spacing.md)
                .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 4, padding: Spacing.md)
                .padding(.horizontal)
            }

            // Show recovery suggestion for specific errors
            if message.contains("not configured") || message.contains("credentials") {
                Button {
                    HapticService.lightImpact()
                    dismiss()
                    NotificationCenter.default.post(name: .navigateToSettings, object: nil)
                } label: {
                    Label(String(localized: "Open Settings"), systemImage: "gear")
                        .font(.headline)
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private func emptyStateView() -> some View {
        VStack(spacing: Spacing.lg) {
            ContentUnavailableView(
                String(localized: "No Journeys Found"),
                systemImage: "magnifyingglass",
                description: Text("Try selecting a different departure time")
            )
            .padding(.top, Spacing.jumbo)

            // Show API limitation notice if only TfL is configured and this looks like an inter-city route
            if journeyService.hasTfLAPI && !journeyService.hasTransportAPI {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundStyle(AppColors.primary)
                    Text(String(localized: "This route may be outside TfL coverage"))
                        .font(.subheadline.bold())
                    Text(String(localized: "TfL API is limited to London and South East UK. For comprehensive UK coverage including inter-city routes, add TransportAPI credentials in Settings."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, Spacing.md)
                .glassCard(material: .thin, cornerRadius: CornerRadius.md, shadowRadius: 4, padding: Spacing.md)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Offline Banner

    @ViewBuilder
    private func offlineBanner(cachedTime: Date) -> some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text(String(localized: "Offline - showing cached results from \(cachedTime.formatted(.relative(presentation: .named)))"))
                .font(.caption)
            Spacer()
        }
        .padding(Spacing.md)
        .background(AppColors.warning.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToSettings = Notification.Name("navigateToSettings")
}
