//
//  trainTimeUITests.swift
//  LiveRailUITests
//
//  UI tests for LiveRail app with automated screenshot generation.
//  App has two views: Departures and Get Home, accessed via a floating tab bar.
//  Settings is a sheet presented from the gear icon in each view's navigation bar.
//
//  Screenshot sequence:
//  01 - Departures search screen (empty)
//  02 - Departures search screen (stations selected)
//  03 - Live departure board (Chesterfield → London St Pancras)
//  04 - Service detail (calling points for a selected train)
//  05 - Journey Planner sheet (connecting journeys with changes)
//  06 - Get Home tab with home station configured
//  07 - Settings sheet
//

import XCTest

final class trainTimeUITests: XCTestCase {
    var screenshot: ScreenshotHelper!

    override func setUpWithError() throws {
        continueAfterFailure = false
        screenshot = ScreenshotHelper(testCase: self)
        UITestSetup.launch(app)
    }

    override func tearDownWithError() throws {
        screenshot = nil
    }

    // MARK: - Screenshot Tests

    /// Screenshot 01-02: Departures search screen — empty then with stations selected
    func testDeparturesSearchScreen() throws {
        // Departures tab is selected by default
        screenshot.takeScreenshot(named: "01-departures-search", waitFor: 1.0)

        // Select origin: Chesterfield
        let fromButton = app.buttons["From"]
        XCTAssertTrue(fromButton.waitForExistence(timeout: 5.0))
        fromButton.tap()
        selectStation(crs: "CHD")

        // Select destination: London St Pancras
        let toButton = app.buttons["To"]
        XCTAssertTrue(toButton.waitForExistence(timeout: 3.0))
        toButton.tap()
        selectStation(crs: "STP")

        // Screenshot: both stations selected, ready to search
        screenshot.takeScreenshot(named: "02-search-ready", waitFor: 0.5)
    }

    /// Screenshot 03: Live departure board (Chesterfield → London St Pancras)
    func testDepartureList() throws {
        navigateToDepartures(from: "CHD", to: "STP", screenshot: screenshot)
        screenshot.takeScreenshot(named: "03-departure-list", waitFor: 2.0)
    }

    /// Screenshot 04: Service detail — tap the first train to view calling points
    func testServiceDetail() throws {
        navigateToDepartures(from: "CHD", to: "STP", screenshot: screenshot)

        // Tap the first train row to open service detail
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5.0) {
            firstCell.tap()
            screenshot.waitForLoadingToComplete(timeout: 10)
            screenshot.takeScreenshot(named: "04-service-detail", waitFor: 2.0)
        }
    }

    /// Screenshot 05: Journey Planner sheet — connecting journeys with changes
    /// Opens via "All Options" (appears when SmartPlanner finds journeys) or "Open Journey Planner"
    func testJourneyPlanner() throws {
        navigateToDepartures(from: "CHD", to: "STP", screenshot: screenshot)

        // Wait for either entry point to the journey planner
        let allOptionsButton = app.buttons["All Options"]
        let openPlannerButton = app.buttons["Open Journey Planner"]

        if allOptionsButton.waitForExistence(timeout: 15.0) {
            allOptionsButton.tap()
        } else if openPlannerButton.waitForExistence(timeout: 3.0) {
            openPlannerButton.tap()
        } else {
            // Route has direct trains only — no journey planner entry point visible.
            // Take a screenshot of the departure board as a fallback.
            screenshot.takeScreenshot(named: "05-journey-planner", waitFor: 1.0)
            return
        }

        // Wait for journey results to load
        screenshot.waitForLoadingToComplete(timeout: 15)
        screenshot.takeScreenshot(named: "05-journey-planner", waitFor: 2.0)
    }

    /// Screenshot 06: Get Home tab with a home station configured
    func testGetHomeScreen() throws {
        navigateToTab("Get Home")

        // Set home station to London Waterloo so the button is enabled
        let homeStationButton = app.buttons["Home Station"]
        XCTAssertTrue(homeStationButton.waitForExistence(timeout: 5.0))
        homeStationButton.tap()
        selectStation(crs: "WAT")

        screenshot.takeScreenshot(named: "06-get-home", waitFor: 1.0)
    }

    /// Screenshot 07: Settings sheet (opened via gear icon)
    func testSettingsSheet() throws {
        // The gear button is in the navigation bar of the Departures view
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5.0))
        settingsButton.tap()
        screenshot.takeScreenshot(named: "07-settings", waitFor: 0.5)
    }
}
