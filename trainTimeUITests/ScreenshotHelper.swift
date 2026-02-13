//
//  ScreenshotHelper.swift
//  trainTimeUITests
//
//  Screenshot capture utility with organized naming and timing control
//

import XCTest

final class ScreenshotHelper {
    private let testCase: XCTestCase
    private var screenshotCounter = 0

    init(testCase: XCTestCase) {
        self.testCase = testCase
    }

    /// Capture a screenshot with organized naming for App Store submission
    /// - Parameters:
    ///   - named: Descriptive name (e.g., "01-search", "02-departures")
    ///   - waitFor: Seconds to wait before capture (allows animations to settle)
    func takeScreenshot(named: String, waitFor seconds: TimeInterval = 0.5) {
        // Wait for animations and layout to settle
        Thread.sleep(forTimeInterval: seconds)

        // Capture screenshot
        let screenshot = XCUIScreen.main.screenshot()

        // Create attachment with descriptive name
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = named
        attachment.lifetime = .keepAlways
        testCase.add(attachment)

        screenshotCounter += 1
    }

    /// Wait for an element to exist with timeout
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    /// Wait for loading indicators to disappear
    func waitForLoadingToComplete(timeout: TimeInterval = 10) {
        let loadingIndicator = XCUIApplication().activityIndicators.firstMatch
        let exists = loadingIndicator.waitForExistence(timeout: 1.0)
        if exists {
            // Wait for it to disappear
            let predicate = NSPredicate(format: "exists == false")
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: loadingIndicator)
            let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
            if result != .completed {
                print("Warning: Loading indicator did not disappear within timeout")
            }
        }
    }
}
