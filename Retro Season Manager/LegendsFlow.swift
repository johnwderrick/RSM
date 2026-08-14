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

    private var crestColor: Color { Color(rgb: store.profile.crestColorRGB) }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Button {
                        Haptics.tap()
                        onBack()
                    } label: {
                        Text("‹ Switch Mode")
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(Retro.text)
                    }
                    .buttonStyle(PressableButtonStyle())
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
                        tile(icon: "flag.checkered", title: "Challenges", phase: 8)
                        tile(icon: "building.columns.fill", title: "Club", phase: 9)
                        tile(icon: "person.crop.rectangle.stack.fill", title: "Managers", phase: 9)
                        tile(icon: "building.2.fill", title: "Stadiums", phase: 9)
                        tile(icon: "gearshape.fill", title: "Settings", phase: 10)
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

    private func tile(icon: String, title: String, phase: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Retro.text.opacity(0.35))
            Text(title)
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.5))
            Text("Coming in Phase \(phase)")
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
