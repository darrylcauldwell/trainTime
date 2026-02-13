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

        // Ensure we're on search tab
        let searchTab = app.buttons["Search"]
        if searchTab.exists {
            searchTab.tap()
        }

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

        // Wait for station picker to appear
        let searchField = app.textFields["Search Stations"]
        _ = searchField.waitForExistence(timeout: 2.0)

        // Type CRS code (faster than full name)
        searchField.tap()
        searchField.typeText(crs)

        // Tap the first result (should be exact match)
        let firstStation = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", crs)).firstMatch
        _ = firstStation.waitForExistence(timeout: 2.0)
        firstStation.tap()
    }

    /// Navigate to a specific tab
    func navigateToTab(_ tabName: String) {
        let app = self.app
        let tab = app.buttons[tabName]
        if tab.exists && !tab.isSelected {
            tab.tap()
        }
    }

    /// Tap the first departure row
    func tapFirstDeparture() {
        let app = self.app
        let firstDeparture = app.buttons.matching(identifier: "departure-row").firstMatch
        _ = firstDeparture.waitForExistence(timeout: 5.0)
        firstDeparture.tap()
    }
}
