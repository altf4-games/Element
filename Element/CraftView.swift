//
//  CraftView.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import SwiftUI

/// A tile placed on the canvas. Purely local view state — where a tile
/// currently sits has no meaning outside this screen, so it doesn't belong
/// in `GameViewModel`'s Single Source of Truth.
private struct CanvasItem: Identifiable {
    let id = UUID()
    var element: Element
    var position: CGPoint
}

/// Reports a view's size up through the view tree without affecting layout —
/// used to keep dropped/dragged tiles within the visible canvas bounds.
private struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// The combining surface: drag a tile out of the tray onto the canvas, then
/// drag one canvas tile onto another to combine them.
///
/// Native `onDrag`/`onDrop` was tried first and didn't reliably trigger on
/// iPhone-sized touch input, so this uses a plain `DragGesture` instead —
/// with `.highPriorityGesture` on the tray tiles specifically, since without
/// it the tray's own horizontal `ScrollView` wins the touch before the tile's
/// drag ever gets a chance to recognize.
struct CraftView: View {
    @Environment(GameViewModel.self) private var viewModel
    @AppStorage("aiCreativity") private var creativityRaw = AICreativity.balanced.rawValue
    @AppStorage("reduceMotionPref") private var reduceMotion = false

    @State private var canvasItems: [CanvasItem] = []
    /// Captured start-of-drag positions, so `DragGesture`'s cumulative
    /// `.translation` can be added to a stable base instead of snapping a
    /// tile straight to the raw touch point.
    @State private var dragStartPositions: [UUID: CGPoint] = [:]
    @State private var draggingPreview: CanvasItem?
    @State private var mergePoint: CGPoint?
    @State private var showingSettings = false
    @State private var canvasSize: CGSize = .zero

    private var creativity: AICreativity { AICreativity(rawValue: creativityRaw) ?? .balanced }
    private var placementAnimation: Animation {
        reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.72)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvasArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: SizePreferenceKey.self, value: geo.size)
                        }
                    )
                    .onPreferenceChange(SizePreferenceKey.self) { canvasSize = $0 }

                trayBar
            }
            .coordinateSpace(name: "canvas")
            .navigationTitle("Craft")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        withAnimation(placementAnimation) { canvasItems.removeAll() }
                    }
                    .disabled(canvasItems.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .overlay(alignment: .top) {
                if let discovery = viewModel.newlyDiscovered {
                    DiscoveryToast(element: discovery)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { viewModel.newlyDiscovered = nil }
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

    // MARK: - Canvas

    private var canvasArea: some View {
        ZStack {
            BlobBackground()

            if let reason = viewModel.unavailableReason {
                unavailableBanner(reason)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            if canvasItems.isEmpty && draggingPreview == nil {
                emptyState
            }

            ForEach(canvasItems) { item in
                ElementTile(element: item.element, isSelected: false)
                    .frame(width: 88)
                    .position(item.position)
                    .transition(.scale.combined(with: .opacity))
                    .gesture(dragGesture(for: item))
                    .onTapGesture(count: 2) { remove(item) }
            }

            if let mergePoint {
                ProgressView()
                    .position(mergePoint)
            }

            if let preview = draggingPreview {
                ElementTile(element: preview.element, isSelected: true)
                    .frame(width: 88)
                    .position(preview.position)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.draw")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Tap or drag elements from the tray onto the canvas, then drag one onto another to combine them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func unavailableBanner(_ reason: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(reason)
                .font(.footnote)
        }
        .padding(12)
        .background(Color.orange.opacity(0.15))
    }

    private var trayBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Elements")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.discovered.count) discovered")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.discovered) { element in
                        ElementTile(element: element, compact: true)
                            .frame(width: 76)
                            .highPriorityGesture(trayDragGesture(for: element))
                            .onTapGesture { addToCanvas(element) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.separator.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .shadow(color: .black.opacity(0.08), radius: 10, y: -2)
    }

    // MARK: - Gestures

    /// Spawning a *new* tile from the tray has no prior position to jump
    /// from, so following the raw touch location is correct here — the new
    /// tile should appear directly under the finger.
    private func trayDragGesture(for element: Element) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named("canvas"))
            .onChanged { value in
                if draggingPreview == nil {
                    draggingPreview = CanvasItem(element: element, position: value.location)
                } else {
                    draggingPreview?.position = value.location
                }
            }
            .onEnded { value in
                let item = CanvasItem(element: element, position: clamp(value.location))
                draggingPreview = nil
                withAnimation(placementAnimation) {
                    canvasItems.append(item)
                }
            }
    }

    /// Repositioning an *existing* canvas tile must track the finger's
    /// movement relative to where the tile already was — adding the
    /// gesture's cumulative `.translation` to a captured start position —
    /// rather than snapping the tile's center to the raw touch point.
    private func dragGesture(for item: CanvasItem) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("canvas"))
            .onChanged { value in
                guard let index = canvasItems.firstIndex(where: { $0.id == item.id }) else { return }
                let start = dragStartPositions[item.id] ?? canvasItems[index].position
                if dragStartPositions[item.id] == nil {
                    dragStartPositions[item.id] = start
                }
                canvasItems[index].position = CGPoint(
                    x: start.x + value.translation.width,
                    y: start.y + value.translation.height
                )
            }
            .onEnded { _ in
                dragStartPositions[item.id] = nil
                attemptMerge(draggedID: item.id)
            }
    }

    private func attemptMerge(draggedID: UUID) {
        guard let draggedIndex = canvasItems.firstIndex(where: { $0.id == draggedID }) else { return }
        let dragged = canvasItems[draggedIndex]

        guard let targetIndex = canvasItems.indices.first(where: { index in
            canvasItems[index].id != dragged.id && distance(canvasItems[index].position, dragged.position) < 70
        }) else { return }

        let target = canvasItems[targetIndex]
        let midpoint = CGPoint(
            x: (dragged.position.x + target.position.x) / 2,
            y: (dragged.position.y + target.position.y) / 2
        )

        withAnimation(placementAnimation) {
            canvasItems.removeAll { $0.id == dragged.id || $0.id == target.id }
        }
        mergePoint = midpoint

        Task {
            let result = await viewModel.combine(dragged.element, target.element, creativity: creativity)
            mergePoint = nil
            guard let result else { return }
            withAnimation(placementAnimation) {
                canvasItems.append(CanvasItem(element: result, position: midpoint))
            }
        }
    }

    private func remove(_ item: CanvasItem) {
        withAnimation(placementAnimation) {
            canvasItems.removeAll { $0.id == item.id }
        }
        dragStartPositions[item.id] = nil
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Fallback for placing a tile with a plain tap, in case drag doesn't
    /// register reliably on a given device — drops it at a random open spot.
    private func addToCanvas(_ element: Element) {
        let width = canvasSize.width > 0 ? canvasSize.width : 300
        let height = canvasSize.height > 0 ? canvasSize.height : 400
        let position = CGPoint(
            x: CGFloat.random(in: 60...max(61, width - 60)),
            y: CGFloat.random(in: 60...max(61, height - 60))
        )
        withAnimation(placementAnimation) {
            canvasItems.append(CanvasItem(element: element, position: position))
        }
    }

    /// Keeps a dropped tile's center within the measured canvas bounds so it
    /// never ends up stranded behind the tray or off the top edge.
    private func clamp(_ point: CGPoint) -> CGPoint {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return point }
        return CGPoint(
            x: min(max(point.x, 42), canvasSize.width - 42),
            y: min(max(point.y, 42), canvasSize.height - 42)
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.lastError = nil } }
        )
    }
}

struct DiscoveryToast: View {
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
