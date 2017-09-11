//
//  DataService.swift
//  HtchHkr
//
//  Created by nag on 08/09/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

import Foundation
import Firebase

let DB_BASE = FIRDatabase.database().reference()


class DataService {
    static let instance = DataService()
    
    let currentUser = FIRAuth.auth()?.currentUser
    
    private var _REF_BASE = DB_BASE
    private var _REF_USERS = DB_BASE.child("Users")
    private var _REF_DRIVERS = DB_BASE.child("Drivers")
    private var _REF_TRIPS = DB_BASE.child("Trips")
    
    var REF_BASE: FIRDatabaseReference {
        return _REF_BASE
    }
    
    var REF_USERS: FIRDatabaseReference {
        return _REF_USERS
    }
    
    var REF_DRIVERS: FIRDatabaseReference {
        return _REF_DRIVERS
    }
    
    var REF_TRIPS: FIRDatabaseReference {
        return _REF_TRIPS
    }
    
    func createFirebaseDBUser(uid: String, userData: [String: Any], isDriver: Bool) {
        if isDriver {
            REF_DRIVERS.child(uid).updateChildValues(userData)
        } else {
            REF_USERS.child(uid).updateChildValues(userData)
        }
    }
    
    func driverIsAvailable(key: String, handler: @escaping (_ status: Bool?)->()) {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value) { (snapshot) in
            
            if let driverSnapshot = snapshot.children.allObjects as? [FIRDataSnapshot] {
                
                for driver in driverSnapshot {
                    if driver.key == key {
                        if driver.childSnapshot(forPath: ACCOUNT_PICKUP_MODE_ENABLED).value as? Bool == true {
                            if driver.childSnapshot(forPath: DRIVER_IS_ON_TRIP).value as? Bool == true {
                                handler(false)
                            } else {
                                handler(true)
                            }
                        }
                    }
                }
                
            }
            
        }
    }
    
    
    func driverIsOnTrip(driverKey: String, handler: @escaping (_ status: Bool?, _ driverKey: String?, _ tripKey: String?) -> Void) {
        
        DataService.instance.REF_DRIVERS.child(driverKey).child(DRIVER_IS_ON_TRIP).observe(.value) { (driverTripStatusSnapshot) in
            
            if let driverTripStatusSnapshot = driverTripStatusSnapshot.value as? Bool {
                if driverTripStatusSnapshot == true {
                    DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripSnapshot) in
                        
                        if let tripSnapshot = tripSnapshot.children.allObjects as? [FIRDataSnapshot] {
                            for trip in tripSnapshot {
                                
                                if trip.childSnapshot(forPath: DRIVER_KEY).value as? String == driverKey {
                                    handler(true, driverKey, trip.key)
                                } else {
                                    // TODO: - why return?
                                    return
                                }
                            }
                            
                        }
                        
                        
                    })
                } else {
                    handler(false, nil, nil)
                }
            }
            
        }
    }
    
    func passengerIsOnTrip(passengerKey: String, handler: @escaping (_ status: Bool?, _ driverKey: String?, _ tripKey: String?) -> Void) {
        
        DataService.instance.REF_TRIPS.observeSingleEvent(of: .value) { (tripSnapshot) in
            if let tripSnapshot = tripSnapshot.children.allObjects as? [FIRDataSnapshot] {
                for trip in tripSnapshot {
                    if trip.key == passengerKey {
                        if trip.childSnapshot(forPath: TRIP_IS_ACCEPTED).value as? Bool == true {
                            
                            let driverKey = trip.childSnapshot(forPath: DRIVER_KEY) as? String
                            
                            handler(true, driverKey, trip.key)
                        } else {
                            handler(false, nil, nil)
                        }
                    }
                }
            }
        }
        
        
    }
    
    func userIsDriver(userKey: String, handler: @escaping (_ status: Bool) -> Void) {
        
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value) { (driverSnapshot) in
            
            if let driverSnapshot = driverSnapshot.children.allObjects as? [FIRDataSnapshot] {
                
                for driver in driverSnapshot {
                    if driver.key == userKey {
                        handler(true)
                    } else {
                        //TODO: - imho wrong. we need to call this handler after for loop completes
                        handler(false)
                    }
                }
                
                
            }
            
            
        }
        
        
    }

}











