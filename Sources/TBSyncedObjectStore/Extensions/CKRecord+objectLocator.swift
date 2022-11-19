//
//  CKRecord+objectLocator.swift
//  
//
//  Created by Todd Bowden on 11/19/22.
//

import Foundation
import CloudKit

extension CKRecord {
    
    func objectLocator(user: String?) -> ObjectLocator {
        ObjectLocator(id: self.recordID.recordName, type: self.recordType, user: user)
    }
}

