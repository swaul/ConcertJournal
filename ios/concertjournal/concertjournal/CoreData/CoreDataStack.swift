//
//  CoreDataStack.swift
//  concertjournal
//
//  Created by Paul Kühnel on 16.02.26.
//

import CoreData
import Combine

@MainActor
class CoreDataStack: ObservableObject {

    static let shared = CoreDataStack()

    // Publisher for data changes
    let didChange = PassthroughSubject<Void, Never>()

    // Persistent Container
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ConcertJournal")

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }

            // Enable automatic merging
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }

        return container
    }()

    // Main context (UI thread)
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    // Background context (for sync)
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }

    // Save context
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
