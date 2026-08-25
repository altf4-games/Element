//
//  ElementApp.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import CoreData
import SwiftUI

@main
struct ElementApp: App {
    private let persistenceController: PersistenceController
    @State private var viewModel: GameViewModel

    init() {
        let controller = PersistenceController.shared
        persistenceController = controller
        _viewModel = State(initialValue: GameViewModel(context: controller.container.viewContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
