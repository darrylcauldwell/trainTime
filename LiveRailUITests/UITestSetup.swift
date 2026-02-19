//
//  UITestSetup.swift
//  trainTimeUITests
//
//  App launch configuration for UI tests
//

import XCTest

enum UITestSetup {
    /// Configure app for UI testing
    static func configureApp(_ app: XCUIApplication) {
        // Signal to the app that UI tests are running (useful for disabling animations etc.)
        app.launchArguments.append("--uitesting")
    }

    /// Launch app with standard UI test configuration
    static func launch(_ app: XCUIApplication) {
        configureApp(app)
        app.launch()
    }
}
