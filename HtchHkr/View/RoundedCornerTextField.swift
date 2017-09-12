//
//  RoundedCornerTextField.swift
//  HtchHkr
//
//  Created by nag on 08/09/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

import UIKit

// ***SOLUTION***
class RoundedCornerTextField: UITextField {

    var textRectOffset: CGFloat = 20
    
    override func awakeFromNib() {
        setupView()
        
        
    }
    
    func setupView() {
        self.layer.cornerRadius = self.frame.height / 2
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(x: 0 + textRectOffset, y: 0 + (textRectOffset / 2), width: self.frame.width - textRectOffset, height: self.frame.height + textRectOffset)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(x: 0 + textRectOffset, y: 0 + (textRectOffset / 2), width: self.frame.width - textRectOffset, height: self.frame.height + textRectOffset)
    }

    

}
