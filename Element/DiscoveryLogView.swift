//
//  DiscoveryLogView.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import CoreData
import SwiftUI

/// A persistent list of everything discovered, backed directly by
/// `@FetchRequest` against `ElementEntity` rather than the in-memory
/// `viewModel.discovered` array — a straight demonstration of driving a
/// SwiftUI `List` off Core Data.
struct DiscoveryLogView: View {
    @Environment(GameViewModel.self) private var viewModel

    @FetchRequest(sortDescriptors: [SortDescriptor(\ElementEntity.discoveredAt, order: .reverse)])
    private var entities: FetchedResults<ElementEntity>

    @State private var searchText = ""
    @State private var favoritesOnly = false

    private var elements: [Element] {
        entities
            .map(Element.init(entity:))
            .filter { favoritesOnly ? $0.isFavorite : true }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $favoritesOnly) {
                        Text("All").tag(false)
                        Label("Favorites", systemImage: "star.fill").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section("\(elements.count) discovered") {
                    ForEach(elements) { element in
                        NavigationLink(value: element) {
                            row(element)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                viewModel.toggleFavorite(element)
                            } label: {
                                Label(
                                    element.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: element.isFavorite ? "star.slash.fill" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search elements")
            .navigationTitle("Discoveries")
            .navigationDestination(for: Element.self) { element in
                ElementDetailView(element: element)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: exportJSON()) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(elements.isEmpty)
                }
            }
            .overlay {
                if elements.isEmpty {
                    ContentUnavailableView(
                        favoritesOnly ? "No favorites yet" : "Nothing discovered yet",
                        systemImage: "sparkles",
                        description: Text("Combine elements in the Craft tab to fill this log.")
                    )
                }
            }
        }
    }

    private func row(_ element: Element) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: element.colorHex).opacity(0.9), Color(hex: element.colorHex).opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .shadow(color: Color(hex: element.colorHex).opacity(0.3), radius: 3, y: 1)
                Text(element.emoji)
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(element.name).font(.body.weight(.semibold))
                Text(element.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if element.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
        }
        .padding(.vertical, 6)
    }

    /// Encodes the currently filtered elements as pretty-printed JSON — a
    /// local, offline demonstration of `Codable`/JSON mapping (no network
    /// call, in keeping with the app being fully on-device).
    private func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(elements), let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}
