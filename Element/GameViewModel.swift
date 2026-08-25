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

@MainActor
@Observable
final class GameViewModel {
    private(set) var discovered: [Element] = []
    private(set) var isGenerating = false
    var lastError: String?
    /// Set briefly whenever a *new* element is discovered, so the UI can show a toast.
    var newlyDiscovered: Element?

    /// Keyed by the two element names, sorted, so A+B and B+A share a cache entry.
    /// Loaded from `CombinationEntity` at launch and appended to as new
    /// combinations are generated, so repeat playthroughs of the same pair
    /// never need to hit the model again.
    private var cache: [String: Element] = [:]

    private let session: LanguageModelSession
    private let context: NSManagedObjectContext

    /// Non-nil when the on-device model isn't usable at all — checked eagerly
    /// so we can explain *why* before the user even attempts a combine, since
    /// a missing/unready model otherwise surfaces as an opaque bridged error
    /// from `respond(to:generating:)` with no actionable case info.
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

        // Prompt style modeled on the terse equation format community
        // reverse-engineering of Infinite Craft found in its own combination
        // calls ("word1" + "word2" = ?), rather than a descriptive sentence —
        // that framing biases the model toward a literal compound-word
        // answer instead of a creative-writing response.
        session = LanguageModelSession(instructions: """
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

        Also pick a single emoji and a hex color that fit the result.
        """)

        loadFromDisk()
        seedBaseCombinations()
    }

    private func cacheKey(for a: Element, _ b: Element) -> String {
        [a.name.lowercased(), b.name.lowercased()].sorted().joined(separator: "+")
    }

    /// Returns the resulting element (from cache or freshly generated), or
    /// `nil` on failure — `lastError`/`newlyDiscovered` are set as side
    /// effects either way, for the alert and toast.
    @discardableResult
    func combine(_ a: Element, _ b: Element, creativity: AICreativity) async -> Element? {
        lastError = nil
        let key = cacheKey(for: a, b)

        if let cached = cache[key] {
            addToDiscovered(cached)
            return cached
        }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let prompt = "\"\(a.name)\" + \"\(b.name)\" = ?"
            let options = GenerationOptions(temperature: creativity.temperature)
            let response = try await session.respond(to: prompt, generating: GeneratedElement.self, options: options)
            let result = Element(generated: response.content)
            cache[key] = result
            persistCombination(key: key, result: result)
            addToDiscovered(result)
            return result
        } catch let error as LanguageModelSession.GenerationError {
            lastError = "Couldn't combine \(a.name) and \(b.name): \(Self.describe(error))"
            return nil
        } catch {
            lastError = "Couldn't combine \(a.name) and \(b.name): \(error.localizedDescription)"
            return nil
        }
    }

    func toggleFavorite(_ element: Element) {
        guard let index = discovered.firstIndex(of: element) else { return }
        discovered[index].isFavorite.toggle()
        persistFavorite(discovered[index])
    }

    /// Wipes all persisted progress and returns to the four starting elements.
    func resetProgress() {
        let elementFetch: NSFetchRequest<NSFetchRequestResult> = ElementEntity.fetchRequest()
        let combinationFetch: NSFetchRequest<NSFetchRequestResult> = CombinationEntity.fetchRequest()
        for request in [elementFetch, combinationFetch] {
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            try? context.execute(delete)
        }
        try? context.save()

        cache.removeAll()
        discovered = Element.baseElements
    }

    private func addToDiscovered(_ element: Element) {
        guard !discovered.contains(element) else { return }
        discovered.append(element)
        newlyDiscovered = element
        persistElement(element)
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

    /// `GenerationError`'s default `localizedDescription` collapses to an
    /// opaque "error 1"-style NSError string, so switch over the case
    /// explicitly to get an actionable message.
    private static func describe(_ error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .assetsUnavailable:
            return "the on-device model isn't ready — make sure Apple Intelligence is turned on and finished downloading in Settings"
        case .guardrailViolation:
            return "that combination was blocked by the model's safety guardrails"
        case .unsupportedGuide:
            return "the generation schema used an unsupported guide (this is a code bug, not a content issue)"
        case .unsupportedLanguageOrLocale:
            return "the model doesn't support the current device language/locale"
        case .decodingFailure:
            return "the model's response didn't match the expected format"
        case .exceededContextWindowSize:
            return "the session's context window is full — try restarting the app"
        case .rateLimited:
            return "the model is rate-limited right now — try again shortly"
        @unknown default:
            return "\(error)"
        }
    }
}
