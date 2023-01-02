//
//  String+uuidHash.swift
//  
//
//  Created by Todd Bowden on 12/15/22.
//

import Foundation

extension String {
    
    func uuidHash() throws -> String {
        try self.utf8data().uuidHash
    }
    
}
