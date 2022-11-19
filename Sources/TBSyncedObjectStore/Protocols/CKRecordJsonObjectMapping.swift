//
//  CKRecordJsonObjectMapping.swift
//  
//
//  Created by Todd Bowden on 11/17/22.
//

import Foundation
import CloudKit

public class CKRecordJsonObjectMapping: CKRecordMappingProtocol {
    
    public func ckRecord(baseRecord: CKRecord, object: Codable) throws -> CKRecord {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonObject = try encoder.encode(object).utf8string()
        let record = baseRecord
        record["object"] = jsonObject
        return record
    }
    
    public func object(ckRecord: CKRecord, type: Codable.Type?) throws -> Codable {
        guard let json = ckRecord["object"] as? String else {
            throw TBSyncedObjectStoreError.ckRecordObjectMissing
        }
        let decoder = JSONDecoder()
        guard let type = type else {
            throw TBSyncedObjectStoreError.codableObjectTypeNotProvided
        }
        return try decoder.decode(type, from: json.utf8data())
    }
    
}
