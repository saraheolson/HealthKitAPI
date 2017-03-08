//
//  HealthKitManager.swift
//  Workout Tracker
//
//  Created by Sarah Olson on 3/5/17.
//  Copyright © 2017 HPlus. All rights reserved.
//

import Foundation
import HealthKit

protocol HeartRateDelegate {
    func heartRateUpdated(heartRateSamples: [HKSample])
}

protocol ActivitySummaryDelegate {
    func activitySummariesUpdated(activitySummaries: [HKActivitySummary])
}

protocol DistanceDelegate {
    func distanceUpdated(distance: [HKSample])
}

protocol EnergyDelegate {
    func energyUpdated(energy: [HKSample])
}

let energyUnit = HKUnit.kilocalorie()

let distanceUnit: HKUnit = {
    let locale = Locale.current
    let isMetric: Bool = locale.usesMetricSystem
    
    if isMetric {
        return HKUnit.meter()
    } else {
        return HKUnit.mile()
    }
} ()

let energyType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!
let heartRateType:HKQuantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
let distanceType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning)!

class HealthKitManager : NSObject {
    
    static let sharedInstance = HealthKitManager()
    
    private override init() {}
    
    let healthStore = HKHealthStore()
    
    var heartRateDelegate: HeartRateDelegate?
    var activitySummaryDelegate: ActivitySummaryDelegate?
    var distanceDelegate: DistanceDelegate?
    var energyDelegate: EnergyDelegate?
    
    var anchor: HKQueryAnchor?
    var distanceAnchor: HKQueryAnchor?
    var energyAnchor: HKQueryAnchor?
    
    func authorizeHealthKitAccess(_ completion: @escaping ((_ success: Bool, _ error: Error?) -> Void)) {
        
        guard let heartRateType: HKQuantityType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("Could not get heart rate type")
            return
        }

        let typesToShare = Set([HKObjectType.workoutType(), heartRateType, energyType, distanceType])
        let typesToRead = Set([HKObjectType.workoutType(), heartRateType, energyType, distanceType, HKObjectType.activitySummaryType()])
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            print("Was healthkit authorization successful? \(success) Errors: \(error)")
            completion(success, error)
        }
    }
    
    func createHeartRateStreamingQuery(_ workoutStartDate: Date) -> HKQuery? {
        
        guard let heartRateType: HKQuantityType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("Could not get heart rate type")
            return nil
        }
        let datePredicate = HKQuery.predicateForSamples(withStart: workoutStartDate,
                                                    end: nil,
                                                    options: .strictEndDate)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate])
        
        let heartRateQuery = HKAnchoredObjectQuery(type: heartRateType,
                                                   predicate: compoundPredicate,
                                                   anchor: nil,
                                                   limit: Int(HKObjectQueryNoLimit))
        { (query, sampleObjects, deletedObjects, newAnchor, error) in
            guard let newAnchor = newAnchor,
                  let sampleObjects = sampleObjects else {
                    return
            }
            self.anchor = newAnchor
            self.heartRateDelegate?.heartRateUpdated(heartRateSamples: sampleObjects)
        }
        
        heartRateQuery.updateHandler = {(query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            guard let newAnchor = newAnchor,
                let sampleObjects = sampleObjects else {
                    return
            }
            self.anchor = newAnchor
            self.heartRateDelegate?.heartRateUpdated(heartRateSamples: sampleObjects)
        }
        return heartRateQuery
    }
    
    func createEnergyBurnedQuery(_ workoutStartDate: Date) -> HKQuery? {
        
        let datePredicate = HKQuery.predicateForSamples(withStart: workoutStartDate, end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: energyType,
                                          predicate: datePredicate,
                                          anchor: distanceAnchor,
                                          limit: Int(HKObjectQueryNoLimit)) {
                                            (query, samples, deleteObjects, newAnchor, error) in
                                            
                                            guard let samples = samples else {
                                                return
                                            }
                                            self.energyAnchor = newAnchor
                                            self.energyDelegate?.energyUpdated(energy: samples)
        }
        
        query.updateHandler = {(query, samples, deleteObjects, newAnchor, error) in
            
            guard let samples = samples else {
                return
            }
            self.energyAnchor = newAnchor
            self.energyDelegate?.energyUpdated(energy: samples)
        }
        return query
    }
    
    func createDistanceQuery(_ workoutStartDate: Date) -> HKQuery? {
        
        let datePredicate = HKQuery.predicateForSamples(withStart: workoutStartDate, end: nil, options: .strictStartDate)
    
        let query = HKAnchoredObjectQuery(type: distanceType,
                                          predicate: datePredicate,
                                          anchor: distanceAnchor,
                                          limit: Int(HKObjectQueryNoLimit)) {
                                            (query, samples, deleteObjects, newAnchor, error) in
                                            
                                            guard let samples = samples else {
                                                return
                                            }
                                            self.distanceAnchor = newAnchor
                                            self.distanceDelegate?.distanceUpdated(distance: samples)
        }
        
        query.updateHandler = {(query, samples, deleteObjects, newAnchor, error) in

            guard let samples = samples else {
                return
            }

            self.distanceAnchor = newAnchor
            self.distanceDelegate?.distanceUpdated(distance: samples)
        }
        return query
    }
    
    func createActivitySummaryQuery() -> HKQuery? {
        
        // Create the date components for the predicate
        let calendar = Calendar.current
        let endDate = Date()
        
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            return nil
        }
        
        let unitFlags = Set<Calendar.Component>([.day, .month, .year])
        
        var startDateComponents = calendar.dateComponents(unitFlags, from: startDate)
        startDateComponents.calendar = calendar
        
        var endDateComponents = calendar.dateComponents(unitFlags, from: endDate)
        endDateComponents.calendar = calendar
        
        // Create the predicate for the query
        let summariesWithinRange = HKQuery.predicate(forActivitySummariesBetweenStart: startDateComponents, end: endDateComponents)
        
        // Build the query
        let query = HKActivitySummaryQuery(predicate: summariesWithinRange) { (query, summaries, error) -> Void in

            print("Summaries: \(summaries)")

            guard let activitySummaries = summaries else {
                guard let queryError = error else {
                    print("Error: \(error)")
                    return
                }
                return
            }
            
            self.activitySummaryDelegate?.activitySummariesUpdated(activitySummaries: activitySummaries)
        }
        return query
    }
}
