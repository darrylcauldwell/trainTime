//
//  ContentView.swift
//  LiveRail
//
//  TabView root: Live, Plan, Settings
//

import SwiftUI

struct ContentView: View {
    let stationSearch: StationSearchService
    let apiService: HuxleyAPIService
    let journeyService: JourneyPlanningService

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            JourneySearchView(stationSearch: stationSearch, apiService: apiService, journeyService: journeyService)
                .tabItem {
                    Label(String(localized: "Live"), systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(0)

            ScheduleView(stationSearch: stationSearch, apiService: apiService)
                .tabItem {
                    Label(String(localized: "Plan"), systemImage: "calendar.badge.clock")
                }
                .tag(1)

            HistoryView(stationSearch: stationSearch, apiService: apiService)
                .tabItem {
                    Label(String(localized: "History"), systemImage: "clock.arrow.2.circlepath")
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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSettings)) { _ in
            selectedTab = 3
        }
    }
}
