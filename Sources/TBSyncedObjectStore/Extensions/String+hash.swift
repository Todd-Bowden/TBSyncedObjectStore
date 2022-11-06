//
//  String+hash.swift
//  
//
//  Created by Todd Bowden on 10/9/22.
//

import Foundation

public enum StringIDError: Error {
    case cannotEncodeString
}

extension String {
    
    func hash(length: Int = 16) throws -> String {
        guard let data = self.data(using: .utf8) else {
            throw StringIDError.cannotEncodeString
        }
        return data.hash(length: length)
    }
    
    func conditionalHash(length: Int = 16) throws -> String {
        if self.alphanumeric == self.replacingOccurrences(of: "-", with: "") {
            return self
        } else {
            return try self.hash(length: length)
        }
    }
    
    
}
