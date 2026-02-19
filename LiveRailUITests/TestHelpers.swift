//
//  TestHelpers.swift
//  trainTimeUITests
//
//  Reusable navigation and interaction helpers for UI tests
//

import XCTest

extension XCTestCase {
    var app: XCUIApplication {
        return XCUIApplication()
    }

    /// Navigate to departure list for a given route
    func navigateToDepartures(from originCRS: String, to destinationCRS: String, screenshot: ScreenshotHelper? = nil) {
        let app = self.app

        // Ensure we're on the Departures tab
        navigateToTab("Departures")

        // Select origin station
        app.buttons["From"].tap()
        selectStation(crs: originCRS)

        // Select destination station
        app.buttons["To"].tap()
        selectStation(crs: destinationCRS)

        // Tap Find Trains
        app.buttons["Find Trains"].tap()

        // Wait for departures to load
        screenshot?.waitForLoadingToComplete()
    }

    /// Select a station in the station picker by CRS code
    func selectStation(crs: String) {
        let app = self.app

        // .searchable() creates a UISearchBar exposed as app.searchFields
        let searchField = app.searchFields.firstMatch
        _ = searchField.waitForExistence(timeout: 5.0)
        searchField.tap()
        searchField.typeText(crs)

        // Station result buttons have format "Station Name (CRS)" — exclude recent-route
        // buttons whose labels contain " - " (e.g. "Chesterfield, London STP, CHD - STP")
        let stationPredicate = NSPredicate(
            format: "label CONTAINS[c] %@ AND NOT (label CONTAINS[c] ' - ')", crs
        )
        let firstStation = app.buttons.matching(stationPredicate).firstMatch
        _ = firstStation.waitForExistence(timeout: 3.0)

        if firstStation.isHittable {
            firstStation.tap()
        } else {
            // Scroll picker list up to bring result into view then retry
            app.swipeUp()
            firstStation.tap()
        }
    }

    /// Navigate to a tab using the floating glass tab bar
    func navigateToTab(_ tabName: String) {
        let app = self.app
        let tab = app.buttons[tabName]
        if tab.waitForExistence(timeout: 3.0) {
            tab.tap()
        }
    }
}
