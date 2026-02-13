//
//  NextDepartureWidget.swift
//  trainTimeWidget
//
//  Widget showing next departure for most recent saved journey
//

import WidgetKit
import SwiftUI

struct NextDepartureEntry: TimelineEntry {
    let date: Date
    let departureTime: String?
    let status: String?
    let platform: String?
    let originName: String?
    let destinationName: String?
    let originCRS: String?
    let destinationCRS: String?
    let isPlaceholder: Bool

    static var placeholder: NextDepartureEntry {
        NextDepartureEntry(
            date: Date(),
            departureTime: "14:30",
            status: "On time",
            platform: "3",
            originName: "London Paddington",
            destinationName: "Bristol Temple Meads",
            originCRS: "PAD",
            destinationCRS: "BRI",
            isPlaceholder: true
        )
    }

    static var empty: NextDepartureEntry {
        NextDepartureEntry(
            date: Date(),
            departureTime: nil,
            status: nil,
            platform: nil,
            originName: nil,
            destinationName: nil,
            originCRS: nil,
            destinationCRS: nil,
            isPlaceholder: false
        )
    }
}

struct NextDepartureProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextDepartureEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (NextDepartureEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextDepartureEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchEntry() async -> NextDepartureEntry {
        guard let journey = WidgetJourney.load() else {
            return .empty
        }

        let urlString = "https://huxley2.azurewebsites.net/departures/\(journey.originCRS)/to/\(journey.destinationCRS)/5"
        guard let url = URL(string: urlString) else { return .empty }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let board = try JSONDecoder().decode(DepartureBoard.self, from: data)
            if let first = board.services.first {
                return NextDepartureEntry(
                    date: Date(),
                    departureTime: first.departureTime,
                    status: first.status.displayText,
                    platform: first.platform,
                    originName: journey.originName,
                    destinationName: journey.destinationName,
                    originCRS: journey.originCRS,
                    destinationCRS: journey.destinationCRS,
                    isPlaceholder: false
                )
            }
        } catch {
            // Fall through to empty
        }

        return NextDepartureEntry(
            date: Date(),
            departureTime: nil,
            status: nil,
            platform: nil,
            originName: journey.originName,
            destinationName: journey.destinationName,
            originCRS: journey.originCRS,
            destinationCRS: journey.destinationCRS,
            isPlaceholder: false
        )
    }
}

struct NextDepartureWidget: Widget {
    let kind: String = "NextDepartureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextDepartureProvider()) { entry in
            NextDepartureWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Departure")
        .description("Shows the next departure for your saved journey.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
