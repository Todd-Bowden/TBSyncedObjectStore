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
    
    public let locator: ObjectLocator
    public let commit: ObjectCommit
    public let action: Action
    
}
