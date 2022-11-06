//
//  TBSyncedObjectLocalStoreProtocol.swift
//  
//
//  Created by Todd Bowden on 10/7/22.
//

import Foundation

public protocol TBSyncedObjectLocalStoreProtocol {
    
    func save(object: Codable, locator: ObjectLocator) throws
    
    func save(objectJson: String, locator: ObjectLocator) throws
    
    func deleteObject(locator: ObjectLocator) throws
    
    func object<T:Codable>(locator: ObjectLocator) -> T?
    
    func objectJson(locator: ObjectLocator) -> String?
    
}

public extension TBSyncedObjectLocalStoreProtocol {
    
    func object<T:Codable>(locator: ObjectLocator) -> T? {
        guard let json = objectJson(locator: locator) else { return nil }
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(T.self, from: data)
    }
    
    func save(object: Codable, locator: ObjectLocator) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        try save(objectJson: data.utf8string(), locator: locator)
    }
    
}
