//
//  Encodable+isSameAs.swift
//  
//
//  Created by Todd Bowden on 11/25/22.
//

import Foundation

extension Encodable {
    
    func isSameAs(_ object: Codable) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let jsonSelf = try? encoder.encode(self) else { return false }
        guard let jsonObject = try? encoder.encode(object) else { return false }
        return jsonSelf == jsonObject
    }
    
    func isDifferentThan(_ object: Codable) -> Bool {
        !isSameAs(object)
    }
    
}
