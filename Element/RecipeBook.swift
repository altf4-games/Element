//
//  RecipeBook.swift
//  Element
//
//  Created by Pradyum Mistry on 12/10/26.
//

import Foundation

/// The offline fallback for when the on-device model can't answer — it's
/// unavailable, it errors, it times out, or it only echoes an input back.
/// Combining should never dead-end in an error, so this always returns
/// *something*: a hand-written recipe if there is one, otherwise a result
/// built from the two inputs' names. Its results aren't cached, so the
/// model gets another try at the same pair later.
enum RecipeBook {
    static func combine(_ a: Element, _ b: Element) -> Element {
        // Sorted so A + B and B + A always fall back to the same result.
        let (first, second) = a.name.lowercased() <= b.name.lowercased() ? (a, b) : (b, a)

        if let entry = recipes[key(first.name, second.name)] {
            return Element(name: entry.name, emoji: entry.emoji, colorHex: entry.colorHex, description: entry.description)
        }
        return improvise(first, second)
    }

    // MARK: - Improvised results

    /// Infinite Craft-style compounds: "Flying Lava", "Living Stone",
    /// "Giant Smoke". One input lends an adjective and the other is the noun.
    private static func improvise(_ a: Element, _ b: Element) -> Element {
        let colorHex = blend(a.colorHex, b.colorHex)

        if a.name.caseInsensitiveCompare(b.name) == .orderedSame {
            let prefix = ["Giant", "Ancient", "Cosmic"].first { !a.name.hasPrefix($0) } ?? "Cosmic"
            return Element(
                name: "\(prefix) \(a.name)",
                emoji: a.emoji,
                colorHex: a.colorHex,
                description: "Twice the \(a.name.lowercased()), twice the trouble."
            )
        }

        var name: String
        let emoji: String
        if let adjective = adjective(for: a) {
            name = "\(adjective) \(lastWord(b.name))"
            emoji = b.emoji
        } else if let adjective = adjective(for: b) {
            name = "\(adjective) \(lastWord(a.name))"
            emoji = a.emoji
        } else {
            name = "\(lastWord(a.name)) \(lastWord(b.name))"
            emoji = b.emoji
        }
        // e.g. Fire + Burning Plant would otherwise give back Burning Plant.
        if [a, b].contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            name = "Giant \(name)"
        }

        return Element(
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            description: "\(a.name) and \(b.name), fused into something new."
        )
    }

    /// The flavor an element lends when it's the modifier in a compound.
    private static func adjective(for element: Element) -> String? {
        let word = lastWord(element.name).lowercased()
        return traits.first { $0.words.contains(word) }?.adjective
    }

    private static let traits: [(adjective: String, words: Set<String>)] = [
        ("Burning", ["fire", "inferno", "lava", "magma", "eruption", "wildfire", "campfire"]),
        ("Liquid", ["water", "rain", "lake", "sea", "ocean", "wave", "flood", "river", "waterfall"]),
        ("Rocky", ["earth", "stone", "mountain", "rock", "sand", "dust", "obsidian", "island"]),
        ("Flying", ["air", "wind", "cloud", "sky", "tornado", "sandstorm"]),
        ("Living", ["plant", "tree", "forest", "flower", "seed", "pollen", "cactus", "lily"]),
        ("Misty", ["smoke", "steam", "fog", "smog", "haze", "mist", "ash", "soot", "geyser"]),
        ("Electric", ["lightning", "storm", "energy"]),
        ("Iron", ["metal", "sword", "hammer", "rust", "axe"]),
        ("Solar", ["sun", "rainbow"]),
    ]

    private static func lastWord(_ name: String) -> String {
        name.split(separator: " ").last.map(String.init) ?? name
    }

    /// Averages two hex colors, so a compound looks like both parents.
    private static func blend(_ first: String, _ second: String) -> String {
        guard let x = UInt32(first, radix: 16), let y = UInt32(second, radix: 16) else { return first }
        let channel = { (shift: UInt32) in ((x >> shift & 0xFF) + (y >> shift & 0xFF)) / 2 }
        return String(format: "%02X%02X%02X", channel(16), channel(8), channel(0))
    }

    // MARK: - Hand-written recipes

    private struct Entry {
        let name: String
        let emoji: String
        let colorHex: String
        let description: String
    }

    private static func key(_ a: String, _ b: String) -> String {
        [a.lowercased(), b.lowercased()].sorted().joined(separator: "+")
    }

    private static let recipes: [String: Entry] = {
        let list: [(String, String, Entry)] = [
            // Doubles
            ("Fire", "Fire", Entry(name: "Inferno", emoji: "🔥", colorHex: "FF4500", description: "A fire so big it makes its own weather.")),
            ("Water", "Water", Entry(name: "Lake", emoji: "🏞️", colorHex: "3A86C8", description: "Water that decided to stay a while.")),
            ("Earth", "Earth", Entry(name: "Mountain", emoji: "⛰️", colorHex: "8B7D6B", description: "Earth piled on earth until it touched the clouds.")),
            ("Air", "Air", Entry(name: "Wind", emoji: "🌬️", colorHex: "B0D8F0", description: "Air with somewhere to be.")),
            ("Steam", "Steam", Entry(name: "Cloud", emoji: "☁️", colorHex: "DDE6EE", description: "A floating pile of tiny droplets.")),
            ("Smoke", "Smoke", Entry(name: "Smog", emoji: "🌫️", colorHex: "7A7A7A", description: "Smoke that settled over a whole city.")),
            ("Lava", "Lava", Entry(name: "Volcano", emoji: "🌋", colorHex: "D84315", description: "A mountain with a molten temper.")),
            ("Dust", "Dust", Entry(name: "Sand", emoji: "⏳", colorHex: "E2C792", description: "Countless grains, each one patient.")),
            ("Rain", "Rain", Entry(name: "Flood", emoji: "🌊", colorHex: "2E6DA4", description: "When the rain just won't stop.")),
            ("Plant", "Plant", Entry(name: "Garden", emoji: "🪴", colorHex: "43A047", description: "Plants that found good company.")),
            ("Cloud", "Cloud", Entry(name: "Storm", emoji: "⛈️", colorHex: "5C6B7A", description: "Clouds that got into an argument.")),
            ("Wind", "Wind", Entry(name: "Tornado", emoji: "🌪️", colorHex: "9AA5B1", description: "Wind spinning faster than it should.")),
            ("Stone", "Stone", Entry(name: "Wall", emoji: "🧱", colorHex: "A1887F", description: "Stones stacked with purpose.")),
            ("Sand", "Sand", Entry(name: "Desert", emoji: "🏜️", colorHex: "E0B872", description: "Sand as far as the eye can see.")),
            ("Tree", "Tree", Entry(name: "Forest", emoji: "🌲", colorHex: "2E7D32", description: "Trees standing shoulder to shoulder.")),
            ("Lake", "Lake", Entry(name: "Sea", emoji: "🌊", colorHex: "1E6FA8", description: "A lake that kept growing.")),
            ("Sea", "Sea", Entry(name: "Ocean", emoji: "🌊", colorHex: "0D47A1", description: "Deep, wide, and full of secrets.")),
            ("Mountain", "Mountain", Entry(name: "Mountain Range", emoji: "🏔️", colorHex: "78909C", description: "Mountains holding hands across the horizon.")),
            ("Brick", "Brick", Entry(name: "House", emoji: "🏠", colorHex: "C0603A", description: "Bricks arranged into a home.")),
            ("Wall", "Wall", Entry(name: "House", emoji: "🏠", colorHex: "C0603A", description: "Walls arranged into a home.")),
            ("Mud", "Mud", Entry(name: "Swamp", emoji: "🐸", colorHex: "556B2F", description: "Murky, muddy, and full of life.")),
            ("Flower", "Flower", Entry(name: "Bouquet", emoji: "💐", colorHex: "F48FB1", description: "Flowers gathered for someone special.")),

            // Base tier and one step beyond
            ("Lava", "Water", Entry(name: "Stone", emoji: "🪨", colorHex: "8A8A8A", description: "Lava cooled in a hiss of steam.")),
            ("Air", "Lava", Entry(name: "Stone", emoji: "🪨", colorHex: "8A8A8A", description: "Lava cooled by the wind.")),
            ("Earth", "Lava", Entry(name: "Volcano", emoji: "🌋", colorHex: "D84315", description: "A mountain with a molten temper.")),
            ("Fire", "Lava", Entry(name: "Eruption", emoji: "💥", colorHex: "FF5722", description: "The moment a volcano can't hold it in.")),
            ("Air", "Steam", Entry(name: "Cloud", emoji: "☁️", colorHex: "DDE6EE", description: "A floating pile of tiny droplets.")),
            ("Steam", "Water", Entry(name: "Hot Spring", emoji: "♨️", colorHex: "80CBC4", description: "Warm water bubbling up from below.")),
            ("Earth", "Steam", Entry(name: "Geyser", emoji: "⛲", colorHex: "90A4AE", description: "The ground letting off steam.")),
            ("Fire", "Steam", Entry(name: "Steam Engine", emoji: "🚂", colorHex: "6D4C41", description: "Fire and steam, put to work.")),
            ("Smoke", "Water", Entry(name: "Fog", emoji: "🌁", colorHex: "B0BEC5", description: "A cloud that got lost and came down to visit.")),
            ("Air", "Smoke", Entry(name: "Haze", emoji: "🌫️", colorHex: "A0A8B0", description: "Smoke spread thin across the sky.")),
            ("Fire", "Smoke", Entry(name: "Ash", emoji: "🌫️", colorHex: "616161", description: "What's left when the fire is done.")),
            ("Earth", "Smoke", Entry(name: "Soot", emoji: "⚫", colorHex: "424242", description: "Smoke that settled into the ground.")),
            ("Smoke", "Steam", Entry(name: "Fog", emoji: "🌁", colorHex: "B0BEC5", description: "A cloud that got lost and came down to visit.")),
            ("Plant", "Water", Entry(name: "Water Lily", emoji: "🪷", colorHex: "F8BBD0", description: "A flower that floats.")),
            ("Earth", "Plant", Entry(name: "Tree", emoji: "🌳", colorHex: "388E3C", description: "A plant that kept reaching up.")),
            ("Fire", "Plant", Entry(name: "Campfire", emoji: "🏕️", colorHex: "FF7043", description: "Crackling wood and good stories.")),
            ("Air", "Plant", Entry(name: "Pollen", emoji: "🌼", colorHex: "FFD54F", description: "Tiny specks riding the breeze.")),
            ("Plant", "Rain", Entry(name: "Flower", emoji: "🌸", colorHex: "F06292", description: "A plant that got enough rain to bloom.")),
            ("Earth", "Rain", Entry(name: "Mud", emoji: "🟫", colorHex: "6D4C41", description: "Squishy, sticky, and everywhere.")),
            ("Fire", "Rain", Entry(name: "Steam", emoji: "♨️", colorHex: "CBD5E0", description: "A hot mist where fire meets water.")),
            ("Air", "Rain", Entry(name: "Storm", emoji: "⛈️", colorHex: "5C6B7A", description: "Rain with a bad attitude.")),
            ("Cloud", "Rain", Entry(name: "Storm", emoji: "⛈️", colorHex: "5C6B7A", description: "Rain with a bad attitude.")),
            ("Dust", "Rain", Entry(name: "Mud", emoji: "🟫", colorHex: "6D4C41", description: "Squishy, sticky, and everywhere.")),
            ("Dust", "Water", Entry(name: "Mud", emoji: "🟫", colorHex: "6D4C41", description: "Squishy, sticky, and everywhere.")),
            ("Dust", "Fire", Entry(name: "Gunpowder", emoji: "💥", colorHex: "37474F", description: "Dust with an explosive personality.")),
            ("Air", "Dust", Entry(name: "Sandstorm", emoji: "🌪️", colorHex: "D7B98E", description: "The desert going for a run.")),
            ("Dust", "Earth", Entry(name: "Sand", emoji: "⏳", colorHex: "E2C792", description: "Countless grains, each one patient.")),
            ("Dust", "Plant", Entry(name: "Pollen", emoji: "🌼", colorHex: "FFD54F", description: "Tiny specks riding the breeze.")),

            // Deeper tiers
            ("Fire", "Stone", Entry(name: "Metal", emoji: "🔩", colorHex: "90A4AE", description: "Stone that learned to shine.")),
            ("Stone", "Water", Entry(name: "Sand", emoji: "⏳", colorHex: "E2C792", description: "Stone worn down by the tide.")),
            ("Earth", "Stone", Entry(name: "Mountain", emoji: "⛰️", colorHex: "8B7D6B", description: "Earth piled on earth until it touched the clouds.")),
            ("Fire", "Metal", Entry(name: "Sword", emoji: "⚔️", colorHex: "B0BEC5", description: "Metal forged with a sharp edge.")),
            ("Metal", "Stone", Entry(name: "Hammer", emoji: "🔨", colorHex: "8D6E63", description: "For when you really mean it.")),
            ("Metal", "Water", Entry(name: "Rust", emoji: "🟠", colorHex: "B5532A", description: "Metal that stayed out in the rain.")),
            ("Metal", "Tree", Entry(name: "Axe", emoji: "🪓", colorHex: "8D6E63", description: "A tree's least favorite tool.")),
            ("Mountain", "Water", Entry(name: "Waterfall", emoji: "💦", colorHex: "4FC3F7", description: "Water taking the scenic route down.")),
            ("Mountain", "Rain", Entry(name: "River", emoji: "🏞️", colorHex: "29B6F6", description: "Rain finding its way back to the sea.")),
            ("Fire", "Mountain", Entry(name: "Volcano", emoji: "🌋", colorHex: "D84315", description: "A mountain with a molten temper.")),
            ("Cloud", "Water", Entry(name: "Rain", emoji: "🌧️", colorHex: "4A90D9", description: "Water falling from the sky.")),
            ("Cloud", "Fire", Entry(name: "Lightning", emoji: "⚡", colorHex: "FFEB3B", description: "A cloud's sudden spark of brilliance.")),
            ("Air", "Cloud", Entry(name: "Sky", emoji: "🌤️", colorHex: "81D4FA", description: "Wide open and endlessly blue.")),
            ("Cloud", "Earth", Entry(name: "Fog", emoji: "🌁", colorHex: "B0BEC5", description: "A cloud that got lost and came down to visit.")),
            ("Fire", "Sky", Entry(name: "Sun", emoji: "☀️", colorHex: "FFC107", description: "The biggest fire anyone has ever seen.")),
            ("Rain", "Sun", Entry(name: "Rainbow", emoji: "🌈", colorHex: "BA68C8", description: "Sunlight caught bending in the rain.")),
            ("Plant", "Sun", Entry(name: "Flower", emoji: "🌸", colorHex: "F06292", description: "A plant that soaked up enough sun to bloom.")),
            ("Fire", "Wind", Entry(name: "Wildfire", emoji: "🔥", colorHex: "E65100", description: "Fire with the wind at its back.")),
            ("Water", "Wind", Entry(name: "Wave", emoji: "🌊", colorHex: "1E88E5", description: "Water pushed into motion.")),
            ("Cloud", "Wind", Entry(name: "Storm", emoji: "⛈️", colorHex: "5C6B7A", description: "Clouds that got into an argument.")),
            ("Plant", "Wind", Entry(name: "Seed", emoji: "🌰", colorHex: "A1887F", description: "A plant's way of traveling.")),
            ("Earth", "Lake", Entry(name: "Swamp", emoji: "🐸", colorHex: "556B2F", description: "Murky, muddy, and full of life.")),
            ("Fire", "Lake", Entry(name: "Steam", emoji: "♨️", colorHex: "CBD5E0", description: "A hot mist where fire meets water.")),
            ("Fire", "Sea", Entry(name: "Salt", emoji: "🧂", colorHex: "ECEFF1", description: "What the sea leaves behind.")),
            ("Fire", "Ocean", Entry(name: "Salt", emoji: "🧂", colorHex: "ECEFF1", description: "What the sea leaves behind.")),
            ("Earth", "Ocean", Entry(name: "Island", emoji: "🏝️", colorHex: "4DB6AC", description: "A little piece of land with ocean views.")),
            ("Earth", "Sea", Entry(name: "Island", emoji: "🏝️", colorHex: "4DB6AC", description: "A little piece of land with ocean views.")),
            ("Volcano", "Water", Entry(name: "Island", emoji: "🏝️", colorHex: "4DB6AC", description: "A little piece of land with ocean views.")),
            ("Air", "Volcano", Entry(name: "Ash", emoji: "🌫️", colorHex: "616161", description: "What's left when the fire is done.")),
            ("Fire", "Sand", Entry(name: "Glass", emoji: "🪟", colorHex: "B3E5FC", description: "Sand that learned to be see-through.")),
            ("Sand", "Water", Entry(name: "Beach", emoji: "🏖️", colorHex: "FFE082", description: "Where the land meets the waves.")),
            ("Plant", "Sand", Entry(name: "Cactus", emoji: "🌵", colorHex: "66BB6A", description: "A plant that refuses to be thirsty.")),
            ("Desert", "Plant", Entry(name: "Cactus", emoji: "🌵", colorHex: "66BB6A", description: "A plant that refuses to be thirsty.")),
            ("Desert", "Water", Entry(name: "Oasis", emoji: "🏝️", colorHex: "26A69A", description: "Relief in the middle of nowhere.")),
            ("Glass", "Sand", Entry(name: "Hourglass", emoji: "⌛", colorHex: "D7CCC8", description: "Time, poured slowly.")),
            ("Fire", "Tree", Entry(name: "Campfire", emoji: "🏕️", colorHex: "FF7043", description: "Crackling wood and good stories.")),
            ("Fire", "Forest", Entry(name: "Wildfire", emoji: "🔥", colorHex: "E65100", description: "Fire with the wind at its back.")),
            ("Earth", "Tree", Entry(name: "Forest", emoji: "🌲", colorHex: "2E7D32", description: "Trees standing shoulder to shoulder.")),
            ("Rain", "Tree", Entry(name: "Fruit", emoji: "🍎", colorHex: "E53935", description: "A tree's sweetest reward.")),
            ("Air", "Tree", Entry(name: "Leaf", emoji: "🍃", colorHex: "7CB342", description: "A tree letting go of a little piece.")),
            ("Fire", "Mud", Entry(name: "Brick", emoji: "🧱", colorHex: "C0603A", description: "Mud baked until it means business.")),
            ("Mud", "Plant", Entry(name: "Swamp", emoji: "🐸", colorHex: "556B2F", description: "Murky, muddy, and full of life.")),
            ("Lightning", "Water", Entry(name: "Life", emoji: "🧬", colorHex: "AB47BC", description: "The spark that started everything.")),
            ("Life", "Earth", Entry(name: "Human", emoji: "🧑", colorHex: "FFAB91", description: "Curious, clever, and a little messy.")),
        ]
        var table: [String: Entry] = [:]
        for (a, b, entry) in list {
            table[key(a, b)] = entry
        }
        return table
    }()
}
