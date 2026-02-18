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
    @State private var deepLinkOrigin: Station?
    @State private var deepLinkDestination: Station?
    @State private var showDeepLinkDepartures = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SavedJourney.self,
            CachedDeparture.self,
            CachedServiceDetail.self,
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
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        // liverail://departures/{origin}/{destination}
        guard url.scheme == "liverail",
              url.host == "departures" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2 else { return }
        let originCRS = parts[0]
        let destCRS = parts[1]

        if let origin = stationSearch.station(forCRS: originCRS),
           let dest = stationSearch.station(forCRS: destCRS) {
            deepLinkOrigin = origin
            deepLinkDestination = dest
            showDeepLinkDepartures = true
        }
    }
}
