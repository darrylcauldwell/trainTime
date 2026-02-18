//
//  StationSearchService.swift
//  LiveRail
//
//  In-memory station search from bundled JSON
//

import Foundation

@Observable
final class StationSearchService {
    private(set) var allStations: [Station] = []
    private var crsDictionary: [String: Station] = [:]
    private var isLoaded = false

    func loadStations() {
        guard !isLoaded else { return }
        guard let url = Bundle.main.url(forResource: "uk_rail_stations", withExtension: "json") else {
            print("Station data file not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            allStations = try JSONDecoder().decode([Station].self, from: data)
            crsDictionary = Dictionary(uniqueKeysWithValues: allStations.map { ($0.crs.uppercased(), $0) })
            isLoaded = true
        } catch {
            print("Failed to load stations: \(error)")
        }
    }

    /// Search stations by name or CRS code
    func search(query: String) -> [Station] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()

        // Exact CRS match first
        if lowered.count == 3 {
            if let exact = allStations.first(where: { $0.crs.lowercased() == lowered }) {
                var results = [exact]
                results.append(contentsOf: allStations.filter {
                    $0.crs != exact.crs && $0.name.lowercased().contains(lowered)
                }.prefix(9))
                return results
            }
        }

        // Name prefix match prioritized, then contains
        let prefixMatches = allStations.filter {
            $0.name.lowercased().hasPrefix(lowered)
        }
        let containsMatches = allStations.filter {
            !$0.name.lowercased().hasPrefix(lowered) &&
            ($0.name.lowercased().contains(lowered) || $0.crs.lowercased().contains(lowered))
        }

        return Array((prefixMatches + containsMatches).prefix(15))
    }

    /// Find station by CRS code (O(1) dictionary lookup)
    func station(forCRS crs: String) -> Station? {
        crsDictionary[crs.uppercased()]
    }
}
