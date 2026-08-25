//
//  GameViewModel.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class GameViewModel {
    private(set) var discovered: [Element] = Element.baseElements
    private(set) var isGenerating = false
    var lastError: String?
    /// Set briefly whenever a *new* element is discovered, so the UI can show a toast.
    var newlyDiscovered: Element?

    /// Keyed by the two element names, sorted, so A+B and B+A share a cache entry.
    private var cache: [String: Element] = [:]

    private let session: LanguageModelSession

    /// Non-nil when the on-device model isn't usable at all — checked eagerly
    /// so we can explain *why* before the user even attempts a combine, since
    /// a missing/unready model otherwise surfaces as an opaque bridged error
    /// from `respond(to:generating:)` with no actionable case info.
    let unavailableReason: String?

    init() {
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

        session = LanguageModelSession(instructions: """
        You are a combination-generation engine for an element-discovery game, \
        in the spirit of Little Alchemy. Given two element names, invent a new, \
        distinct element that plausibly results from combining them. Keep names \
        short and playful (1-3 words). Pick an emoji and color that fit the \
        result. Never just echo one of the two input names back — the result \
        must be a genuinely new element.
        """)
    }

    private func cacheKey(for a: Element, _ b: Element) -> String {
        [a.name.lowercased(), b.name.lowercased()].sorted().joined(separator: "+")
    }

    func combine(_ a: Element, _ b: Element) async {
        lastError = nil
        let key = cacheKey(for: a, b)

        if let cached = cache[key] {
            addToDiscovered(cached)
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let prompt = "Combine \(a.name) (\(a.emoji)) and \(b.name) (\(b.emoji)) into a new element."
            let response = try await session.respond(to: prompt, generating: GeneratedElement.self)
            let result = Element(generated: response.content)
            cache[key] = result
            addToDiscovered(result)
        } catch let error as LanguageModelSession.GenerationError {
            lastError = "Couldn't combine \(a.name) and \(b.name): \(Self.describe(error))"
        } catch {
            lastError = "Couldn't combine \(a.name) and \(b.name): \(error.localizedDescription)"
        }
    }

    private func addToDiscovered(_ element: Element) {
        guard !discovered.contains(element) else { return }
        discovered.append(element)
        newlyDiscovered = element
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
