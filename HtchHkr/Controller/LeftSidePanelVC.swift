//
//  LeftSidePanelVC.swift
//  HtchHkr
//
//  Created by nag on 08/09/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

import UIKit

class LeftSidePanelVC: UIViewController {
    
    @IBOutlet weak var userEmailLbl: UILabel!
    @IBOutlet weak var userAccountTypeLbl: UILabel!
    @IBOutlet weak var userImageView: RoundImageView!
    @IBOutlet weak var loginOutBtn: UIButton!
    @IBOutlet weak var pickupModeSwitch: UISwitch!
    @IBOutlet weak var pickupModeLbl: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        
    }

    
    
    @IBAction func switchWasToggled(_ sender: Any) {

    }
    
    @IBAction func signUpLoginBtnWasPressed(_ sender: Any) {
        
        let loginVC = UIStoryboard.loginVC()
        present(loginVC!, animated: true, completion: nil)
        

    }

}
