//
//  SmartJourneyPlanner.swift
//  LiveRail
//
//  Free multi-query journey planner using Huxley2 API.
//  Uses arrivals at interchange (not departures from origin) so that
//  service.sta correctly gives the arrival time at the interchange station,
//  even for trains that originate at the queried origin station.
//  Handles cross-station walking connections (e.g., Wigan Wallgate → Wigan NW).
//

import Foundation

@Observable
final class SmartJourneyPlanner {
    private let apiService: HuxleyAPIService

    private let minimumChangeTime: TimeInterval = 5 * 60   // 5 minutes
    private let maximumChangeTime: TimeInterval = 60 * 60  // 60 minutes
    private let maximumResults: Int = 5

    // Known walking connections between adjacent stations.
    // Meaning: when a train ARRIVES at the key station, the onward connection
    // DEPARTS from the paired station (after a short walk).
    // Defined bidirectionally to support both outbound and return journeys.
    private let stationPairs: [String: (paired: String, walkMinutes: Int)] = [
        // Wigan — Northern trains use Wallgate, mainline (Avanti) uses North Western
        "WGW": (paired: "WGN", walkMinutes: 7),
        "WGN": (paired: "WGW", walkMinutes: 7),
        // Manchester — Northern/TransPennine use Victoria, Avanti/LNER/CrossCountry use Piccadilly
        "MCV": (paired: "MAN", walkMinutes: 15),
        "MAN": (paired: "MCV", walkMinutes: 15),
        // Glasgow — suburban/ScotRail use Queen Street, southbound (Avanti) uses Central
        "GCQ": (paired: "GLC", walkMinutes: 10),
        "GLC": (paired: "GCQ", walkMinutes: 10),
        // Exeter — mainline (GWR) uses St Davids, city services use Central
        "EXD": (paired: "EXC", walkMinutes: 8),
        "EXC": (paired: "EXD", walkMinutes: 8),
        // London: Cannon Street ↔ London Bridge (Thameslink, Southern)
        "CST": (paired: "LBG", walkMinutes: 8),
        "LBG": (paired: "CST", walkMinutes: 8),
    ]

    // Estimated outbound journey durations from common origins to interchanges (seconds)
    private let typicalOutboundDurations: [String: [String: TimeInterval]] = [
        "WKD": ["WGW": 24*60, "WGN": 35*60, "MCV": 45*60, "MAN": 50*60],
        "BON": ["WGW": 30*60, "MCV": 30*60, "MAN": 35*60, "PRE": 40*60],
        "BLB": ["MCV": 45*60, "MAN": 50*60, "PRE": 30*60],
        "BPW": ["MCV": 60*60, "MAN": 65*60, "PRE": 20*60],
        "PLY": ["EXD": 60*60, "BRI": 2*3600],
        "EXC": ["EXD": 8*60],
    ]

    // Estimated inbound journey durations from interchanges to common destinations (seconds)
    private let typicalInboundDurations: [String: [String: TimeInterval]] = [
        "WGN": ["EUS": 2*3600, "MAN": 30*60, "MCV": 30*60],
        "WGW": ["EUS": 2*3600+15*60],
        "MAN": ["EUS": 2*3600+10*60, "KGX": 2*3600+10*60, "PAD": 2*3600+10*60],
        "MCV": ["EUS": 2*3600+10*60, "KGX": 2*3600+10*60],
        "PRE": ["EUS": 2*3600+15*60],
        "CRE": ["EUS": 1*3600+45*60, "PAD": 2*3600],
        "BHM": ["EUS": 1*3600+20*60, "PAD": 1*3600+45*60],
        "LDS": ["KGX": 2*3600+10*60],
        "YRK": ["KGX": 1*3600+50*60],
        "NCL": ["KGX": 2*3600+45*60],
        "EDB": ["KGX": 4*3600+30*60, "EUS": 4*3600+30*60],
        "GLC": ["EUS": 4*3600+30*60, "EDB": 50*60],
        "GCQ": ["EDB": 50*60, "ABD": 2*3600+30*60],
        "EXD": ["PAD": 2*3600, "BRI": 1*3600],
        "BRI": ["PAD": 1*3600+45*60],
        "RDG": ["PAD": 30*60, "WAT": 50*60],
        "CDF": ["PAD": 2*3600],
    ]

    init(apiService: HuxleyAPIService) {
        self.apiService = apiService
    }

    // MARK: - Public API

    func planJourney(from origin: String, to destination: String, originName: String = "", destinationName: String = "", departureTime: Date = Date()) async throws -> [Journey] {
        let interchanges = findInterchanges(from: origin, to: destination)
        guard !interchanges.isEmpty else {
            throw SmartPlannerError.noInterchangesFound
        }

        var allJourneys: [Journey] = []
        for interchange in interchanges {
            do {
                let journeys = try await findConnectionsVia(
                    interchange: interchange,
                    from: origin,
                    to: destination,
                    originName: originName.isEmpty ? origin : originName,
                    departureTime: departureTime
                )
                allJourneys.append(contentsOf: journeys)
            } catch {
                print("Failed to find connections via \(interchange): \(error)")
            }
        }

        guard !allJourneys.isEmpty else {
            throw SmartPlannerError.noConnectionsFound
        }

        // Deduplicate: same train service pair may be found via multiple interchanges
        var seen = Set<String>()
        let uniqueJourneys = allJourneys.filter { journey in
            let trainLegs = journey.legs.filter { $0.mode == .train }
            let key = trainLegs.map { $0.serviceIdentifier ?? $0.id }.joined(separator: "|")
            return seen.insert(key).inserted
        }

        return Array(uniqueJourneys.sorted { $0.duration < $1.duration }.prefix(maximumResults))
    }

    // MARK: - Connection Finding

    /// Find connections via a specific interchange.
    /// Uses arrivals at the interchange (from the origin direction) so that
    /// service.sta gives the accurate arrival time at the interchange —
    /// even for trains that originate at the origin station (where sta would
    /// be nil on a departures board).
    private func findConnectionsVia(
        interchange: String,
        from origin: String,
        to destination: String,
        originName: String,
        departureTime: Date
    ) async throws -> [Journey] {
        // Leg 1: arrivals at interchange filtered by origin
        // service.sta = arrival time at interchange ✓
        let leg1Board = try await apiService.fetchArrivals(at: interchange, from: origin, rows: 20)
        guard let leg1Services = leg1Board.trainServices, !leg1Services.isEmpty else {
            return []
        }

        // For station pairs (e.g., WGW→WGN walk), leg 2 departs from the paired station
        let (leg2Station, walkMinutes) = departurePair(for: interchange)

        // Leg 2: departures from departure station to destination
        // service.std = departure time from interchange ✓
        let leg2Board = try await apiService.fetchDepartures(from: leg2Station, to: destination, rows: 20)
        guard let leg2Services = leg2Board.trainServices, !leg2Services.isEmpty else {
            return []
        }

        return matchConnections(
            firstLeg: leg1Services,
            secondLeg: leg2Services,
            origin: origin,
            originName: originName,
            arrivalInterchange: interchange,
            arrivalInterchangeName: leg1Board.locationName ?? interchange,
            departureInterchange: leg2Station,
            departureInterchangeName: leg2Board.locationName ?? leg2Station,
            walkMinutes: walkMinutes
        )
    }

    private func departurePair(for interchange: String) -> (station: String, walkMinutes: Int) {
        if let pair = stationPairs[interchange] {
            return (pair.paired, pair.walkMinutes)
        }
        return (interchange, 0)
    }

    // MARK: - Matching

    private func matchConnections(
        firstLeg: [TrainService],
        secondLeg: [TrainService],
        origin: String,
        originName: String,
        arrivalInterchange: String,
        arrivalInterchangeName: String,
        departureInterchange: String,
        departureInterchangeName: String,
        walkMinutes: Int
    ) -> [Journey] {
        var journeys: [Journey] = []
        let now = Date()
        let walkTime = TimeInterval(walkMinutes * 60)

        for service1 in firstLeg {
            guard service1.isCancelled != true else { continue }

            // service1.sta is the arrival at the interchange from the arrivals board
            guard let sta1 = service1.sta,
                  let arrivalTime1 = parseTime(sta1, baseDate: now) else {
                continue
            }

            let earliestDeparture = arrivalTime1 + walkTime

            for service2 in secondLeg {
                guard service2.isCancelled != true else { continue }

                guard let std2 = service2.std,
                      let departureTime2 = parseTime(std2, baseDate: now) else {
                    continue
                }

                // Handle midnight crossing: if leg2 departure appears to be before leg1
                // arrival (by more than 12 hours), the departure is actually the next day.
                var adjustedDeparture2 = departureTime2
                if departureTime2 < earliestDeparture,
                   earliestDeparture.timeIntervalSince(departureTime2) > 12 * 3600 {
                    adjustedDeparture2 = departureTime2.addingTimeInterval(24 * 3600)
                }

                let changeTime = adjustedDeparture2.timeIntervalSince(earliestDeparture)
                guard changeTime >= minimumChangeTime && changeTime <= maximumChangeTime else {
                    continue
                }

                if let journey = createJourney(
                    firstService: service1,
                    secondService: service2,
                    origin: origin,
                    originName: originName,
                    arrivalInterchange: arrivalInterchange,
                    arrivalInterchangeName: arrivalInterchangeName,
                    departureInterchange: departureInterchange,
                    departureInterchangeName: departureInterchangeName,
                    arrivalTime1: arrivalTime1,
                    departureTime2: adjustedDeparture2,
                    walkMinutes: walkMinutes
                ) {
                    journeys.append(journey)
                }
            }
        }

        return journeys
    }

    // MARK: - Journey Creation

    private func createJourney(
        firstService: TrainService,
        secondService: TrainService,
        origin: String,
        originName: String,
        arrivalInterchange: String,
        arrivalInterchangeName: String,
        departureInterchange: String,
        departureInterchangeName: String,
        arrivalTime1: Date,
        departureTime2: Date,
        walkMinutes: Int
    ) -> Journey? {
        // Estimate departure from origin using typical durations (we don't have this
        // from the arrivals board, so we calculate backwards from the interchange arrival)
        let outboundDuration = typicalOutboundDurations[origin]?[arrivalInterchange]
            ?? TimeInterval(30 * 60)
        let estimatedDepartureTime1 = arrivalTime1 - outboundDuration

        // Estimate arrival at destination using typical durations
        let destCRS = secondService.destination?.first?.crs ?? ""
        let inboundDuration = typicalInboundDurations[departureInterchange]?[destCRS]
            ?? TimeInterval(2 * 3600)
        let estimatedArrivalTime2 = departureTime2 + inboundDuration

        // Locations — use the user's searched origin, not the train's originating station
        let originLocation = JourneyLocation(
            name: originName,
            crs: origin,
            latitude: nil,
            longitude: nil
        )
        let arrivalInterchangeLocation = JourneyLocation(
            name: arrivalInterchangeName,
            crs: arrivalInterchange,
            latitude: nil,
            longitude: nil
        )
        let departureInterchangeLocation = JourneyLocation(
            name: departureInterchangeName,
            crs: departureInterchange,
            latitude: nil,
            longitude: nil
        )
        let destinationLocation = JourneyLocation(
            name: secondService.destinationName,
            crs: secondService.destination?.first?.crs,
            latitude: nil,
            longitude: nil
        )

        // Leg 1: origin → arrival interchange
        let leg1 = JourneyLeg(
            id: UUID().uuidString,
            mode: .train,
            origin: originLocation,
            destination: arrivalInterchangeLocation,
            departureTime: estimatedDepartureTime1,
            arrivalTime: arrivalTime1,
            duration: outboundDuration,
            operatorName: firstService.operatorName,
            serviceIdentifier: firstService.serviceID,
            platform: firstService.platform,
            instructions: nil
        )

        var legs: [JourneyLeg] = [leg1]

        // Walk leg between paired stations (e.g., Wigan Wallgate → Wigan North Western)
        if arrivalInterchange != departureInterchange {
            let walkDuration = TimeInterval(walkMinutes * 60)
            let walkLeg = JourneyLeg(
                id: UUID().uuidString,
                mode: .walk,
                origin: arrivalInterchangeLocation,
                destination: departureInterchangeLocation,
                departureTime: arrivalTime1,
                arrivalTime: arrivalTime1 + walkDuration,
                duration: walkDuration,
                operatorName: nil,
                serviceIdentifier: nil,
                platform: nil,
                instructions: "Walk between stations (~\(walkMinutes) min)"
            )
            legs.append(walkLeg)
        }

        // Leg 2: departure interchange → destination
        let leg2 = JourneyLeg(
            id: UUID().uuidString,
            mode: .train,
            origin: departureInterchangeLocation,
            destination: destinationLocation,
            departureTime: departureTime2,
            arrivalTime: estimatedArrivalTime2,
            duration: inboundDuration,
            operatorName: secondService.operatorName,
            serviceIdentifier: secondService.serviceID,
            platform: secondService.platform,
            instructions: nil
        )
        legs.append(leg2)

        let totalDuration = estimatedArrivalTime2.timeIntervalSince(estimatedDepartureTime1)
        return Journey(
            id: UUID().uuidString,
            legs: legs,
            departureTime: estimatedDepartureTime1,
            arrivalTime: estimatedArrivalTime2,
            duration: totalDuration
        )
    }

    // MARK: - UK Interchange Station Database

    private func findInterchanges(from origin: String, to destination: String) -> [String] {
        let interchangeDatabase: [String: [String]] = [
            // North West England
            "WKD": ["WGW", "MCV"],           // Walkden → Wigan Wallgate (Northern), Manchester Victoria
            "BON": ["WGW", "MCV", "PRE"],    // Bolton → Wigan Wallgate (Northern), Manchester Victoria, Preston
            "BLB": ["MCV", "PRE"],           // Blackburn → Manchester Victoria, Preston
            "BPW": ["MCV", "PRE"],           // Blackpool → Manchester Victoria, Preston

            // Manchester area
            "MAN": ["CRE", "WGW", "PRE"],
            "MCV": ["CRE", "WGW", "PRE"],
            "STO": ["MAN", "MCV", "CRE"],

            // Yorkshire
            "LDS": ["YRK", "DHM", "MAN"],
            "SHF": ["DHM", "YRK", "MAN"],
            "YRK": ["DHM", "NCL", "LDS"],

            // Scotland
            "GLC": ["GCQ", "PRE", "CRE"],    // Glasgow Central → Queen Street (walk), then north
            "GCQ": ["GLC", "EDB"],           // Glasgow Queen Street → Central (walk), Edinburgh
            "EDB": ["NCL", "YRK", "PRE"],
            "ABD": ["EDB", "GCQ"],

            // Wales
            "CDF": ["NPT", "BRI", "SWA"],
            "SWA": ["CDF", "NPT"],

            // South West
            "BRI": ["RDG", "SWI", "BHM"],
            "PLY": ["BRI", "EXD"],
            "EXD": ["BRI", "RDG"],           // Exeter St Davids → Bristol, Reading
            "EXC": ["EXD"],                  // Exeter Central → walk to St Davids

            // Midlands
            "BHM": ["CRE", "MAN", "RDG"],
            "NTM": ["BHM", "SHF", "LEI"],
            "DER": ["BHM", "SHF", "CRE"],

            // Major hubs with direct London services (empty = direct, no interchange needed)
            // Note: WGN excluded from this list — it appears in stationPairs and is only
            // reached as a paired station from WGW, not used as a standalone interchange.
            "PRE": [], "CRE": [], "RDG": [], "DHM": [], "PTR": [], "NCL": [],
        ]

        let londonTermini = ["EUS", "KGX", "SPX", "PAD", "VIC", "WAT", "CHX", "LST", "LBG", "MYB"]
        let isToLondon = londonTermini.contains(destination)

        if let originInterchanges = interchangeDatabase[origin] {
            if isToLondon && originInterchanges.isEmpty {
                return [] // Direct to London, no interchange needed
            }
            return originInterchanges
        }

        // Fallback interchanges for origins not in the database
        if isToLondon {
            return ["WGW", "MCV", "MAN", "BHM", "CRE", "PRE", "RDG", "DHM", "NCL", "EDB"]
        }
        return ["MAN", "MCV", "BHM", "CRE", "YRK", "NCL", "EDB", "GCQ", "CDF", "BRI"]
    }

    // MARK: - Time Parsing

    private func parseTime(_ timeString: String, baseDate: Date) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current

        guard let timeOnly = formatter.date(from: timeString) else { return nil }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOnly)
        let baseComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)

        var combined = DateComponents()
        combined.year = baseComponents.year
        combined.month = baseComponents.month
        combined.day = baseComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        return calendar.date(from: combined)
    }
}

// MARK: - Error Types

enum SmartPlannerError: LocalizedError {
    case noInterchangesFound
    case noConnectionsFound

    var errorDescription: String? {
        switch self {
        case .noInterchangesFound:
            return String(localized: "No suitable interchange stations found for this route")
        case .noConnectionsFound:
            return String(localized: "No connecting services found. Try a different departure time.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noInterchangesFound:
            return String(localized: "This route may require a paid journey planning API for comprehensive results.")
        case .noConnectionsFound:
            return String(localized: "Try selecting a different departure time, or check if direct services are available.")
        }
    }
}
