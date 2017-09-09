//
//  PassengerAnnotation.swift
//  HtchHkr
//
//  Created by Anton Novoselov on 09/09/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

import UIKit
import MapKit

class PassengerAnnotation: NSObject, MKAnnotation {
    
    dynamic let coordinate: CLLocationCoordinate2D
    var key: String
    
    init(coordinate: CLLocationCoordinate2D, withKey key: String) {
        self.coordinate = coordinate
        self.key = key
        super.init()
    }
    
    
    
}
