//
//  trainTimeUITests.swift
//  trainTimeUITests
//
//  UI tests for trainTime app with automated screenshot generation
//

import XCTest

final class trainTimeUITests: XCTestCase {
    var screenshot: ScreenshotHelper!

    override func setUpWithError() throws {
        continueAfterFailure = false

        screenshot = ScreenshotHelper(testCase: self)

        // Configure app for UI testing
        UITestSetup.launch(app)
    }

    override func tearDownWithError() throws {
        screenshot = nil
    }

    // MARK: - Screenshot Tests

    /// Test 1: Journey Search Flow
    /// Captures: Search screen, station selection, departure list
    func testJourneySearchFlow() throws {
        // Screenshot 1: Initial search screen
        screenshot.takeScreenshot(named: "01-search-initial")

        // Tap "From" button
        let fromButton = app.buttons["From"]
        XCTAssertTrue(fromButton.waitForExistence(timeout: 5.0))
        fromButton.tap()

        // Select London Paddington
        selectStation(crs: "PAD")

        // Screenshot 2: After selecting origin
        screenshot.takeScreenshot(named: "02-search-origin-selected", waitFor: 0.3)

        // Tap "To" button
        let toButton = app.buttons["To"]
        XCTAssertTrue(toButton.exists)
        toButton.tap()

        // Select Bristol Temple Meads
        selectStation(crs: "BRI")

        // Screenshot 3: Both stations selected
        screenshot.takeScreenshot(named: "03-search-ready", waitFor: 0.3)

        // Tap "Find Trains"
        let findTrainsButton = app.buttons["Find Trains"]
        XCTAssertTrue(findTrainsButton.exists)
        XCTAssertTrue(findTrainsButton.isEnabled)
        findTrainsButton.tap()

        // Wait for departures to load
        screenshot.waitForLoadingToComplete()

        // Screenshot 4: Departure list
        screenshot.takeScreenshot(named: "04-departures", waitFor: 1.0)
    }

    /// Test 2: Service Detail Flow
    /// Captures: Service detail view, calling points, live map
    func testServiceDetailFlow() throws {
        // Navigate to departures
        navigateToDepartures(from: "PAD", to: "BRI", screenshot: screenshot)

        // Tap first departure
        tapFirstDeparture()

        // Wait for service detail to load
        screenshot.waitForLoadingToComplete()

        // Screenshot 5: Service detail - calling points tab
        screenshot.takeScreenshot(named: "05-service-detail-calling-points", waitFor: 1.0)

        // Switch to Live Map tab
        let liveMapTab = app.buttons["Live Map"]
        XCTAssertTrue(liveMapTab.waitForExistence(timeout: 5.0))
        liveMapTab.tap()

        // Wait for map to render
        screenshot.takeScreenshot(named: "06-service-detail-live-map", waitFor: 2.0)
    }

    /// Test 3: Saved Journeys Flow
    /// Captures: Saving a journey, saved journeys list
    func testSavedJourneysFlow() throws {
        // Navigate to search and select stations
        let fromButton = app.buttons["From"]
        XCTAssertTrue(fromButton.waitForExistence(timeout: 5.0))
        fromButton.tap()
        selectStation(crs: "PAD")

        app.buttons["To"].tap()
        selectStation(crs: "BRI")

        // Tap "Save Journey"
        let saveButton = app.buttons["Save Journey"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2.0))
        saveButton.tap()

        // Navigate to Saved tab
        navigateToTab("Saved")

        // Wait for saved journeys to appear
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 7: Saved journeys list
        screenshot.takeScreenshot(named: "07-saved-journeys", waitFor: 0.5)
    }

    /// Test 4: Schedule View
    /// Captures: Schedule tab with quick select
    func testScheduleView() throws {
        // Navigate to Schedule tab
        navigateToTab("Schedule")

        // Wait for schedule view to appear
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 8: Schedule view
        screenshot.takeScreenshot(named: "08-schedule", waitFor: 0.5)
    }

    /// Test 5: Settings View
    /// Captures: Settings screen
    func testSettingsView() throws {
        // Navigate to Settings tab
        navigateToTab("Settings")

        // Wait for settings to appear
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 9: Settings view
        screenshot.takeScreenshot(named: "09-settings", waitFor: 0.5)
    }
}
