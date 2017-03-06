//
//  ViewController.swift
//  Workout Tracker
//
//  Created by Sarah Olson on 3/5/17.
//  Copyright © 2017 HPlus. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let healthKitManager = HealthKitManager.sharedInstance

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        healthKitManager.authorizeHealthKitAccess { (success, error) in
            print("HealthKit authorized? \(success)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

