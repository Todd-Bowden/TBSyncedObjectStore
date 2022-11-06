//
//  Data+hash.swift
//  
//
//  Created by Todd Bowden on 11/5/22.
//

import Foundation
import CryptoKit

extension Data {
    
    func hash(length: Int?) -> String {
        let hash = Data(SHA256.hash(data: self))
        let string = hash.base64EncodedString().alphanumeric
        if let length = length {
            return String(string.prefix(length))
        } else {
            return string
        }
    }

}
