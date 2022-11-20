
// TBSyncedObjectLocalStore
//
//  Created by Todd Bowden on 10/7/22.
//

import Foundation
import TBFileManager

public class TBSyncedObjectLocalStore: TBSyncedObjectLocalStoreProtocol {

    private let fileManager: TBFileManager
    
    public init(config: TBSyncedObjectStore.Config) throws {
        let directory = try config.identifier()
        
        if let appGroup = config.appGroup {
            fileManager = TBFileManager(appGroup: appGroup, directory: directory, doNotBackUp: true)
        } else {
            let baseDirectory = config.baseDirectory ?? .documentDirectory
            fileManager = TBFileManager(baseDirectory, directory: directory, doNotBackUp: true)
        }
        fileManager.encryptionProvider = config.localEncryptionProvider
    }
    
    private func directory(type: String, user: String?) throws -> String {
        try (user ?? "_") + "/objects/" + type.conditionalHash()
    }
    
    private func filename(locator: ObjectLocator) throws -> String {
        try directory(type: locator.type, user: locator.user) + "/" + locator.id.conditionalHash()
    }
    
    public func objects<T: Codable>(type: String, user: String?) -> [T] {
        guard let directory = try? directory(type: type, user: user) else { return [] }
        guard let files = try? fileManager.contents(directory: directory) else { return [] }
        var objects = [T]()
        for file in files {
            let filename = directory + "/" + file
            if let object: T = try? fileManager.read(file: filename) {
                objects.append(object)
            }
        }
        return objects
    }
    
    public func saveObject(_ object: Codable, locator: ObjectLocator) throws {
        try fileManager.write(file: filename(locator: locator), object: object)
    }
    
    public func deleteObject(locator: ObjectLocator) throws {
        try fileManager.delete(file: filename(locator: locator))
    }
    
    public func object(locator: ObjectLocator, type: Codable.Type) -> Codable? {
        try? fileManager.read(type: type, file: filename(locator: locator))
    }
    
}
