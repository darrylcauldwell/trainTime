//
//  CarPlaySceneDelegate.swift
//  LiveRail
//
//  CPTemplateApplicationSceneDelegate — shows live departures for the route
//  selected in the main app's Departures view.
//

import CarPlay

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var departuresTemplate: CPListTemplate?
    private var refreshTimer: Timer?
    private var apiService = HuxleyAPIService()

    private var currentOriginCRS: String? {
        UserDefaults.standard.string(forKey: "carplay.originCRS")
    }
    private var currentDestinationCRS: String? {
        UserDefaults.standard.string(forKey: "carplay.destinationCRS")
    }
    private var currentOriginName: String? {
        UserDefaults.standard.string(forKey: "carplay.originName")
    }
    private var currentDestinationName: String? {
        UserDefaults.standard.string(forKey: "carplay.destinationName")
    }

    // MARK: - Scene Lifecycle

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let template = buildDeparturesTemplate()
        self.departuresTemplate = template
        interfaceController.setRootTemplate(template, animated: true, completion: nil)

        startAutoRefresh()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChanged),
            name: .routeChanged,
            object: nil
        )

        if currentOriginCRS != nil {
            Task { await refreshDepartures() }
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        stopAutoRefresh()
        NotificationCenter.default.removeObserver(self)
        self.interfaceController = nil
        self.departuresTemplate = nil
    }

    // MARK: - Template

    private func buildDeparturesTemplate() -> CPListTemplate {
        let header: String
        let items: [CPListItem]

        if let origin = currentOriginCRS, let dest = currentDestinationCRS {
            header = "\(currentOriginName ?? origin) → \(currentDestinationName ?? dest)"
            items = [CPListItem(text: "Loading…", detailText: nil)]
        } else {
            header = "Departures"
            items = [CPListItem(text: "Select a route in the LiveRail app", detailText: nil)]
        }

        let template = CPListTemplate(
            title: "LiveRail",
            sections: [CPListSection(items: items, header: header, sectionIndexTitle: nil)]
        )
        return template
    }

    // MARK: - Data Fetching

    private func refreshDepartures() async {
        guard let origin = currentOriginCRS, let dest = currentDestinationCRS,
              let template = departuresTemplate else { return }

        do {
            let board = try await apiService.fetchDepartures(from: origin, to: dest, rows: 10)
            let services = board.services.prefix(10)

            let items: [CPListItem]
            if services.isEmpty {
                items = [CPListItem(text: "No services found", detailText: nil)]
            } else {
                items = services.map { CarPlayDepartureItem.listItem(from: $0) }
            }

            let header = "\(currentOriginName ?? origin) → \(currentDestinationName ?? dest)"
            let section = CPListSection(items: items, header: header, sectionIndexTitle: nil)

            await MainActor.run {
                template.updateSections([section])
            }
        } catch {
            // Keep existing display on error
        }
    }

    // MARK: - Route Change

    @objc private func handleRouteChanged() {
        // Rebuild template header and refresh
        guard let template = departuresTemplate else { return }
        let header = "\(currentOriginName ?? currentOriginCRS ?? "Departures") → \(currentDestinationName ?? currentDestinationCRS ?? "")"
        let section = CPListSection(
            items: [CPListItem(text: "Loading…", detailText: nil)],
            header: header,
            sectionIndexTitle: nil
        )
        template.updateSections([section])
        Task { await refreshDepartures() }
    }

    // MARK: - Auto-Refresh

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.refreshDepartures() }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
