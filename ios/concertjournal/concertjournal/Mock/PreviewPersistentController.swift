//
//  PreviewPersistentController.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

#if DEBUG

import CoreData

final class PreviewPersistenceController {
    static let shared = PreviewPersistenceController()

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "CJModels")

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType  // 🔥 wichtig!
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Preview store failed \(error)")
            }
        }
    }
}

extension Concert {
    static func preview(in context: NSManagedObjectContext) -> Concert {
        let concert = Concert(context: context)
        concert.id = UUID()
        concert.title = "Taylor Swift – Eras Tour"
        concert.date = Date()
        concert.serverId = "preview-id"
        return concert
    }
}
#endif
