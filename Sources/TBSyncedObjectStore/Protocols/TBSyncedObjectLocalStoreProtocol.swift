//
//  TBSyncedObjectLocalStoreProtocol.swift
//  
//
//  Created by Todd Bowden on 10/7/22.
//

import Foundation

public protocol TBSyncedObjectLocalStoreProtocol {
    
    func saveObject(_ object: Codable, locator: ObjectLocator) throws
    
    func deleteObject(locator: ObjectLocator) throws
    
    func object<T:Codable>(locator: ObjectLocator) -> T?
    
    func objects<T:Codable>(type: String, user: String?) -> [T] 
    
    func objectJson(locator: ObjectLocator) -> String?
    
}

public extension TBSyncedObjectLocalStoreProtocol {
    
    func object<T:Codable>(locator: ObjectLocator) -> T? {
        guard let json = objectJson(locator: locator) else { return nil }
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(T.self, from: data)
    }
    
}
