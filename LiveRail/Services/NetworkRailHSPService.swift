//
//  NetworkRailHSPService.swift
//  LiveRail
//
//  Network client for Network Rail Historical Service Performance API
//  Provides actual vs scheduled times for departed trains
//

import Foundation

@Observable
final class NetworkRailHSPService {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    var username: String {
        get {
            UserDefaults.standard.string(forKey: "networkRailUsername") ?? Config.defaultNetworkRailUsername
        }
        set { UserDefaults.standard.set(newValue, forKey: "networkRailUsername") }
    }

    var password: String {
        get {
            UserDefaults.standard.string(forKey: "networkRailPassword") ?? Config.defaultNetworkRailPassword
        }
        set { UserDefaults.standard.set(newValue, forKey: "networkRailPassword") }
    }

    private var baseURL: String {
        "https://hsp-prod.rockshore.net/api/v1"
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
    }

    /// Get service details by RID (RTTI ID)
    func fetchServiceByRID(_ rid: String) async throws -> HSPServiceDetail {
        let payload = ["rid": rid]
        return try await post(endpoint: "/serviceDetails", payload: payload)
    }

    /// Search for services between origin and destination using serviceMetrics
    func searchServices(from origin: String, to destination: String, fromDate: Date, toDate: Date? = nil, fromTime: String = "0000", toTime: String = "2359") async throws -> HSPMetricsResponse {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let fromDateString = dateFormatter.string(from: fromDate)
        let toDateString = dateFormatter.string(from: toDate ?? fromDate)

        // Determine day type
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: fromDate)
        let dayType: String
        if weekday == 1 { // Sunday
            dayType = "SUNDAY"
        } else if weekday == 7 { // Saturday
            dayType = "SATURDAY"
        } else {
            dayType = "WEEKDAY"
        }

        let payload: [String: Any] = [
            "from_loc": origin,
            "to_loc": destination,
            "from_time": fromTime,
            "to_time": toTime,
            "from_date": fromDateString,
            "to_date": toDateString,
            "days": dayType
        ]

        return try await post(endpoint: "/serviceMetrics", payload: payload)
    }

    private func post<T: Decodable>(endpoint: String, payload: [String: Any]) async throws -> T {
        let urlString = baseURL + endpoint

        guard let url = URL(string: urlString) else {
            throw HSPAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // HTTP Basic Authentication
        if !username.isEmpty && !password.isEmpty {
            let credentials = "\(username):\(password)"
            if let credentialData = credentials.data(using: .utf8) {
                let base64Credentials = credentialData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Encode JSON payload
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HSPAPIError.invalidResponse
        }

        // Log response for debugging
        print("HSP API \(endpoint) Response Status: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("HSP API Error Response: \(responseString)")
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw HSPAPIError.authenticationRequired
            }
            throw HSPAPIError.httpError(httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }
}

enum HSPAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serviceNotFound
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "Server error (\(code))"
        case .serviceNotFound: return "Service not found"
        case .authenticationRequired: return "Network Rail credentials required"
        }
    }
}
