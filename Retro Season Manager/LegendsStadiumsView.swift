//
//  LegendsStadiumsView.swift
//  Retro Season Manager
//
//  Stadiums (Phase 9, redesigned) — collect and assign a single home
//  stadium for its gameplay bonus and cosmetic theme colour.
//
//  Presentation mirrors the redesigned Assistants screen and the accepted
//  Squad/Division/Training/Packs/Facilities language. Store logic is
//  untouched — this view only reads the existing catalog/profile state
//  and calls the existing setActiveStadium().
//

import SwiftUI

struct LegendsStadiumsView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    private enum Filter: String, CaseIterable {
        case all, owned
    }

    @State private var filter: Filter = .all
    @State private var feedback: String?

    var body: some View {
        LegendsMenuShell(store: store, title: "STADIUMS", subtitle: "HOME GROUND COLLECTION", icon: "building.2.fill", accent: LegendsPalette.blue, onBack: onBack, currentNav: .club, onNavigate: onNavigate, headerBackTitle: "Back to Club", onHeaderBack: backToClub, scrollContent: false) {
            GeometryReader { geo in
                let wide = geo.size.width >= 860
                // One stable scroll container owned by this screen's content;
                // plain (non-lazy) rows keep every card in the accessibility
                // tree even when scrolled off-screen.
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        summaryBand
                        filterRow
                        if let feedback {
                            feedbackBand(feedback)
                        }
                        let stadiums = filteredStadiums
                        if stadiums.isEmpty {
                            emptyState
                        } else {
                            let columnCount = wide ? 3 : 2
                            ForEach(stride(from: 0, to: stadiums.count, by: columnCount).map { start in
                                (id: stadiums[start].id, stadiums: Array(stadiums[start..<min(start + columnCount, stadiums.count)]))
                            }, id: \.id) { row in
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(row.stadiums) { stadium in
                                        stadiumCard(stadium)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .accessibilityIdentifier("legends.stadiums.screen")
        }
    }

    private var backToClub: (() -> Void)? {
        guard let onNavigate else { return nil }
        return { onNavigate(.club) }
    }

    // MARK: - Derived state

    /// The home stadium only counts when it is still owned, so a stale saved
    /// id can never present a benefit the player does not have.
    private var effectiveActiveStadium: LegendsStadiumCard? {
        guard let id = store.profile.activeStadiumID,
              store.profile.ownedStadiumIDs.contains(id) else { return nil }
        return LegendsStadiumDatabase.all.first { $0.id == id }
    }

    private var filteredStadiums: [LegendsStadiumCard] {
        switch filter {
        case .all: return LegendsStadiumDatabase.all
        case .owned: return LegendsStadiumDatabase.all.filter { store.profile.ownedStadiumIDs.contains($0.id) }
        }
    }

    // MARK: - Summary

    private var summaryBand: some View {
        let active = effectiveActiveStadium
        let benefit = active.map { "+\($0.gameplayBonus) TEAM STRENGTH BONUS · CAPACITY \($0.capacity.formatted())" }
            ?? "NO HOME STADIUM — SELECT AN OWNED CARD BELOW"
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                collectionStat(value: "\(store.profile.ownedStadiumIDs.count) / \(LegendsStadiumDatabase.all.count)",
                               label: "OWNED",
                               color: LegendsPalette.blue,
                               identifier: "legends.stadiums.summary.owned")
                collectionStat(value: active?.name.uppercased() ?? "NONE",
                               label: "HOME",
                               color: LegendsPalette.green,
                               identifier: "legends.stadiums.summary.home")
            }
            Text(benefit)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(active == nil ? LegendsPalette.navy.opacity(0.62) : LegendsPalette.green)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.blue.opacity(0.24), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.stadiums.summary")
    }

    private func collectionStat(value: String, label: String, color: Color, identifier: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: label == "HOME" ? "building.2.fill" : "building.2")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LegendsPalette.navy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.66))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(LegendsPalette.contentBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label.lowercased()) \(value)")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Filter

    private var filterRow: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases, id: \.rawValue) { item in
                Button {
                    Haptics.tap()
                    filter = item
                } label: {
                    Text(item == .all ? "ALL" : "OWNED")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(filter == item ? .white : LegendsPalette.navy)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(filter == item ? LegendsPalette.blue : .white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(filter == item ? LegendsPalette.blue : LegendsPalette.navy.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("legends.stadiums.filter.\(item.rawValue)")
                .accessibilityAddTraits(filter == item ? [.isSelected] : [])
            }
            Spacer()
            Text("\(filteredStadiums.count) SHOWING")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.62))
        }
    }

    private func feedbackBand(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(LegendsPalette.navy)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LegendsPalette.blueWash)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("legends.stadiums.feedback")
            .accessibilityLabel(message)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "building.2")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(LegendsPalette.navy.opacity(0.35))
            Text("NO STADIUMS OWNED YET")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)
            Text("Win matches for a chance to unlock a stadium.")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.navy.opacity(0.10), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.stadiums.empty")
    }

    // MARK: - Card

    private func stadiumCard(_ stadium: LegendsStadiumCard) -> some View {
        let owned = store.profile.ownedStadiumIDs.contains(stadium.id)
        let active = owned && effectiveActiveStadium?.id == stadium.id
        let themeColor = Color(rgb: stadium.themeColorRGB)

        return Button {
            guard owned else { return }
            Haptics.tap()
            withAnimation(.spring(duration: 0.3)) {
                if active {
                    store.setActiveStadium(nil)
                    feedback = "HOME STADIUM CLEARED."
                } else {
                    store.setActiveStadium(stadium.id)
                    feedback = "\(stadium.name.uppercased()) SET AS HOME · +\(stadium.gameplayBonus) TEAM STRENGTH BONUS."
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(owned ? themeColor : LegendsPalette.navy.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(LegendsPalette.navy.opacity(0.18), lineWidth: 1))
                        .overlay {
                            if !owned {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(LegendsPalette.navy.opacity(0.4))
                            }
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(owned ? stadium.name : "???")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(owned ? LegendsPalette.navy : LegendsPalette.navy.opacity(0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(stadium.club.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if owned {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("+\(stadium.gameplayBonus)")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(LegendsPalette.goldDeep)
                            Text("HOME BONUS")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                        }
                    }
                }

                if owned {
                    HStack(spacing: 5) {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(LegendsPalette.blue)
                        Text("CAPACITY \(stadium.capacity.formatted())")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(LegendsPalette.navy.opacity(0.66))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text("Adds +\(stadium.gameplayBonus) team strength while this stadium is your home ground.")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    HStack {
                        if active {
                            Text("HOME")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(LegendsPalette.green)
                                .clipShape(Capsule())
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityIdentifier("legends.stadiums.badge.\(stadium.id)")
                        }
                        Spacer()
                        Text(active ? "TAP TO CLEAR" : "TAP TO SET AS HOME")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.5))
                    }
                } else {
                    Text("LOCKED — WIN MATCHES FOR A CHANCE TO UNLOCK A STADIUM.")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.orange)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? LegendsPalette.blueWash.opacity(0.55) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? LegendsPalette.green.opacity(0.7) : owned ? themeColor.opacity(0.30) : LegendsPalette.navy.opacity(0.10), lineWidth: active ? 1.5 : 1))
            .shadow(color: LegendsPalette.navy.opacity(active ? 0.12 : 0.08), radius: 7, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!owned)
        .accessibilityIdentifier("legends.stadiums.card.\(stadium.id)")
        .accessibilityLabel(owned
            ? "\(stadium.name), home of \(stadium.club). Gameplay bonus plus \(stadium.gameplayBonus). Capacity \(stadium.capacity). \(active ? "Current home stadium." : "Not the home stadium.")"
            : "Locked stadium. Win matches for a chance to unlock.")
    }
}
