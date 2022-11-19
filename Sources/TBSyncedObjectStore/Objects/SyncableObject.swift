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
        static let tombstone = "_tombstone"
        static let commit = "_commit"
    }
    
    public let locator: ObjectLocator
    public let object: Codable?
    public let isTombstone: Bool
    public let archivedMetadata: Data?
    public var commit: ObjectCommit
        
    private let codableType: Codable.Type?
    private let recordMapping: CKRecordMappingProtocol?
    
    public var id: String { locator.id }
    public var type: String { locator.type }
    public var user: String? { locator.user }
    public var isNotTombstone: Bool { !isTombstone }
    
    private var objectJson: String? {
        guard let object = self.object else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(object).utf8string()
    }
    
    private var ckMetadataRecord: CKRecord? {
        guard let archivedMetadata = archivedMetadata else { return nil }
        return CKRecord(archivedMetadata: archivedMetadata)
    }
    
    public var metadata: Metadata? {
        guard let ckMetadata = ckMetadataRecord else { return nil }
        return Metadata(ckRecord: ckMetadata)
    }
    
    private func object(json: String?, type: Codable.Type) -> Codable? {
        guard let json = json else { return nil }
        return try? JSONDecoder().decode(type, from: json.utf8data())
    }
    
    public func syncdata(staus: Syncdata.Status) -> Syncdata {
        Syncdata(locator: locator, status: staus, isTombstone: isTombstone, commit: commit)
    }
    
    internal func ckRecord() throws -> CKRecord {
        var record = ckMetadataRecord ?? CKRecord(recordType: type, recordID: CKRecord.ID(recordName: id))
        guard isNotTombstone else {
            record[Keys.tombstone] = true
            record[Keys.commit] = commit.string
            return record
        }
        guard let recordMapping = recordMapping else {
            throw TBSyncedObjectStoreError.recordMappingNotProvided
        }
        if let object = self.object {
            record = try recordMapping.ckRecord(baseRecord: record, object: object)
        }
        record[Keys.tombstone] = isTombstone
        record[Keys.commit] = commit.string
        return record
    }
                                          
    init(ckRecord: CKRecord, type: Codable.Type, recordMapping: CKRecordMappingProtocol, user: String?) throws {
        self.locator = ckRecord.objectLocator(user: user)
        self.isTombstone = ckRecord[Keys.tombstone] as? Bool ?? false
        let commit = ckRecord[Keys.commit] as? String ?? ""
        self.commit = ObjectCommit(commit) ?? ObjectCommit.empty
        self.archivedMetadata = ckRecord.archivedMetadata
        
        if isTombstone {
            self.codableType = nil
            self.recordMapping = nil
            self.object = nil
        } else {
            self.codableType = type
            self.recordMapping = recordMapping
            self.object = try recordMapping.object(ckRecord: ckRecord, type: type)
        }
    }
    
    init(tombstoneId: String, type: String, user: String?, metadata: Data?, commit: ObjectCommit) {
        self.locator = ObjectLocator(id: tombstoneId, type: type, user: user)
        self.object = nil
        self.isTombstone = true
        self.commit = commit.tombstone
        self.archivedMetadata = metadata
        self.recordMapping = nil
        self.codableType = nil
    }
    
    init(object: Codable?, locator: ObjectLocator, metadata: Data?, syncdata: Syncdata, codableType: Codable.Type?, recordMapping: CKRecordMappingProtocol?) throws {
        self.locator = locator
        self.isTombstone = syncdata.isTombstone
        self.object = object
        self.archivedMetadata = metadata
        self.commit = syncdata.commit
        self.codableType = codableType
        self.recordMapping = recordMapping
    }
    
    init(object: Codable?, locator: ObjectLocator, metadata: Data?, commit: ObjectCommit, codableType: Codable.Type?, recordMapping: CKRecordMappingProtocol?) throws {
        self.locator = locator
        self.isTombstone = commit.isTombstone
        self.object = object
        self.archivedMetadata = metadata
        self.commit = commit
        self.codableType = codableType
        self.recordMapping = recordMapping
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
