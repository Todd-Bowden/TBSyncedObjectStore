//
//  SyncableObject.swift
//  
//
//  Created by Todd Bowden on 10/7/22.
//

import Foundation
import CloudKit

public struct SyncableObject {
    
    private struct Keys {
        static let object = "object"
        static let tombstone = "tombstone"
        static let commit = "commit"
    }
    
    public let locator: ObjectLocator
    public let objectJson: String
    public let isTombstone: Bool
    public let archivedMetadata: Data?
    public var commit: ObjectCommit
    
    public var id: String { locator.id }
    public var type: String { locator.type }
    public var user: String? { locator.user }
    public var isNotTombstone: Bool { !isTombstone }
    
    private var ckMetadata: CKRecord? {
        guard let archivedMetadata = archivedMetadata else { return nil }
        return CKRecord(archivedMetadata: archivedMetadata)
    }
    
    public var metadata: Metadata? {
        guard let ckMetadata = ckMetadata else { return nil }
        return Metadata(ckRecord: ckMetadata)
    }
    
    public func object<T:Codable>() throws -> T {
        guard let data = objectJson.data(using: .utf8) else {
            throw TBSyncedObjectStoreError.utf8EncodingError
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    public func object(type: Codable.Type) throws -> Codable {
        return try JSONDecoder().decode(type, from: objectJson.utf8data())
    }
    
    public func syncdata(staus: Syncdata.Status) -> Syncdata {
        Syncdata(locator: locator, status: staus, isTombstone: isTombstone, commit: commit)
    }
    
    internal var ckRecord: CKRecord {
        let record = ckMetadata ?? CKRecord(recordType: type, recordID: CKRecord.ID(recordName: id))
        record[Keys.object] = isTombstone ? "" : objectJson
        record[Keys.tombstone] = isTombstone
        record[Keys.commit] = commit.string
        return record
    }
                                          
    init(ckRecord: CKRecord, user: String?) {
        self.locator = ObjectLocator(id: ckRecord.recordID.recordName, type: ckRecord.recordType, user: user)
        self.objectJson = ckRecord[Keys.object] as? String ?? ""
        self.isTombstone = ckRecord[Keys.tombstone] as? Bool ?? false
        let commit = ckRecord[Keys.commit] as? String ?? ""
        self.commit = ObjectCommit(commit) ?? ObjectCommit.empty
        self.archivedMetadata = ckRecord.archivedMetadata
    }
    
    init(tombstoneId: String, type: String, user: String?, metadata: Data?, commit: ObjectCommit) {
        self.locator = ObjectLocator(id: tombstoneId, type: type, user: user)
        self.objectJson = ""
        self.isTombstone = true
        self.commit = commit
        self.archivedMetadata = metadata
    }
    
    init(object: String, locator: ObjectLocator, metadata: Data?, commit: ObjectCommit) throws {
        self.locator = locator
        self.isTombstone = false
        self.objectJson = object
        self.archivedMetadata = metadata
        self.commit = commit
    }
    
    init(object: String, locator: ObjectLocator, metadata: Data?, syncdata: Syncdata) throws {
        self.locator = locator
        self.isTombstone = syncdata.isTombstone
        self.objectJson = object
        self.archivedMetadata = metadata
        self.commit = syncdata.commit
    }
    
    init(object: Codable, locator: ObjectLocator, metadata: Data?, commit: ObjectCommit) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        guard let objectJson = String(data: data, encoding: .utf8) else {
            throw TBSyncedObjectStoreError.utf8EncodingError
        }
        self = try SyncableObject(object: objectJson, locator: locator, metadata: metadata, commit: commit)
    }
    
}

public extension SyncableObject {
    struct Metadata {
        let recordID: String
        let recordType: String
        let creationDate: Date?
        let creatorUserRecordID: String?
        let modificationDate: Date?
        let lastModifiedUserRecordID: String?
        let recordChangeTag: String?
        
        var modificationTime: UInt64? {
            guard let modDate = modificationDate else { return nil }
            return UInt64(modDate.timeIntervalSince1970)
        }
        
        init(ckRecord: CKRecord) {
            self.recordID = ckRecord.recordID.recordName
            self.recordType = ckRecord.recordType
            self.creationDate = ckRecord.creationDate
            self.creatorUserRecordID = ckRecord.creatorUserRecordID?.recordName
            self.modificationDate = ckRecord.modificationDate
            self.lastModifiedUserRecordID = ckRecord.lastModifiedUserRecordID?.recordName
            self.recordChangeTag = ckRecord.recordChangeTag
        }
    }
}
