//
//  ContentView.swift
//  trainTime
//
//  TabView root: Search, Schedule, Saved, Settings
//

import SwiftUI

struct ContentView: View {
    let stationSearch: StationSearchService
    let apiService: HuxleyAPIService

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            JourneySearchView(stationSearch: stationSearch, apiService: apiService)
                .tabItem {
                    Label(String(localized: "Search"), systemImage: "magnifyingglass")
                }
                .tag(0)

            ScheduleView(stationSearch: stationSearch, apiService: apiService)
                .tabItem {
                    Label(String(localized: "Schedule"), systemImage: "clock.fill")
                }
                .tag(1)

            SavedJourneysView(stationSearch: stationSearch, apiService: apiService)
                .tabItem {
                    Label(String(localized: "Saved"), systemImage: "star.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label(String(localized: "Settings"), systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(AppColors.primary)
        .onChange(of: selectedTab) { _, _ in
            HapticService.selection()
        }
    }
}
