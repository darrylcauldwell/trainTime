//
//  CacheService.swift
//  trainTime
//
//  SwiftData read/write for offline data caching
//

import Foundation
import SwiftData

@Observable
final class CacheService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Departure Cache

    func cacheDepartures(_ board: DepartureBoard, origin: String, destination: String) {
        let key = "\(origin.uppercased())_\(destination.uppercased())"
        do {
            let data = try JSONEncoder().encode(board)

            // Delete existing
            let descriptor = FetchDescriptor<CachedDeparture>(
                predicate: #Predicate { $0.cacheKey == key }
            )
            let existing = try modelContext.fetch(descriptor)
            for item in existing {
                modelContext.delete(item)
            }

            let cached = CachedDeparture(cacheKey: key, jsonData: data, originCRS: origin, destinationCRS: destination)
            modelContext.insert(cached)
            try modelContext.save()
        } catch {
            print("Cache write error: \(error)")
        }
    }

    func getCachedDepartures(origin: String, destination: String) -> (board: DepartureBoard, fetchedAt: Date)? {
        let key = "\(origin.uppercased())_\(destination.uppercased())"
        do {
            let descriptor = FetchDescriptor<CachedDeparture>(
                predicate: #Predicate { $0.cacheKey == key }
            )
            guard let cached = try modelContext.fetch(descriptor).first,
                  !cached.isExpired else { return nil }
            let board = try JSONDecoder().decode(DepartureBoard.self, from: cached.jsonData)
            return (board, cached.fetchedAt)
        } catch {
            return nil
        }
    }

    // MARK: - Service Detail Cache

    func cacheServiceDetail(_ detail: ServiceDetail, serviceID: String) {
        do {
            let data = try JSONEncoder().encode(detail)

            let descriptor = FetchDescriptor<CachedServiceDetail>(
                predicate: #Predicate { $0.serviceID == serviceID }
            )
            let existing = try modelContext.fetch(descriptor)
            for item in existing {
                modelContext.delete(item)
            }

            let cached = CachedServiceDetail(serviceID: serviceID, jsonData: data)
            modelContext.insert(cached)
            try modelContext.save()
        } catch {
            print("Cache write error: \(error)")
        }
    }

    func getCachedServiceDetail(serviceID: String) -> (detail: ServiceDetail, fetchedAt: Date)? {
        do {
            let descriptor = FetchDescriptor<CachedServiceDetail>(
                predicate: #Predicate { $0.serviceID == serviceID }
            )
            guard let cached = try modelContext.fetch(descriptor).first,
                  !cached.isExpired else { return nil }
            let detail = try JSONDecoder().decode(ServiceDetail.self, from: cached.jsonData)
            return (detail, cached.fetchedAt)
        } catch {
            return nil
        }
    }

    // MARK: - Cleanup

    func pruneExpiredCache() {
        do {
            let departures = try modelContext.fetch(FetchDescriptor<CachedDeparture>())
            for item in departures where item.isExpired {
                modelContext.delete(item)
            }

            let details = try modelContext.fetch(FetchDescriptor<CachedServiceDetail>())
            for item in details where item.isExpired {
                modelContext.delete(item)
            }

            try modelContext.save()
        } catch {
            print("Cache prune error: \(error)")
        }
    }

    func clearAllCache() {
        do {
            try modelContext.delete(model: CachedDeparture.self)
            try modelContext.delete(model: CachedServiceDetail.self)
            try modelContext.save()
        } catch {
            print("Cache clear error: \(error)")
        }
    }
}
