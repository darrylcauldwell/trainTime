//
//  HuxleyAPIService.swift
//  LiveRail
//
//  Network client for Huxley2 REST API (Darwin OpenLDBWS proxy)
//

import Foundation

@Observable
final class HuxleyAPIService {
    private let session: URLSession
    private let decoder: JSONDecoder

    var apiToken: String {
        get {
            // Use user's custom token if set, otherwise use default
            UserDefaults.standard.string(forKey: "darwinApiToken") ?? Config.defaultDarwinAPIToken
        }
        set { UserDefaults.standard.set(newValue, forKey: "darwinApiToken") }
    }

    var baseURL: String {
        Config.huxleyBaseURL
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    /// Fetch departures from origin filtered by destination
    func fetchDepartures(from origin: String, to destination: String, rows: Int = 10) async throws -> DepartureBoard {
        // Note: Huxley2 doesn't support row count in path for filtered departures
        let path = "/departures/\(origin)/to/\(destination)"
        return try await fetch(path: path)
    }

    /// Fetch arrivals at a station filtered by origin
    func fetchArrivals(at station: String, from origin: String, rows: Int = 20) async throws -> DepartureBoard {
        let path = "/arrivals/\(station)/from/\(origin)"
        return try await fetch(path: path)
    }

    /// Fetch all departures from a station (unfiltered)
    func fetchAllDepartures(from station: String, rows: Int = 20) async throws -> DepartureBoard {
        let path = "/all/\(station)"
        return try await fetch(path: path)
    }

    /// Fetch detailed service information by service ID
    func fetchServiceDetail(serviceID: String) async throws -> ServiceDetail {
        let encodedID = serviceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? serviceID
        let path = "/service/\(encodedID)"
        return try await fetch(path: path)
    }

    /// Fetch departures for schedule view with optional date/time
    func fetchScheduleDepartures(from origin: String, to destination: String, at departureTime: Date? = nil, rows: Int = 20) async throws -> DepartureBoard {
        // Note: Huxley2 doesn't support row count in path for filtered departures
        let path = "/departures/\(origin)/to/\(destination)"

        var queryParams: [String: String] = [:]

        // Calculate timeOffset if departureTime provided
        if let departureTime = departureTime {
            let minutesFromNow = Int(departureTime.timeIntervalSinceNow / 60)
            // Clamp to Huxley2's -120 to +120 minute range
            let clampedOffset = max(-120, min(120, minutesFromNow))
            queryParams["timeOffset"] = String(clampedOffset)
        }

        return try await fetch(path: path, queryParams: queryParams)
    }

    private func fetch<T: Decodable>(path: String, queryParams: [String: String] = [:]) async throws -> T {
        var urlString = baseURL + path
        var allParams = queryParams

        if !apiToken.isEmpty {
            allParams["accessToken"] = apiToken
        }

        if !allParams.isEmpty {
            let queryString = allParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "Server error (\(code))"
        case .noData: return "No data received"
        }
    }
}
