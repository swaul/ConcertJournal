//
//  CoreDataStack.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import CoreData
import Combine

class CoreDataStack {

    static var shared = CoreDataStack()

    let didChange = PassthroughSubject<Void, Never>()

    let persistentContainer: NSPersistentContainer

    init() {
        persistentContainer = NSPersistentContainer(name: "CJModels")

        let appGroupID = "group.de.kuehnel.concertjournal"
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
            .appendingPathComponent("CJModels.sqlite")

        let description = NSPersistentStoreDescription(url: storeURL)
        persistentContainer.persistentStoreDescriptions = [description]

        persistentContainer.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data failed to load: \(error), \(error.userInfo)")
            }
            logSuccess("Loaded Persistent Stores successfully")
        }

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }

    func save() {
        let context = viewContext

        if context.hasChanges {
            do {
                try context.save()
                didChange.send()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // Save with error handling
    func saveWithResult() throws {
        let context = viewContext

        if context.hasChanges {
            try context.save()
            didChange.send()
        }
    }

    // Background save
    func saveInBackground(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = newBackgroundContext()

        context.perform {
            block(context)

            if context.hasChanges {
                do {
                    try context.save()

                    DispatchQueue.main.async {
                        self.didChange.send()
                    }
                } catch {
                    print("Error saving background context: \(error)")
                }
            }
        }
    }
}
