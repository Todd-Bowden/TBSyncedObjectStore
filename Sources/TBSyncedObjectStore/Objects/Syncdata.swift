//
//  Syncdata.swift
//  
//
//  Created by Todd Bowden on 10/7/22.
//

import Foundation

public struct Syncdata: Codable {
    
    public enum Status: String, Codable {
        case current
        case needsUpSync
        case upSyncing
    }
    public var locator: ObjectLocator
    public var status: Status
    public var isTombstone: Bool
    public var commit: ObjectCommit
    public var retryAfter: Date?
    public var retries: Int?
    
    public var id: String { locator.id }
    public var type: String { locator.type }
    public var user: String? { locator.user }
    public var isNotTombstone: Bool { !isTombstone }
    
    public var shouldRetry: Bool {
        if let retryAfter = retryAfter {
            return retryAfter < Date()
        }
        return true
    }
    
    public var summary: String {
        locator.summary + " | " + status.rawValue + " | " + (isTombstone ? "tombstone | " : "") + commit.string
    }
    
    init(locator: ObjectLocator, status: Status, isTombstone: Bool = false, commit: ObjectCommit, retryAfter: Date? = nil, retries: Int? = 0) {
        self.locator = locator
        self.status = status
        self.isTombstone = isTombstone
        self.commit = commit
        self.retryAfter = retryAfter
        self.retries = retries
        
        if isTombstone {
            self.commit = self.commit.tombstone
        }
    }
}


