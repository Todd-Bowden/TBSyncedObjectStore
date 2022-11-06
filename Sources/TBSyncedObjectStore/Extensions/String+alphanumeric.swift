//
//  String+alphanumeric.swift
//
//  Created by Todd Bowden on 10/1/22.
//

import Foundation

extension String {
    
    var alphanumeric: String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
    
    var isAlphanumeric: Bool {
        self == self.alphanumeric
    }
    
    var isNotAlphanumeric: Bool {
        !isAlphanumeric
    }
    
}
