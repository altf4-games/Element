//
//  GameViewModel.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import CoreData
import Foundation
import FoundationModels
import Observation
import os

/// Model failures are recovered from silently, so they're logged instead.
private let logger = Logger(subsystem: "com.altf4games.Element", category: "Combine")

/// How closely the model should stick to intuitive, expected combinations
/// (Water + Earth = Plant) versus inventing more surprising results. Backed
/// by `@AppStorage` in `SettingsView`, so it's a `String` raw value.
enum AICreativity: String, CaseIterable, Identifiable {
    case grounded
    case balanced
    case wild

    var id: String { rawValue }

    var label: String {
        switch self {
        case .grounded: "Grounded"
        case .balanced: "Balanced"
        case .wild: "Wild"
        }
    }

    var temperature: Double {
        switch self {
        case .grounded: 0.4
        case .balanced: 0.8
        case .wild: 1.3
        }
    }
}

/// A first-time discovery plus the pair that produced it, for the toast.
struct Discovery: Equatable {
    let element: Element
    let first: Element
    let second: Element
}

/// What a combine produced, and whether it was new to the player.
struct CombineOutcome {
    let element: Element
    let isNew: Bool
}

/// One known combination, resolved back to discovered elements.
struct Recipe: Identifiable {
    let id: String
    let first: Element
    let second: Element
    let result: Element
}

@MainActor
@Observable
final class GameViewModel {
    private(set) var discovered: [Element] = []
    /// A counter rather than a flag, since several combines can be in
    /// flight at once on the canvas.
    private(set) var pendingCount = 0
    var isGenerating: Bool { pendingCount > 0 }
    /// Set briefly whenever a *new* element is discovered, so the UI can show a toast.
    var newDiscovery: Discovery?

    /// Keyed by the two element names, sorted, so A+B and B+A share a cache entry.
    /// Loaded from `CombinationEntity` at launch and appended to as new
    /// combinations are generated, so repeat playthroughs of the same pair
    /// never need to hit the model again.
    private var cache: [String: Element] = [:]

    /// Each combine gets its own single-use session: a shared session keeps
    /// growing its transcript until it overflows the context window, and
    /// can't serve two requests at once. The next one is created and
    /// prewarmed ahead of time so the first token comes back faster.
    private var spareSession: LanguageModelSession?
    private let context: NSManagedObjectContext

    /// Non-nil when the on-device model isn't usable at all — checked eagerly
    /// so the Craft screen can explain *why*, and so combines skip straight
    /// to `RecipeBook` instead of waiting on a model that can't answer.
    let unavailableReason: String?

    init(context: NSManagedObjectContext) {
        self.context = context

        switch SystemLanguageModel.default.availability {
        case .available:
            unavailableReason = nil
        case .unavailable(.deviceNotEligible):
            unavailableReason = "This device isn't eligible for Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            unavailableReason = "Apple Intelligence is turned off. Enable it in Settings > Apple Intelligence & Siri."
        case .unavailable(.modelNotReady):
            unavailableReason = "The on-device model is still downloading. Check Settings > Apple Intelligence & Siri and try again shortly."
        case .unavailable(let reason):
            unavailableReason = "The on-device model is unavailable (\(reason))."
        }

        loadFromDisk()
        seedBaseCombinations()

        if unavailableReason == nil {
            spareSession = Self.makeSession()
            spareSession?.prewarm()
        }
    }

    // Prompt style modeled on the terse equation format community
    // reverse-engineering of Infinite Craft found in its own combination
    // calls ("word1" + "word2" = ?), rather than a descriptive sentence —
    // that framing biases the model toward a literal compound-word
    // answer instead of a creative-writing response.
    private static let instructions = """
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

    private static func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: instructions)
    }

    private func takeSession() -> LanguageModelSession {
        let session = spareSession ?? Self.makeSession()
        spareSession = Self.makeSession()
        spareSession?.prewarm()
        return session
    }

    private func cacheKey(for a: Element, _ b: Element) -> String {
        [a.name.lowercased(), b.name.lowercased()].sorted().joined(separator: "+")
    }

    private func existing(named name: String) -> Element? {
        discovered.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Always produces a result: from the cache, from the on-device model,
    /// or — if the model is unavailable, errors, times out, or only echoes
    /// an input — from `RecipeBook`. Sets `newDiscovery` for the toast.
    @discardableResult
    func combine(_ a: Element, _ b: Element, creativity: AICreativity) async -> CombineOutcome {
        let key = cacheKey(for: a, b)

        if let cached = cache[key] {
            return record(cached, from: a, b)
        }

        pendingCount += 1
        defer { pendingCount -= 1 }

        let made = await generate(a, b, creativity: creativity) ?? RecipeBook.combine(a, b)
        // If the result is something already discovered, reuse it so the same
        // name always keeps the same emoji and color.
        let result = existing(named: made.name) ?? made
        cache[key] = result
        persistCombination(key: key, result: result)
        return record(result, from: a, b)
    }

    /// Asks the model, or returns `nil` so the caller can fall back. An
    /// answer that just repeats an input ("Smoke + Smoke = Smoke") gets one
    /// retry with a hotter temperature before giving up.
    private func generate(_ a: Element, _ b: Element, creativity: AICreativity) async -> Element? {
        guard unavailableReason == nil else { return nil }

        let prompt = "\"\(a.name)\" + \"\(b.name)\" = ?"
        let temperatures = [creativity.temperature, max(creativity.temperature, 1.0)]
        for temperature in temperatures {
            let session = takeSession()
            let options = GenerationOptions(temperature: temperature)
            let request = Task {
                try await session.respond(to: prompt, generating: GeneratedElement.self, options: options)
            }
            // The model can occasionally stall; don't leave the player
            // staring at a spinner.
            let timeout = Task {
                try await Task.sleep(for: .seconds(10))
                request.cancel()
            }
            defer { timeout.cancel() }

            do {
                let element = Element(generated: try await request.value.content)
                let echoesInput = [a, b].contains { $0.name.caseInsensitiveCompare(element.name) == .orderedSame }
                if !echoesInput { return element }
            } catch {
                logger.error("Model couldn't combine \(a.name, privacy: .public) + \(b.name, privacy: .public): \(String(describing: error), privacy: .public)")
                return nil
            }
        }
        return nil
    }

    func toggleFavorite(_ element: Element) {
        guard let index = discovered.firstIndex(of: element) else { return }
        discovered[index].isFavorite.toggle()
        persistFavorite(discovered[index])
    }

    /// Wipes all persisted progress and returns to the four starting elements.
    func resetProgress() {
        // Deleting through the context (rather than `NSBatchDeleteRequest`)
        // keeps `@FetchRequest` in the Discoveries tab in sync immediately.
        for entity in (try? context.fetch(ElementEntity.fetchRequest())) ?? [] {
            context.delete(entity)
        }
        for entity in (try? context.fetch(CombinationEntity.fetchRequest())) ?? [] {
            context.delete(entity)
        }
        try? context.save()

        cache.removeAll()
        newDiscovery = nil
        discovered = Element.baseElements
        for base in Element.baseElements {
            persistElement(base)
        }
        seedBaseCombinations()
    }

    // MARK: - Recipes

    /// Every known combination whose inputs and result have all been
    /// discovered, derived from the combination cache.
    var recipes: [Recipe] {
        let byName = Dictionary(discovered.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        return cache.compactMap { key, result in
            let parts = key.split(separator: "+", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let first = byName[parts[0]],
                  let second = byName[parts[1]],
                  let result = byName[result.name.lowercased()]
            else { return nil }
            return Recipe(id: key, first: first, second: second, result: result)
        }
        .sorted { $0.id < $1.id }
    }

    func recipes(producing element: Element) -> [Recipe] {
        recipes.filter { $0.result == element }
    }

    func recipes(using element: Element) -> [Recipe] {
        recipes.filter { $0.first == element || $0.second == element }
    }

    private func record(_ element: Element, from a: Element, _ b: Element) -> CombineOutcome {
        if let known = existing(named: element.name) {
            return CombineOutcome(element: known, isNew: false)
        }
        discovered.append(element)
        persistElement(element)
        newDiscovery = Discovery(element: element, first: a, second: b)
        return CombineOutcome(element: element, isNew: true)
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        let elementRequest = ElementEntity.fetchRequest()
        elementRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ElementEntity.discoveredAt, ascending: true)]
        let storedElements = (try? context.fetch(elementRequest)) ?? []

        if storedElements.isEmpty {
            discovered = Element.baseElements
            for base in Element.baseElements {
                persistElement(base)
            }
        } else {
            discovered = storedElements.map(Element.init(entity:))
        }

        let combinationRequest = CombinationEntity.fetchRequest()
        let storedCombinations = (try? context.fetch(combinationRequest)) ?? []
        for entity in storedCombinations {
            guard let key = entity.key else { continue }
            cache[key] = Element(
                name: entity.resultName ?? "",
                emoji: entity.resultEmoji ?? "",
                colorHex: entity.resultColorHex ?? "888888",
                description: entity.resultDescription ?? ""
            )
        }
    }

    private func persistElement(_ element: Element) {
        let entity = ElementEntity(context: context)
        entity.id = element.id
        entity.name = element.name
        entity.emoji = element.emoji
        entity.colorHex = element.colorHex
        entity.elementDescription = element.description
        entity.isFavorite = element.isFavorite
        entity.discoveredAt = element.discoveredAt
        try? context.save()
    }

    private func persistFavorite(_ element: Element) {
        let request = ElementEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", element.id as CVarArg)
        request.fetchLimit = 1
        if let entity = try? context.fetch(request).first {
            entity.isFavorite = element.isFavorite
            try? context.save()
        }
    }

    private func persistCombination(key: String, result: Element) {
        let entity = CombinationEntity(context: context)
        entity.key = key
        entity.resultName = result.name
        entity.resultEmoji = result.emoji
        entity.resultColorHex = result.colorHex
        entity.resultDescription = result.description
        try? context.save()
    }

    /// Pins the six base-tier pairs to their well-known real-world results
    /// (matching what Infinite Craft itself produces) instead of leaving
    /// them to the model's variance — "Water + Earth" should always be
    /// "Plant", not sometimes "Mud". Only fills in combinations that aren't
    /// already cached, so it never clobbers a result from an earlier session.
    private func seedBaseCombinations() {
        let seeds: [(String, String, Element)] = [
            ("Fire", "Water", Element(name: "Steam", emoji: "♨️", colorHex: "CBD5E0", description: "A hot mist where fire meets water.")),
            ("Fire", "Earth", Element(name: "Lava", emoji: "🌋", colorHex: "FF4500", description: "Molten rock, glowing and unstoppable.")),
            ("Fire", "Air", Element(name: "Smoke", emoji: "🌫️", colorHex: "708090", description: "A hazy trail left behind by flame.")),
            ("Water", "Earth", Element(name: "Plant", emoji: "🌱", colorHex: "2ECC71", description: "Something green, reaching for the sun.")),
            ("Water", "Air", Element(name: "Rain", emoji: "🌧️", colorHex: "4A90D9", description: "Water falling from the sky.")),
            ("Earth", "Air", Element(name: "Dust", emoji: "🏜️", colorHex: "C2B280", description: "Fine, dry particles carried on the wind.")),
        ]

        for (first, second, result) in seeds {
            let key = [first.lowercased(), second.lowercased()].sorted().joined(separator: "+")
            guard cache[key] == nil else { continue }
            cache[key] = result
            persistCombination(key: key, result: result)
        }
    }
}
