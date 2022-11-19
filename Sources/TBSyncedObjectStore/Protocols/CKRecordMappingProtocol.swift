//
//  CKRecordMappingProtocol.swift
//  
//
//  Created by Todd Bowden on 11/17/22.
//

import Foundation
import CloudKit

public protocol CKRecordMappingProtocol {
    
    func ckRecord(baseRecord: CKRecord, object: Codable) throws -> CKRecord
    
    func object(ckRecord: CKRecord, type: Codable.Type?) throws -> Codable
    
}
