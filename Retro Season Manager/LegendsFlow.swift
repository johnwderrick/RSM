//
//  LegendsFlow.swift
//  Retro Season Manager
//
//  Top-level mode selection between Career Mode and RSM Legends, plus the
//  Legends stub screen. Legends itself is fictionalized like the rest of
//  the app — no real player/club/league names — and reuses the app's
//  existing visual identity rather than introducing a new one.
//

import SwiftUI

enum GameExperience {
    case career
    case legends
}

/// A back/dismiss control shared by every Legends screen. Previously each
/// screen wrote its own `Text("‹ Back")` button, whose tap target was just
/// the text glyphs' own bounding box — easy to miss. This gives every
/// screen the same look plus a real 44×44pt minimum tap target.
struct LegendsBackButton: View {
    var label: String = "Back"
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text(label)
            }
            .font(.system(.callout, design: .monospaced).bold())
            .foregroundStyle(Retro.text)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct ExperienceSelectView: View {
    let store: GameStore
    @Binding var experience: GameExperience?

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 4) {
                    Text("⚽︎ RETRO SEASON MANAGER")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text("CHOOSE YOUR EXPERIENCE")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                        .tracking(6)
                }

                VStack(spacing: 16) {
                    experienceTile(icon: "sportscourt.fill", title: "Career Mode",
                                   subtitle: "Manage a club through a full career") {
                        experience = .career
                    }
                    experienceTile(icon: "sparkles", title: "RSM Legends",
                                   subtitle: "Collect cards and build your ultimate squad") {
                        experience = .legends
                    }
                }
                .frame(maxWidth: 420)

                Spacer()
                Text("An old-school football management sim")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                    .padding(.bottom, 20)
            }
            .padding()
        }
    }

    private func experienceTile(icon: String, title: String, subtitle: String,
                                 action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(Retro.accent)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                    Text(subtitle)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Retro.text.opacity(0.5))
            }
            .padding(18)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Retro.accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// The real Legends home screen (Phase 2): club identity, currencies and
/// the full button set from the design doc. Every button but the ones a
/// later phase actually implements is shown greyed-out with a "Coming in
/// Phase N" subtitle, mirroring how `MainMenuView.menuTile` already dims
/// unavailable tiles rather than hiding them outright.
struct LegendsHomeView: View {
    let store: LegendsStore
    var onBack: () -> Void
    @State private var showCollection = false
    @State private var showPacks = false
    @State private var showSquad = false
    @State private var showMatch = false
    @State private var showChallenges = false
    @State private var showManagers = false
    @State private var showStadiums = false
    @State private var showSettings = false

    private var crestColor: Color { Color(rgb: store.profile.crestColorRGB) }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    LegendsBackButton(label: "Switch Mode", action: onBack)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)

                header

                statRow

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        playMatchTile
                        squadTile
                        packsTile
                        collectionTile
                        challengesTile
                        tile(icon: "building.columns.fill", title: "Club")
                        managersTile
                        stadiumsTile
                        settingsTile
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .fullScreenCover(isPresented: $showCollection) {
            LegendsCollectionView(store: store) { showCollection = false }
        }
        .fullScreenCover(isPresented: $showPacks) {
            LegendsPacksView(store: store) { showPacks = false }
        }
        .fullScreenCover(isPresented: $showSquad) {
            LegendsSquadView(store: store) { showSquad = false }
        }
        .fullScreenCover(isPresented: $showMatch) {
            LegendsMatchView(store: store) { showMatch = false }
        }
        .fullScreenCover(isPresented: $showChallenges) {
            LegendsChallengesView(store: store) { showChallenges = false }
        }
        .fullScreenCover(isPresented: $showManagers) {
            LegendsManagersView(store: store) { showManagers = false }
        }
        .fullScreenCover(isPresented: $showStadiums) {
            LegendsStadiumsView(store: store) { showStadiums = false }
        }
        .fullScreenCover(isPresented: $showSettings) {
            LegendsSettingsView(store: store) { showSettings = false }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            CrestView(shortName: store.profile.crestShort, size: 56, color: crestColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.profile.clubName)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text("MANAGER LEVEL \(store.profile.managerLevel)")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .tracking(2)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            stat(icon: "dollarsign.circle.fill", value: "\(store.profile.coins)", label: "COINS")
            stat(icon: "shippingbox.fill", value: "\(store.profile.packTokens)", label: "TOKENS")
            stat(icon: "star.fill", value: store.currentTeamRating > 0 ? "\(store.currentTeamRating)" : "—", label: "RATING")
            stat(icon: "trophy.fill", value: store.profile.division.displayName, label: "DIVISION")
        }
        .padding(.horizontal)
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Retro.accent)
            Text(value)
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.4), value: value)
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Retro.panel.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var playMatchTile: some View {
        Button {
            Haptics.tap()
            showMatch = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Retro.accent)
                Text("Play Match")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text(store.profile.division.displayName)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.65))
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(10)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var challengesTile: some View {
        let completed = LegendsChallengeDatabase.all.filter { store.isCompleted($0) }.count
        return Button {
            Haptics.tap()
            showChallenges = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 22))
                    .foregroundStyle(Retro.accent)
                Text("Challenges")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text("\(completed)/\(LegendsChallengeDatabase.all.count) done")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.65))
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(10)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var managersTile: some View {
        Button {
            Haptics.tap()
            showManagers = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Retro.accent)
                Text("Managers")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text("\(store.profile.ownedManagerIDs.count)/\(LegendsManagerDatabase.all.count) owned")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.65))
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(10)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var stadiumsTile: some View {
        Button {
            Haptics.tap()
            showStadiums = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Retro.accent)
                Text("Stadiums")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text("\(store.profile.ownedStadiumIDs.count)/\(LegendsStadiumDatabase.all.count) owned")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.65))
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(10)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var settingsTile: some View {
        Button {
            Haptics.tap()
            showSettings = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Retro.accent)
                Text("Settings")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text("Sound & more")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.65))
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(10)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var squadTile: some View {
        Button {
            Haptics.tap()
            showSquad = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Retro.accent)
                Text("Squad")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text(store.currentTeamRating > 0 ? "Rating \(store.currentTeamRating)" : "Not set")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.65))
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(10)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var packsTile: some View {
        Button {
            Haptics.tap()
            showPacks = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Retro.accent)
                Text("Packs")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text("\(LegendsPackDatabase.all.count) available")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.65))
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(10)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var collectionTile: some View {
        Button {
            Haptics.tap()
            showCollection = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Retro.accent)
                Text("Collection")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text("\(store.profile.ownedCardIDs.count) / \(LegendsCardDatabase.all.count) cards")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.65))
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(10)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// `phase` is nil for tiles that were never given a roadmap phase in
    /// the design doc (just "Club" now — every phase 1-10 tile has a
    /// real screen behind it).
    private func tile(icon: String, title: String, phase: Int? = nil) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Retro.text.opacity(0.35))
            Text(title)
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.5))
            Text(phase.map { "Coming in Phase \($0)" } ?? "Coming soon")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(10)
        .background(Retro.panel.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.accent.opacity(0.1), lineWidth: 1))
    }
}
