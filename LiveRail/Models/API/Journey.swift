//
//  Journey.swift
//  LiveRail
//
//  Multi-leg journey with route, times, and transport modes
//

import Foundation
import MapKit

// MARK: - Journey

struct Journey: Codable, Identifiable, Hashable {
    let id: String
    let legs: [JourneyLeg]
    let departureTime: Date
    let arrivalTime: Date
    let duration: TimeInterval // in seconds

    static func == (lhs: Journey, rhs: Journey) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Number of changes (transfers) in this journey
    var numberOfChanges: Int {
        // Count rail/bus legs and subtract 1 for the number of changes
        let transitLegs = legs.filter { $0.mode == .train || $0.mode == .bus }
        return max(0, transitLegs.count - 1)
    }

    /// Formatted duration string (e.g., "1h 23m")
    var totalDurationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Display text for number of changes
    var changesText: String {
        if numberOfChanges == 0 {
            return String(localized: "Direct")
        } else if numberOfChanges == 1 {
            return String(localized: "1 change")
        } else {
            return String(localized: "\(numberOfChanges) changes")
        }
    }

    /// Departure time formatted for display
    var departureTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: departureTime)
    }

    /// Arrival time formatted for display
    var arrivalTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: arrivalTime)
    }

    /// Origin station
    var origin: JourneyLocation {
        legs.first?.origin ?? JourneyLocation(name: "Unknown", crs: nil, latitude: nil, longitude: nil)
    }

    /// Destination station
    var destination: JourneyLocation {
        legs.last?.destination ?? JourneyLocation(name: "Unknown", crs: nil, latitude: nil, longitude: nil)
    }

    /// Unique transport modes used in journey (for icon preview)
    var uniqueModes: [TransportMode] {
        Array(Set(legs.map { $0.mode })).sorted { $0.displayOrder < $1.displayOrder }
    }
}

// MARK: - JourneyLeg

struct JourneyLeg: Codable, Identifiable, Hashable {
    let id: String
    let mode: TransportMode
    let origin: JourneyLocation
    let destination: JourneyLocation
    let departureTime: Date
    let arrivalTime: Date
    let duration: TimeInterval // in seconds
    let operatorName: String?
    let serviceIdentifier: String? // For trains: serviceID for live detail lookup
    let platform: String?
    let instructions: String? // For walking legs

    static func == (lhs: JourneyLeg, rhs: JourneyLeg) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Formatted duration string
    var durationFormatted: String {
        let minutes = Int(duration) / 60
        if minutes < 1 {
            return "< 1m"
        }
        return "\(minutes)m"
    }

    /// Departure time formatted for display
    var departureTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: departureTime)
    }

    /// Arrival time formatted for display
    var arrivalTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: arrivalTime)
    }
}

// MARK: - JourneyLocation

struct JourneyLocation: Codable, Hashable {
    let name: String
    let crs: String? // CRS code for rail stations
    let latitude: Double?
    let longitude: Double?

    /// MapKit coordinate if location data available
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Display name with optional CRS code
    var displayName: String {
        if let crs = crs {
            return "\(name) (\(crs))"
        }
        return name
    }
}

// MARK: - TransportMode

enum TransportMode: String, Codable, CaseIterable {
    case train = "train"
    case bus = "bus"
    case walk = "walking"
    case tube = "tube"
    case dlr = "dlr"
    case overground = "overground"
    case tram = "tram"
    case cableCar = "cable-car"
    case river = "river-bus"
    case coach = "coach"
    case cycle = "cycle"
    case unknown = "unknown"

    /// SF Symbol name for this transport mode
    var iconName: String {
        switch self {
        case .train:
            return "train.side.front.car"
        case .bus, .coach:
            return "bus"
        case .walk:
            return "figure.walk"
        case .tube:
            return "tram.circle.fill"
        case .dlr, .overground:
            return "tram"
        case .tram:
            return "tram.fill"
        case .cableCar:
            return "cablecar.fill"
        case .river:
            return "ferry"
        case .cycle:
            return "bicycle"
        case .unknown:
            return "questionmark.circle"
        }
    }

    /// Display name for this transport mode
    var displayName: String {
        switch self {
        case .train:
            return String(localized: "Train")
        case .bus:
            return String(localized: "Bus")
        case .walk:
            return String(localized: "Walk")
        case .tube:
            return String(localized: "Tube")
        case .dlr:
            return String(localized: "DLR")
        case .overground:
            return String(localized: "Overground")
        case .tram:
            return String(localized: "Tram")
        case .cableCar:
            return String(localized: "Cable Car")
        case .river:
            return String(localized: "River Bus")
        case .coach:
            return String(localized: "Coach")
        case .cycle:
            return String(localized: "Cycle")
        case .unknown:
            return String(localized: "Unknown")
        }
    }

    /// Sort order for display in mode previews
    var displayOrder: Int {
        switch self {
        case .train: return 0
        case .tube: return 1
        case .overground: return 2
        case .dlr: return 3
        case .tram: return 4
        case .bus, .coach: return 5
        case .river: return 6
        case .cableCar: return 7
        case .cycle: return 8
        case .walk: return 9
        case .unknown: return 10
        }
    }
}
