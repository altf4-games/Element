//
//  ContentView.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import CoreData
import SwiftUI

/// Root tab container. `@SceneStorage` remembers the last tab across
/// backgrounding/relaunch within the same scene — deliberately lighter-weight
/// than the Core Data-backed game state, which is why it's `@SceneStorage`
/// rather than persisted through `GameViewModel`.
struct ContentView: View {
    @SceneStorage("selectedTab") private var selectedTab = 0
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            CraftView()
                .tabItem { Label("Craft", systemImage: "sparkles") }
                .tag(0)

            DiscoveryLogView()
                .tabItem { Label("Discoveries", systemImage: "book.closed.fill") }
                .tag(1)

            AtlasView()
                .tabItem { Label("Atlas", systemImage: "map.fill") }
                .tag(2)
        }
        .tint(.accentColor)
        .preferredColorScheme((AppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme)
    }
}

#Preview {
    ContentView()
        .environment(GameViewModel(context: PersistenceController.preview.container.viewContext))
}
