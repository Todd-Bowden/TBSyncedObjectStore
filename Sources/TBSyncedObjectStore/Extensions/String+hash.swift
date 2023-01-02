//
//  String+hash.swift
//  
//
//  Created by Todd Bowden on 10/9/22.
//

import Foundation
import TBEncodingHashingExtensions

extension String {
        
    func conditionalHash(length: Int = 16) throws -> String {
        if self.alphanumeric == self.replacingOccurrences(of: "-", with: "") {
            return self
        } else {
            return try self.hash(length: length)
        }
    }
    
    
}
