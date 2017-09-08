//
//  LoginVC.swift
//  HtchHkr
//
//  Created by nag on 08/09/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

import UIKit
import Firebase

class LoginVC: UIViewController {
    
    // MARK: - OUTLETS
    @IBOutlet weak var emailField: RoundedCornerTextField!
    @IBOutlet weak var passwordField: RoundedCornerTextField!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var authBtn: RoundedShadowButton!
    
    // MARK: - OUTLETS
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.bindtoKeyboard()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(sender:)))
        view.addGestureRecognizer(tap)
        
        emailField.delegate = self
        passwordField.delegate = self
    }
    
    // MARK: - OUTLETS
    @objc func handleScreenTap(sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    // MARK: - OUTLETS
    @IBAction func cancelBtnWasPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func authBtnWasPressed(_ sender: Any) {
        guard let email = emailField.text, let password = passwordField.text else { return }
        
        authBtn.animateButton(shouldLoad: true, withMessage: nil)
        self.view.endEditing(true)
        
        FIRAuth.auth()?.signIn(withEmail: email, password: password, completion: { (user, error) in
            
            if let error = error, let errorCode = FIRAuthErrorCode(rawValue: error._code) {
                
                
                switch errorCode {
                case .errorCodeInvalidEmail:
                    print("Email invalid")
                    return
                case .errorCodeEmailAlreadyInUse:
                    print("Email already in use")
                    return
                case .errorCodeWrongPassword:
                    print("Wrong password")
                    return
                default:
                    print("An unexpected error")
                }
                
                
                print(error.localizedDescription)
                
                
                
                // CREATE USER
                FIRAuth.auth()?.createUser(withEmail: email, password: password, completion: { (user, error) in
                    if let error = error, let errorCode = FIRAuthErrorCode(rawValue: error._code) {
                        switch errorCode {
                        case .errorCodeEmailAlreadyInUse:
                            print("Email already in use")
                            return
                        default:
                            print("An unexpected error")
                        }
                        
                    } else {
                        if let user = user {
                            var userData = ["provider": user.providerID] as [String: Any]
                            var isDriver: Bool
                            
                            if self.segmentedControl.selectedSegmentIndex == 0 {
                                isDriver = false
                            } else {
                                isDriver = true
                                
                                userData.updateValue(true, forKey: "userIsDriver")
                                userData.updateValue(false, forKey: "isPickupModeEnabled")
                                userData["driverIsOnTrip"] = false
                            }
                            
                            DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: isDriver)
                        }
                        print("Sign in success")
                        self.dismiss(animated: true, completion: nil)
                    }
                })
                
                
            } else {
                // SIGN IN USER
                if let user = user {
                    var userData = ["provider": user.providerID] as [String: Any]
                    var isDriver: Bool
                    
                    if self.segmentedControl.selectedSegmentIndex == 0 {
                        isDriver = false
                    } else {
                        isDriver = true
                        
                        userData.updateValue(true, forKey: "userIsDriver")
                        userData.updateValue(false, forKey: "isPickupModeEnabled")
                        userData["driverIsOnTrip"] = false
                    }
                    
                    DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: isDriver)
                }
                
                print("Sign in success")
                self.dismiss(animated: true, completion: nil)
            }
            
            
        })
        
        
    }
    
}


// MARK: - UITextFieldDelegate
extension LoginVC: UITextFieldDelegate {
    
}




