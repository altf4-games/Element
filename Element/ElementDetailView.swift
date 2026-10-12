//
//  ElementDetailView.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import SwiftUI

/// Pushed from `DiscoveryLogView` and presented from `AtlasView` — the same
/// destination reached two different ways, one example of passing typed data
/// across navigation.
struct ElementDetailView: View {
    @Environment(GameViewModel.self) private var viewModel
    let element: Element

    /// Re-resolves against the live view model so the favorite star stays in
    /// sync even though `element` itself is a static snapshot passed in.
    private var live: Element {
        viewModel.discovered.first(where: { $0.id == element.id }) ?? element
    }

    var body: some View {
        ScrollView {
            content
        }
        .navigationTitle(element.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: element.colorHex).opacity(0.9), Color(hex: element.colorHex).opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: Color(hex: element.colorHex).opacity(0.4), radius: 16, y: 6)

                Text(element.emoji)
                    .font(.system(size: 64))
            }
            .padding(.top, 24)

            Text(element.name)
                .font(.largeTitle.bold())

            Text(element.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Discovered \(element.discoveredAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                viewModel.toggleFavorite(live)
            } label: {
                Label(
                    live.isFavorite ? "Remove Favorite" : "Add Favorite",
                    systemImage: live.isFavorite ? "star.fill" : "star"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)

            let madeFrom = viewModel.recipes(producing: element)
            if !madeFrom.isEmpty {
                recipeSection("Made from", systemImage: "arrow.triangle.merge") {
                    ForEach(madeFrom) { recipe in
                        recipeRow([recipe.first, recipe.second], result: nil)
                    }
                }
            }

            let combinesInto = viewModel.recipes(using: element)
            if !combinesInto.isEmpty {
                recipeSection("Combines into", systemImage: "sparkles") {
                    ForEach(combinesInto) { recipe in
                        let partner = recipe.first == element ? recipe.second : recipe.first
                        recipeRow([partner], result: recipe.result)
                    }
                }
            }
        }
        .padding()
    }

    private func recipeSection(_ title: String, systemImage: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            rows()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// "A + B" for a recipe that makes this element, or "+ Partner → Result"
    /// for one this element is an ingredient in.
    private func recipeRow(_ inputs: [Element], result: Element?) -> some View {
        HStack(spacing: 6) {
            if result != nil {
                Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            ForEach(Array(inputs.enumerated()), id: \.offset) { index, input in
                if index > 0 {
                    Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
                ElementPill(element: input, compact: true)
            }
            if let result {
                Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                ElementPill(element: result, compact: true)
            }
        }
    }
}
