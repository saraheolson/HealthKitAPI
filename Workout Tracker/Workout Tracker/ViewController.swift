//
//  ViewController.swift
//  Workout Tracker
//
//  Created by Sarah Olson on 3/5/17.
//  Copyright © 2017 HPlus. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
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
        let heartRateFormattedString = String(format: "%.00f", heartRate)
        cell.textLabel?.text = "\(heartRateFormattedString)"
        return cell
    }
}

extension ViewController: HeartRateDelegate {
    
    func heartRateUpdated(heartRateSamples: [HKSample]) {
        
        guard let heartRateSamples = heartRateSamples as? [HKQuantitySample] else {
            return
        }
        
        DispatchQueue.main.async {
            //self.datasource.append(contentsOf: heartRateSamples)
            for sample in heartRateSamples {
                self.datasource.append(sample)
            }
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
