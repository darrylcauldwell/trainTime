//
//  StationPickerView.swift
//  LiveRail
//
//  Autocomplete sheet for station selection
//

import SwiftUI

struct StationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let stationSearch: StationSearchService
    let onSelect: (Station) -> Void

    @State private var searchText = ""

    private var results: [Station] {
        stationSearch.search(query: searchText)
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        String(localized: "Search Stations"),
                        systemImage: "magnifyingglass",
                        description: Text(String(localized: "Type a station name or CRS code"))
                    )
                } else if results.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Stations Found"),
                        systemImage: "tram.fill",
                        description: Text("No stations match \"\(searchText)\"")
                    )
                } else {
                    ForEach(results) { station in
                        Button {
                            onSelect(station)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(station.crs)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityLabel("\(station.name), \(station.crs)")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: String(localized: "Station name or code"))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
            .glassNavigation()
        }
    }
}
