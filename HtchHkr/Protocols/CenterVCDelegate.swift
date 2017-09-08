//
//  CenterVCDelegate.swift
//  HtchHkr
//
//  Created by nag on 08/09/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

import UIKit

protocol CenterVCDelegate {
    func toggleLeftPanel()
    func addLeftPanelViewController()
    func animateLeftPanel(shouldExpand: Bool)
}
