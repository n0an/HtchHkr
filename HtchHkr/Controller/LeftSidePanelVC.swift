//
//  LeftSidePanelVC.swift
//  HtchHkr
//
//  Created by nag on 08/09/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

import UIKit
import Firebase

class LeftSidePanelVC: UIViewController {
    
    // MARK: - OUTLETS
    @IBOutlet weak var userEmailLbl: UILabel!
    @IBOutlet weak var userAccountTypeLbl: UILabel!
    @IBOutlet weak var userImageView: RoundImageView!
    @IBOutlet weak var loginOutBtn: UIButton!
    @IBOutlet weak var pickupModeSwitch: UISwitch!
    @IBOutlet weak var pickupModeLbl: UILabel!
    
    var currentUserUid: String?
    let appDelegate = AppDelegate.getAppDelegate()
    
    // MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        pickupModeSwitch.isOn = false
        pickupModeSwitch.isHidden = true
        pickupModeLbl.isHidden = true
        
        observePassengersAndDrivers()
        
        if FIRAuth.auth()?.currentUser == nil {
            userEmailLbl.text = ""
            userAccountTypeLbl.text = ""
            userImageView.isHidden = true
            loginOutBtn.setTitle("Sign Up / Login", for: .normal)
        } else {
            userEmailLbl.text = FIRAuth.auth()?.currentUser?.email
            userAccountTypeLbl.text = ""
            userImageView.isHidden = false
            loginOutBtn.setTitle("Logut", for: .normal)
        }
    }
    
    // MARK: - HELPER METHODS
    func observePassengersAndDrivers() {
        // Ovserve Passengers
        DataService.instance.REF_USERS.observeSingleEvent(of: .value) { (snapshot) in
            
            if let snapshotObjects = snapshot.children.allObjects as? [FIRDataSnapshot] {
                
                for snap in snapshotObjects {
                    if snap.key == FIRAuth.auth()?.currentUser?.uid {
                        self.userAccountTypeLbl.text = "Passenger"
                        
                        self.currentUserUid = FIRAuth.auth()?.currentUser?.uid
                    }
                }
            }
        }
        
        // Ovserve Drivers
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value) { (snapshot) in
            if let snapshotObjects = snapshot.children.allObjects as? [FIRDataSnapshot] {
                
                for snap in snapshotObjects {
                    if snap.key == FIRAuth.auth()?.currentUser?.uid {
                        self.userAccountTypeLbl.text = "Driver"
                        self.pickupModeSwitch.isHidden = false
                        
                        let switchStatus = snap.childSnapshot(forPath: "isPickupModeEnabled").value as! Bool
                        self.pickupModeSwitch.isOn = switchStatus
                        self.pickupModeLbl.isHidden = false
                        
                        self.currentUserUid = FIRAuth.auth()?.currentUser?.uid
                        
                    }
                }
            }
        }
        
        
        
    }
    
    // MARK: - ACTIONS
    @IBAction func switchWasToggled(_ sender: Any) {
        
        if pickupModeSwitch.isOn {
            pickupModeLbl.text = "PICKUP MODE ENABLED"
            DataService.instance.REF_DRIVERS.child(currentUserUid!).updateChildValues(["isPickupModeEnabled": true])
        } else {
            pickupModeLbl.text = "PICKUP MODE DISABLED"
            DataService.instance.REF_DRIVERS.child(currentUserUid!).updateChildValues(["isPickupModeEnabled": false])
        }
        appDelegate.menuContainerVC.toggleLeftPanel()

        
    }
    
    @IBAction func signUpLoginBtnWasPressed(_ sender: Any) {
        
        if FIRAuth.auth()?.currentUser == nil {
            
            let loginVC = UIStoryboard.loginVC()
            present(loginVC!, animated: true, completion: nil)
        } else {
            
            do {
                try FIRAuth.auth()?.signOut()
                
                userEmailLbl.text = ""
                userAccountTypeLbl.text = ""
                userImageView.isHidden = true
                
                pickupModeLbl.text = ""
                pickupModeSwitch.isHidden = true
                
                loginOutBtn.setTitle("Sign Up / Login", for: .normal)
                
                currentUserUid = nil
                
            } catch {
                print(error.localizedDescription)
            }
            
        }
        
    }
    
}







