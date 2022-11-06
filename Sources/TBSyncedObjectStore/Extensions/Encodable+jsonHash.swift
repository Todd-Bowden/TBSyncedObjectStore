//
//  Encodable+jsonHash.swift
//  
//
//  Created by Todd Bowden on 10/23/22.
//

import Foundation

extension Encodable {
    
    func jsonHash(length: Int = 16) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let jsonData = try? encoder.encode(self) else { return "" }
        return jsonData.hash(length: length)
    }
    
}
