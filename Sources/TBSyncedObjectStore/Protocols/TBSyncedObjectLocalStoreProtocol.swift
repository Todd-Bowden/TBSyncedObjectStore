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
    
    func object(locator: ObjectLocator, type: Codable.Type) -> Codable?
    
    
    func object<T:Codable>(locator: ObjectLocator) -> T?
    
    func objects<T:Codable>(type: String, user: String?) throws -> [T]
    
    func objects<T:Codable>(idPrefix: String, type: String, user: String?) throws -> [T]
    
    func objectIDs(prefix: String, type: String, user: String?) throws -> [String]
    
    func locators(type: String, user: String?) throws -> [ObjectLocator]
    
}

public extension TBSyncedObjectLocalStoreProtocol {
    
    func object<T:Codable>(locator: ObjectLocator) -> T? {
        object(locator: locator, type: T.self) as? T
    }
    
}
