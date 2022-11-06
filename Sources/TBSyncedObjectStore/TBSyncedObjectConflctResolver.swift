//
//  TBSyncedObjectConflctResolver.swift
//  
//
//  Created by Todd Bowden on 10/13/22.
//

import Foundation

public class TBSyncedObjectConflctResolver: TBSyncedObjectConflctResolverProtocol {
    
    public func resolveConflict(_ object1: SyncableObject, _ object2: SyncableObject) throws -> SyncableObject {
        throw TBSyncedObjectStoreError.coflictingSyncableObjects(object1, object2)
    }
    
}
