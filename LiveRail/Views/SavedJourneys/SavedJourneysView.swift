//
//  SavedJourneysView.swift
//  LiveRail
//
//  List of favourite routes with quick navigation
//

import SwiftUI
import SwiftData

struct SavedJourneysView: View {
    @Query(sort: \SavedJourney.createdAt, order: .reverse) private var journeys: [SavedJourney]
    @Environment(\.modelContext) private var modelContext
    let stationSearch: StationSearchService
    let apiService: HuxleyAPIService
    let journeyService: JourneyPlanningService

    var body: some View {
        NavigationStack {
            Group {
                if journeys.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Saved Journeys"),
                        systemImage: "star",
                        description: Text(String(localized: "Save a journey from the search screen to access it quickly here"))
                    )
                } else {
                    List {
                        ForEach(journeys) { journey in
                            NavigationLink {
                                if let origin = stationSearch.station(forCRS: journey.originCRS),
                                   let dest = stationSearch.station(forCRS: journey.destinationCRS) {
                                    DepartureListView(
                                        origin: origin,
                                        destination: dest,
                                        apiService: apiService,
                                        stationSearch: stationSearch,
                                        journeyService: journeyService
                                    )
                                }
                            } label: {
                                savedJourneyRow(journey)
                            }
                        }
                        .onDelete(perform: deleteJourneys)
                    }
                    .glassList()
                }
            }
            .navigationTitle(String(localized: "Saved"))
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigation()
            .onChange(of: journeys.count) { _, _ in
                syncFirstJourneyToWidget()
            }
            .onAppear {
                syncFirstJourneyToWidget()
            }
        }
    }

    private func syncFirstJourneyToWidget() {
        guard let first = journeys.first else { return }
        let widgetJourney = WidgetJourney(
            originCRS: first.originCRS,
            originName: first.originName,
            destinationCRS: first.destinationCRS,
            destinationName: first.destinationName
        )
        widgetJourney.save()
    }

    private func savedJourneyRow(_ journey: SavedJourney) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "star.fill")
                .foregroundStyle(AppColors.delayed)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.sm) {
                    Text(journey.originName)
                        .font(.subheadline.bold())
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(journey.destinationName)
                        .font(.subheadline.bold())
                }

                Text("\(journey.originCRS) - \(journey.destinationCRS)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .accessibilityLabel("\(journey.originName) to \(journey.destinationName)")
    }

    private func deleteJourneys(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(journeys[index])
        }
    }
}
