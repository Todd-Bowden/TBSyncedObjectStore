//
//  File.swift
//  
//
//  Created by Todd Bowden on 10/29/22.
//

import Foundation

extension Data {
    
    func utf8string() throws -> String {
        guard let string = String(data: self, encoding: .utf8) else {
            throw TBSyncedObjectStoreError.utf8EncodingError
        }
        return string
    }
    
}
