//
//  HomeVC.swift
//  HtchHkr
//
//  Created by nag on 08/09/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

import UIKit
import MapKit
import RevealingSplashView
import CoreLocation
import Firebase

class HomeVC: UIViewController, Alertable {
    
    // MARK: - OUTLETS
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionBtn: RoundedShadowButton!
    @IBOutlet weak var centerMapBtn: UIButton!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var destinationCircle: CircleView!
    @IBOutlet weak var cancelBtn: UIButton!
    
    var delegate: CenterVCDelegate?
    
    var locationManager = CLLocationManager()
    
    var regionRadius: CLLocationDistance = 1000
    
    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize.init(width: 80, height: 80), backgroundColor: UIColor.white)
    
    let tableView = UITableView()
    
    var matchingItems = [MKMapItem]()
    
    var selectedItemPlacemark: MKPlacemark?
    
    var route: MKRoute!
    
    //MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        destinationTextField.delegate = self
        
        locationManager.delegate = self

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        checkLocationAuthStatus()
        
        self.mapView.delegate = self
        centerMapOnUserLocation()
        
        DataService.instance.REF_DRIVERS.observe(.value, with: { (snapshot) in
            self.loadDriverAnnotationsFromFB()
            
            DataService.instance.passengerIsOnTrip(passengerKey: (DataService.instance.currentUser?.uid)!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                }
            })
        })

        cancelBtn.alpha = 0.0
        
        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = .heartBeat
        revealingSplashView.startAnimation()
        
        revealingSplashView.heartAttack = true
        
        UpdateService.instance.observeTrips { tripDict in
            
            if let tripDict = tripDict {
                let pickupCoordinateArray = tripDict["pickupCoordinate"] as! NSArray
                let tripKey = tripDict["passengerKey"] as! String
                let acceptanceStatus = tripDict["tripIsAccepted"] as! Bool
                
                if acceptanceStatus == false {
                    
                    DataService.instance.driverIsAvailable(key: (DataService.instance.currentUser?.uid)!, handler: { (available) in
                        
                        guard let available = available else { return }
                        
                        if available {
                            
                            let pickupVC = UIStoryboard.pickupVC()
                            
                            pickupVC?.initData(coordinate: CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees), passengerKey: tripKey)
                            
                            
                            self.present(pickupVC!, animated: true, completion: nil)

                        }
                    })
                    
                }
            }
            
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        connectUserAndDriverForTrip()
        
        DataService.instance.REF_TRIPS.observe(.childRemoved, with: { (removedTripSnapshot) in
            let removedTripDict = removedTripSnapshot.value as? [String: AnyObject]
            if removedTripDict?[DRIVER_KEY] != nil {
                DataService.instance.REF_DRIVERS.child(removedTripDict?[DRIVER_KEY] as! String).updateChildValues([DRIVER_IS_ON_TRIP: false])
            }
            
            DataService.instance.userIsDriver(userKey: (DataService.instance.currentUser?.uid)!, handler: { (isDriver) in
                if isDriver == true {
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                } else {
                    self.cancelBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    self.actionBtn.animateButton(shouldLoad: false, withMessage: MSG_REQUEST_RIDE)
                    
                    self.destinationTextField.isUserInteractionEnabled = true
                    self.destinationTextField.text = ""
                    
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                    self.centerMapOnUserLocation()
                }
            })
        })
        
        
        DataService.instance.driverIsAvailable(key: (DataService.instance.currentUser?.uid)!) { isDriverAvailable in
            
            guard let isDriverAvailable = isDriverAvailable else { return }
            
            if isDriverAvailable == false {
                DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripSnapshot) in
                    
                    if let tripSnapshot = tripSnapshot.children.allObjects as? [FIRDataSnapshot] {
                        
                        for trip in tripSnapshot {
                            
                            if trip.childSnapshot(forPath: "driverKey").value as? String == (DataService.instance.currentUser?.uid)! {
                                
                                let pickupCoordinateArray = trip.childSnapshot(forPath: "pickupCoordinate").value as! NSArray
                                
                                let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                                
                                let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                                
                                self.dropPinFor(placemark: pickupPlacemark)
                                
                                self.searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: MKMapItem(placemark: pickupPlacemark))
                                
                            }
                            
                        }
                    }
                    
                    
                    
                })
            }
            
        }
        
    }
   
    
    func checkLocationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func loadDriverAnnotationsFromFB() {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let driverSnapshot = snapshot.children.allObjects as? [FIRDataSnapshot] {
                for driver in driverSnapshot {
                    if driver.hasChild(COORDINATE) {
                        if driver.childSnapshot(forPath: ACCOUNT_PICKUP_MODE_ENABLED).value as? Bool == true {
                            if let driverDict = driver.value as? Dictionary<String, AnyObject> {
                                let coordinateArray = driverDict[COORDINATE] as! NSArray
                                let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateArray[0] as! CLLocationDegrees, longitude: coordinateArray[1] as! CLLocationDegrees)
                                
                                let annotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driver.key)
                                
                                var driverIsVisible: Bool {
                                    return self.mapView.annotations.contains(where: { (annotation) -> Bool in
                                        if let driverAnnotation = annotation as? DriverAnnotation {
                                            if driverAnnotation.key == driver.key {
                                                driverAnnotation.update(annotationPosition: driverAnnotation, withCoordinate: driverCoordinate)
                                                return true
                                            }
                                        }
                                        return false
                                    })
                                }
                                
                                if !driverIsVisible {
                                    self.mapView.addAnnotation(annotation)
                                }
                            }
                        } else {
                            for annotation in self.mapView.annotations {
                                if annotation.isKind(of: DriverAnnotation.self) {
                                    if let annotation = annotation as? DriverAnnotation {
                                        if annotation.key == driver.key {
                                            self.mapView.removeAnnotation(annotation)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        })
        revealingSplashView.heartAttack = true
    }
    
    func connectUserAndDriverForTrip() {
        DataService.instance.passengerIsOnTrip(passengerKey: (DataService.instance.currentUser?.uid)!, handler: { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                
                DataService.instance.REF_TRIPS.child(tripKey!).observeSingleEvent(of: .value, with: { (tripSnapshot) in
                    let tripDict = tripSnapshot.value as? [String: Any]
                    let driverId = tripDict?[DRIVER_KEY] as! String
                    
                    let pickupCoordinateArray = tripDict?[USER_PICKUP_COORDINATE] as! NSArray
                    let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                    let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                    let pickupMapItem = MKMapItem(placemark: pickupPlacemark)
                    
                    DataService.instance.REF_DRIVERS.child(driverId).child(COORDINATE).observeSingleEvent(of: .value, with: { (coordinateSnapshot) in
                        let coordinateSnapshot = coordinateSnapshot.value as! NSArray
                        let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateSnapshot[0] as! CLLocationDegrees, longitude: coordinateSnapshot[1] as! CLLocationDegrees)
                        let driverPlacemark = MKPlacemark(coordinate: driverCoordinate)
                        let driverMapItem = MKMapItem(placemark: driverPlacemark)
                        
                        let passengerAnnotation = PassengerAnnotation(coordinate: pickupCoordinate, withKey: (DataService.instance.currentUser?.uid)!)
                        self.mapView.addAnnotation(passengerAnnotation)
                        
                        self.searchMapKitForResultsWithPolyline(forOriginMapItem: driverMapItem, withDestinationMapItem: pickupMapItem)
                        self.actionBtn.animateButton(shouldLoad: false, withMessage: MSG_DRIVER_COMING)
                        self.actionBtn.isUserInteractionEnabled = false
                    })
                    
                    DataService.instance.REF_TRIPS.child(tripKey!).observeSingleEvent(of: .value, with: { (tripSnapshot) in
                        if tripDict?[TRIP_IN_PROGRESS] as? Bool == true {
                            self.removeOverlaysAndAnnotations(forDrivers: true, forPassengers: true)
                            
                            let destinationCoordinateArray = tripDict?[USER_DESTINATION_COORDINATE] as! NSArray
                            let destinationCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees, longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                            let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
                            
                            self.dropPinFor(placemark: destinationPlacemark)
                            self.searchMapKitForResultsWithPolyline(forOriginMapItem: pickupMapItem, withDestinationMapItem: MKMapItem(placemark: destinationPlacemark))
                            
                            self.actionBtn.setTitle(MSG_ON_TRIP, for: .normal)
                        }
                    })
                    
                })
            }
        })
    }
    
    func centerMapOnUserLocation() {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(mapView.userLocation.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        
        mapView.setRegion(coordinateRegion, animated: true)
    }

    // MARK: - ACTIONS
    @IBAction func actionBtnWasPressed(_ sender: Any) {
        
        UpdateService.instance.updateTripsWithCoordinatesUpnRequest()
        
        actionBtn.animateButton(shouldLoad: true, withMessage: nil)
        
        self.view.endEditing(true)
        
        destinationTextField.isUserInteractionEnabled = false
    }
    
    @IBAction func menuBtnWasPressed(_ sender: Any) {
        delegate?.toggleLeftPanel()
    }
    
    @IBAction func cancelBtnWasPressed(_ sender: Any) {
        
        DataService.instance.driverIsOnTrip(driverKey: (DataService.instance.currentUser?.uid)!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassengerKey: tripKey!, forDriverKey: driverKey!)
            }
        }
        
        DataService.instance.passengerIsOnTrip(passengerKey: (DataService.instance.currentUser?.uid)!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassengerKey: (DataService.instance.currentUser?.uid)!, forDriverKey: driverKey!)
            } else {
                // TODO: - delete this line
                UpdateService.instance.cancelTrip(withPassengerKey: (DataService.instance.currentUser?.uid)!, forDriverKey: nil)
                
                
                self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                self.centerMapOnUserLocation()
            }
        }
        
        self.actionBtn.isUserInteractionEnabled = true
    }
    
    @IBAction func centerMapBtnWasPressed(_ sender: Any) {
        
        DataService.instance.REF_USERS.observeSingleEvent(of: .value) { (snapshot) in
            
            if let userSnapshot = snapshot.children.allObjects as? [FIRDataSnapshot] {
                for user in userSnapshot {
                    if user.key == DataService.instance.currentUser?.uid {
                        if user.hasChild("tripCoordinate") {
                            self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)

                            
                            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        } else {
                            self.centerMapOnUserLocation()
                            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        }
                    }
                }
            }
            
        }
        
        
    }

}


extension HomeVC: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if status == .authorizedAlways {
            checkLocationAuthStatus()
            
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
        }
        
    }
    
}

// MARK: - MKMapViewDelegate
extension HomeVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
        UpdateService.instance.updateUserLocation(withCoordinate: userLocation.coordinate)
        UpdateService.instance.updateDriverLocation(withCoordinate: userLocation.coordinate)
        
        if DataService.instance.currentUser != nil {
            DataService.instance.userIsDriver(userKey: (DataService.instance.currentUser?.uid)!) { (isDriver) in
                if isDriver == true {
                    DataService.instance.driverIsOnTrip(driverKey: (DataService.instance.currentUser?.uid)!, handler: { (isOnTrip, driverKey, tripKey) in
                        if isOnTrip == true {
                            self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                        } else {
                            self.centerMapOnUserLocation()
                        }
                    })
                } else {
                    DataService.instance.passengerIsOnTrip(passengerKey: (DataService.instance.currentUser?.uid)!, handler: { (isOnTrip, driverKey, tripKey) in
                        if isOnTrip == true {
                            self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                        } else {
                            self.centerMapOnUserLocation()
                        }
                    })
                }
            }
        }
        
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let identifier = "driver"
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: ANNO_DRIVER)
            return view
        } else if let annotation = annotation as? PassengerAnnotation {
            let identifier = "passenger"
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: ANNO_PICKUP)
            return view
        } else if let annotation = annotation as? MKPointAnnotation {
            let identifier = "destination"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.image = UIImage(named: ANNO_DESTINATION)
            return annotationView
        }
        
        return nil
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        centerMapBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let lineRenderer = MKPolylineRenderer(overlay: (self.route?.polyline)!)
        lineRenderer.strokeColor = UIColor(red: 216/255, green: 71/255, blue: 30/255, alpha: 0.75)
        lineRenderer.lineWidth = 3
        
        shouldPresentLoadingView(false)
        
        return lineRenderer
    }
    
    func performSearch() {
        matchingItems.removeAll()
        let request = MKLocalSearchRequest()
        
        request.naturalLanguageQuery = destinationTextField.text
        request.region = mapView.region
        
        let search = MKLocalSearch(request: request)
        
        search.start { (response, error) in
            
            guard error == nil else {
                print(error!.localizedDescription)
                self.showAlert(error!.localizedDescription)
                self.shouldPresentLoadingView(false)
                return
            }
            
            if response?.mapItems.count == 0 {
                self.showAlert("no results")
                
            } else {
                for mapItem in (response?.mapItems)! {
                    self.matchingItems.append(mapItem as MKMapItem)
                    self.tableView.reloadData()
                    
                }
            }
            self.shouldPresentLoadingView(false)
            
        }
    }
    
    func dropPinFor(placemark: MKPlacemark) {
        selectedItemPlacemark = placemark
        
        for annotation in mapView.annotations {
            if annotation.isKind(of: MKPointAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        mapView.addAnnotation(annotation)
    }
    
    func searchMapKitForResultsWithPolyline(forOriginMapItem originMapItem: MKMapItem?, withDestinationMapItem destinationMapItem: MKMapItem) {
        let request = MKDirectionsRequest()
        
        if originMapItem == nil {
            request.source = MKMapItem.forCurrentLocation()
        } else {
            request.source = originMapItem
        }
        
        request.destination = destinationMapItem
        request.transportType = MKDirectionsTransportType.automobile
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        
        directions.calculate { (response, error) in
            guard let response = response else {
                self.showAlert(error.debugDescription)
                return
            }
            self.route = response.routes[0]
            
            self.mapView.add(self.route!.polyline)
            
            self.zoom(toFitAnnotationsFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)
            
            let delegate = AppDelegate.getAppDelegate()
            delegate.window?.rootViewController?.shouldPresentLoadingView(false)
        }
    }
    
    func zoom(toFitAnnotationsFromMapView mapView: MKMapView, forActiveTripWithDriver: Bool, withKey key: String?) {
        if mapView.annotations.count == 0 {
            return
        }
        
        var topLeftCoordinate = CLLocationCoordinate2D(latitude: -90, longitude: 180)
        var bottomRightCoordinate = CLLocationCoordinate2D(latitude: 90, longitude: -180)
        
        
        if forActiveTripWithDriver {
            for annotation in mapView.annotations {
                if let annotation = annotation as? DriverAnnotation {
                    if annotation.key == key {
                        topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                        topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                        bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                        bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
                    }
                } else {
                    topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                    topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                    bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                    bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
                }
            }
        }
        
        
        for annotation in mapView.annotations where !annotation.isKind(of: DriverAnnotation.self) {
            topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
            topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
            bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
            bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
        }
        
        var region = MKCoordinateRegion(center: CLLocationCoordinate2DMake(topLeftCoordinate.latitude - (topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 0.5, topLeftCoordinate.longitude + (bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 0.5), span: MKCoordinateSpan(latitudeDelta: fabs(topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 2.0, longitudeDelta: fabs(bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 2.0))
        
        region = mapView.regionThatFits(region)
        mapView.setRegion(region, animated: true)
    }
    
    
    func removeOverlaysAndAnnotations(forDrivers: Bool?, forPassengers: Bool?) {
        
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            }
            
            if forPassengers! {
                if let annotation = annotation as? PassengerAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }
            
            if forDrivers! {
                if let annotation = annotation as? DriverAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }
        }
        
        for overlay in mapView.overlays {
            if overlay is MKPolyline {
                mapView.remove(overlay)
            }
        }
    }
    
}

// MARK: - UITextFieldDelegate
extension HomeVC: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        tableView.frame = CGRect(x: 20, y: view.frame.height, width: view.frame.width - 40, height: view.frame.height - 170)
        tableView.layer.cornerRadius = 5.0
        tableView.clipsToBounds = true
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LocationCell")
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.tag = 18
        tableView.rowHeight = 60
        
        view.addSubview(tableView)
        
        animateTableView(shouldShow: true)
        
        UIView.animate(withDuration: 0.2) {
            self.destinationCircle.backgroundColor = UIColor.red
            self.destinationCircle.borderColor = UIColor(red: 199/255.0, green: 0, blue: 0, alpha: 1.0)
        }
    }
    
    func animateTableView(shouldShow: Bool) {
        if shouldShow {
            UIView.animate(withDuration: 0.2, animations: {
                self.tableView.frame = CGRect(x: 20, y: 170, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            })
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.tableView.frame = CGRect(x: 20, y: self.view.frame.height, width: self.view.frame.width - 40, height: self.view.frame.height - 170)

            }, completion: { (finished) in
                if let tableView = self.view.viewWithTag(18) {
                    tableView.removeFromSuperview()
                }
            })
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == destinationTextField {
            performSearch()
            shouldPresentLoadingView(true)
            view.endEditing(true)
        }
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        if textField == destinationTextField && textField.text == "" {
            
            UIView.animate(withDuration: 0.2) {
                self.destinationCircle.backgroundColor = UIColor.lightGray
                self.destinationCircle.borderColor = UIColor.darkGray
            }
        }
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        matchingItems = []
        tableView.reloadData()
        
        DataService.instance.REF_USERS.child((DataService.instance.currentUser?.uid)!).child("tripCoordinate").removeValue()
        
        mapView.removeOverlays(mapView.overlays)
        
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            } else if annotation.isKind(of: PassengerAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        
        centerMapOnUserLocation()
        return true
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension HomeVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "locationCell")
        
        let mapItem = matchingItems[indexPath.row]
        
        cell.textLabel?.text = mapItem.name
        cell.detailTextLabel?.text = mapItem.placemark.title
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        shouldPresentLoadingView(true)
        
        let passengerCoordinate = locationManager.location?.coordinate
        
        let passengerAnnotation = PassengerAnnotation(coordinate: passengerCoordinate!, withKey: (DataService.instance.currentUser?.uid)!)
        
        mapView.addAnnotation(passengerAnnotation)
        
        destinationTextField.text = tableView.cellForRow(at: indexPath)?.textLabel?.text
        
        let selectedMapItem = matchingItems[indexPath.row]
        DataService.instance.REF_USERS.child((DataService.instance.currentUser?.uid)!).updateChildValues(["tripCoordinate": [selectedMapItem.placemark.coordinate.latitude, selectedMapItem.placemark.coordinate.longitude]])
        
        dropPinFor(placemark: selectedMapItem.placemark)
        
        searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: selectedMapItem)
        
        animateTableView(shouldShow: false)
        print("Selected")
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.view.endEditing(true)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if destinationTextField.text == "" {
            animateTableView(shouldShow: false)
        }
    }
    
}







