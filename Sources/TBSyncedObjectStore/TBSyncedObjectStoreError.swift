//
//  TBSyncedObjectStoreError.swift
//  
//
//  Created by Todd Bowden on 10/7/22.
//

import Foundation

public enum TBSyncedObjectStoreError: Error {
    case utf8EncodingError
    case noObjectID
    case objectDeleted
    case coflictingObjects(Codable, Codable)
    case coflictingSyncableObjects(SyncableObject, SyncableObject)
    case missingServerRecord
    case missingClientRecord
    case missingLocalObject(ObjectLocator)
    case cannotSaveSyncdata(ObjectLocator, Error)
    case cannotSaveMetadata(ObjectLocator, Error)
    case cannotDeleteMetadata(ObjectLocator, Error)
    case unknownObjectType(String)
    case codableObjectMissing
    case codableObjectTypeNotProvided
    case codableObjectTypeMismatch
    case recordMappingNotProvided
    case ckRecordObjectMissing
    case initialUserNotSet
    case userMismatch(String, String)
}
