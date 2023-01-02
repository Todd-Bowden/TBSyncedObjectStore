//
//  File.swift
//  
//
//  Created by Todd Bowden on 12/15/22.
//

import Foundation

extension Data {
    
    var hex: String {
        (self.map { String(format: "%02X", $0) }).joined()
    }
    
}
