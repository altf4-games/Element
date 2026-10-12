//
//  ElementPill.swift
//  Element
//
//  Created by Pradyum Mistry on 12/10/26.
//

import SwiftUI

/// The Infinite Craft-style "emoji + name" chip used on the canvas and in
/// the tray. Sizes itself to its content, so long and short names both read
/// naturally instead of being squeezed into a fixed-width tile.
struct ElementPill: View {
    let element: Element
    /// Another tile is hovering over this one and will combine on release.
    var isHighlighted = false
    /// This tile is currently under the player's finger.
    var isLifted = false
    var compact = false

    private var tint: Color { Color(hex: element.colorHex) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous) }

    var body: some View {
        HStack(spacing: compact ? 5 : 6) {
            Text(element.emoji)
                .font(.system(size: compact ? 15 : 18))
            Text(element.name)
                .font(.system(compact ? .footnote : .subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 6 : 8)
        .background {
            ZStack {
                shape.fill(Color(.systemBackground))
                shape.fill(tint.opacity(isHighlighted ? 0.25 : 0.1))
            }
        }
        .overlay(
            shape.strokeBorder(tint.opacity(isHighlighted ? 1 : 0.35), lineWidth: isHighlighted ? 2 : 1)
        )
        .shadow(
            color: (isHighlighted ? tint : Color.black).opacity(isLifted || isHighlighted ? 0.25 : 0.07),
            radius: isLifted ? 10 : (isHighlighted ? 8 : 2),
            y: isLifted ? 6 : 1
        )
        .scaleEffect(isLifted ? 1.08 : (isHighlighted ? 1.06 : 1))
        .fixedSize()
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHighlighted)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isLifted)
        .accessibilityElement(children: .combine)
    }
}

/// Lays children out left to right, wrapping onto new rows — a custom
/// `Layout`, used for the expanded tray so pills of different widths pack
/// together the way Infinite Craft's sidebar does.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, maxWidth: bounds.width)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#Preview {
    VStack(spacing: 16) {
        ElementPill(element: Element.baseElements[0])
        ElementPill(element: Element.baseElements[1], isHighlighted: true)
        ElementPill(element: Element.baseElements[2], isLifted: true)
        ElementPill(element: Element.baseElements[3], compact: true)
    }
    .padding()
}
