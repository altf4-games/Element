//
//  Element.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import Foundation
import FoundationModels

/// The shape the language model fills in for a newly-discovered combination.
/// Kept flat and simple per Foundation Models guidance — field order matters
/// because later fields can be conditioned on earlier ones in the same pass.
@Generable
struct GeneratedElement {
    @Guide(description: "A short, grounded name for the resulting element or concept (1-3 words). Never just repeat one of the two input names.")
    var name: String

    @Guide(description: "A single emoji that best represents this element.")
    var emoji: String

    @Guide(description: "A 6-digit hex color code (no #) that fits the element's theme, e.g. 'FF5733'.")
    var colorHex: String

    @Guide(description: "A one-sentence, playful description of the element.")
    var description: String
}

/// The app-facing model. Distinct from `GeneratedElement` so the UI never has
/// to deal with model-generation concerns (and so base elements — which
/// aren't generated — fit the same type). `Codable` backs the JSON export
/// feature; `isFavorite`/`discoveredAt` are local UI/persistence metadata
/// that the model never generates.
struct Element: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let emoji: String
    let colorHex: String
    let description: String
    var isFavorite: Bool
    var discoveredAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        colorHex: String,
        description: String,
        isFavorite: Bool = false,
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.description = description
        self.isFavorite = isFavorite
        self.discoveredAt = discoveredAt
    }

    init(generated: GeneratedElement) {
        self.init(
            name: generated.name,
            emoji: generated.emoji,
            colorHex: generated.colorHex,
            description: generated.description
        )
    }

    init(entity: ElementEntity) {
        self.init(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            emoji: entity.emoji ?? "",
            colorHex: entity.colorHex ?? "888888",
            description: entity.elementDescription ?? "",
            isFavorite: entity.isFavorite,
            discoveredAt: entity.discoveredAt ?? Date()
        )
    }

    static func == (lhs: Element, rhs: Element) -> Bool {
        lhs.name.caseInsensitiveCompare(rhs.name) == .orderedSame
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name.lowercased())
    }
}

extension Element {
    /// The four starting elements. Everything else in the game is generated —
    /// this is the only hardcoded content, and it exists purely to seed play.
    static let baseElements: [Element] = [
        Element(name: "Fire", emoji: "🔥", colorHex: "FF5733", description: "Hot, bright, and always hungry for more."),
        Element(name: "Water", emoji: "💧", colorHex: "3498DB", description: "Flows wherever it can, calm until it isn't."),
        Element(name: "Earth", emoji: "🌍", colorHex: "8B5E3C", description: "Solid ground beneath everything else."),
        Element(name: "Air", emoji: "💨", colorHex: "AED6F1", description: "Invisible, everywhere, and always moving."),
    ]

    /// A stable pseudo-random map coordinate derived from the element's name,
    /// so the same element always lands in the same spot on the Atlas map
    /// across launches without needing to persist coordinates separately.
    var atlasCoordinateSeed: (latFraction: Double, lonFraction: Double) {
        var hasher = Hasher()
        hasher.combine(name.lowercased())
        let hash = UInt64(bitPattern: Int64(hasher.finalize()))
        let latFraction = Double(hash % 10_000) / 10_000
        let lonFraction = Double((hash / 10_000) % 10_000) / 10_000
        return (latFraction, lonFraction)
    }
}
