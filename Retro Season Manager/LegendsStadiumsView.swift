//
//  LegendsStadiumsView.swift
//  Retro Season Manager
//
//  Stadiums (Phase 9) — collect and assign a single home stadium for
//  its gameplay bonus and cosmetic theme colour.
//

import SwiftUI

struct LegendsStadiumsView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    var body: some View {
        LegendsMenuShell(store: store, title: "STADIUMS", subtitle: "\(store.profile.ownedStadiumIDs.count) / \(LegendsStadiumDatabase.all.count) OWNED", icon: "building.2.fill", accent: LegendsPalette.blue, onBack: onBack, currentNav: .club, onNavigate: onNavigate, scrollContent: false) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(LegendsStadiumDatabase.all) { stadium in
                        stadiumRow(stadium)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func stadiumRow(_ stadium: LegendsStadiumCard) -> some View {
        let owned = store.profile.ownedStadiumIDs.contains(stadium.id)
        let active = store.profile.activeStadiumID == stadium.id
        let themeColor = Color(rgb: stadium.themeColorRGB)
        return Button {
            guard owned else { return }
            Haptics.tap()
            withAnimation(.spring(duration: 0.3)) {
                store.setActiveStadium(active ? nil : stadium.id)
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(owned ? themeColor : Retro.text.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Retro.accent.opacity(0.3), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(owned ? stadium.name : "???")
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(owned ? Retro.text : Retro.text.opacity(0.4))
                    if owned {
                        Text("\(stadium.club) · Capacity \(stadium.capacity.formatted())")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.6))
                    } else {
                        Text("Win matches for a chance to unlock a stadium.")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.4))
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    if owned {
                        Text("+\(stadium.gameplayBonus)")
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(Retro.gold)
                    }
                    if active {
                        Text("HOME")
                            .font(.system(size: 9, design: .monospaced).bold())
                            .foregroundStyle(Retro.emerald)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(12)
            .background(Retro.panel.opacity(owned ? 0.7 : 0.35))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Retro.emerald.opacity(0.6) : Retro.accent.opacity(owned ? 0.2 : 0.08), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!owned)
    }
}
