//
//  Persistence.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import CoreData

/// Thin CoreData stack wrapper. `ElementEntity` persists discovered elements
/// (survives relaunch); `CombinationEntity` persists the combination cache so
/// A+B doesn't need to be regenerated in a future session either.
struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Model")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load Core Data store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
