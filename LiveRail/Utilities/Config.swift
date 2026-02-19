//
//  Config.swift
//  LiveRail
//
//  API configuration and secrets
//

import Foundation

enum Config {
    /// Default Darwin API token for National Rail Enquiries data
    /// Users can override this in Settings if they have their own token
    static let defaultDarwinAPIToken: String = {
        // Check for build-time injected token first (from GitHub Secrets / CI/CD)
        if let buildToken = ProcessInfo.processInfo.environment["DARWIN_API_TOKEN"], !buildToken.isEmpty {
            return buildToken
        }
        
        // Fallback to embedded token (obfuscated)
        // Token: 0ca3d009-ddb1-4f12-975e-59f0a737a8f7
        let parts = [
            "0ca3d009",
            "ddb1",
            "4f12",
            "975e",
            "59f0a737a8f7"
        ]
        return parts.joined(separator: "-")
    }()
    
    /// Network Rail Open Data credentials
    /// Register at https://raildata.org.uk/
    static let defaultNetworkRailUsername: String = {
        if let buildUsername = ProcessInfo.processInfo.environment["NETWORK_RAIL_USERNAME"], !buildUsername.isEmpty {
            return buildUsername
        }
        return "" // User must provide their own
    }()

    static let defaultNetworkRailPassword: String = {
        if let buildPassword = ProcessInfo.processInfo.environment["NETWORK_RAIL_PASSWORD"], !buildPassword.isEmpty {
            return buildPassword
        }
        return "" // User must provide their own
    }()

    /// App version read from bundle (CFBundleShortVersionString)
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// TfL Unified API key — used for Get Home and London journey planning
    /// Registered under the LiveRail subscription (500 req/min)
    static let defaultTfLAppKey: String = {
        if let envKey = ProcessInfo.processInfo.environment["TFL_APP_KEY"], !envKey.isEmpty {
            return envKey
        }
        let parts = ["25c691ef", "0fa84750", "8d3aecf7", "3823ec8d"]
        return parts.joined()
    }()

    /// Huxley2 API base URL
    static let huxleyBaseURL = "https://huxley2.azurewebsites.net"
}
