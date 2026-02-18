//
//  CarPlaySceneDelegate.swift
//  LiveRail
//
//  CPTemplateApplicationSceneDelegate for CarPlay departures display
//

import CarPlay
import SwiftData

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var refreshTimer: Timer?
    private var apiService = HuxleyAPIService()
    private var currentOriginCRS: String?
    private var currentDestinationCRS: String?

    // MARK: - Scene Lifecycle

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        // Load most recent saved journey from widget app group
        if let journey = WidgetJourney.load() {
            currentOriginCRS = journey.originCRS
            currentDestinationCRS = journey.destinationCRS
        }

        let departuresTemplate = buildDeparturesTemplate()
        let savedTemplate = buildSavedTemplate()

        let tabBar = CPTabBarTemplate(templates: [departuresTemplate, savedTemplate])
        interfaceController.setRootTemplate(tabBar, animated: true, completion: nil)

        startAutoRefresh()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        stopAutoRefresh()
        self.interfaceController = nil
    }

    // MARK: - Templates

    private func buildDeparturesTemplate() -> CPListTemplate {
        let section: CPListSection
        if let origin = currentOriginCRS, let dest = currentDestinationCRS {
            section = CPListSection(
                items: [CPListItem(text: "Loading...", detailText: nil)],
                header: "\(origin) → \(dest)",
                sectionIndexTitle: nil
            )
        } else {
            section = CPListSection(
                items: [CPListItem(text: "No journey selected", detailText: "Save a journey in the app")],
                header: "Departures",
                sectionIndexTitle: nil
            )
        }

        let template = CPListTemplate(title: "Departures", sections: [section])
        template.tabImage = UIImage(systemName: "tram.fill")

        if currentOriginCRS != nil {
            Task { await refreshDepartures(template: template) }
        }

        return template
    }

    private func buildSavedTemplate() -> CPListTemplate {
        var items: [CPListItem] = []

        // Load saved journeys from widget app group
        if let journey = WidgetJourney.load() {
            let item = CPListItem(
                text: "\(journey.originCRS) → \(journey.destinationCRS)",
                detailText: "\(journey.originName) to \(journey.destinationName)"
            )
            item.handler = { [weak self] _, completion in
                self?.currentOriginCRS = journey.originCRS
                self?.currentDestinationCRS = journey.destinationCRS
                self?.refreshCurrentRoute()
                completion()
            }
            items.append(item)
        }

        if items.isEmpty {
            items.append(CPListItem(text: "No saved journeys", detailText: "Save a journey in the app"))
        }

        let template = CPListTemplate(
            title: "Saved",
            sections: [CPListSection(items: items)]
        )
        template.tabImage = UIImage(systemName: "star.fill")
        return template
    }

    // MARK: - Data Fetching

    private func refreshDepartures(template: CPListTemplate) async {
        guard let origin = currentOriginCRS, let dest = currentDestinationCRS else { return }

        do {
            let board = try await apiService.fetchDepartures(from: origin, to: dest, rows: 5)
            let items = board.services.prefix(5).map { service in
                CarPlayDepartureItem.listItem(from: service)
            }

            let section = CPListSection(
                items: items.isEmpty ? [CPListItem(text: "No services", detailText: nil)] : items,
                header: "\(origin) → \(dest)",
                sectionIndexTitle: nil
            )

            await MainActor.run {
                template.updateSections([section])
            }
        } catch {
            // Keep existing display on error
        }
    }

    private func refreshCurrentRoute() {
        guard let controller = interfaceController,
              let tabBar = controller.rootTemplate as? CPTabBarTemplate,
              let departuresTemplate = tabBar.templates.first as? CPListTemplate else { return }

        Task { await refreshDepartures(template: departuresTemplate) }
    }

    // MARK: - Auto-Refresh

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshCurrentRoute()
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
