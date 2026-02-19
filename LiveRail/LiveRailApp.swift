//
//  LiveRailApp.swift
//  LiveRail
//
//  @main entry point with ModelContainer and service setup
//

import SwiftUI
import SwiftData

@main
struct LiveRailApp: App {
    @State private var stationSearch = StationSearchService()
    @State private var apiService = HuxleyAPIService()
    @State private var journeyService = JourneyPlanningService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SavedJourney.self,
            CachedDeparture.self,
            CachedJourney.self,
            RecentRoute.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            return container
        } catch {
            // If migration fails, delete the old store and create a new one
            // This is acceptable for development since these are just cached/recent items
            print("Migration failed, recreating container: \(error)")
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer after cleanup: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(stationSearch: stationSearch, apiService: apiService, journeyService: journeyService)
                .onAppear {
                    stationSearch.loadStations()
                    // Configure smart planner with Huxley API
                    journeyService.configureSmartPlanner(apiService: apiService)
                }
        }
        .modelContainer(sharedModelContainer)
    }

}
