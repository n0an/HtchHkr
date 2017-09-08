//
//  UpdateService.swift
//  HtchHkr
//
//  Created by Anton Novoselov on 08/09/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

import UIKit
import MapKit
import Firebase

class UpdateService {
    
    static let instance = UpdateService()
    
    func updateUserLocation(withCoordinate coordinate: CLLocationCoordinate2D) {
        DataService.instance.REF_USERS.observeSingleEvent(of: .value) { (snapshot) in
            if let userObjects = snapshot.children.allObjects as? [FIRDataSnapshot] {
                for user in userObjects {
                    if user.key == FIRAuth.auth()?.currentUser?.uid {
                        DataService.instance.REF_USERS.child(user.key).updateChildValues(["coordinate": [coordinate.latitude, coordinate.longitude]])
                    }
                }
            }
        }
    }
    
    func updateDriverLocation(withCoordinate coordinate: CLLocationCoordinate2D) {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value) { (snapshot) in
            if let driverObjects = snapshot.children.allObjects as? [FIRDataSnapshot] {
                for driver in driverObjects {
                    if driver.key == FIRAuth.auth()?.currentUser?.uid {
                        
                        if driver.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool == true {
                            DataService.instance.REF_DRIVERS.child(driver.key).updateChildValues(["coordinate": [coordinate.latitude, coordinate.longitude]])
                        }
                    
                    }
                }
            }
        }
    }
    
}
