//
//  ServiceDetail.swift
//  LiveRail
//
//  Full service detail response from Huxley2
//

import Foundation

struct ServiceDetail: Codable {
    let generatedAt: String?
    let serviceType: String?
    let locationName: String?
    let crs: String?
    let operatorName: String?  // 'operator' in JSON
    let operatorCode: String?
    let isCancelled: Bool?
    let cancelReason: String?
    let delayReason: String?
    let sta: String?
    let eta: String?
    let ata: String?
    let std: String?
    let etd: String?
    let atd: String?
    let platform: String?
    let previousCallingPoints: [CallingPointList]?
    let subsequentCallingPoints: [CallingPointList]?
    let length: Int?

    enum CodingKeys: String, CodingKey {
        case generatedAt, serviceType, locationName, crs
        case operatorName = "operator"
        case operatorCode, isCancelled, cancelReason, delayReason
        case sta, eta, ata, std, etd, atd, platform
        case previousCallingPoints, subsequentCallingPoints, length
    }

    /// All calling points in order (previous + current + subsequent)
    var allCallingPoints: [CallingPoint] {
        var points: [CallingPoint] = []

        // Previous calling points
        if let prev = previousCallingPoints?.first?.callingPoint {
            points.append(contentsOf: prev)
        }

        // Current station as a calling point
        let currentPoint = CallingPoint(
            locationName: locationName,
            crs: crs,
            st: std ?? sta,
            et: etd ?? eta,
            at: atd ?? ata,
            isCancelled: isCancelled,
            length: length,
            detachFront: nil
        )
        points.append(currentPoint)

        // Subsequent calling points
        if let sub = subsequentCallingPoints?.first?.callingPoint {
            points.append(contentsOf: sub)
        }

        return points
    }
}
