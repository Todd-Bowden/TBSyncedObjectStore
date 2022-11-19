//
//  CKRecordMapingProtocol.swift
//  
//
//  Created by Todd Bowden on 11/17/22.
//

import Foundation
import CloudKit

public protocol CKRecordMapingProtocol {
    
    func ckRecord(baseRecord: CKRecord, object: Codable) throws -> CKRecord
    
    func object(ckRecord: CKRecord, type: Codable.Type?) throws -> Codable
    
}
