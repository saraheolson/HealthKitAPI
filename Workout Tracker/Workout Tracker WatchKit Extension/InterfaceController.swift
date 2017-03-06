//
//  InterfaceController.swift
//  Workout Tracker WatchKit Extension
//
//  Created by Sarah Olson on 3/5/17.
//  Copyright © 2017 HPlus. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {

    let healthKitManager = HealthKitManager.sharedInstance
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
                
        healthKitManager.authorizeHealthKitAccess { (success, error) in
            print("HealthKit authorized? \(success)")
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
}
