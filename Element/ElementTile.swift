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

    private var tint: Color { Color(hex: element.colorHex) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.9), tint.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: tint.opacity(0.35), radius: isSelected ? 6 : 3, y: 2)

                Text(element.emoji)
                    .font(.system(size: 24))
            }

            Text(element.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background)
        )
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(isSelected ? 0.18 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: isSelected ? 8 : 3, y: 2)
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
