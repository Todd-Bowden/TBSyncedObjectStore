//
//  CKRecord+metadata.swift
//  
//
//  Created by Todd Bowden on 10/14/22.
//

import Foundation
import CloudKit

extension CKRecord {
    
    var archivedMetadata: Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    convenience init?(archivedMetadata: Data) {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: archivedMetadata) else {
            return nil
        }
        self.init(coder: unarchiver)
    }
    
}
