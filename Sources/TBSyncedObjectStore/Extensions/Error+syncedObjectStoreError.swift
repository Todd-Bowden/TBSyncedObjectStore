//
//  Error+syncedObjectStoreError.swift
//  
//
//  Created by Todd Bowden on 11/26/22.
//

import Foundation

public extension Error {
    
    var syncedObjectStoreError: TBSyncedObjectStoreError? {
        self as? TBSyncedObjectStoreError
    }
}
