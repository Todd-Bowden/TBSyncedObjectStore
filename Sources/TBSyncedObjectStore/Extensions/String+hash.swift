//
//  String+hash.swift
//  
//
//  Created by Todd Bowden on 10/9/22.
//

import Foundation
import TBEncodingHashing

extension String {
        
    func conditionalHash(length: Int = 16) throws -> String {
        if self.alphanumeric == self.remove("-").remove("_") {
            return self
        } else {
            return try self.hash(length: length)
        }
    }
    
    
}
