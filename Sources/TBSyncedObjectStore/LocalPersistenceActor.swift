//
//  LocalPersistenceActor.swift
//
//  Created by Todd Bowden on 10/9/22.
//

import Foundation
import CloudKit
import TBFileManager
import TBEncodingHashing

// The LocalPersistenceActor serializes calls to local persistence for the syncdata metadata and the local store
// so that only one thread is calling a function at a time
// NO ASYNC METHODS SHOULD BE USED IN THIS ACTOR -- function calls should not suspend

internal actor LocalPersistenceActor {
    
    struct ProcessingResults {
        let changes: [ObjectChange]
        let errors: [ObjectError]
    }
    
    private let types: [String: Codable.Type]
    private let recordMappings: [String: CKRecordMappingProtocol]
    private let fileManager: TBFileManager
    private let localStore: TBSyncedObjectLocalStoreProtocol
    private let deviceID: String
    private let conflictResolver: TBSyncedObjectConflctResolverProtocol
    
    private let maxRetryInterval: TimeInterval = 3600

    init(config: TBSyncedObjectStore.Config) throws {
        self.types = config.types
        self.recordMappings = config.recordMappings
        
        let directory = try config.identifier()
        
        if let appGroup = config.appGroup {
            fileManager = TBFileManager(appGroup: appGroup, directory: directory, doNotBackUp: true)
        } else {
            let baseDirectory = config.baseDirectory ?? .documentDirectory
            fileManager = TBFileManager(baseDirectory, directory: directory, doNotBackUp: true)
        }
        fileManager.encryptionProvider = config.localEncryptionProvider
        
        self.localStore = try config.localStore ?? TBSyncedObjectLocalStore(config: config)
        self.conflictResolver = config.conflictResolver ?? TBSyncedObjectConflctResolver()
        
        if let deviceID: String = try? fileManager.read(file: "DeviceID") {
            self.deviceID = deviceID
        } else {
            self.deviceID = (try? UUID().uuidString.hash()) ?? "_"
            try? fileManager.write(file: "DeviceID", string: self.deviceID)
        }
    }
    
    // MARK: Types
    
    private func codableType(type: String) throws -> Codable.Type {
        guard let codableType = types[type] else {
            throw TBSyncedObjectStoreError.codableObjectTypeNotProvided
        }
        return codableType
    }
    
    // MARK: Read and write objects
    
    /// Get an object from the local store and acknowledge it
    func object<T:Codable>(locator: ObjectLocator) -> T? {
        guard let object:T = localStore.object(locator: locator) else { return nil }
        try? acknowledgeObject(locator: locator)
        return object
    }
    
    func object(locator: ObjectLocator) -> Codable? {
        guard let type = try? codableType(type: locator.type) else { return nil }
        guard let object = localStore.object(locator: locator, type: type) else { return nil }
        try? acknowledgeObject(locator: locator)
        return object
    }
    
    func objects<T:Codable>(type: String, user: String?) throws -> [T] {
        try localStore.objects(type: type, user: user)
    }
    
    func objects<T:Codable>(idPrefix: String, type: String, user: String?) throws -> [T] {
        try localStore.objects(idPrefix: idPrefix, type: type, user: user)
    }
    
    func objectIDs(prefix: String, type: String, user: String?) throws -> [String] {
        try localStore.objectIDs(prefix: prefix, type: type, user: user)
    }
    
    private func filename(locator: ObjectLocator, folder: DataFolder) throws -> String {
        try folder.path(user: locator.user) + "/" + locator.type.conditionalHash() + "/" + locator.id.conditionalHash()
    }
    
    private func latestCloudModificationDateFilename(type: String, user: String?) throws -> String {
        try DataFolder.syncdata.path(user: user) + "/" + type.conditionalHash() + "/_LatestCloudModificationDate"
    }
    
    private func syncdata(locator: ObjectLocator) -> Syncdata? {
        try? fileManager.read(file: filename(locator: locator, folder: .syncdata))
    }
    
    private func metadata(locator: ObjectLocator) -> Data? {
        try? fileManager.readData(file: filename(locator: locator, folder: .metadata))
    }
    
    func latestCloudModificationDate(type: String, user: String?) throws -> Date {
        let filename = try latestCloudModificationDateFilename(type: type, user: user)
        return (try? fileManager.read(file: filename)) ?? Date(timeIntervalSince1970: 0)
    }
    
    private func recordMapping(type: String) -> CKRecordMappingProtocol {
        recordMappings[type] ?? CKRecordJsonObjectMapping()
    }
    
    // MARK: SyncableObjects
    
    private func localSyncableObject(locator: ObjectLocator) throws -> SyncableObject {
        let codableType = try codableType(type: locator.type)
        let object = localStore.object(locator: locator, type: codableType)
        let metadata = metadata(locator: locator)
        guard let syncdata = syncdata(locator: locator) else {
            throw TBSyncedObjectStoreError.missingLocalObject(locator)
        }
        let mapping = recordMapping(type: locator.type)
        return try SyncableObject(object: object, locator: locator, metadata: metadata, syncdata: syncdata, codableType: codableType, recordMapping: mapping)
    }
    
    private func syncableObject(ckRecord: CKRecord, user: String?) throws -> SyncableObject {
        guard let codableType = types[ckRecord.recordType] else {
            throw TBSyncedObjectStoreError.unknownObjectType(ckRecord.recordType)
        }
        let mapping = recordMapping(type: ckRecord.recordType)
        return try SyncableObject(ckRecord: ckRecord, type: codableType, recordMapping: mapping, user: user)
    }
    
    private func syncableObject(object: Codable?, locator: ObjectLocator, metadata: Data?, commit: ObjectCommit) throws -> SyncableObject {
        let codableType = try codableType(type: locator.type)
        let maping = recordMapping(type: locator.type)
        return try SyncableObject(object: object, locator: locator, metadata: metadata, commit: commit, codableType: codableType, recordMapping: maping)
    }
    
    
    // MARK: Saving and Deleting
    
    private func save(object: Codable?, locator: ObjectLocator) throws {
        guard let object = object else { return }
        try localStore.saveObject(object, locator: locator)
    }
    
    private func save(syncdata: Syncdata, locator: ObjectLocator) throws {
        do {
            try fileManager.write(file: filename(locator: locator, folder: .syncdata), object: syncdata)
        } catch {
            throw TBSyncedObjectStoreError.cannotSaveSyncdata(locator, error)
        }
    }
    
    private func save(metadata: Data?, locator: ObjectLocator) throws {
        guard let metadata = metadata else { return }
        do {
            try fileManager.write(file: filename(locator: locator, folder: .metadata), data: metadata)
        } catch {
            throw TBSyncedObjectStoreError.cannotSaveMetadata(locator, error)
        }
    }
    
    private func saveLatestCloudModificationDate(_ date: Date, type: String, user: String?) throws {
        let filename = try latestCloudModificationDateFilename(type: type, user: user)
        return try fileManager.write(file: filename, object: date)
    }
    
    func conditionallyUpdateCloudModificationDate(_ date: Date, type: String, user: String?) throws {
        let existingDate = try latestCloudModificationDate(type: type, user: user)
        if date > existingDate {
            try saveLatestCloudModificationDate(date, type: type, user: user)
        }
    }
    
    private func deleteMetadata(locator: ObjectLocator) throws {
        do {
            try fileManager.delete(file: filename(locator: locator, folder: .metadata))
        } catch {
            throw TBSyncedObjectStoreError.cannotDeleteMetadata(locator, error)
        }
    }

    
    // MARK: Locators
    
    func needsUpSync(user: String?) -> Bool {
        locatorsNeedingUpSync(user: user).count > 0
    }
    
    private func locatorsNeedingUpSyncFilename(user: String?) -> String {
        DataFolder.syncdata.path(user: user) + "/NeedsUpSync"
    }
    
    private func locatorsNeedingUpSync(user: String?, max: Int? = nil) -> [ObjectLocator] {
        do {
            let locators: [ObjectLocator] = try fileManager.read(file: locatorsNeedingUpSyncFilename(user: user))
            if let max = max {
                return Array(locators.prefix(max))
            } else {
                return locators
            }
        } catch {
            return []
        }
    }
    
    private func addLocatorNeedingUpSync(_ locator: ObjectLocator) throws {
        var locators = locatorsNeedingUpSync(user: locator.user)
        guard !locators.contains(locator) else { return }
        locators.append(locator)
        try fileManager.write(file: locatorsNeedingUpSyncFilename(user: locator.user), object: locators)
    }
    
    private func removeLocatorNeedingUpSync(_ locator: ObjectLocator) throws {
        var locators = locatorsNeedingUpSync(user: locator.user)
        locators = locators.filter { $0 != locator }
        try fileManager.write(file: locatorsNeedingUpSyncFilename(user: locator.user), object: locators)
    }
    
    private func scanForLocatorsNeedingUpSync(user: String?, max: Int) -> [ObjectLocator] {
        var locators = [ObjectLocator]()
        for type in types.keys {
            guard let files = try? fileManager.contents(directory: DataFolder.syncdata.path(user: user) + "/" + type) else { continue }
            for file in files {
                let locator = ObjectLocator(id: file, type: type, user: user)
                guard let syncdata = syncdata(locator: locator) else { continue }
                if syncdata.status == .needsUpSync {
                    locators.append(locator)
                }
                if locators.count >= max {
                    return locators
                }
            }
        }
        return locators
    }
        
    /// All objects needing sync
    func objectsNeedingUpSync(user: String?, setStatusUpSyncing: Bool, max: Int) -> [SyncableObject] {
        let user = user ?? "_"
        let locators = locatorsNeedingUpSync(user: user, max: max)
        var objects = [SyncableObject]()
        for locator in locators {
            guard var syncdata = syncdata(locator: locator), syncdata.status == .needsUpSync, syncdata.shouldRetry else { continue }
            guard let object = try? localSyncableObject(locator: locator) else { continue }
            objects.append(object)
            if setStatusUpSyncing {
                syncdata.status = .upSyncing
                try? save(syncdata: syncdata, locator: locator)
            }
        }
        return objects
    }
    
    func setStatus(_ status: Syncdata.Status, objects: [SyncableObject]) {
        let locators = objects.map { $0.locator }
        setStatus(status, locators: locators)
    }
    
    func setStatus(_ status: Syncdata.Status, locators: [ObjectLocator]) {
        for locator in locators {
            guard var syncdata = syncdata(locator: locator) else { continue }
            syncdata.status = status
            try? save(syncdata: syncdata, locator: locator)
        }
    }
    
    
    // MARK: Processing cloud responses
    
    // update the local store for objects saved to the cloud
    // always update the metadata
    // if the commit on the newly saved cloud object and the local object are the same, update the status to current
    // if commits are different, the local object was likely updated before the save confirmation from the cloud and will need to be synced again
    @discardableResult
    func processCloudSavedRecords(_ records: [CKRecord], user: String?) -> ProcessingResults {
        var errors = [ObjectError]()
        for record in records {
            do {
                let object = try syncableObject(ckRecord: record, user: user)
                try save(metadata: record.archivedMetadata, locator: object.locator)
                guard var syncdata = syncdata(locator: object.locator) else { continue }
                if syncdata.commit == object.commit {
                    syncdata.status = .current
                    syncdata.retryAfter = nil
                    syncdata.retries = 0
                    try save(syncdata: syncdata, locator: object.locator)
                    try removeLocatorNeedingUpSync(object.locator)
                }
            } catch {
                let locator = record.objectLocator(user: user)
                errors.append(ObjectError(locator: locator, error: error))
            }
        }
        return ProcessingResults(changes: [], errors: errors)
    }
    
    // Process attempted cloud save errors
    func processCloudErrors(_ objectErrors: [ObjectError], user: String?) -> ProcessingResults {
        var changes = [ObjectChange]()
        var processingErrors = [ObjectError]()
        for objectError in objectErrors {
            guard let ckError = objectError.error as? CKError else { continue }
            do {
                switch ckError.code {
                case .serverRecordChanged:
                    if let change = try processServerRecordChangedError(ckError, user: user) {
                        changes.append(change)
                    }
                case .unknownItem:
                    try? deleteMetadata(locator: objectError.locator)
                default:
                    try processCloudErrorRetry(objectError, user: user)
                }
            } catch let processingError {
                processingErrors.append(ObjectError(locator: objectError.locator, error: processingError))
            }
        }
        return ProcessingResults(changes: changes, errors: processingErrors)
    }
    
    private func processServerRecordChangedError(_ error: CKError, user: String?) throws -> ObjectChange? {
        guard let cloudRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
            throw TBSyncedObjectStoreError.missingServerRecord
        }
        let cloudObject = try syncableObject(ckRecord: cloudRecord, user: user)
        let localObject = try localSyncableObject(locator: cloudObject.locator)
        let locator = cloudObject.locator
        
        // always update the metadata to the latest cloud metadata
        try? save(metadata: cloudObject.archivedMetadata, locator: locator)
        
        // always resolve conficts in favor of a tombstone
        // if the cloud record is a tombstone, delete the local record
        if cloudObject.isTombstone {
            try? deleteMetadata(locator: cloudObject.locator)
            let syncdata = cloudObject.syncdata(staus: .current)
            try save(syncdata: syncdata, locator: locator)
            try localStore.deleteObject(locator: locator)
            try removeLocatorNeedingUpSync(locator)
            return ObjectChange(locator: locator, commit: cloudObject.commit, action: .deleted, origin: .cloud)
        }
        
        // do a conflict resolve
        // three posibilites: the cloud object wins, the local oeject wins, or the resolver combines them into a new object
        var object = resolveConflict(cloudObject, localObject)
        if object.commit.isResolve || object.commit.isEmpty {
            object.commit = try newCommit(hash: object.objectHash)
        }
        
        // if the local object wins, update the metadata and resync
        // (local object will always win if it is a tombstone)
        // the local object should resync with the next cycle using the updated metadata so the next save should succeed
        if object.commit == localObject.commit {
            let syncdata = object.syncdata(staus: .needsUpSync)
            try save(syncdata: syncdata, locator: locator)
            try addLocatorNeedingUpSync(locator)
            return nil
        }
        
        // get the codable object
        guard let codableObject = object.object else {
            throw TBSyncedObjectStoreError.codableObjectMissing
        }
        
        // if the cloud object wins, update the local object
        if object.commit == cloudObject.commit {
            try localStore.saveObject(codableObject, locator: locator)
            let syncdata = object.syncdata(staus: .current)
            try save(syncdata: syncdata, locator: locator)
            try removeLocatorNeedingUpSync(locator)
            return ObjectChange(locator: locator, commit: object.commit, action: .modified, origin: .cloud)
        }
        
        // if a combined object is created, update the local object and resync
        try localStore.saveObject(codableObject, locator: locator)
        let syncdata = object.syncdata(staus: .needsUpSync)
        try save(syncdata: syncdata, locator: locator)
        try addLocatorNeedingUpSync(locator)
        return ObjectChange(locator: locator, commit: object.commit, action: .modified, origin: .local)
    }
    
    // retry sync again with exponential backoff
    private func processCloudErrorRetry(_ objectError: ObjectError, user: String?) throws {
        let ckError = objectError.error as? CKError
        let locator = objectError.locator
        guard var syncdata = self.syncdata(locator: locator) else { return }
        syncdata.status = .needsUpSync
        var retries = (syncdata.retries ?? 0) + 1
        var retrySeconds = TimeInterval(pow(Double(retries), 2))
        if retrySeconds > maxRetryInterval {
            retrySeconds = maxRetryInterval
            retries -= 1
        }
        retrySeconds = ckError?.retryAfterSeconds ?? retrySeconds
        syncdata.retries = retries
        let retryTime = Date().timeIntervalSince1970 + retrySeconds
        syncdata.retryAfter = Date(timeIntervalSince1970: retryTime)
        syncdata.error = ckError.debugDescription
        try save(syncdata: syncdata, locator: locator)
        try addLocatorNeedingUpSync(locator)
        print(ckError.debugDescription)
        print("\(locator.id) retry after \(retrySeconds) seconds")
    }
    
    private func resolveConflict(_ object1: SyncableObject, _ object2: SyncableObject) -> SyncableObject {
        if object1.isTombstone { return object1 }
        if object2.isTombstone { return object2 }
        
        // first try the conflictResolver
        if let object = try? conflictResolver.resolveConflict(object1, object2) {
            return object
        // else return the object with the latest commit time
        } else {
            return object1.commit.commitTime < object2.commit.commitTime ? object2 : object1
        }
    }
    
    func processFetchedRecords(_ records: [CKRecord], user: String?) -> ProcessingResults {
        var changes = [ObjectChange]()
        var errors = [ObjectError]()
        for record in records {
            do {
                let object = try syncableObject(ckRecord: record, user: user)
                if let change = try processFetchedObject(object) {
                    changes.append(change)
                }
            } catch {
                let locator = record.objectLocator(user: user)
                errors.append(ObjectError(locator: locator, error: error))
            }
        }
        return ProcessingResults(changes: changes, errors: errors)
    }
    
    func processFetchedRecord(_ record: CKRecord, user: String?) throws -> ObjectChange? {
        let object = try syncableObject(ckRecord: record, user: user)
        return try processFetchedObject(object)
    }
    
    private func processFetchedObject(_ object: SyncableObject) throws -> ObjectChange? {
        let locator = object.locator
                
        // if no syncdata, this is a new object, create
        guard var syncdata = syncdata(locator: locator) else {
            let syncdata = object.syncdata(staus: .current)
            try save(syncdata: syncdata, locator: locator)
            // if the new object is a tombstone return nil, no need to save the object/metdata or return an ObjectChange
            guard object.isNotTombstone else { return nil }
            try? save(metadata: object.archivedMetadata, locator: locator)
            try save(object: object.object, locator: object.locator)
            return ObjectChange(locator: locator, commit: object.commit, action: .created, origin: .cloud)
        }
        
        // if fetched object is a tombstone and local object is not, then delete
        if object.isTombstone && syncdata.isNotTombstone {
            try? deleteMetadata(locator: locator)
            let syncdata = object.syncdata(staus: .current)
            try save(syncdata: syncdata, locator: locator)
            try localStore.deleteObject(locator: locator)
            try removeLocatorNeedingUpSync(locator)
            return ObjectChange(locator: locator, commit: object.commit, action: .deleted, origin: .cloud)
        }
        
        // if local object is a tombstone with status current and fetched object is not a tombstone, local object needs upSync
        if syncdata.isTombstone && syncdata.status == .current && object.isNotTombstone {
            try? save(metadata: object.archivedMetadata, locator: locator)
            syncdata.status = .needsUpSync
            try save(syncdata: syncdata, locator: locator)
            try addLocatorNeedingUpSync(locator)
            return nil
        }
    
        // if fetched object is the same as the local object, nothing to do, return nil
        if object.commit.isSameAs(commit: syncdata.commit) {
            print("fetched object is the same as local")
            return nil
        }
        
        // if the existing object sync status is current, update the local object
        if syncdata.status == .current {
            try? save(metadata: object.archivedMetadata, locator: locator)
            let syncdata = object.syncdata(staus: .current)
            try save(syncdata: syncdata, locator: locator)
            try save(object: object.object, locator: object.locator)
            return ObjectChange(locator: locator, commit: object.commit, action: .modified, origin: .cloud)
        }
        
        // if the object is in the middle of upSyncing, do nothing, wait for upSync to complete
        if syncdata.status == .upSyncing {
            return nil
        }
        
        // if fetched object needs upSync, do nothing, wait for upSync to complete
        if syncdata.status == .needsUpSync {
            return nil
        }
    
        // default, return nil
        return nil
    }
    

    // MARK: Save, acknowledge, delete
    
    // Save an object
    func saveObject<T:Codable>(_ object: T, locator: ObjectLocator) throws -> ObjectChange? {
        // if there is no sync data (first time save) just save and set to needsUpSync
        guard let existingSyncdata = syncdata(locator: locator) else {
            return try saveObjectAndSetNeedsUpSync(object: object, locator: locator, action: .created)
        }
        
        // check for a tombstone, if found, the object was previously deleted, throw an error
        guard existingSyncdata.isNotTombstone else {
            throw TBSyncedObjectStoreError.objectDeleted
        }
        
        // get the existing object, if none just save and set to needsUpSync
        guard let existingObject:T = localStore.object(locator: locator) else {
            return try saveObjectAndSetNeedsUpSync(object: object, locator: locator, action: .created)
        }
        
        // if the object is the same as the exising object just return
        guard existingObject.isDifferentThan(object) else { return nil }
        
        // if the deviceID in the existing sync data is not this device, do a conflict resolve
        guard self.deviceID == existingSyncdata.commit.deviceID else {
            let existingMetadata = metadata(locator: locator)
            let existingCommit = existingSyncdata.commit
            let existingSyncObject = try syncableObject(object: existingObject, locator: locator, metadata: existingMetadata, commit: existingCommit)
            let newCommit = try newCommit(hash: object.jsonHash())
            let newSyncObject = try syncableObject(object: object, locator: locator, metadata: nil, commit: newCommit)
            let resolvedSyncObject = try conflictResolver.resolveConflict(existingSyncObject, newSyncObject)
            guard let resolvedObject = resolvedSyncObject.object as? T else {
                throw TBSyncedObjectStoreError.codableObjectTypeMismatch
            }
            return try saveObjectAndSetNeedsUpSync(object: resolvedObject, locator: locator, action: .modified)
        }
       
        // save object
        return try saveObjectAndSetNeedsUpSync(object: object, locator: locator, action: .modified)
    }
    
    private func saveObjectAndSetNeedsUpSync<T:Codable>(object: T, locator: ObjectLocator, action: ObjectChange.Action) throws -> ObjectChange {
        let hash = object.jsonHash()
        let commit = try newCommit(hash: hash)
        let syncdata = Syncdata(locator: locator, status: .needsUpSync, commit: commit)
        try localStore.saveObject(object, locator: locator)
        try save(syncdata: syncdata, locator: locator)
        try addLocatorNeedingUpSync(locator)
        print(syncdata)
        return ObjectChange(locator: locator, commit: commit, action: action, origin: .local)
    }
    
    // update the commit deviceID to this device
    func acknowledgeObject(locator: ObjectLocator) throws {
        guard var syncdata = syncdata(locator: locator) else { return }
        syncdata.commit = syncdata.commit.newDeviceID(deviceID)
        try save(syncdata: syncdata, locator: locator)
    }
    
    @discardableResult
    func acknowledgeObjects(locators: [ObjectLocator]) -> [ObjectError] {
        var errors = [ObjectError]()
        for locator in locators {
            do {
                try acknowledgeObject(locator: locator)
            } catch {
                errors.append(ObjectError(locator: locator, error: error))
            }
        }
        return errors
    }
    
    func isDeletedObject(locator: ObjectLocator) throws -> Bool {
        guard let syncdata = syncdata(locator: locator) else { return false }
        return syncdata.isTombstone
    }
    
    func deleteObject(locator: ObjectLocator) throws -> ObjectChange {
        let commit = try newCommit(hash: ObjectCommit.tombstoneHash)
        let syncdata = Syncdata(locator: locator, status: .needsUpSync, isTombstone: true, commit: commit)
        try save(syncdata: syncdata, locator: locator)
        try localStore.deleteObject(locator: locator)
        try addLocatorNeedingUpSync(locator)
        return ObjectChange(locator: locator, commit: commit, action: .deleted, origin: .local)
    }
    
    // MARK: Commits and IDs
    
    private func newCommitID() throws -> String {
        try UUID().uuidString.hash(length: 6)
    }
    
    private func newCommit(deviceID: String? = nil, hash: String) throws -> ObjectCommit {
        let deviceID = deviceID ?? self.deviceID
        return try ObjectCommit(deviceID: deviceID, commitHash: hash, commitDate: Date(), commitID: newCommitID())
    }
    
    private enum DataFolder: String {
        case syncdata
        case metadata
        
        func path(user: String?) -> String {
            (user ?? "_") + "/" + self.rawValue
        }
    }
    
    // MARK: Rebuild Syncdata
    
    // get all objects from the local store
    // if no syncdata exists, create new syncdata with status of .needsUpsync
    func rebuildSyncdata(type: String, user: String?) throws {
        let locators = try localStore.locators(type: type, user: user)
        for locator in locators {
            guard let object = object(locator: locator) else { continue }
            let hash = object.jsonHash()
            guard let commit = try? newCommit(hash: hash) else { continue }
            let syncdata = Syncdata(locator: locator, status: .needsUpSync, commit: commit)
            try save(syncdata: syncdata, locator: locator)
            try addLocatorNeedingUpSync(locator)
        }
        
    }
}

