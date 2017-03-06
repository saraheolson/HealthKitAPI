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
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
                
        healthKitManager.authorizeHealthKitAccess { [weak self] (success, error) in
            print("HealthKit authorized? \(success)")
            self?.createWorkoutSession()
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
            guard let samples = self?.heartRateSamples else {
                print("No data to save")
                return
            }
            self?.healthKitManager.healthStore.add(samples, to: workout, completion: { (success, error) in
                print("Successfully saved heart rate samples.")
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
