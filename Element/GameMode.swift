//
//  GameMode.swift
//  Element
//
//  Created by Pradyum Mistry on 21/10/26.
//

import Foundation

/// Which world the player is crafting in. Each mode has its own starting
/// elements, pinned recipes, AI prompt, and saved progress.
enum GameMode: String, CaseIterable, Identifiable {
    case classic
    case periodic

    var id: String { rawValue }

    static let storageKey = "gameMode"

    /// The mode saved from last time, read straight from `UserDefaults` so
    /// views can build their fetch requests before the view model exists.
    static var current: GameMode {
        GameMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .classic
    }

    var label: String {
        switch self {
        case .classic: "Classic"
        case .periodic: "Periodic"
        }
    }

    var icon: String {
        switch self {
        case .classic: "flame.fill"
        case .periodic: "atom"
        }
    }

    var tagline: String {
        switch self {
        case .classic: "Start with Fire, Water, Earth, and Air and combine your way to anything."
        case .periodic: "Start with real chemical elements. Combine them into compounds, minerals, and materials."
        }
    }

    var discoveryLabel: String {
        switch self {
        case .classic: "NEW DISCOVERY"
        case .periodic: "NEW COMPOUND"
        }
    }

    var emptyStateHint: String {
        switch self {
        case .classic: "Tap an element below, or hold and drag it up here.\nDrop one element onto another to combine them."
        case .periodic: "Tap an element below, or hold and drag it up here.\nTry hydrogen and oxygen, or sodium and chlorine."
        }
    }

    var baseElements: [Element] {
        switch self {
        case .classic:
            Element.baseElements
        case .periodic:
            [
                Element(name: "Hydrogen", emoji: "🎈", colorHex: "4FC3F7", description: "H · Atomic number 1. The lightest element, and the most common one in the universe."),
                Element(name: "Oxygen", emoji: "🫁", colorHex: "EF5350", description: "O · Atomic number 8. What you breathe, and what makes fire burn."),
                Element(name: "Carbon", emoji: "⚫", colorHex: "546E7A", description: "C · Atomic number 6. The backbone of all known life."),
                Element(name: "Nitrogen", emoji: "🌫️", colorHex: "7E57C2", description: "N · Atomic number 7. Makes up most of the air around you."),
                Element(name: "Sodium", emoji: "🟡", colorHex: "FBC02D", description: "Na · Atomic number 11. A soft metal that reacts wildly with water."),
                Element(name: "Chlorine", emoji: "☣️", colorHex: "9CCC65", description: "Cl · Atomic number 17. A pale green gas that keeps pools clean."),
                Element(name: "Iron", emoji: "🔩", colorHex: "78909C", description: "Fe · Atomic number 26. The metal that built the modern world."),
                Element(name: "Sulfur", emoji: "🟨", colorHex: "FDD835", description: "S · Atomic number 16. A bright yellow solid with a famously bad smell."),
            ]
        }
    }

    /// Well-known pairs pinned to their real-world results, so the start of
    /// each mode is consistent rather than left to the model's variance.
    var seedRecipes: [(String, String, Element)] {
        switch self {
        case .classic:
            [
                ("Fire", "Water", Element(name: "Steam", emoji: "♨️", colorHex: "CBD5E0", description: "A hot mist where fire meets water.")),
                ("Fire", "Earth", Element(name: "Lava", emoji: "🌋", colorHex: "FF4500", description: "Molten rock, glowing and unstoppable.")),
                ("Fire", "Air", Element(name: "Smoke", emoji: "🌫️", colorHex: "708090", description: "A hazy trail left behind by flame.")),
                ("Water", "Earth", Element(name: "Plant", emoji: "🌱", colorHex: "2ECC71", description: "Something green, reaching for the sun.")),
                ("Water", "Air", Element(name: "Rain", emoji: "🌧️", colorHex: "4A90D9", description: "Water falling from the sky.")),
                ("Earth", "Air", Element(name: "Dust", emoji: "🏜️", colorHex: "C2B280", description: "Fine, dry particles carried on the wind.")),
            ]
        case .periodic:
            [
                ("Hydrogen", "Oxygen", Element(name: "Water", emoji: "💧", colorHex: "3498DB", description: "H₂O · Two hydrogens and an oxygen, the molecule of life.")),
                ("Carbon", "Oxygen", Element(name: "Carbon Dioxide", emoji: "🫧", colorHex: "90A4AE", description: "CO₂ · The gas you breathe out and plants breathe in.")),
                ("Hydrogen", "Nitrogen", Element(name: "Ammonia", emoji: "🧪", colorHex: "AED581", description: "NH₃ · A sharp-smelling gas used in fertilizer and cleaners.")),
                ("Carbon", "Hydrogen", Element(name: "Methane", emoji: "🔥", colorHex: "FF8A65", description: "CH₄ · The simplest hydrocarbon, and the main part of natural gas.")),
                ("Sodium", "Chlorine", Element(name: "Salt", emoji: "🧂", colorHex: "ECEFF1", description: "NaCl · A violent metal and a toxic gas, tamed into table salt.")),
                ("Iron", "Oxygen", Element(name: "Rust", emoji: "🟠", colorHex: "B5532A", description: "Fe₂O₃ · What iron turns into when it meets oxygen and time.")),
                ("Iron", "Carbon", Element(name: "Steel", emoji: "⚙️", colorHex: "90A4AE", description: "Fe + C · Iron with a pinch of carbon, much stronger than either.")),
                ("Sulfur", "Oxygen", Element(name: "Sulfur Dioxide", emoji: "🌋", colorHex: "FFB74D", description: "SO₂ · The sharp gas you smell near volcanoes.")),
            ]
        }
    }

    /// The system prompt for the on-device model.
    ///
    /// Prompt style modeled on the terse equation format community
    /// reverse-engineering of Infinite Craft found in its own combination
    /// calls ("word1" + "word2" = ?), rather than a descriptive sentence —
    /// that framing biases the model toward a literal compound-word
    /// answer instead of a creative-writing response.
    var instructions: String {
        switch self {
        case .classic:
            """
            You combine two words according to their real-world meaning, like a \
            crafting game. Answer with the single most obvious, common-sense \
            result — the one almost anyone would guess first. Not the most \
            original, clever, or unexpected one.

            Rules:
            - Prefer a single common noun. Avoid adjectives.
            - Keep it general and simple, not hyper-specific.
            - Never answer with either input word unchanged.
            - Two words maximum.

            Examples:
            - "Water" + "Earth" = "Plant"
            - "Fire" + "Water" = "Steam"
            - "Fire" + "Earth" = "Lava"
            - "Water" + "Air" = "Rain"
            - "Fire" + "Air" = "Smoke"
            - "Earth" + "Air" = "Dust"
            - "Fire" + "Fire" = "Inferno"

            Also pick a single emoji and a hex color that fit the result.
            """
        case .periodic:
            """
            You combine two chemical substances (elements or compounds) like a \
            chemistry crafting game. Answer with the single most common real \
            result: a well-known compound, molecule, mineral, alloy, or material \
            that actually exists. Use the everyday name, not a long chemical name.

            Rules:
            - The result must be real chemistry or materials science.
            - Prefer a familiar name (Salt, Rust, Steel, Glass) over a formula.
            - Never answer with either input unchanged.
            - Two words maximum.
            - In the description, start with the chemical formula, then one short \
            plain sentence.

            Examples:
            - "Hydrogen" + "Oxygen" = "Water"
            - "Sodium" + "Chlorine" = "Salt"
            - "Carbon" + "Oxygen" = "Carbon Dioxide"
            - "Iron" + "Oxygen" = "Rust"
            - "Iron" + "Carbon" = "Steel"
            - "Water" + "Salt" = "Brine"
            - "Carbon" + "Carbon" = "Diamond"

            Also pick a single emoji and a hex color that fit the result.
            """
        }
    }
}
