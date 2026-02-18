//
//  LocationService.swift
//  LiveRail
//
//  CoreLocation wrapper for user position
//

import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isAuthorized = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }

    /// Whether current location is in London (rough bounding box)
    var isInLondon: Bool {
        guard let loc = currentLocation else { return false }
        return loc.coordinate.latitude >= 51.28 && loc.coordinate.latitude <= 51.69 &&
               loc.coordinate.longitude >= -0.51 && loc.coordinate.longitude <= 0.33
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // CLLocationManager callbacks come on arbitrary threads
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = locations.last
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = manager.authorizationStatus
            self?.isAuthorized = manager.authorizationStatus == .authorizedWhenInUse ||
                                 manager.authorizationStatus == .authorizedAlways

            if self?.isAuthorized == true {
                manager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
