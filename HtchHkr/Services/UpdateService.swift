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
    
    func observeTrips(handler: @escaping (_ coordinateDict: [String: Any]?) -> Void) {
        
        DataService.instance.REF_TRIPS.observe(.value) { (snapshot) in
            
            if let tripSnapshot = snapshot.children.allObjects as? [FIRDataSnapshot] {
                for trip in tripSnapshot {
                    if trip.hasChild("passengerKey") && trip.hasChild("tripIsAccepted") {
                        if let tripDict = trip.value as? [String: Any] {
                            handler(tripDict)
                        }
                    }
                }
            }
        }
        
    }
    
    func updateTripsWithCoordinatesUpnRequest() {
        DataService.instance.REF_USERS.observeSingleEvent(of: .value) { (snapshot) in
            if let userSnapshot = snapshot.children.allObjects as? [FIRDataSnapshot] {
                for user in userSnapshot {
                    if user.key == FIRAuth.auth()?.currentUser?.uid {
                        if !user.hasChild("userIsDriver") {
                            if let userDict = user.value as? [String: Any] {
                                
                                let pickupArray = userDict["coordinate"] as! NSArray
                                
                                let distinationArray = userDict["tripCoordinate"] as! NSArray
                                
                                let dict: [String: Any] = [
                                    "pickupCoordinate": [pickupArray[0], pickupArray[1]],
                                    "destinationCoordinate": [distinationArray[0], distinationArray[1]],
                                    "passengerKey": user.key,
                                    "tripIsAccepted": false
                                ]
                                
                                DataService.instance.REF_TRIPS.child(user.key).updateChildValues(dict)
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    func acceptTrip(withPassengerKey passengerKey: String, forDirverKey driverKey: String) {
        
        let dict: [String: Any] = [
            "driverKey": driverKey,
            "tripIsAccepted": true
        ]
        
        DataService.instance.REF_TRIPS.child(passengerKey).updateChildValues(dict)
        DataService.instance.REF_DRIVERS.child(driverKey).updateChildValues(["driverIsOnTrip": true])
        
        
    }
    
    func cancelTrip(withPassengerKey passengerKey: String, forDriverKey driverKey: String?) {
        DataService.instance.REF_TRIPS.child(passengerKey).removeValue()
        DataService.instance.REF_USERS.child(passengerKey).child(TRIP_COORDINATE).removeValue()
        if driverKey != nil {
            DataService.instance.REF_DRIVERS.child(driverKey!).updateChildValues([DRIVER_IS_ON_TRIP: false])
        }
    }
    
}
