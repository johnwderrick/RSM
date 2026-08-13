//
//  TeamSetupSheet.swift
//  Retro Season Manager
//
//  The formation / mentality / auto-pick sheet opened from the
//  Tactics toolbar.
//

import SwiftUI

// MARK: - Team setup sheet

/// Everything about setting the team up — formation, mentality, auto-pick,
/// clear XI, training focus — consolidated into one sheet reached from a
/// single button, instead of permanently occupying a strip above the pitch
/// and a bar below it.
struct TeamSetupSheet: View {
    let store: GameStore
    @Binding var message: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("TEAM SETUP")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Panel(title: "FORMATION") {
                            VStack(alignment: .leading, spacing: 10) {
                                if store.autoPickAssist {
                                    Text("ASSIST ON")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Retro.background)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Retro.highlight)
                                        .clipShape(Capsule())
                                }
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                    ForEach(Formation.all) { formation in
                                        let selected = store.formation == formation
                                        Button {
                                            Haptics.tap()
                                            store.formation = formation
                                            message = nil
                                        } label: {
                                            Text(formation.name)
                                                .font(.system(.footnote, design: .monospaced).bold())
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(selected ? Retro.accent : Retro.panel)
                                                .foregroundStyle(selected ? Retro.background : Retro.text)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(PressableButtonStyle())
                                    }
                                }
                                if store.isFormationBeddingIn {
                                    Text("Formation still bedding in — performance dips slightly for a few matches after a switch.")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Retro.highlight)
                                }
                                HStack(spacing: 8) {
                                    Button {
                                        Haptics.tap()
                                        store.resetSlotPins()
                                        message = "Pitch positions reset to best fit."
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.counterclockwise")
                                            Text("RESET SLOTS")
                                        }
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Retro.panel)
                                        .foregroundStyle(Retro.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(PressableButtonStyle())

                                    let suggested = store.recommendedFormation
                                    if suggested != store.formation {
                                        Button {
                                            Haptics.tap()
                                            store.formation = suggested
                                            message = "Switched to \(suggested.name) — your assistant's suggested shape for this squad."
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "lightbulb.fill")
                                                Text("TRY \(suggested.name)")
                                            }
                                            .font(.system(.caption, design: .monospaced).bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(Retro.highlight.opacity(0.25))
                                            .foregroundStyle(Retro.highlight)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(PressableButtonStyle())
                                    }
                                }
                            }
                        }

                        Panel(title: "MENTALITY") {
                            HStack(spacing: 8) {
                                ForEach(Mentality.allCases) { mentality in
                                    let selected = store.preferredMentality == mentality
                                    Button {
                                        Haptics.tap()
                                        store.preferredMentality = mentality
                                    } label: {
                                        Text(mentality.rawValue)
                                            .font(.system(.footnote, design: .monospaced).bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(selected ? Retro.highlight : Retro.panel)
                                            .foregroundStyle(selected ? Retro.background : Retro.text)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                }
                            }
                        }

                        Panel(title: "SQUAD TOOLS") {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    setupButton("AUTO-PICK") { store.autoPickLineup(); message = "Best XI selected." }
                                    setupButton("CLEAR XI") { store.clearLineup(); message = "Lineup cleared." }
                                }
                                Menu {
                                    Picker("Training", selection: Binding(
                                        get: { store.trainingFocus },
                                        set: { store.trainingFocus = $0; message = "Training focus: \($0.rawValue)." }
                                    )) {
                                        ForEach(TrainingFocus.allCases) { Text($0.rawValue).tag($0) }
                                    }
                                } label: {
                                    Text("TRAIN: \(store.trainingFocus.rawValue.uppercased())")
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Retro.panel)
                                        .foregroundStyle(Retro.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .menuStyle(.button)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func setupButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact()
            action()
        } label: {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Retro.accent)
                .foregroundStyle(Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

