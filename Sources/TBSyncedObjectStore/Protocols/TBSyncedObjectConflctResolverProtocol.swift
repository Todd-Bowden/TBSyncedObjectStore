//
//  TBSyncedObjectConflctResolverProtocol.swift
//  
//
//  Created by Todd Bowden on 11/5/22.
//

import Foundation

public protocol TBSyncedObjectConflctResolverProtocol {
    
    func resolveConflict(_ object1: SyncableObject, _ object2: SyncableObject) throws -> SyncableObject
    
}

