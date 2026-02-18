//
//  NavigationService.swift
//  LiveRail
//
//  MapKit/TfL transit directions to station
//

import Foundation
import MapKit
import CoreLocation

struct NavigationStep: Identifiable {
    let id = UUID()
    let instruction: String
    let distance: CLLocationDistance
    let transportType: TransportMode
    let lineName: String?
    let duration: TimeInterval

    enum TransportMode: String {
        case walk, tube, bus, rail, other
    }
}

struct NavigationResult {
    let steps: [NavigationStep]
    let totalDuration: TimeInterval
    let totalDistance: CLLocationDistance
    let arrivalTime: Date
}

@Observable
final class NavigationService {
    private(set) var isLoading = false
    private(set) var navigationResult: NavigationResult?
    private(set) var error: String?

    /// Get transit directions from current location to a station
    @MainActor
    func getDirections(
        from userLocation: CLLocationCoordinate2D,
        to station: Station
    ) async {
        isLoading = true
        error = nil

        // Check if in London for TfL API
        let isLondon = userLocation.latitude >= 51.28 && userLocation.latitude <= 51.69 &&
                       userLocation.longitude >= -0.51 && userLocation.longitude <= 0.33

        if isLondon {
            await getTfLDirections(from: userLocation, to: station)
        } else {
            await getAppleMapsDirections(from: userLocation, to: station)
        }

        isLoading = false
    }

    /// Open transit directions in Apple Maps
    func openInAppleMaps(to station: Station) {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: station.coordinate))
        destination.name = station.name
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit
        ])
    }

    // MARK: - Apple Maps Transit Directions

    @MainActor
    private func getAppleMapsDirections(
        from userLocation: CLLocationCoordinate2D,
        to station: Station
    ) async {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: station.coordinate))
        request.transportType = .transit

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()
            guard let route = response.routes.first else {
                error = "No transit routes found"
                return
            }

            let steps = route.steps.compactMap { step -> NavigationStep? in
                guard !step.instructions.isEmpty else { return nil }
                return NavigationStep(
                    instruction: step.instructions,
                    distance: step.distance,
                    transportType: step.transportType == .walking ? .walk : .rail,
                    lineName: nil,
                    duration: step.distance / 1.4 // rough walking speed estimate
                )
            }

            navigationResult = NavigationResult(
                steps: steps,
                totalDuration: route.expectedTravelTime,
                totalDistance: route.distance,
                arrivalTime: Date().addingTimeInterval(route.expectedTravelTime)
            )
        } catch {
            self.error = "Transit directions unavailable. Try opening in Apple Maps."
        }
    }

    // MARK: - TfL Journey Planner

    @MainActor
    private func getTfLDirections(
        from userLocation: CLLocationCoordinate2D,
        to station: Station
    ) async {
        let fromStr = "\(userLocation.latitude),\(userLocation.longitude)"
        let toStr = "\(station.lat),\(station.lon)"
        let urlString = "https://api.tfl.gov.uk/Journey/JourneyResults/\(fromStr)/to/\(toStr)?mode=tube,bus,walking,dlr,elizabeth-line,overground"

        guard let url = URL(string: urlString) else {
            await getAppleMapsDirections(from: userLocation, to: station)
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let tflResponse = try JSONDecoder().decode(NavTfLJourneyResponse.self, from: data)

            guard let journey = tflResponse.journeys?.first else {
                await getAppleMapsDirections(from: userLocation, to: station)
                return
            }

            let steps = journey.legs?.compactMap { leg -> NavigationStep? in
                let mode: NavigationStep.TransportMode
                switch leg.mode?.id {
                case "walking": mode = .walk
                case "tube": mode = .tube
                case "bus": mode = .bus
                case "dlr", "elizabeth-line", "overground", "national-rail": mode = .rail
                default: mode = .other
                }

                let instruction: String
                if mode == .walk {
                    instruction = "Walk to \(leg.arrivalPoint?.commonName ?? "next stop")"
                } else {
                    let lineName = leg.routeOptions?.first?.name ?? leg.mode?.name ?? ""
                    let direction = leg.arrivalPoint?.commonName ?? ""
                    instruction = "\(lineName) to \(direction)"
                }

                return NavigationStep(
                    instruction: instruction,
                    distance: CLLocationDistance(leg.distance ?? 0),
                    transportType: mode,
                    lineName: leg.routeOptions?.first?.name,
                    duration: TimeInterval(leg.duration ?? 0) * 60
                )
            } ?? []

            navigationResult = NavigationResult(
                steps: steps,
                totalDuration: TimeInterval(journey.duration ?? 0) * 60,
                totalDistance: steps.reduce(0) { $0 + $1.distance },
                arrivalTime: Date().addingTimeInterval(TimeInterval(journey.duration ?? 0) * 60)
            )
        } catch {
            // Fallback to Apple Maps
            await getAppleMapsDirections(from: userLocation, to: station)
        }
    }
}

// MARK: - TfL Walking Directions Response Models (Navigation only)

private struct NavTfLJourneyResponse: Codable {
    let journeys: [NavTfLJourney]?
}

private struct NavTfLJourney: Codable {
    let duration: Int?
    let legs: [NavTfLLeg]?
}

private struct NavTfLLeg: Codable {
    let duration: Int?
    let distance: Int?
    let mode: NavTfLMode?
    let routeOptions: [NavTfLRouteOption]?
    let departurePoint: NavTfLPoint?
    let arrivalPoint: NavTfLPoint?
}

private struct NavTfLMode: Codable {
    let id: String?
    let name: String?
}

private struct NavTfLRouteOption: Codable {
    let name: String?
}

private struct NavTfLPoint: Codable {
    let commonName: String?
    let lat: Double?
    let lon: Double?
}
