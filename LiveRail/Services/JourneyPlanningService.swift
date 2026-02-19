//
//  JourneyPlanningService.swift
//  LiveRail
//
//  Service for multi-leg journey planning using TfL and TransportAPI
//

import Foundation
import CoreLocation

// MARK: - Get Home Option

struct GetHomeOption: Identifiable {
    let id = UUID()
    let fromStation: Station
    let services: [TrainService]
    let walkDistanceMeters: Double
    let transitJourney: Journey? // TfL local transit route to terminus (London only)

    /// Approximate walking time at 80m/min
    var walkTimeMinutes: Int { max(1, Int(walkDistanceMeters / 80)) }

    /// True when any transit leg carries a disruption message (line suspended/closed)
    var hasTransitDisruption: Bool {
        transitJourney?.legs.contains(where: { $0.disruption != nil }) ?? false
    }

    /// The disruption message from the first disrupted transit leg, if any
    var transitDisruptionMessage: String? {
        transitJourney?.legs.compactMap(\.disruption).first
    }
}

@Observable
final class JourneyPlanningService {
    private let session: URLSession
    private let decoder: JSONDecoder
    private var smartPlanner: SmartJourneyPlanner?
    private var huxleyService: HuxleyAPIService?

    // Major London termini in priority order
    private let londonTermini = ["STP", "EUS", "KGX", "VIC", "WAT", "PAD", "LBG", "LST", "MYB"]

    /// Enable free smart algorithm (uses Huxley2 multi-query)
    var enableSmartAlgorithm: Bool {
        get { UserDefaults.standard.object(forKey: "enableSmartAlgorithm") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enableSmartAlgorithm") }
    }

    // MARK: - TfL API Key (embedded — no user configuration required)

    private var tflAppKey: String { Config.defaultTfLAppKey }

    // MARK: - TransportAPI Credentials (optional, for future use)

    var transportAPIAppId: String {
        get { UserDefaults.standard.string(forKey: "transportAPIAppId") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "transportAPIAppId") }
    }

    var transportAPIAppKey: String {
        get { UserDefaults.standard.string(forKey: "transportAPIAppKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "transportAPIAppKey") }
    }

    // MARK: - API Provider Selection

    enum APIProvider {
        case transportAPI
        case tfl
        case smartAlgorithm
        case none
    }

    /// Automatically detect which API to use
    /// Priority: TransportAPI (full UK, paid) > TfL (embedded key) > Smart Algorithm (free)
    var provider: APIProvider {
        // Prefer TransportAPI if the user has configured paid credentials
        if !transportAPIAppId.isEmpty && !transportAPIAppKey.isEmpty {
            return .transportAPI
        }
        // TfL key is always available (embedded)
        if !tflAppKey.isEmpty {
            return .tfl
        }
        // Use smart algorithm if enabled (free, uses Huxley2)
        if enableSmartAlgorithm {
            return .smartAlgorithm
        }
        // No API configured
        return .none
    }

    /// Check if TransportAPI is configured (for full UK coverage)
    var hasTransportAPI: Bool {
        !transportAPIAppId.isEmpty && !transportAPIAppKey.isEmpty
    }

    /// TfL key is always available via the embedded default
    var hasTfLAPI: Bool { !tflAppKey.isEmpty }

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    /// Configure smart planner with Huxley API service
    func configureSmartPlanner(apiService: HuxleyAPIService) {
        self.huxleyService = apiService
        self.smartPlanner = SmartJourneyPlanner(apiService: apiService)
    }

    // MARK: - Public API

    /// Plan a journey between two stations
    /// - Parameters:
    ///   - origin: Origin station CRS code
    ///   - destination: Destination station CRS code
    ///   - departureTime: Desired departure time (defaults to now)
    /// - Returns: Array of Journey options
    func planJourney(from origin: String, to destination: String, originName: String = "", destinationName: String = "", departureTime: Date = Date(), originLat: Double? = nil, originLon: Double? = nil, destLat: Double? = nil, destLon: Double? = nil) async throws -> [Journey] {
        switch provider {
        case .transportAPI:
            return try await planJourneyTransportAPI(from: origin, to: destination, departureTime: departureTime)
        case .tfl:
            return try await planJourneyTfL(from: origin, to: destination, departureTime: departureTime, originLat: originLat, originLon: originLon, destLat: destLat, destLon: destLon)
        case .smartAlgorithm:
            guard let smartPlanner = smartPlanner else {
                throw JourneyPlanningError.smartPlannerNotConfigured
            }
            return try await smartPlanner.planJourney(from: origin, to: destination, originName: originName, destinationName: destinationName, departureTime: departureTime)
        case .none:
            throw JourneyPlanningError.noAPIConfigured
        }
    }

    // MARK: - TfL API Implementation

    private func planJourneyTfL(from origin: String, to destination: String, departureTime: Date, originLat: Double? = nil, originLon: Double? = nil, destLat: Double? = nil, destLon: Double? = nil) async throws -> [Journey] {
        // TfL Journey API: use coordinates when available to avoid CRS disambiguation failures.
        // CRS codes like "WAT" or "CHD" cause 0 results; lat/lon always resolves correctly.
        let fromParam: String
        if let lat = originLat, let lon = originLon {
            fromParam = "\(lat),\(lon)"
        } else {
            fromParam = origin
        }
        let toParam: String
        if let lat = destLat, let lon = destLon {
            toParam = "\(lat),\(lon)"
        } else {
            toParam = destination
        }
        let baseURL = "https://api.tfl.gov.uk/Journey/JourneyResults/\(fromParam)/to/\(toParam)"

        // Format time and date for TfL API
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        let timeString = timeFormatter.string(from: departureTime)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: departureTime)

        let queryParams: [String: String] = [
            "app_key": tflAppKey,
            "mode": "national-rail",
            "time": timeString,
            "date": dateString,
            "timeIs": "Departing"
        ]

        do {
            let response: TfLJourneyResponse = try await fetch(urlString: baseURL, queryParams: queryParams)
            return response.mapToJourneys()
        } catch let error as JourneyPlanningError {
            throw error
        } catch {
            throw JourneyPlanningError.networkError(error.localizedDescription)
        }
    }

    // MARK: - TransportAPI Implementation

    private func planJourneyTransportAPI(from origin: String, to destination: String, departureTime: Date) async throws -> [Journey] {
        // TransportAPI journey endpoint - uses CRS codes in path
        let baseURL = "https://transportapi.com/v3/uk/public/journey/from/\(origin)/to/\(destination).json"

        // Format time and date for TransportAPI
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: departureTime)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: departureTime)

        // Build query parameters
        let queryParams: [String: String] = [
            "app_id": transportAPIAppId,
            "app_key": transportAPIAppKey,
            "date": dateString,
            "time": timeString,
            "type": "public" // Use public transport routing
        ]

        do {
            let response: TransportAPIJourneyResponse = try await fetch(urlString: baseURL, queryParams: queryParams)
            // Pass departure date for proper time parsing
            return response.mapToJourneys(departureDate: departureTime)
        } catch let error as JourneyPlanningError {
            throw error
        } catch {
            throw JourneyPlanningError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Location-Based Journey Planning (Get Home)

    /// Find departure options from the user's location to their home station.
    /// In London: queries all major termini in parallel via Huxley2.
    /// Outside London: queries the nearest stations via Huxley2.
    /// Returns options sorted by walking distance, each containing live departures.
    func getHomeOptions(
        latitude: Double,
        longitude: Double,
        toStation: Station,
        stationSearch: StationSearchService
    ) async throws -> [GetHomeOption] {
        guard let service = huxleyService else {
            throw JourneyPlanningError.smartPlannerNotConfigured
        }

        let userLocation = CLLocation(latitude: latitude, longitude: longitude)
        let londonRoute = isInLondon(latitude: latitude, longitude: longitude)

        let stationsToSearch: [Station]
        if londonRoute {
            stationsToSearch = londonTermini.compactMap { stationSearch.station(forCRS: $0) }
        } else {
            stationsToSearch = stationSearch.nearestStations(to: userLocation, count: 5)
        }

        let options = await withTaskGroup(of: GetHomeOption?.self) { group in
            for station in stationsToSearch {
                group.addTask {
                    guard let board = try? await service.fetchDepartures(from: station.crs, to: toStation.crs, rows: 5),
                          let services = board.trainServices,
                          !services.isEmpty else { return nil }
                    let walkMeters = userLocation.distance(from: CLLocation(latitude: station.lat, longitude: station.lon))
                    // For London routes, also fetch TfL transit directions to terminus
                    var transitJourney: Journey? = nil
                    if londonRoute {
                        transitJourney = await self.planLocalTransitJourney(
                            fromLat: latitude, fromLon: longitude, toStation: station)
                    }
                    return GetHomeOption(fromStation: station, services: services, walkDistanceMeters: walkMeters, transitJourney: transitJourney)
                }
            }
            var results: [GetHomeOption] = []
            for await option in group {
                if let opt = option { results.append(opt) }
            }
            return results
        }

        if options.isEmpty {
            throw JourneyPlanningError.noRoutesFound
        }
        return options.sorted { $0.walkDistanceMeters < $1.walkDistanceMeters }
    }

    /// Fetch TfL local transit journey (tube/DLR/overground) from GPS to a station.
    /// Returns nil silently if TfL can't route this journey — display falls back to walk estimate.
    private func planLocalTransitJourney(fromLat: Double, fromLon: Double, toStation: Station) async -> Journey? {
        let from = "\(fromLat),\(fromLon)"
        let to = "\(toStation.lat),\(toStation.lon)"
        let baseURL = "https://api.tfl.gov.uk/Journey/JourneyResults/\(from)/to/\(to)"

        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        let timeString = timeFormatter.string(from: now)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: now)

        let queryParams: [String: String] = [
            "app_key": tflAppKey,
            "mode": "tube,dlr,overground,elizabeth-line,walking",
            "time": timeString,
            "date": dateString,
            "timeIs": "Departing",
            "journeyPreference": "LeastTime"
        ]

        do {
            let response: TfLJourneyResponse = try await fetch(urlString: baseURL, queryParams: queryParams)
            guard let journey = response.mapToJourneys().first else { return nil }
            return await correctTransitLegTimes(in: journey)
        } catch {
            return nil
        }
    }

    /// Result of querying the TfL Arrivals endpoint for a specific line.
    private enum DepartureResult {
        case found(Date)   // Next arrival found after the requested time
        case noService     // Stop has predictions but none on our line → line likely suspended
        case unknown       // API unavailable or stop quiet — cannot determine service state
    }

    /// Fetch the next actual departure from a TfL stop on a specific line after a given time.
    /// Uses the real-time arrivals endpoint so off-peak gaps in service are handled correctly.
    /// Pass `expectedPlatform` to filter by direction (e.g. "Northbound - Platform 6") when
    /// the Journey API provided platform info, avoiding wrong-direction trains at the same stop.
    private func fetchNextDeparture(fromStopId: String, lineId: String, after time: Date, expectedPlatform: String? = nil) async -> DepartureResult {
        let urlString = "https://api.tfl.gov.uk/StopPoint/\(fromStopId)/Arrivals"
        guard let predictions: [TfLArrivalPrediction] = try? await fetch(urlString: urlString, queryParams: ["app_key": tflAppKey]) else {
            return .unknown
        }

        // Non-empty predictions array means the stop is live. If none match our line → no service.
        if !predictions.isEmpty && !predictions.contains(where: { ($0.lineId ?? "").lowercased() == lineId.lowercased() }) {
            return .noService
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Filter by line, then optionally by platform to avoid wrong-direction trains.
        // Platform matching is substring-based (Arrivals API may format differently from Journey API).
        let filtered = predictions.filter { prediction in
            guard (prediction.lineId ?? "").lowercased() == lineId.lowercased() else { return false }
            if let expected = expectedPlatform, let actual = prediction.platformName {
                // Match on directional keyword (northbound/southbound etc.) when present
                let expectedLower = expected.lowercased()
                let actualLower = actual.lowercased()
                let directionalKeywords = ["northbound", "southbound", "eastbound", "westbound", "inner", "outer"]
                for keyword in directionalKeywords {
                    if expectedLower.contains(keyword) {
                        return actualLower.contains(keyword)
                    }
                }
                // No directional keyword found — don't filter by platform, accept the arrival
            }
            return true
        }

        let nextDate = filtered
            .compactMap { prediction -> Date? in
                guard let arrival = prediction.expectedArrival else { return nil }
                if let date = formatter.date(from: arrival) { return date }
                formatter.formatOptions = [.withInternetDateTime]
                let result = formatter.date(from: arrival)
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return result
            }
            .filter { $0 > time }
            .min()

        if let date = nextDate {
            return .found(date)
        }
        return .unknown
    }

    /// Correct transit leg departure times using live TfL arrivals data.
    /// When a leg departs before the previous leg arrives (timetable scheduling artefact),
    /// query the real-time arrivals endpoint to find the actual next service.
    private func correctTransitLegTimes(in journey: Journey) async -> Journey {
        var correctedLegs = journey.legs

        for i in 1..<correctedLegs.count {
            let previousLeg = correctedLegs[i - 1]
            let currentLeg = correctedLegs[i]

            // Only correct when departure precedes previous arrival
            guard currentLeg.departureTime < previousLeg.arrivalTime else { continue }

            // Prefer a real-time next departure from the Arrivals API; fall back to
            // previous arrival + 2 min minimum transfer so the display is always coherent.
            let stopId = currentLeg.origin.stopId
            let lineId = currentLeg.lineId
            let platform = currentLeg.platform  // Direction hint (e.g. "Northbound - Platform 6")
            let minimumTransferDate = previousLeg.arrivalTime.addingTimeInterval(180)

            let nextDeparture: Date
            var legDisruption: String? = currentLeg.disruption

            if let sid = stopId, let lid = lineId {
                let result = await fetchNextDeparture(fromStopId: sid, lineId: lid, after: previousLeg.arrivalTime, expectedPlatform: platform)
                switch result {
                case .found(let date):
                    nextDeparture = date
                case .noService:
                    // Stop is live but our line has no arrivals — line is suspended or closed
                    let lineName = currentLeg.operatorName ?? lid.capitalized
                    legDisruption = "No live service on \(lineName). Check TfL Status for alternatives."
                    nextDeparture = minimumTransferDate
                case .unknown:
                    // API unavailable or quiet period — use fallback, don't flag disruption
                    nextDeparture = minimumTransferDate
                }
            } else {
                nextDeparture = minimumTransferDate
            }

            // Preserve leg duration; shift departure and arrival forward
            let newArrival = nextDeparture.addingTimeInterval(currentLeg.duration)
            correctedLegs[i] = JourneyLeg(
                id: currentLeg.id,
                mode: currentLeg.mode,
                origin: currentLeg.origin,
                destination: currentLeg.destination,
                departureTime: nextDeparture,
                arrivalTime: newArrival,
                duration: currentLeg.duration,
                operatorName: currentLeg.operatorName,
                serviceIdentifier: currentLeg.serviceIdentifier,
                platform: currentLeg.platform,
                instructions: currentLeg.instructions,
                lineId: currentLeg.lineId,
                disruption: legDisruption
            )
        }

        let newDeparture = correctedLegs.first?.departureTime ?? journey.departureTime
        let newArrival = correctedLegs.last?.arrivalTime ?? journey.arrivalTime
        return Journey(
            id: journey.id,
            legs: correctedLegs,
            departureTime: newDeparture,
            arrivalTime: newArrival,
            duration: newArrival.timeIntervalSince(newDeparture)
        )
    }

    private func isInLondon(latitude: Double, longitude: Double) -> Bool {
        latitude >= 51.28 && latitude <= 51.69 && longitude >= -0.51 && longitude <= 0.33
    }

    // MARK: - Generic Fetch Method

    private func fetch<T: Decodable>(urlString: String, queryParams: [String: String] = [:]) async throws -> T {
        // Build URL with query parameters
        var components = URLComponents(string: urlString)
        if !queryParams.isEmpty {
            components?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components?.url else {
            throw JourneyPlanningError.invalidURL
        }

        // Make request
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JourneyPlanningError.invalidResponse
        }

        // Handle HTTP errors
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw JourneyPlanningError.authenticationRequired
        case 403:
            throw JourneyPlanningError.quotaExceeded
        case 404:
            throw JourneyPlanningError.noRoutesFound
        default:
            throw JourneyPlanningError.httpError(httpResponse.statusCode)
        }

        // Decode response
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw JourneyPlanningError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Error Types

enum JourneyPlanningError: LocalizedError {
    case noAPIConfigured
    case noTfLConfigured
    case smartPlannerNotConfigured
    case authenticationRequired
    case quotaExceeded
    case noRoutesFound
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case networkError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIConfigured:
            return String(localized: "Journey planning is not configured. Enable the free Smart Algorithm in Settings.")
        case .noTfLConfigured:
            return String(localized: "Get Home requires a TfL API key to plan tube and national rail routes.\n\nRegister free at api.tfl.gov.uk and add your credentials in Settings → Journey Planning.")
        case .smartPlannerNotConfigured:
            return String(localized: "Smart journey planner not initialized. Please restart the app.")
        case .authenticationRequired:
            return String(localized: "Invalid API credentials. Please check your settings.")
        case .quotaExceeded:
            return String(localized: "API usage limit exceeded. Please try again later.")
        case .noRoutesFound:
            return String(localized: "No routes found for this journey. Try a different time.")
        case .invalidURL:
            return String(localized: "Invalid request URL")
        case .invalidResponse:
            return String(localized: "Invalid response from server")
        case .httpError(let code):
            return String(localized: "Server error (\(code))")
        case .networkError(let message):
            return String(localized: "Network error: \(message)")
        case .decodingError(let message):
            return String(localized: "Failed to parse response: \(message)")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noAPIConfigured:
            return String(localized: "Go to Settings → Journey Planning and enable the free Smart Algorithm, or add paid API credentials.")
        case .smartPlannerNotConfigured:
            return String(localized: "Close and reopen the app to initialize the journey planner.")
        case .authenticationRequired:
            return String(localized: "Check that your API credentials are entered correctly in Settings.")
        case .quotaExceeded:
            return String(localized: "Wait a few minutes before trying again, or consider upgrading your API plan.")
        case .noRoutesFound:
            return String(localized: "Try selecting a different departure time or check that station codes are correct.")
        default:
            return nil
        }
    }
}
