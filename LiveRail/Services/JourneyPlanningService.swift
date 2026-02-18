//
//  JourneyPlanningService.swift
//  LiveRail
//
//  Service for multi-leg journey planning using TfL and TransportAPI
//

import Foundation

@Observable
final class JourneyPlanningService {
    private let session: URLSession
    private let decoder: JSONDecoder
    private var smartPlanner: SmartJourneyPlanner?

    /// Enable free smart algorithm (uses Huxley2 multi-query)
    var enableSmartAlgorithm: Bool {
        get { UserDefaults.standard.object(forKey: "enableSmartAlgorithm") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enableSmartAlgorithm") }
    }

    // MARK: - TfL API Credentials

    var tflAppId: String {
        get { UserDefaults.standard.string(forKey: "tflAppId") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "tflAppId") }
    }

    var tflAppKey: String {
        get { UserDefaults.standard.string(forKey: "tflAppKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "tflAppKey") }
    }

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

    /// Automatically detect which API to use based on configured credentials
    /// Priority: TransportAPI (full UK) > TfL (London area) > Smart Algorithm (free) > None
    var provider: APIProvider {
        // Prefer TransportAPI if configured (full UK coverage including inter-city)
        if !transportAPIAppId.isEmpty && !transportAPIAppKey.isEmpty {
            return .transportAPI
        }
        // Fallback to TfL if configured (London and South East only)
        if !tflAppId.isEmpty && !tflAppKey.isEmpty {
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

    /// Check if TfL API is configured (for London area)
    var hasTfLAPI: Bool {
        !tflAppId.isEmpty && !tflAppKey.isEmpty
    }

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
        self.smartPlanner = SmartJourneyPlanner(apiService: apiService)
    }

    // MARK: - Public API

    /// Plan a journey between two stations
    /// - Parameters:
    ///   - origin: Origin station CRS code
    ///   - destination: Destination station CRS code
    ///   - departureTime: Desired departure time (defaults to now)
    /// - Returns: Array of Journey options
    func planJourney(from origin: String, to destination: String, departureTime: Date = Date()) async throws -> [Journey] {
        switch provider {
        case .transportAPI:
            return try await planJourneyTransportAPI(from: origin, to: destination, departureTime: departureTime)
        case .tfl:
            return try await planJourneyTfL(from: origin, to: destination, departureTime: departureTime)
        case .smartAlgorithm:
            guard let smartPlanner = smartPlanner else {
                throw JourneyPlanningError.smartPlannerNotConfigured
            }
            return try await smartPlanner.planJourney(from: origin, to: destination, departureTime: departureTime)
        case .none:
            throw JourneyPlanningError.noAPIConfigured
        }
    }

    // MARK: - TfL API Implementation

    private func planJourneyTfL(from origin: String, to destination: String, departureTime: Date) async throws -> [Journey] {
        // TfL Journey API endpoint
        let baseURL = "https://api.tfl.gov.uk/Journey/JourneyResults/\(origin)/to/\(destination)"

        // Format time and date for TfL API
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        let timeString = timeFormatter.string(from: departureTime)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: departureTime)

        // Build query parameters
        let queryParams: [String: String] = [
            "app_id": tflAppId,
            "app_key": tflAppKey,
            "mode": "national-rail", // Focus on rail journeys
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
