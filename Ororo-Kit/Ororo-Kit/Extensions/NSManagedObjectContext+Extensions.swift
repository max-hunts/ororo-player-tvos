//
//  NSManagedObjectContext+Extensions.swift
//  Ororo-Kit
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import CoreData

extension NSManagedObject: Sortable {

    public static var sortDescriptor: String {
        return "id"
    }
}

extension NSManagedObject: Identifiable {

    public static var primaryId: String {
        return "id"
    }
}

public extension NSManagedObject {

    /// Returns a name of the property without module prefix.
    static var entityName: String {
        return NSStringFromClass(self).components(separatedBy: ".").last!
    }

    /// Returns the existing object with the given primary id, or inserts a new one.
    ///
    /// The primary id attribute is an `Integer 64` for most entities but a `String`
    /// for `CDSubtitle`. The predicate argument must match the attribute's type: a
    /// numeric id compared as a string never matches an integer column, so the
    /// existing row is missed, a duplicate is inserted, and the next save fails on
    /// the uniqueness constraint. Coerce numeric ids to `Int` so the lookup matches.
    static func forceCreate<T>(with id: String,
                               into context: NSManagedObjectContext) -> T where T: NSManagedObject {

        let argument: Any
        if let numericId = Int(id) {
            argument = numericId
        } else {
            argument = id
        }

        let existing = context.fetchAll("\(T.primaryId) == %@", arguments: [argument]) as [T]?
        if let existing = existing?.first {
            return existing
        }

        let description = NSEntityDescription.entity(forEntityName: self.entityName,
                                                     in: context)
        return T.init(entity: description!, insertInto: context)
    }
}

public extension NSManagedObjectContext {

    /// Deletes existing object from the database.
    func deleteExisting(_ object: NSManagedObject) {
        self.performAndWait {
            self.delete(object)
        }
    }
}

extension NSManagedObjectContext: Fetchable {

    /// Fetches all items matching particular type.
    public func fetchAll<I>() -> [I]? where I: NSManagedObject {
        return fetchAll("", arguments: [])
    }

    /// Fetches all items matching particular type and fetchClause.
    public func fetchAll<I, O>(_ fetchQuery: String,
                               arguments: [O]) -> [I]? where I: NSManagedObject {

        let fetchRequest = NSFetchRequest<I>(entityName: I.entityName)
        fetchRequest.resultType = .managedObjectResultType

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: I.sortDescriptor,
                                                         ascending: true)]

        // In case of absent a fetch query will create a predicate.
        if !fetchQuery.isEmpty {
            let predicate = NSPredicate(format: fetchQuery,
                                        argumentArray: arguments)
            fetchRequest.predicate = predicate
        }

        var fetchResults: [I]?
        var fetchError: Error?
        self.performAndWait {
            do {
                fetchResults = try self.fetch(fetchRequest)
            } catch {
                fetchError = error
            }
        }
        if fetchResults == nil {
            logDebug("[Storage Service] Execution failed with error \(String(describing: fetchError))")
            return nil
        }
        return fetchResults
    }

    public func fetchOne<I, O>(_ fetchClause: String,
                               arguments: [O]) -> I? where I: NSManagedObject {
        return fetchAll(fetchClause, arguments: arguments)?.first
    }
}
