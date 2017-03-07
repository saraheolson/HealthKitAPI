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

class HealthKitManager : NSObject {
    
    static let sharedInstance = HealthKitManager()
    
    private override init() {}
    
    let healthStore = HKHealthStore()
    
    var heartRateDelegate: HeartRateDelegate?
    
    var anchor: HKQueryAnchor?
    
    func authorizeHealthKitAccess(_ completion: @escaping ((_ success: Bool, _ error: Error?) -> Void)) {
        
        guard let heartRateType: HKQuantityType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("Could not get heart rate type")
            return
        }

        let typesToShare = Set([HKObjectType.workoutType(), heartRateType])
        let typesToRead = Set([HKObjectType.workoutType(), heartRateType])
        
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
}
