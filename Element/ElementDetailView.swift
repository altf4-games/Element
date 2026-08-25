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

            Spacer()
        }
        .padding()
        .navigationTitle(element.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
