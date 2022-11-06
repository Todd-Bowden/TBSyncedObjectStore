//
//  ObjectCommit.swift
//  
//
//  Created by Todd Bowden on 10/30/22.
//

import Foundation

public struct ObjectCommit: Codable, Equatable {

    public static var empty: ObjectCommit {
        ObjectCommit(deviceID: "", commitHash: "", commitTime: 0, commitID: "")
    }
    
    public static var resolve: ObjectCommit {
        ObjectCommit(deviceID: "resolve", commitHash: "resolve", commitTime: 0, commitID: "resolve")
    }
    
    public static let tombstoneHash = "tombstone"
    
    public let deviceID: String
    public let commitHash: String
    public let commitTime: UInt64
    public let commitID: String
    
    public var commitDate: Date {
        Date(timeIntervalSince1970: TimeInterval(commitTime))
    }
    
    public var isTombstone: Bool {
        commitHash == ObjectCommit.tombstoneHash
    }
    
    public var string: String {
        "\(deviceID)-\(commitHash)-\(commitTime)-\(commitID)"
    }
     
    public var tombstone: ObjectCommit {
        ObjectCommit(deviceID: deviceID, commitHash: ObjectCommit.tombstoneHash, commitTime: commitTime, commitID: commitID)
    }
    
    public func maxDate(_ maxDate: Date) -> ObjectCommit {
        if commitDate > maxDate {
            return ObjectCommit(deviceID: deviceID, commitHash: commitHash, commitDate: maxDate, commitID: commitID)
        } else {
            return self
        }
    }
     
    public func isSameAs(commit: ObjectCommit) -> Bool {
        self.commitHash == commit.commitHash && self.commitTime == commit.commitTime && self.commitID == commit.commitID
    }
    
    public var isEmpty: Bool {
        self == ObjectCommit.empty
    }
    
    public var isResolve: Bool {
        self == ObjectCommit.resolve
    }
    
    init(deviceID: String, commitHash: String, commitTime: UInt64, commitID: String) {
        self.deviceID = deviceID.remove("-")
        self.commitHash = commitHash.remove("-")
        self.commitTime = commitTime
        self.commitID = commitID.remove("-")
    }
    
    init(deviceID: String, commitHash: String, commitDate: Date, commitID: String) {
        self.deviceID = deviceID.remove("-")
        self.commitHash = commitHash.remove("-")
        self.commitTime = UInt64(commitDate.timeIntervalSince1970)
        self.commitID = commitID.remove("-")
    }
    
    init?(_ string: String) {
        let comp = string.components(separatedBy: "-")
        guard comp.count >= 4 else { return nil }
        deviceID = comp[0]
        commitHash = comp[1]
        commitTime = UInt64(comp[2]) ?? 0
        commitID = comp[3]
    }
        
}

