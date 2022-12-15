//
//  ObjectChange.swift
//  
//
//  Created by Todd Bowden on 10/29/22.
//

import Foundation

public struct ObjectChange {
    
    public enum Action {
        case created
        case modified
        case deleted
    }
    
    public enum Origin {
        case local
        case cloud
    }
    
    public let locator: ObjectLocator
    public let commit: ObjectCommit
    public let action: Action
    public let origin: Origin
    
}
