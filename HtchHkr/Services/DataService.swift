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

}











