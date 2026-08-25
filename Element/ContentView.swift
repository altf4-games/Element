//
//  ContentView.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var selection: [Element] = []

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color.accentColor.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if let reason = viewModel.unavailableReason {
                        unavailableBanner(reason)
                    }

                    header

                    selectionTray

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.discovered) { element in
                                ElementTile(element: element, isSelected: selection.contains(element))
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            toggleSelection(element)
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) {
                if let discovery = viewModel.newlyDiscovered {
                    DiscoveryToast(element: discovery)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation(.spring) { viewModel.newlyDiscovered = nil }
                        }
                }
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.lastError ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("Element")
                .font(.largeTitle.bold())
            Text("\(viewModel.discovered.count) elements discovered")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func unavailableBanner(_ reason: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(reason)
                .font(.footnote)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15))
    }

    private var selectionTray: some View {
        HStack(spacing: 14) {
            slot(selection.count > 0 ? selection[0] : nil)

            Image(systemName: "plus")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            slot(selection.count > 1 ? selection[1] : nil)

            Spacer(minLength: 8)

            Button {
                combine()
            } label: {
                ZStack {
                    Circle()
                        .fill(canCombine ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 52, height: 52)

                    if viewModel.isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .disabled(!canCombine)
            .animation(.easeInOut(duration: 0.2), value: canCombine)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var canCombine: Bool {
        selection.count == 2 && !viewModel.isGenerating && viewModel.unavailableReason == nil
    }

    private func slot(_ element: Element?) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.secondary.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        Color.secondary.opacity(element == nil ? 0.25 : 0),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                    )
            )
            .frame(width: 60, height: 60)
            .overlay {
                if let element {
                    Text(element.emoji).font(.system(size: 26))
                }
            }
    }

    private func toggleSelection(_ element: Element) {
        if let index = selection.firstIndex(of: element) {
            selection.remove(at: index)
        } else if selection.count < 2 {
            selection.append(element)
        } else {
            selection = [element]
        }
    }

    private func combine() {
        guard selection.count == 2 else { return }
        let a = selection[0]
        let b = selection[1]
        Task {
            await viewModel.combine(a, b)
            withAnimation { selection = [] }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.lastError = nil } }
        )
    }
}

private struct DiscoveryToast: View {
    let element: Element

    var body: some View {
        HStack(spacing: 8) {
            Text(element.emoji)
            Text("New: \(element.name)!")
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(Color(hex: element.colorHex).opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }
}

#Preview {
    ContentView()
}
