//
//  Data.swift
//  
//
//  Created by Todd Bowden on 12/15/22.
//

import Foundation
import CryptoKit

extension Data {
    
    var uuidHash: String {
        var hash = [UInt8](Data(SHA256.hash(data: self)))
        hash[6] = hash[6] | 0b01000000
        hash[6] = hash[6] & 0b01001111
        hash[8] = hash[8] | 0b10000000
        hash[8] = hash[8] & 0b10111111
        return
            Data(hash[0...3]).hex + "-" +
            Data(hash[4...5]).hex + "-" +
            Data(hash[6...7]).hex + "-" +
            Data(hash[8...9]).hex + "-" +
            Data(hash[10...15]).hex
    }
    
}
