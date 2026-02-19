//
//  AppLogger.swift
//  LiveRail
//
//  Centralised os.Logger instances for each subsystem.
//  Capture with:  xcrun simctl spawn booted log stream \
//                   --predicate 'subsystem == "dev.dreamfold.LiveRail"' \
//                   --level debug
//

import OSLog

enum AppLogger {
    private static let subsystem = "dev.dreamfold.LiveRail"

    static let api      = Logger(subsystem: subsystem, category: "API")
    static let journey  = Logger(subsystem: subsystem, category: "Journey")
    static let ui       = Logger(subsystem: subsystem, category: "UI")
    static let cache    = Logger(subsystem: subsystem, category: "Cache")
}
