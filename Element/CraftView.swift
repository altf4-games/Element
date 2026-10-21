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

/// Two tiles that have been dropped on each other and are waiting on the model.
private struct PendingMerge: Identifiable {
    let id = UUID()
    let first: CanvasItem
    let second: CanvasItem
    let position: CGPoint
}

/// A short-lived celebration effect at the spot a new element appeared.
private struct Burst: Identifiable {
    let id = UUID()
    let position: CGPoint
    let color: Color
}

/// An element being dragged out of the tray. `location` is nil between the
/// long press succeeding and the finger first moving.
private struct TrayDrag: Equatable {
    let element: Element
    var location: CGPoint?
}

enum TraySort: String, CaseIterable, Identifiable {
    case newest
    case name
    case emoji

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: "Newest first"
        case .name: "Name"
        case .emoji: "Emoji"
        }
    }

    var icon: String {
        switch self {
        case .newest: "clock"
        case .name: "textformat"
        case .emoji: "face.smiling"
        }
    }
}

/// The combining surface, modeled on Infinite Craft: drag an element out of
/// the tray onto the canvas (or straight onto another tile), drop one tile on
/// another to combine them, and drag a tile back into the tray to remove it.
///
/// Native `onDrag`/`onDrop` was tried first and didn't reliably trigger on
/// iPhone-sized touch input, so this uses a plain `DragGesture` instead. Tray
/// tiles need a short press-and-hold before dragging, so a normal swipe still
/// scrolls the tray.
struct CraftView: View {
    @Environment(GameViewModel.self) private var viewModel
    @AppStorage("aiCreativity") private var creativityRaw = AICreativity.balanced.rawValue
    @AppStorage("reduceMotionPref") private var reduceMotion = false
    @AppStorage("traySort") private var traySortRaw = TraySort.newest.rawValue

    @State private var canvasItems: [CanvasItem] = []
    /// Captured start-of-drag positions, so `DragGesture`'s cumulative
    /// `.translation` can be added to a stable base instead of snapping a
    /// tile straight to the raw touch point.
    @State private var dragStartPositions: [UUID: CGPoint] = [:]
    @State private var draggingID: UUID?
    @State private var hoverTargetID: UUID?
    @State private var isOverTray = false
    @State private var trayDrag: TrayDrag?
    @State private var pending: [PendingMerge] = []
    @State private var bursts: [Burst] = []
    @State private var showingSettings = false
    @State private var showingClearConfirm = false
    @State private var canvasSize: CGSize = .zero
    @State private var trayExpanded = false
    @State private var expandedGridHeight: CGFloat = 0
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    @State private var mergeTick = 0
    @State private var removeTick = 0

    private var modeBinding: Binding<GameMode> {
        Binding(get: { viewModel.mode }, set: { viewModel.setMode($0) })
    }

    private var creativity: AICreativity { AICreativity(rawValue: creativityRaw) ?? .balanced }
    private var traySort: TraySort { TraySort(rawValue: traySortRaw) ?? .newest }
    private var placementAnimation: Animation {
        reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.72)
    }
    private var isDraggingAnything: Bool { draggingID != nil || trayDrag != nil }

    /// The tile that will receive a drop right now, from either kind of drag.
    private var highlightedTargetID: UUID? {
        if let location = trayDrag?.location {
            return location.y < canvasSize.height ? target(near: location, excluding: nil)?.id : nil
        }
        return hoverTargetID
    }

    private var trayElements: [Element] {
        let filtered = viewModel.discovered.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
        switch traySort {
        case .newest: return filtered.reversed()
        case .name: return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .emoji: return filtered.sorted { $0.emoji < $1.emoji }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvasArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { canvasSize = $0 }
                    // Lets a dragged tile draw over the tray (to drop it there
                    // and remove it) instead of sliding underneath.
                    .zIndex(isDraggingAnything ? 1 : 0)

                trayBar
            }
            .coordinateSpace(name: "canvas")
            .navigationTitle("Craft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingClearConfirm = true
                    } label: {
                        Label("Clear canvas", systemImage: "trash")
                    }
                    .disabled(canvasItems.isEmpty)
                }
                ToolbarItem(placement: .principal) {
                    Menu {
                        Picker("Game mode", selection: modeBinding) {
                            ForEach(GameMode.allCases) { mode in
                                Label(mode.label, systemImage: mode.icon).tag(mode)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.mode.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                            Text(viewModel.mode.label).font(.headline)
                            Text("\(viewModel.discovered.count)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                                .contentTransition(.numericText())
                                .animation(.snappy, value: viewModel.discovered.count)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("\(viewModel.mode.label) mode, \(viewModel.discovered.count) elements discovered")
                    .accessibilityHint("Switch game mode")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .confirmationDialog("Clear the canvas?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
                Button("Clear Canvas", role: .destructive) {
                    withAnimation(placementAnimation) { canvasItems.removeAll() }
                }
            } message: {
                Text("Your discoveries are kept.")
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .overlay(alignment: .top) {
                if let discovery = viewModel.newDiscovery {
                    DiscoveryToast(discovery: discovery, label: viewModel.mode.discoveryLabel)
                        .padding(.top, 8)
                        .id(discovery.element.id)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { viewModel.newDiscovery = nil } }
                        .task(id: discovery.element.id) {
                            try? await Task.sleep(for: .seconds(2.5))
                            guard !Task.isCancelled else { return }
                            withAnimation { viewModel.newDiscovery = nil }
                        }
                }
            }
            .animation(placementAnimation, value: viewModel.newDiscovery)
            .sensoryFeedback(trigger: viewModel.newDiscovery) { _, new in
                new == nil ? nil : .success
            }
            .sensoryFeedback(trigger: trayDrag != nil) { _, picked in
                picked ? .impact(weight: .light) : nil
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: mergeTick)
            .sensoryFeedback(.impact(weight: .light), trigger: removeTick)
            .sensoryFeedback(.selection, trigger: highlightedTargetID) { _, new in new != nil }
            .onChange(of: viewModel.mode) {
                // A fresh world gets a fresh canvas.
                canvasItems.removeAll()
                pending.removeAll()
                searchText = ""
            }
            .onChange(of: canvasSize) {
                // Keep tiles reachable when the tray expands and the canvas shrinks.
                for index in canvasItems.indices {
                    canvasItems[index].position = clamp(canvasItems[index].position)
                }
            }
        }
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        ZStack {
            DotGrid()
            BlobBackground()

            if let reason = viewModel.unavailableReason {
                unavailableBanner(reason)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            if canvasItems.isEmpty && pending.isEmpty && trayDrag == nil {
                emptyState
            }

            ForEach(canvasItems) { item in
                ElementPill(
                    element: item.element,
                    isHighlighted: item.id == highlightedTargetID,
                    isLifted: item.id == draggingID
                )
                .position(item.position)
                .zIndex(item.id == draggingID ? 1 : 0)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
                .gesture(dragGesture(for: item))
                .onTapGesture(count: 2) { duplicate(item) }
            }

            ForEach(pending) { merge in
                PendingPill(first: merge.first.element, second: merge.second.element)
                    .position(merge.position)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            ForEach(bursts) { burst in
                BurstView(color: burst.color)
                    .position(burst.position)
                    .allowsHitTesting(false)
            }

            if let drag = trayDrag, let location = drag.location {
                ElementPill(element: drag.element, isLifted: true)
                    .position(location)
                    .allowsHitTesting(false)
                    .zIndex(2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = false }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.draw")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 3)), isActive: !reduceMotion)
            Text("Start crafting")
                .font(.headline)
            Text(viewModel.mode.emptyStateHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .allowsHitTesting(false)
    }

    private func unavailableBanner(_ reason: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("\(reason) Using the built-in recipe book until it's ready.")
                .font(.footnote)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15))
    }

    // MARK: - Tray

    private var trayBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("Search \(viewModel.discovered.count) items", text: $searchText)
                        .font(.subheadline)
                        .focused($searchFocused)
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.systemBackground).opacity(0.7), in: Capsule())

                Menu {
                    Picker("Sort", selection: $traySortRaw) {
                        ForEach(TraySort.allCases) { sort in
                            Label(sort.label, systemImage: sort.icon).tag(sort.rawValue)
                        }
                    }
                } label: {
                    trayButtonLabel("arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort elements")

                Button {
                    withAnimation(placementAnimation) { trayExpanded.toggle() }
                } label: {
                    trayButtonLabel(trayExpanded ? "chevron.down" : "chevron.up")
                }
                .accessibilityLabel(trayExpanded ? "Collapse elements" : "Expand elements")
            }
            .padding(.horizontal, 12)

            if trayElements.isEmpty {
                Text("No elements match \u{201C}\(searchText)\u{201D}")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(height: 40)
            } else if trayExpanded {
                // Hug the content while it's short, and only scroll once
                // it outgrows the cap.
                ScrollView(.vertical) {
                    expandedGrid
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { expandedGridHeight = $0 }
                }
                .frame(height: min(max(expandedGridHeight, 44), 260))
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.immediately)
                .scrollDisabled(trayDrag != nil)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(trayElements) { element in
                            trayPill(element)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .scrollDismissesKeyboard(.immediately)
                .scrollDisabled(trayDrag != nil)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isOverTray ? AnyShapeStyle(Color.red.opacity(0.7)) : AnyShapeStyle(.separator.opacity(0.25)),
                              lineWidth: isOverTray ? 2 : 1)
        )
        .overlay(alignment: .top) {
            // Sits above the tray so the tile under the finger can't hide it.
            if isOverTray {
                Label("Drop to remove", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -48)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isOverTray)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .shadow(color: .black.opacity(0.08), radius: 10, y: -2)
    }

    private var expandedGrid: some View {
        FlowLayout(spacing: 8) {
            ForEach(trayElements) { element in
                trayPill(element)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func trayButtonLabel(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 34, height: 34)
            .background(Color(.systemBackground).opacity(0.7), in: Circle())
    }

    private func trayPill(_ element: Element) -> some View {
        ElementPill(element: element, compact: true)
            .opacity(trayDrag?.element == element ? 0.4 : 1)
            .onTapGesture { addToCanvas(element) }
            .gesture(
                HoldAndDrag(
                    coordinateSpace: .named("canvas"),
                    onChanged: { location in trayDrag = TrayDrag(element: element, location: location) },
                    onEnded: { location in dropFromTray(element, at: location) }
                )
            )
    }

    // MARK: - Gestures

    /// `nil` means the system cancelled the drag. A drop back over the tray
    /// is treated as a cancel too. The new tile lands at the raw touch
    /// location, since it has no prior position on the canvas.
    private func dropFromTray(_ element: Element, at location: CGPoint?) {
        trayDrag = nil
        guard let point = location, point.y < canvasSize.height else { return }

        let item = CanvasItem(element: element, position: clamp(point))
        if let target = target(near: point, excluding: nil) {
            merge(item, into: target)
        } else {
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
                    draggingID = item.id
                    searchFocused = false
                }
                let position = CGPoint(
                    x: start.x + value.translation.width,
                    y: start.y + value.translation.height
                )
                canvasItems[index].position = position
                isOverTray = position.y > canvasSize.height
                hoverTargetID = isOverTray ? nil : target(near: position, excluding: item.id)?.id
            }
            .onEnded { _ in
                let droppedOnTray = isOverTray
                dragStartPositions[item.id] = nil
                draggingID = nil
                hoverTargetID = nil
                isOverTray = false

                guard let index = canvasItems.firstIndex(where: { $0.id == item.id }) else { return }
                let dragged = canvasItems[index]

                if droppedOnTray {
                    remove(dragged)
                } else if let target = target(near: dragged.position, excluding: dragged.id) {
                    merge(dragged, into: target)
                } else {
                    withAnimation(placementAnimation) {
                        canvasItems[index].position = clamp(dragged.position)
                    }
                }
            }
    }

    // MARK: - Combining

    /// The closest canvas tile whose pill overlaps `point`. Pills are wider
    /// than they are tall, so the hit area is too.
    private func target(near point: CGPoint, excluding id: UUID?) -> CanvasItem? {
        canvasItems
            .filter { $0.id != id && abs($0.position.x - point.x) < 70 && abs($0.position.y - point.y) < 36 }
            .min { distance($0.position, point) < distance($1.position, point) }
    }

    /// Like Infinite Craft, the result appears where the target tile was.
    private func merge(_ dragged: CanvasItem, into target: CanvasItem) {
        let merge = PendingMerge(first: dragged, second: target, position: target.position)
        withAnimation(placementAnimation) {
            canvasItems.removeAll { $0.id == dragged.id || $0.id == target.id }
            pending.append(merge)
        }
        mergeTick += 1

        let startMode = viewModel.mode
        Task {
            let outcome = await viewModel.combine(dragged.element, target.element, creativity: creativity)
            guard viewModel.mode == startMode else { return }
            withAnimation(placementAnimation) {
                pending.removeAll { $0.id == merge.id }
                canvasItems.append(CanvasItem(element: outcome.element, position: merge.position))
            }
            if outcome.isNew {
                celebrate(at: merge.position, color: Color(hex: outcome.element.colorHex))
            }
        }
    }

    private func celebrate(at position: CGPoint, color: Color) {
        guard !reduceMotion else { return }
        let burst = Burst(position: position, color: color)
        bursts.append(burst)
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            bursts.removeAll { $0.id == burst.id }
        }
    }

    private func remove(_ item: CanvasItem) {
        withAnimation(placementAnimation) {
            canvasItems.removeAll { $0.id == item.id }
        }
        dragStartPositions[item.id] = nil
        removeTick += 1
    }

    /// Double-tap makes a copy beside the original — handy for Fire + Fire.
    private func duplicate(_ item: CanvasItem) {
        let copy = CanvasItem(element: item.element, position: clamp(CGPoint(x: item.position.x + 24, y: item.position.y + 44)))
        withAnimation(placementAnimation) {
            canvasItems.append(copy)
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Tapping a tray element drops it at a random open-ish spot near the
    /// middle of the canvas, the fallback for players who don't drag.
    private func addToCanvas(_ element: Element) {
        searchFocused = false
        let width = canvasSize.width > 0 ? canvasSize.width : 300
        let height = canvasSize.height > 0 ? canvasSize.height : 400
        var position = CGPoint(x: width / 2, y: height / 2)
        for _ in 0..<12 {
            let candidate = CGPoint(
                x: CGFloat.random(in: 70...max(71, width - 70)),
                y: CGFloat.random(in: 60...max(61, height - 60))
            )
            position = candidate
            if target(near: candidate, excluding: nil) == nil { break }
        }
        withAnimation(placementAnimation) {
            canvasItems.append(CanvasItem(element: element, position: position))
        }
    }

    /// Keeps a tile's center within the measured canvas bounds so it never
    /// ends up stranded behind the tray or off the top edge.
    private func clamp(_ point: CGPoint) -> CGPoint {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return point }
        return CGPoint(
            x: min(max(point.x, 50), max(50, canvasSize.width - 50)),
            y: min(max(point.y, 24), max(24, canvasSize.height - 24))
        )
    }
}

// MARK: - Hold-and-drag gesture

/// Press-and-hold, then drag, for pulling tiles out of the scrolling tray.
///
/// Built on `UILongPressGestureRecognizer` rather than SwiftUI's
/// `LongPressGesture().sequenced(before: DragGesture())`, which claims the
/// touch immediately and stops the tray from scrolling at all. The UIKit
/// recognizer fails as soon as the finger moves before the hold completes,
/// handing the touch to the scroll view, and once it begins it keeps
/// reporting the finger's position as it moves.
private struct HoldAndDrag: UIGestureRecognizerRepresentable {
    var minimumDuration: TimeInterval = 0.2
    let coordinateSpace: NamedCoordinateSpace
    let onChanged: (CGPoint) -> Void
    /// Called with the drop location, or `nil` if the gesture was cancelled.
    let onEnded: (CGPoint?) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumDuration
        recognizer.allowableMovement = 10
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let location = context.converter.location(in: coordinateSpace)
        switch recognizer.state {
        case .began, .changed:
            onChanged(location)
        case .ended:
            onEnded(location)
        case .cancelled, .failed:
            onEnded(nil)
        default:
            break
        }
    }
}

// MARK: - Canvas decorations

/// A faint dot grid, like a crafting table — drawn with `Canvas` in one pass
/// rather than as hundreds of separate views.
private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 22
            for x in stride(from: spacing / 2, to: size.width, by: spacing) {
                for y in stride(from: spacing / 2, to: size.height, by: spacing) {
                    context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                                 with: .color(.primary.opacity(0.1)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Shown where two tiles were dropped, while the model works on the result.
private struct PendingPill: View {
    let first: Element
    let second: Element
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Text(first.emoji)
            Image(systemName: "plus")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(second.emoji)
            ProgressView()
                .controlSize(.small)
        }
        .font(.system(size: 18))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [Color(hex: first.colorHex), Color(hex: second.colorHex)],
                                   startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1.5
                )
        )
        .scaleEffect(pulsing ? 1.05 : 0.97)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulsing = true }
        }
        .accessibilityLabel("Combining \(first.name) and \(second.name)")
    }
}

/// An expanding ring with a spray of sparks, for first-time discoveries.
private struct BurstView: View {
    let color: Color
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(expanded ? 0 : 0.8), lineWidth: expanded ? 1 : 6)
                .frame(width: 40, height: 40)
                .scaleEffect(expanded ? 3.2 : 0.4)
            ForEach(0..<10, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .offset(x: expanded ? 72 : 8)
                    .rotationEffect(.degrees(Double(index) * 36))
                    .opacity(expanded ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { expanded = true }
        }
    }
}

struct DiscoveryToast: View {
    let discovery: Discovery
    var label = "NEW DISCOVERY"

    private var tint: Color { Color(hex: discovery.element.colorHex) }

    var body: some View {
        HStack(spacing: 12) {
            Text(discovery.element.emoji)
                .font(.system(size: 28))
                .frame(width: 46, height: 46)
                .background(Circle().fill(tint.opacity(0.2)))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Text(discovery.element.name)
                    .font(.headline)
                Text("\(discovery.first.emoji) \(discovery.first.name) + \(discovery.second.emoji) \(discovery.second.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tint.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}
