//
//  InterfaceController.swift
//  Workout Tracker WatchKit Extension
//
//  Created by Sarah Olson on 3/5/17.
//  Copyright © 2017 HPlus. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit

class InterfaceController: WKInterfaceController {

    @IBOutlet var heartRateLabel: WKInterfaceLabel!
    @IBOutlet var workoutButton: WKInterfaceButton!
    
    let healthKitManager = HealthKitManager.sharedInstance
    
    var workoutSession: HKWorkoutSession?
    
    var isWorkoutInProgress = false
    
    var workoutStartDate: Date?
    
    var heartRateQuery: HKQuery?
    
    var heartRateSamples: [HKQuantitySample] = [HKQuantitySample]()
    var distanceSamples: [HKSample] = [HKSample]()
    var energySamples: [HKSample] = [HKSample]()
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        self.workoutButton.setEnabled(false)
        
        healthKitManager.authorizeHealthKitAccess { [weak self] (success, error) in
            print("HealthKit authorized? \(success)")
            self?.createWorkoutSession()

            self?.workoutButton.setEnabled(true)
        }
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    @IBAction func startOrStopWorkout() {
        
        if isWorkoutInProgress {
            print("End workout")
            endWorkoutSession()
        } else {
            print("Start workout")
            startWorkoutSession()
        }
        isWorkoutInProgress = !isWorkoutInProgress
        self.workoutButton.setTitle(isWorkoutInProgress ? "End Workout" : "Start Workout")
    }
    
    // MARK: - Workout Sessions
    
    func createWorkoutSession() {
        
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .other
        workoutConfiguration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(configuration: workoutConfiguration)
            workoutSession?.delegate = self
        } catch {
            print("Could not create a session")
        }
    }
    
    func startWorkoutSession() {
        
        if self.workoutSession != nil {
            createWorkoutSession()
        }
        guard let session = workoutSession else {
            print("Cannot start a workout without a session.")
            return
        }
        healthKitManager.healthStore.start(session)
        workoutStartDate = Date()
    }
    
    func endWorkoutSession() {
        guard let session = workoutSession else {
            print("Cannot end a workout without a session.")
            return
        }
        healthKitManager.healthStore.end(session)
        saveWorkout()
    }
    
    func saveWorkout() {
        
        guard let startDate = workoutStartDate else {
            print("Workout had no start date")
            return
        }
        let workout = HKWorkout(activityType: .other,
                                start: startDate,
                                end: Date())
        healthKitManager.healthStore.save(workout) { [weak self] (success, error) in
            if !success {
                print("Could not successfully save workout.")
                return
            }
            
            print("Number of heart rate samples: \(self?.heartRateSamples.count)")
            print("Number of distance samples: \(self?.distanceSamples.count)")
            print("Number of energy samples: \(self?.energySamples.count)")
            
            let allSamples: [HKSample] = [self?.heartRateSamples, self?.energySamples, self?.distanceSamples].reduce([], { (result: [HKSample], element: [HKSample]?) -> [HKSample] in
                return result + element!
            })
            
            print("All Samples: \(allSamples)")
            print("Total samples: \(allSamples.count)")
            
            self?.healthKitManager.healthStore.add(allSamples, to: workout, completion: { (success, error) in
                if success {
                    print("Successfully saved samples.")
                }
            })
        }
    }
}

extension InterfaceController: HKWorkoutSessionDelegate {
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        switch toState {
        case .running:
            print("Workout started.")
            if let query = healthKitManager.createHeartRateStreamingQuery(date) {
                self.heartRateQuery = query
                self.healthKitManager.heartRateDelegate = self
                healthKitManager.healthStore.execute(query)
            }
            
            if let distanceQuery = healthKitManager.createDistanceQuery(date) {
                self.healthKitManager.distanceDelegate = self
                healthKitManager.healthStore.execute(distanceQuery)
            }
            
            if let energyQuery = healthKitManager.createEnergyBurnedQuery(date) {
                self.healthKitManager.energyDelegate = self
                healthKitManager.healthStore.execute(energyQuery)
            }
        case .ended:
            print("Workout ended.")
            if let query = self.heartRateQuery {
                healthKitManager.healthStore.stop(query)
            }
        default:
            print("Other workout state.")
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didFailWithError error: Error) {
        print("Workout failed with error: \(error)")
        
    }
}

extension InterfaceController: HeartRateDelegate {
    
    func heartRateUpdated(heartRateSamples: [HKSample]) {
        
        guard let heartRateSamples = heartRateSamples as? [HKQuantitySample] else {
            return
        }
        DispatchQueue.main.async {
            self.heartRateSamples = heartRateSamples
            guard let sample = heartRateSamples.first else {
                return
            }
            let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            let heartRateString = String(format: "%.00f", value)
            self.heartRateLabel.setText(heartRateString)
        }
    }
}

extension InterfaceController: EnergyDelegate {
    
    func energyUpdated(energy: [HKSample]) {
        
        DispatchQueue.main.async {
            self.energySamples.append(contentsOf: energy)
        }
    }
}

extension InterfaceController: DistanceDelegate {
    
    func distanceUpdated(distance: [HKSample]) {
        
        DispatchQueue.main.async {
            self.distanceSamples.append(contentsOf: distance)
        }
    }
}
