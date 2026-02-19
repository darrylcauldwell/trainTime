//
//  ContentView.swift
//  LiveRail
//
//  Two-view navigation: Departures and Get Home with a floating glass tab switcher.
//  Settings is accessed via the gear icon in each view's navigation bar.
//

import SwiftUI

struct ContentView: View {
    let stationSearch: StationSearchService
    let apiService: HuxleyAPIService
    let journeyService: JourneyPlanningService

    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if selectedTab == 0 {
                    JourneySearchView(
                        stationSearch: stationSearch,
                        apiService: apiService,
                        journeyService: journeyService
                    )
                } else {
                    GetHomeView(
                        journeyService: journeyService,
                        stationSearch: stationSearch
                    )
                }
            }
            // Reserve space so scroll content clears the floating tab bar
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 80)
            }

            // Floating glass tab switcher
            HStack(spacing: Spacing.jumbo) {
                tabButton(icon: "tram.fill", index: 0)
                tabButton(icon: "house.fill", index: 1)
            }
            .padding(.horizontal, Spacing.jumbo)
            .padding(.vertical, Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            .padding(.bottom, Spacing.sm)
        }
        .tint(AppColors.primary)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSettings)) { _ in
            showSettings = true
        }
    }

    private func tabButton(icon: String, index: Int) -> some View {
        let label = index == 0 ? String(localized: "Departures") : String(localized: "Get Home")
        return Button {
            guard selectedTab != index else { return }
            HapticService.selection()
            withAnimation(.spring(duration: 0.25)) { selectedTab = index }
        } label: {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(selectedTab == index ? AppColors.primary : Color.secondary)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}
