//
//  ObjectLocator.swift
//  
//
//  Created by Todd Bowden on 10/25/22.
//

import Foundation

public struct ObjectLocator: Hashable, Codable {
    public let id: String
    public let type: String
    public let user: String?
    
    public var summary: String {
        id + "<" + type + "> (" + (user ?? "") + ")"
    }
    
    public init(id: String, type: String, user: String? = nil) {
        self.id = id
        self.type = type
        self.user = user
    }
}

