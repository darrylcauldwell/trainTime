//
//  Formatters.swift
//  trainTime
//
//  Train time parsing and display utilities
//

import Foundation

enum TrainTimeFormatter {

    /// Parse a Huxley2 time string like "14:30" or "14:30:00" into hours and minutes
    static func parseTime(_ timeString: String?) -> (hour: Int, minute: Int)? {
        guard let timeString, !timeString.isEmpty else { return nil }
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    /// Format a time string to HH:mm display
    static func displayTime(_ timeString: String?) -> String {
        guard let timeString else { return "--:--" }
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2 else { return timeString }
        return "\(parts[0]):\(parts[1])"
    }

    /// Calculate delay in minutes between scheduled and actual/estimated time
    static func delayMinutes(scheduled: String?, actual: String?) -> Int? {
        guard let sched = parseTime(scheduled),
              let act = parseTime(actual) else { return nil }
        var diff = (act.hour * 60 + act.minute) - (sched.hour * 60 + sched.minute)
        // Handle midnight crossing
        if diff < -720 { diff += 1440 }
        if diff > 720 { diff -= 1440 }
        return diff
    }

    /// Human-readable delay string
    static func delayText(scheduled: String?, actual: String?) -> String {
        guard let delay = delayMinutes(scheduled: scheduled, actual: actual) else {
            return ""
        }
        if delay == 0 { return "On time" }
        if delay > 0 { return "+\(delay) min" }
        return "\(delay) min"
    }

    /// Relative time from now, e.g. "3 min ago", "just now"
    static func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return String(localized: "just now") }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }

    /// Create a Date from today's date with given time string.
    /// If referenceDate is provided and the result would be before it,
    /// rolls forward to the next day (handles midnight crossing).
    static func dateFromTimeString(_ timeString: String?, after referenceDate: Date? = nil) -> Date? {
        guard let (hour, minute) = parseTime(timeString) else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard var date = calendar.date(from: components) else { return nil }

        // Handle midnight crossing: if this time should be after the reference
        // but came out before, add a day
        if let ref = referenceDate, date < ref {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        return date
    }

    /// Best available time: actual > estimated > scheduled
    /// Filters out status strings like "On time", "Cancelled", "Delayed"
    static func bestTime(scheduled: String?, estimated: String?, actual: String?) -> String? {
        if let actual, parseTime(actual) != nil { return actual }
        if let estimated, parseTime(estimated) != nil { return estimated }
        return scheduled
    }

    /// Minutes from now until a given time string
    static func minutesUntil(_ timeString: String?) -> Int? {
        guard let date = dateFromTimeString(timeString) else { return nil }
        let diff = date.timeIntervalSince(Date())
        return Int(diff / 60)
    }

    /// Short display: "in 5 min" or "due" or "departed"
    static func departureCountdown(_ timeString: String?) -> String {
        guard let minutes = minutesUntil(timeString) else { return "" }
        if minutes <= 0 { return String(localized: "Due") }
        if minutes == 1 { return "1 min" }
        return "\(minutes) min"
    }
}
