//
//  UITestSetup.swift
//  trainTimeUITests
//
//  App launch configuration for UI tests with seeded data
//

import XCTest

enum UITestSetup {
    /// Configure app for UI testing with mock data
    static func configureApp(_ app: XCUIApplication, withMockData: Bool = true) {
        // Enable UI testing mode
        app.launchArguments.append("--uitesting")

        if withMockData {
            // Enable mock API responses for consistent screenshots
            app.launchArguments.append("--mock-api")

            // Seed predictable test data
            app.launchEnvironment["TEST_ORIGIN_CRS"] = "PAD"
            app.launchEnvironment["TEST_ORIGIN_NAME"] = "London Paddington"
            app.launchEnvironment["TEST_DESTINATION_CRS"] = "BRI"
            app.launchEnvironment["TEST_DESTINATION_NAME"] = "Bristol Temple Meads"

            // Set fixed time for consistent departure times in screenshots
            let formatter = ISO8601DateFormatter()
            app.launchEnvironment["TEST_CURRENT_TIME"] = formatter.string(from: Date())
        }

        // Disable animations for faster test execution (optional)
        // app.launchArguments.append("-UITestingDisableAnimations")

        // Reset state for clean test runs
        app.launchArguments.append("--reset-state")
    }

    /// Launch app with standard UI test configuration
    static func launch(_ app: XCUIApplication) {
        configureApp(app)
        app.launch()
    }
}
