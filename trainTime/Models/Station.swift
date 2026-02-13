//
//  Station.swift
//  trainTime
//
//  Bundled station data: CRS code, name, coordinates
//

import Foundation
import CoreLocation

struct Station: Codable, Identifiable, Hashable {
    let crs: String
    let name: String
    let lat: Double
    let lon: Double

    var id: String { crs }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Whether this station is within the London zone (rough bounding box)
    var isInLondon: Bool {
        lat >= 51.28 && lat <= 51.69 && lon >= -0.51 && lon <= 0.33
    }
}
