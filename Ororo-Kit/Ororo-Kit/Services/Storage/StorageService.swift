//
//  StorageService.swift
//  Ororo-Kit
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import CoreData

public protocol Fetchable {

    func fetchAll<I>() -> [I]? where I: NSManagedObject

    func fetchAll<I, O>(_ fetchClause: String,
                        arguments: [O]) -> [I]? where I: NSManagedObject

    func fetchOne<I, O>(_ fetchClause: String,
                        arguments: [O]) -> I? where I: NSManagedObject
}

public final class StorageService {

    // MARK: - Properties
    private let container: NSPersistentContainer
    private let bundle = Bundle(for: StorageService.self)

    // MARK: - Life cycle
    public init(modelName: String) {
        guard let modelPath = bundle.url(forResource: modelName, withExtension: "momd") else {
            logFatal("[StorageService] Can't find the object model path")
        }
        guard let objectModel = NSManagedObjectModel(contentsOf: modelPath) else {
            logFatal("[StorageService] Can't find the object model")
        }
        container = NSPersistentContainer(name: modelName,
                                          managedObjectModel: objectModel)
        container.loadPersistentStores { (_, error) in
            self.container.viewContext.automaticallyMergesChangesFromParent = true
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            if let error = error {
                logFatal("[StorageService] Failed to load store: \(error)")
            } else {
                logDebug("[StorageService] Persistent Store is loaded successfully")
            }
        }
    }

    // MARK: - Public Interface
    public func clearAllData() {
        let entityNames = container.managedObjectModel.entities.compactMap { $0.name }
        performAsync(transaction: { context in
            entityNames.forEach { name in
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                try? context.execute(deleteRequest)
            }
        })
    }

    public func performAsync(transaction: @escaping (NSManagedObjectContext) -> Void,
                             completion: (() -> Void)? = nil) {
        container.performBackgroundTask { (context) in
            // Match the viewContext's merge policy. Background contexts otherwise
            // default to NSErrorMergePolicy, so a single uniqueness-constraint
            // conflict makes the whole save throw and silently drop every change.
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            transaction(context)
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    logDebug("[StorageService] Context can't be saved due to \(error)")
                }
            }
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
}

// MARK: - Fetchable
extension StorageService: Fetchable {

    public func fetchAll<I>() -> [I]? where I: NSManagedObject {
        return container.viewContext.fetchAll()
    }

    public func fetchAll<I, O>(_ fetchClause: String,
                               arguments: [O]) -> [I]? where I: NSManagedObject {
        return container.viewContext.fetchAll(fetchClause,
                                              arguments: arguments)
    }

    public func fetchOne<I, O>(_ fetchClause: String,
                               arguments: [O]) -> I? where I: NSManagedObject {
        return container.viewContext.fetchOne(fetchClause, arguments: arguments)
    }
}
