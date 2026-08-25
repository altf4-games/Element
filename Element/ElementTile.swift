//
//  ElementTile.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import SwiftUI

struct ElementTile: View {
    let element: Element
    var isSelected: Bool = false
    /// Smaller variant for tight spaces (the tray). Previously the tray
    /// forced this view into a fixed 68pt frame shorter than its natural
    /// ~92pt layout, clipping the top of the circle badge — this gives it a
    /// real smaller layout instead of squashing the regular one.
    var compact: Bool = false

    private var tint: Color { Color(hex: element.colorHex) }
    private var circleDiameter: CGFloat { compact ? 38 : 48 }
    private var emojiSize: CGFloat { compact ? 19 : 24 }
    private var minTileHeight: CGFloat { compact ? 72 : 92 }

    var body: some View {
        VStack(spacing: compact ? 6 : 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.9), tint.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: circleDiameter, height: circleDiameter)
                    .shadow(color: tint.opacity(0.35), radius: isSelected ? 6 : 3, y: 2)

                Text(element.emoji)
                    .font(.system(size: emojiSize))
            }

            Text(element.name)
                .font(compact ? .caption2 : .caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: minTileHeight)
        .padding(.vertical, compact ? 8 : 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background)
        )
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(isSelected ? 0.2 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(isSelected ? 0.9 : 0.12), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06), radius: isSelected ? 8 : 3, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

extension Color {
    /// Parses a 6-digit hex string (with or without a leading `#`). Falls back
    /// to gray for malformed input — generated color strings are untrusted.
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }

        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            self = .gray
            return
        }

        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

#Preview {
    HStack {
        ElementTile(element: Element.baseElements[0])
        ElementTile(element: Element.baseElements[1], isSelected: true)
    }
    .padding()
}
