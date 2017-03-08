//
//  ViewController.swift
//  Workout Tracker
//
//  Created by Sarah Olson on 3/5/17.
//  Copyright © 2017 HPlus. All rights reserved.
//

import UIKit
import HealthKit
import HealthKitUI

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activitySummaryView: HKActivityRingView!
    
    let healthKitManager = HealthKitManager.sharedInstance

    var datasource: [HKQuantitySample] = []
    
    var heartRateQuery: HKQuery?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        healthKitManager.authorizeHealthKitAccess { (success, error) in
            print("HealthKit authorized? \(success)")
            self.retrieveHeartRateData()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func viewSummary(_ sender: Any) {
        if let query = healthKitManager.createActivitySummaryQuery() {
            self.healthKitManager.activitySummaryDelegate = self
            healthKitManager.healthStore.execute(query)
        }
    }
}

extension ViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datasource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "heartRate", for: indexPath)
        let heartRate = datasource[indexPath.row].quantity
        cell.textLabel?.text = "\(heartRate)"
        return cell
    }
}

extension ViewController: HeartRateDelegate {
    
    func heartRateUpdated(heartRateSamples: [HKSample]) {
        
        guard let heartRateSamples = heartRateSamples as? [HKQuantitySample] else {
            return
        }
        
        DispatchQueue.main.async {
            self.datasource.append(contentsOf: heartRateSamples)
            self.tableView.reloadData()
        }
    }
    
    func retrieveHeartRateData() {
        if let query = healthKitManager.createHeartRateStreamingQuery(Date()) {
            self.heartRateQuery = query
            self.healthKitManager.heartRateDelegate = self
            self.healthKitManager.healthStore.execute(query)
        }
    }
}

extension ViewController: ActivitySummaryDelegate {
    
    func activitySummariesUpdated(activitySummaries: [HKActivitySummary]) {

        guard let summary = activitySummaries.first else {
            return
        }
        
        let energyUnit   = HKUnit.jouleUnit(with: .kilo)
        let standUnit    = HKUnit.count()
        let exerciseUnit = HKUnit.second()
        
        let energy   = summary.activeEnergyBurned.doubleValue(for: energyUnit)
        let stand    = summary.appleStandHours.doubleValue(for: standUnit)
        let exercise = summary.appleExerciseTime.doubleValue(for: exerciseUnit)

        let energyGoal   = summary.activeEnergyBurnedGoal.doubleValue(for: energyUnit)
        let standGoal    = summary.appleStandHoursGoal.doubleValue(for: standUnit)
        let exerciseGoal = summary.appleExerciseTimeGoal.doubleValue(for: exerciseUnit)
        
        let energyProgress   = energyGoal == 0 ? 0 : energy / energyGoal
        let standProgress    = standGoal == 0 ? 0 : stand / standGoal
        let exerciseProgress = exerciseGoal == 0 ? 0 : exercise / exerciseGoal

        print("Energy progress: \(energyProgress)")
        print("Stand progress: \(standProgress)")
        print("Exercise progress: \(exerciseProgress)")
        
        DispatchQueue.main.async {
            if let activityView = self.activitySummaryView {
                activityView.setActivitySummary(summary, animated: true)
            }
        }
    }
}
