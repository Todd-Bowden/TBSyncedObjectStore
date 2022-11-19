
// TBSyncedObjectStore
//
// Created by Todd Bowden on 10/7/22.
//

import Foundation
import CloudKit
import Combine
import TBFileManager

public class TBSyncedObjectStore {
    
    /// There should only be one instance for each config identifier, this dictionary keeps a reference to that instance
    private static var stores = [String: TBSyncedObjectStore]()
    
    private struct FetchResults {
        let records: [CKRecord]
        let cursor: CKQueryOperation.Cursor?
        let latestModificationDate: Date
    }
    
    /// CloudKit database scope
    public enum Scope: String {
        case `private`
        case `public`
    }
    
    private let container: CKContainer
    private let database: CKDatabase
    private let scope: Scope
    private let types:[String: Codable.Type]
    private let localStore: TBSyncedObjectLocalStoreProtocol
    /// Provides serialized access to local sync data and the local store
    private let localPersistenceActor: LocalPersistenceActor
    
    public var upSyncInterval: TimeInterval = 5
    public var downSyncInterval: TimeInterval = 60
    public var batchSize = 100
    
    private var upSyncTimer: Timer? = nil
    private var needsUpSync: Bool = true
    private var downSyncTimer: Timer? = nil
    
    private var isSyncing: Bool = false
    private var isNotSyncing: Bool {
        !isSyncing
    }
    
    public static func store(_ scope: Scope, types: [String:Codable.Type], appGroup: String?, container: String?) throws -> TBSyncedObjectStore {
        let config = Config(appGroup: appGroup, container: container, scope: scope, types: types)
        return try store(config: config)
    }
    
    public static func store(config: Config) throws -> TBSyncedObjectStore {
        let identifier = try config.identifier()
        if let store = stores[identifier] {
            return store
        }
        let store = try TBSyncedObjectStore(config: config)
        stores[identifier] = store
        return store
    }
    
    /// There should only be one instance for each config identifier
    /// Get that instance by calling the class static func
    /// If no instance for the identifier yet, it will be created
    private init(config: Config) throws {
        if let container = config.container {
            self.container = CKContainer(identifier: container)
        } else {
            self.container = CKContainer.default()
        }
        self.scope = config.scope
        switch config.scope {
        case .private:
            database = self.container.privateCloudDatabase
        case .public:
            database = self.container.publicCloudDatabase
        }
        self.types = config.types
       
        var config = config
        config.container = self.container.containerIdentifier
        self.localStore = try config.localStore ?? TBSyncedObjectLocalStore(config: config)
        config.localStore = self.localStore
        
        self.localPersistenceActor = try LocalPersistenceActor(config: config)
        
        startUpSync()
        startDownSync()
        downSyncTask()
    }
    
    
    // MARK: Publishing

    private func publish(changes: [ObjectChange]) {
        guard changes.count > 0 else { return }
        
    }
    
    
    private func publish(errors: [ObjectError]) {
        guard errors.count > 0 else { return }
        
    }
    
    
    // MARK: Syncing
    
    func startUpSync() {
        self.upSyncTimer = Timer.scheduledTimer(withTimeInterval: upSyncInterval, repeats: true) { _ in
            guard self.needsUpSync && !self.isSyncing else { return }
            self.upSyncTask()
        }
    }
    
    func stopUpSync() {
        upSyncTimer?.invalidate()
        upSyncTimer = nil
    }
    
    func startDownSync() {
        self.downSyncTimer = Timer.scheduledTimer(withTimeInterval: downSyncInterval, repeats: true) { _ in
            Task(priority: .background) {
                try await self.downSync()
            }
        }
    }
    
    func stopDownSync() {
        downSyncTimer?.invalidate()
        downSyncTimer = nil
    }
    
    private func upSyncTask() {
        Task(priority: .background) {
            try await self.upSync()
        }
    }
    
    private func upSync() async throws {
        guard needsUpSync && isNotSyncing else { return }
        let user = try await user()
        
        isSyncing = true
        let objects = await localPersistenceActor.objectsNeedingUpSync(user: user, setStatusUpSyncing: true, max: batchSize)
        guard objects.count > 0 else {
            needsUpSync = false
            isSyncing = false
            return
        }
        print(objects)
        
        // map objects to cloudkit records and save to cloudkit
        var errors = [ObjectError]()
        var records = [CKRecord]()
        for object in objects {
            do {
                let record = try object.ckRecord()
                records.append(record)
            } catch {
                let error = ObjectError(locator: object.locator, error: error)
                errors.append(error)
            }
        }
        print(records)
        let results = try await database.modifyRecords(saving: records, deleting: [], atomically: false).saveResults
        
        // map the result into successfully saved records and errors
        var savedRecords = [CKRecord]()
        var ckErrors = [CKError]()
        for (_,result) in results {
            switch result {
            case .success(let record):
                savedRecords.append(record)
            case .failure(let error):
                if let ckError = error as? CKError {
                    ckErrors.append(ckError)
                }
            }
        }
        
        var processingErrors = await localPersistenceActor.processCloudSavedRecords(records, user: user).errors
        let processingResults = await localPersistenceActor.processCloudErrors(ckErrors, user: user)
        publish(changes: processingResults.changes)
        if processingResults.changes.count > 0 { needsUpSync = true }
        processingErrors.append(contentsOf: processingResults.errors)
        publish(errors: processingErrors)
        isSyncing = false
    }
    
    private func downSyncTask() {
        Task(priority: .background) {
            try await self.downSync()
        }
    }
    
    private func downSync() async throws {
        guard isNotSyncing else { return }
        isSyncing = true
        let user = try await user()
        for type in types.keys {
            try await downSync(type: type, user: user)
        }
        isSyncing = false
    }
    
    private func downSync(type: String, user: String?) async throws {
        var latestCloudModificationDate = try await localPersistenceActor.latestCloudModificationDate(type: type, user: user)
        var fetchResults = try await fetchRecords(type: type, since: latestCloudModificationDate)
        try await processFetchResults(fetchResults, user: user)
        var cursor = fetchResults.cursor
        latestCloudModificationDate = fetchResults.latestModificationDate
        while cursor != nil {
            fetchResults = try await fetchRecords(cursor: cursor!)
            try await processFetchResults(fetchResults, user: user)
            cursor = fetchResults.cursor
            latestCloudModificationDate = Date.laterDate(latestCloudModificationDate, fetchResults.latestModificationDate)
        }
        try await localPersistenceActor.saveLatestCloudModificationDate(latestCloudModificationDate, type: type, user: user)
    }
    
    private func processFetchResults(_ fetchResults: FetchResults, user: String?) async throws {
        let processingResults = await localPersistenceActor.processFetchedRecords(fetchResults.records, user: user)
        publish(changes: processingResults.changes)
        publish(errors: processingResults.errors)
    }
    
    private func latestModificationDate(records: [CKRecord]) -> Date {
        var date = Date(timeIntervalSince1970: 0)
        for record in records {
            if let modificationDate = record.modificationDate, modificationDate > date {
                date = modificationDate
            }
        }
        return date
    }
    
    
    // MARK: Fetching CloudKit Records
    
    /// Extract the records from an array of Results
    private func records(results: [Result<CKRecord, Error>]) -> [CKRecord] {
        var records = [CKRecord]()
        for result in results {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure:
                break
            }
        }
        return records
    }
    
    private func fetchRecords(locators: [ObjectLocator]) async throws -> [CKRecord] {
        let ids = locators.map { $0.id }
        return try await fetchRecords(ids: ids)
    }
    
    private func fetchRecords(ids: [String]) async throws -> [CKRecord] {
        let ckRecordIds = ids.map { CKRecord.ID(recordName: $0) }
        let results = try await database.records(for: ckRecordIds)
        return records(results: Array(results.values))
    }
    
    private func fetchRecords(type: String, since date: Date) async throws -> FetchResults {
        let predicate = NSPredicate(format: "modificationDate >= %@", date as CVarArg)
        let query = CKQuery(recordType: type, predicate: predicate)
        let resultsAndCursor = try await database.records(matching: query, resultsLimit: batchSize)
        let results = resultsAndCursor.matchResults.map { (_, result) in
            return result
        }
        let records = records(results: results)
        let latestModificationDate = latestModificationDate(records: records)
        return FetchResults(records: records, cursor: resultsAndCursor.queryCursor, latestModificationDate: latestModificationDate)
    }
    
    private func fetchRecords(cursor: CKQueryOperation.Cursor) async throws -> FetchResults {
        let resultsAndCursor = try await database.records(continuingMatchFrom: cursor, resultsLimit: batchSize)
        let results = resultsAndCursor.matchResults.map { (_, result) in
            return result
        }
        let records = records(results: results)
        let latestModificationDate = latestModificationDate(records: records)
        return FetchResults(records: records, cursor: resultsAndCursor.queryCursor, latestModificationDate: latestModificationDate)
    }

    // MARK: User and Locator
    
    public func user() async throws -> String? {
        switch scope {
        case .public:
            return nil
        case .private:
            return try await container.userRecordID().recordName
        }
    }
    
    private func locator(id: String, type: String) async throws -> ObjectLocator {
        try await ObjectLocator(id: id, type: type, user: user())
    }
    
    // MARK: Get and delete objects
    
    public func fetchObject<T:Codable>(id: String, type: String) async throws -> T? {
        if let record = try? await database.record(for: CKRecord.ID(recordName: id)) {
            let _ = try await localPersistenceActor.processFetchedRecord(record, user: user())
        }
        return try await object(id: id, type: type)
    }
    
    public func object<T:Codable>(id: String, type: String) async throws -> T? {
        let locator = try await locator(id: id, type: type)
        guard let object:T = localStore.object(locator: locator) else { return nil }
        return object
    }
    
    public func objects<T:Codable>(type: String) async throws -> [T] {
        let objects: [T] = try await localPersistenceActor.objects(type: type, user: user())
        return objects
    }
    
    public func saveObject<T:Codable>(_ object: T, id: String, type: String) async throws {
        let locator = try await locator(id: id, type: type)
        try await localPersistenceActor.saveObject(object, locator: locator)
        needsUpSync = true
    }
    
    public func acknowledgeObject(id: String, type: String) async throws {
        let locator = try await locator(id: id, type: type)
        try await acknowledgeObject(locator: locator)
    }
    
    public func acknowledgeObject(locator: ObjectLocator) async throws {
        try await localPersistenceActor.acknowledgeObject(locator: locator)
    }
    
    public func acknowledgeObjects(locators: [ObjectLocator]) async {
        await localPersistenceActor.acknowledgeObjects(locators: locators)
    }
    
    public func deleteObject(id: String, type: String) async throws {
        let locator = try await locator(id: id, type: type)
        try await localPersistenceActor.deleteObject(locator: locator)
        needsUpSync = true
    }
    
}


public extension TBSyncedObjectStore{
    
    struct Config {
        public var appGroup: String?
        public var baseDirectory: FileManager.SearchPathDirectory?
        public var container: String?
        public var scope: Scope
        public var types: [String: Codable.Type]
        public var recordMappings: [String: CKRecordMapingProtocol]
        public var localStore: TBSyncedObjectLocalStoreProtocol?
        public var conflictResolver: TBSyncedObjectConflctResolverProtocol?
        public var localEncryptionProvider: TBFileManagerEncryptionProviderProtocol?
        
        func identifier() throws -> String {
            try ((container ?? "") + scope.rawValue).hash(length: 32)
        }
        
        public init(appGroup: String? = nil,
                    baseDirectory: FileManager.SearchPathDirectory? = nil,
                    container: String? = nil,
                    scope: TBSyncedObjectStore.Scope,
                    types: [String : Codable.Type],
                    recordMappings: [String: CKRecordMapingProtocol] = [:],
                    localStore: TBSyncedObjectLocalStoreProtocol? = nil,
                    conflictResolver: TBSyncedObjectConflctResolverProtocol? = nil,
                    localEncryptionProvider: TBFileManagerEncryptionProviderProtocol? = nil) {
            self.appGroup = appGroup
            self.baseDirectory = baseDirectory
            self.container = container
            self.scope = scope
            self.types = types
            self.recordMappings = recordMappings
            self.localStore = localStore
            self.conflictResolver = conflictResolver
            self.localEncryptionProvider = localEncryptionProvider
        }
    }
}


