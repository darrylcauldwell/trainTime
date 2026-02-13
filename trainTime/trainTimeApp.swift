//
//  trainTimeApp.swift
//  trainTime
//
//  @main entry point with ModelContainer and service setup
//

import SwiftUI
import SwiftData

@main
struct trainTimeApp: App {
    @State private var stationSearch = StationSearchService()
    @State private var apiService = HuxleyAPIService()
    @State private var deepLinkOrigin: Station?
    @State private var deepLinkDestination: Station?
    @State private var showDeepLinkDepartures = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SavedJourney.self,
            CachedDeparture.self,
            CachedServiceDetail.self,
            RecentRoute.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(stationSearch: stationSearch, apiService: apiService)
                .onAppear {
                    stationSearch.loadStations()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        // traintime://departures/{origin}/{destination}
        guard url.scheme == "traintime",
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
