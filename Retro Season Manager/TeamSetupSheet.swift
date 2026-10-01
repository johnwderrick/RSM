//
//  TeamSetupSheet.swift
//  Retro Season Manager
//
//  The formation / mentality / auto-pick sheet opened from the
//  Squad toolbar, in the Career light-card treatment: pale canvas,
//  white cards, dark ink headings, restrained green accents and
//  PressableButtonStyle everywhere. One vertical scroll container;
//  the header close and footer Done stay pinned outside it so the
//  sheet is always closable on a compact landscape phone.
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
        VStack(spacing: 0) {
            setupHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    formationCard
                    mentalityCard
                    squadToolsCard
                    Color.clear
                        .frame(height: 1)
                        .accessibilityElement()
                        .accessibilityIdentifier(CareerIdentifiers.teamSetupEnd)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(CareerIdentifiers.teamSetupScroll)

            setupFooter
        }
        .background(CareerPalette.canvas.ignoresSafeArea())
        .font(.system(.body, design: .monospaced))
        // The sheet's root anchor lives on a 1x1 overlay element instead of
        // the container itself: an identifier on a parent container is
        // inherited by its descendants and masks their own identifiers.
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(CareerIdentifiers.teamSetupSheet)
        }
    }

    // MARK: Header / footer (pinned)

    private var setupHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TEAM SETUP")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("Shape, mentality and squad tools")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
            Spacer(minLength: 8)
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(CareerPalette.ink)
                    .frame(width: 32, height: 32)
                    .background(CareerPalette.surface)
                    .overlay(Circle().stroke(CareerPalette.line.opacity(0.18)))
                    .clipShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.teamSetupClose)
            .accessibilityLabel("Close team setup")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(CareerPalette.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(CareerPalette.line.opacity(0.12)).frame(height: 1) }
    }

    private var setupFooter: some View {
        Button {
            Haptics.tap()
            dismiss()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .black))
                    // The symbol's default accessibility story advertises a
                    // misleading Selected trait on the whole button; the
                    // button's own label is all VoiceOver needs.
                    .accessibilityHidden(true)
                Text("DONE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: 460)
            .frame(height: 44)
            .background(CareerPalette.line)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: CareerPalette.line.opacity(0.22), radius: 6, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(CareerIdentifiers.teamSetupDone)
        .accessibilityLabel("Done — close team setup")
        .padding(.horizontal, 14)
        .padding(.top, 7)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity)
        .background(CareerPalette.surface)
        .overlay(alignment: .top) { Rectangle().fill(CareerPalette.line.opacity(0.14)).frame(height: 1) }
    }

    // MARK: Formation card

    private var formationCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            cardHeading("FORMATION", icon: "square.grid.3x3.fill")

            if store.autoPickAssist {
                Text("ASSIST ON")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(CareerPalette.line)
                    .clipShape(Capsule())
                    .accessibilityIdentifier(CareerIdentifiers.teamSetupAssistBadge)
                    .accessibilityLabel("Auto-pick assist is on")
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 7)], spacing: 7) {
                ForEach(Formation.all) { formation in
                    let selected = store.formation == formation
                    Button {
                        Haptics.tap()
                        store.formation = formation
                        message = nil
                    } label: {
                        Text(formation.name)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(selected ? Color.white : CareerPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(selected ? CareerPalette.line : CareerPalette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(selected ? CareerPalette.line : CareerPalette.line.opacity(0.18)))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(CareerIdentifiers.teamSetupFormation(formation.name))
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }

            if store.isFormationBeddingIn {
                Label {
                    Text("Formation still bedding in — performance dips slightly for a few matches after a switch.")
                } icon: {
                    Image(systemName: "info.circle.fill")
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .accessibilityIdentifier(CareerIdentifiers.teamSetupBeddingIn)
            }

            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    store.resetSlotPins()
                    message = "Pitch positions reset to best fit."
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .black))
                        Text("RESET SLOTS")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(CareerPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(CareerPalette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(CareerPalette.line.opacity(0.35)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(CareerIdentifiers.teamSetupResetSlots)

                let suggested = store.recommendedFormation
                if suggested != store.formation {
                    Button {
                        Haptics.tap()
                        store.formation = suggested
                        message = "Switched to \(suggested.name) — your assistant's suggested shape for this squad."
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10, weight: .black))
                            Text("TRY \(suggested.name)")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(CareerPalette.line)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(CareerPalette.line.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(CareerPalette.line.opacity(0.3)))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(CareerIdentifiers.teamSetupTrySuggested)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(CareerPalette.line.opacity(0.16)))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: Mentality card

    private var mentalityCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            cardHeading("MENTALITY", icon: "brain.head.profile")
            HStack(spacing: 7) {
                ForEach(Mentality.allCases) { mentality in
                    let selected = store.preferredMentality == mentality
                    Button {
                        Haptics.tap()
                        store.preferredMentality = mentality
                    } label: {
                        Text(mentality.rawValue)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(selected ? Color.white : CareerPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(selected ? CareerPalette.line : CareerPalette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(selected ? CareerPalette.line : CareerPalette.line.opacity(0.18)))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(CareerIdentifiers.teamSetupMentality(mentality))
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(CareerPalette.line.opacity(0.16)))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: Squad tools card

    private var squadToolsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            cardHeading("SQUAD TOOLS", icon: "wrench.and.screwdriver.fill")

            HStack(spacing: 8) {
                toolsButton("AUTO-PICK", icon: "wand.and.stars", style: .primary) {
                    store.autoPickLineup()
                    message = "Best XI selected."
                }
                .accessibilityIdentifier(CareerIdentifiers.teamSetupAutoPick)

                toolsButton("CLEAR XI", icon: "eraser.fill", style: .outline) {
                    store.clearLineup()
                    message = "Lineup cleared."
                }
                .accessibilityIdentifier(CareerIdentifiers.teamSetupClearXI)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("TRAINING FOCUS")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 7)], spacing: 7) {
                    ForEach(TrainingFocus.allCases) { focus in
                        let selected = store.trainingFocus == focus
                        Button {
                            Haptics.tap()
                            store.trainingFocus = focus
                            message = "Training focus: \(focus.rawValue)."
                        } label: {
                            Text(focus.rawValue)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(selected ? Color.white : CareerPalette.ink)
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(selected ? CareerPalette.line : CareerPalette.surface)
                                .overlay(RoundedRectangle(cornerRadius: 9)
                                    .stroke(selected ? CareerPalette.line : CareerPalette.line.opacity(0.18)))
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityIdentifier(CareerIdentifiers.teamSetupTraining(focus))
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(CareerPalette.line.opacity(0.16)))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
    }

    private enum ToolStyle { case primary, outline }

    /// AUTO-PICK / CLEAR XI share one shape; the primary variant carries the
    /// green fill. Both keep the sheet's original impact haptic.
    private func toolsButton(_ title: String, icon: String, style: ToolStyle,
                             action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact()
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .black))
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
            .foregroundStyle(style == .primary ? Color.white : CareerPalette.line)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(style == .primary ? CareerPalette.line : CareerPalette.surface)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(CareerPalette.line.opacity(style == .primary ? 0 : 0.35)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func cardHeading(_ title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(CareerPalette.line)
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
            Spacer()
        }
    }
}
