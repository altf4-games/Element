# Element

Combine anything. Discover what the world hasn't named yet.

Element is a small iOS game in the spirit of Little Alchemy or Infinite Craft: you start with four elements (Fire, Water, Earth, Air), drag or tap two together, and get something new. The twist is that nothing is hardcoded. Every combination past the starting four is generated on the spot by Apple's on-device Foundation Models framework, so no two playthroughs necessarily land on the same result for an unusual pair.

This started as a SwiftUI mini project and grew into something a bit bigger: a drag-and-drop crafting canvas, a persistent discovery log backed by Core Data, and a bonus map screen showing where each element was "discovered."

## How it works

Pick two elements and combine them. If that exact pair has been combined before, in this session or a previous one, you get the cached result instantly. Otherwise, the app asks the on-device language model to invent something, using a short prompt modeled after how Infinite Craft itself seems to work: a terse `"Water" + "Earth" = ?` style question rather than a full sentence, which keeps answers grounded (a common noun, not a rambling description). The six base-tier pairs (Fire+Water, Water+Earth, and so on) are pinned to their well-known results like Steam and Plant, so the start of the game feels consistent; everything past that is genuinely generated.

Nothing here calls out to the internet. The model runs entirely on-device through Apple Intelligence, which is also why it needs a fairly specific setup to run at all (see below).

## Screens

**Craft** is the main screen: drag elements out of the tray onto the canvas, then drag one tile onto another to combine them. A new discovery pops up as a toast.

**Discoveries** is a searchable log of everything you've found, with a favorites filter and a JSON export you can share.

**Atlas** drops a pin for every element you've discovered on a world map, at a spot derived from its name so it's the same every time you look. Mostly decorative, but it was a fun excuse to use MapKit.

Settings lets you pick how "grounded" the AI should be (closer to the obvious answer versus more original), toggle reduced motion, switch between light/dark/system appearance, and reset your progress.

## Requirements

This needs iOS 26 (or the matching Simulator runtime) and a Mac with Apple Intelligence turned on, since Foundation Models runs through the same on-device pipeline. If you open the app and see a banner saying Apple Intelligence isn't ready, that's not a bug: check System Settings > Apple Intelligence & Siri on your Mac and make sure the model has finished downloading.

- Xcode 26+
- macOS and Simulator runtime both on 26.x (mismatched versions are a common source of "model catalog" errors)
- Apple Intelligence enabled and downloaded on the host Mac

## Running it

Open `Element.xcodeproj` in Xcode and run on a Simulator or device running iOS 26+. There's no backend, no API keys, and no third-party dependencies to install.

If you just want to sanity-check that Foundation Models is working on your machine without running the full app, an Xcode Playground with `import Playgrounds` and a quick `LanguageModelSession` call is the fastest way to check.

## Project layout

- `Element.swift`: the `Element` model and `GeneratedElement`, the `@Generable` struct the model fills in
- `GameViewModel.swift`: owns the discovered elements, the combination cache, the prompt, and the Core Data plumbing
- `CraftView.swift`: the drag-and-drop canvas and tray
- `DiscoveryLogView.swift` / `ElementDetailView.swift`: the discoveries list and detail screen
- `AtlasView.swift` / `LocationManager.swift`: the map screen
- `SettingsView.swift`: AI creativity, appearance, and reset
- `Persistence.swift` / `Model.xcdatamodeld`: the Core Data stack
- `ElementTile.swift` / `Blob.swift`: shared UI pieces

## What this covers, for the curious

Built as a SwiftUI mini project, so it deliberately touches a wide spread of the framework: declarative view composition, `@State`/`@Binding`/`@Observable` for state management, `@AppStorage` and `@SceneStorage` for lightweight persistence, gestures (drag, tap, double-tap), `NavigationStack` with typed navigation, custom `Shape`/`Path` drawing, animations and transitions, Core Data with `@FetchRequest` and `NSPredicate`, and MapKit with `CLLocationManager`.

Left out on purpose: any real network calls (the whole point is that it's offline), and CoreML/Vision, since there wasn't an honest way to fit an image classifier into a text-combination game without it feeling bolted on.

## Why no combination table

Because that's the entire point. A hardcoded table of "Fire + Water = Steam" is what every other version of this game already does. The interesting part here is that the model is actually deciding, which means the game can genuinely surprise you, for better or worse.
