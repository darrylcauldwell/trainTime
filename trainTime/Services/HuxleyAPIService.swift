//
//  HuxleyAPIService.swift
//  trainTime
//
//  Network client for Huxley2 REST API (Darwin OpenLDBWS proxy)
//

import Foundation

@Observable
final class HuxleyAPIService {
    private let session: URLSession
    private let decoder: JSONDecoder

    var apiToken: String {
        get { UserDefaults.standard.string(forKey: "darwinApiToken") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "darwinApiToken") }
    }

    var baseURL: String {
        "https://huxley2.azurewebsites.net"
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
        let path = "/departures/\(origin)/to/\(destination)/\(rows)"
        return try await fetch(path: path)
    }

    /// Fetch all departures from a station (unfiltered)
    func fetchAllDepartures(from station: String, rows: Int = 20) async throws -> DepartureBoard {
        let path = "/departures/\(station)/\(rows)"
        return try await fetch(path: path)
    }

    /// Fetch detailed service information by service ID
    func fetchServiceDetail(serviceID: String) async throws -> ServiceDetail {
        let encodedID = serviceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? serviceID
        let path = "/service/\(encodedID)"
        return try await fetch(path: path)
    }

    /// Fetch departures for schedule view (larger window)
    func fetchScheduleDepartures(from origin: String, to destination: String, rows: Int = 20) async throws -> DepartureBoard {
        let path = "/departures/\(origin)/to/\(destination)/\(rows)"
        return try await fetch(path: path)
    }

    private func fetch<T: Decodable>(path: String) async throws -> T {
        var urlString = baseURL + path
        if !apiToken.isEmpty {
            urlString += "?accessToken=\(apiToken)"
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
