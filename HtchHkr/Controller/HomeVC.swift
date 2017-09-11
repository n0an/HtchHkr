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

        })

        
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
    
    @IBAction func centerMapBtnWasPressed(_ sender: Any) {
        
        DataService.instance.REF_USERS.observeSingleEvent(of: .value) { (snapshot) in
            
            if let userSnapshot = snapshot.children.allObjects as? [FIRDataSnapshot] {
                for user in userSnapshot {
                    if user.key == DataService.instance.currentUser?.uid {
                        if user.hasChild("tripCoordinate") {
                            self.zoom(toFitAnnotationsFromMapView: self.mapView)
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
        let lineRenderer = MKPolylineRenderer(overlay: self.route.polyline)
        
        lineRenderer.strokeColor = UIColor(red: 216/255, green: 71/255, blue: 30/255, alpha: 0.75)
        lineRenderer.lineWidth = 3
        
        zoom(toFitAnnotationsFromMapView: self.mapView)
        
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
    
    func searchMapKitForResultsWithPolyline(forMapItem mapItem: MKMapItem) {
        
        let request = MKDirectionsRequest()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapItem
        
        request.transportType = MKDirectionsTransportType.automobile
        
        let directions = MKDirections(request: request)
        
        directions.calculate { (response, error) in
            
            guard let response = response else {
                print(error!.localizedDescription)
                return
            }
            
            self.route = response.routes.first
            
            self.mapView.add(self.route.polyline)
            
            self.shouldPresentLoadingView(false)
            
        }
    }
    
    func zoom(toFitAnnotationsFromMapView mapView: MKMapView) {
        guard !mapView.annotations.isEmpty else {
            return
        }
        
        var topLeftCoordinate = CLLocationCoordinate2D(latitude: -90, longitude: 100)
        var bottomRightCoordinate = CLLocationCoordinate2D(latitude: 90, longitude: -100)
        
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
        
        searchMapKitForResultsWithPolyline(forMapItem: selectedMapItem)
        
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







