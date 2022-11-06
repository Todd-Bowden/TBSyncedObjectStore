
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
    
    private func filename(locator: ObjectLocator) throws -> String {
        try (locator.user ?? "_") + "/objects/" + locator.type.conditionalHash() + "/" + locator.id.conditionalHash()
    }
    
    public func save(objectJson: String, locator: ObjectLocator) throws {
        try fileManager.write(file: filename(locator: locator), string: objectJson)
    }
    
    public func deleteObject(locator: ObjectLocator) throws {
        try fileManager.delete(file: filename(locator: locator))
    }
    
    public func objectJson(locator: ObjectLocator) -> String? {
        try? fileManager.read(file: filename(locator: locator))
    }
    
}
