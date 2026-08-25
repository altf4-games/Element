//
//  SettingsView.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import SwiftUI

/// System/Light/Dark — `nil` `colorScheme` defers to the device setting.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SettingsView: View {
    @Environment(GameViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    /// `@AppStorage` — lightweight persistence for settings that should
    /// survive relaunch but don't belong in Core Data.
    @AppStorage("aiCreativity") private var creativityRaw = AICreativity.balanced.rawValue
    @AppStorage("reduceMotionPref") private var reduceMotion = false
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue

    @State private var showingResetConfirm = false

    private var creativity: AICreativity { AICreativity(rawValue: creativityRaw) ?? .balanced }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.icon).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("AI Creativity") {
                    Picker("Combination style", selection: $creativityRaw) {
                        ForEach(AICreativity.allCases) { style in
                            Text(style.label).tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(creativityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Accessibility") {
                    Toggle("Reduce motion", isOn: $reduceMotion)
                }

                Section {
                    Button("Reset Progress", role: .destructive) {
                        showingResetConfirm = true
                    }
                } footer: {
                    Text("Deletes every discovered element and combination and starts over with just Fire, Water, Earth, and Air.")
                }

                Section("About") {
                    Text("Combine anything. Discover what the world hasn't named yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset all progress?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    viewModel.resetProgress()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private var creativityDescription: String {
        switch creativity {
        case .grounded: "Combinations stick closely to the most obvious, expected result (Water + Earth = Plant)."
        case .balanced: "A mix of expected results and the occasional surprise."
        case .wild: "Leans into unexpected, more original combinations."
        }
    }
}
