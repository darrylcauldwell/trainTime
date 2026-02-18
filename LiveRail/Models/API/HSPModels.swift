//
//  HSPModels.swift
//  LiveRail
//
//  Data models for Network Rail Historical Service Performance API
//

import Foundation

// MARK: - Service Detail Response

struct HSPServiceDetail: Codable {
    let serviceAttributesDetails: HSPServiceAttributes?
}

struct HSPServiceAttributes: Codable {
    let date_of_service: String?
    let toc_code: String?
    let rid: String?
    let locations: [HSPLocation]?
}

struct HSPLocation: Codable {
    let location: String?  // CRS code
    let gbtt_ptd: String?  // Scheduled departure time (HHMM)
    let gbtt_pta: String?  // Scheduled arrival time (HHMM)
    let actual_td: String?  // Actual departure time (HHMM)
    let actual_ta: String?  // Actual arrival time (HHMM)
    let late_canc_reason: String?  // Delay/cancellation reason code
}

// MARK: - Metrics Response

struct HSPMetricsResponse: Codable {
    let Services: [HSPMetricsService]?
}

struct HSPMetricsService: Codable {
    let serviceAttributesMetrics: HSPServiceAttributesMetrics?
    let Metrics: [HSPMetric]?
}

struct HSPServiceAttributesMetrics: Codable {
    let origin_location: String?
    let destination_location: String?
    let gbtt_ptd: String?  // Scheduled departure time (HHMM format)
    let gbtt_pta: String?  // Scheduled arrival time
    let toc_code: String?
    let matched_services: String?
    let rids: [String]?  // Array of RIDs
}

struct HSPMetric: Codable {
    let tolerance_value: String?
    let num_not_tolerance: String?
    let num_tolerance: String?
    let percent_tolerance: String?
    let global_tolerance: Bool?
}

// MARK: - Conversion to ServiceDetail

extension HSPServiceDetail {
    /// Convert HSP service detail to our ServiceDetail format
    func toServiceDetail(originCRS: String, destinationCRS: String) -> ServiceDetail {
        var previousPoints: [CallingPoint] = []
        var subsequentPoints: [CallingPoint] = []
        var foundOrigin = false

        guard let locations = serviceAttributesDetails?.locations else {
            return ServiceDetail(
                generatedAt: nil,
                serviceType: nil,
                locationName: nil,
                crs: originCRS,
                operatorName: nil,
                operatorCode: serviceAttributesDetails?.toc_code,
                isCancelled: false,
                cancelReason: nil,
                delayReason: nil,
                sta: nil, eta: nil, ata: nil,
                std: nil, etd: nil, atd: nil,
                platform: nil,
                previousCallingPoints: nil,
                subsequentCallingPoints: nil,
                length: nil
            )
        }

        // Process locations
        for location in locations {
            // Format times from HHMM to HH:mm
            let scheduledTime = formatTime(location.gbtt_ptd ?? location.gbtt_pta)
            let actualTime = formatTime(location.actual_td ?? location.actual_ta)

            let point = CallingPoint(
                locationName: location.location,  // CRS code as name for now
                crs: location.location,
                st: scheduledTime,
                et: actualTime,
                at: actualTime,
                isCancelled: !(location.late_canc_reason?.isEmpty ?? true),
                length: nil,
                detachFront: nil
            )

            if location.location == originCRS {
                foundOrigin = true
            }

            if foundOrigin {
                subsequentPoints.append(point)
            } else {
                previousPoints.append(point)
            }
        }

        // Get origin and destination times
        let originLocation = locations.first(where: { $0.location == originCRS })
        let destLocation = locations.first(where: { $0.location == destinationCRS })

        return ServiceDetail(
            generatedAt: serviceAttributesDetails?.date_of_service,
            serviceType: "train",
            locationName: originLocation?.location,
            crs: originCRS,
            operatorName: nil,
            operatorCode: serviceAttributesDetails?.toc_code,
            isCancelled: false,
            cancelReason: nil,
            delayReason: nil,
            sta: formatTime(destLocation?.gbtt_pta),
            eta: formatTime(destLocation?.actual_ta),
            ata: formatTime(destLocation?.actual_ta),
            std: formatTime(originLocation?.gbtt_ptd),
            etd: formatTime(originLocation?.actual_td),
            atd: formatTime(originLocation?.actual_td),
            platform: nil,
            previousCallingPoints: previousPoints.isEmpty ? nil : [CallingPointList(callingPoint: previousPoints)],
            subsequentCallingPoints: subsequentPoints.isEmpty ? nil : [CallingPointList(callingPoint: subsequentPoints)],
            length: nil
        )
    }

    /// Convert HHMM format to HH:mm
    private func formatTime(_ time: String?) -> String? {
        guard let time = time, !time.isEmpty, time.count == 4 else {
            return nil
        }
        let hours = time.prefix(2)
        let minutes = time.suffix(2)
        return "\(hours):\(minutes)"
    }
}
