//
//  LegendsManagersView.swift
//  Retro Season Manager
//
//  Assistants (Phase 9, redesigned) — collect and assign a single active
//  assistant for their tactical bonus and club-affinity chemistry link.
//  (Collectible cards keep the internal `manager` naming for save
//  compatibility.)
//
//  Presentation follows the accepted Squad/Division/Training/Packs/
//  Facilities language: white cards on the light content background,
//  LegendsPalette accents, one stable scroll container owned by the
//  shell. Store logic is untouched — this view only reads the existing
//  catalog/profile state and calls the existing setActiveManager().
//

import SwiftUI

struct LegendsManagersView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    private enum Filter: String, CaseIterable {
        case all, owned
    }

    @State private var filter: Filter = .all
    @State private var feedback: String?

    var body: some View {
        LegendsMenuShell(store: store, title: "ASSISTANTS", subtitle: "SIDELINE STAFF COLLECTION", icon: "person.crop.rectangle.stack.fill", accent: LegendsPalette.green, onBack: onBack, currentNav: .club, onNavigate: onNavigate, headerBackTitle: "Back to Club", onHeaderBack: backToClub, scrollContent: false) {
            GeometryReader { geo in
                let wide = geo.size.width >= 860
                // One stable scroll container: the whole collection scrolls
                // as a unit and nothing inside resets its position. Plain
                // (non-lazy) rows keep every card in the accessibility tree
                // even when scrolled off-screen.
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        summaryBand
                        filterRow
                        if let feedback {
                            feedbackBand(feedback)
                        }
                        let managers = filteredManagers
                        if managers.isEmpty {
                            emptyState
                        } else {
                            let columnCount = wide ? 3 : 2
                            ForEach(stride(from: 0, to: managers.count, by: columnCount).map { start in
                                (id: managers[start].id, managers: Array(managers[start..<min(start + columnCount, managers.count)]))
                            }, id: \.id) { row in
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(row.managers) { manager in
                                        managerCard(manager)
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
            .accessibilityIdentifier("legends.assistants.screen")
        }
    }

    private var backToClub: (() -> Void)? {
        guard let onNavigate else { return nil }
        return { onNavigate(.club) }
    }

    // MARK: - Derived state

    /// The active assistant only counts when it is still owned, so a stale
    /// saved id can never present a benefit the player does not have.
    private var effectiveActiveManager: LegendsManagerCard? {
        guard let id = store.profile.activeManagerID,
              store.profile.ownedManagerIDs.contains(id) else { return nil }
        return LegendsManagerDatabase.all.first { $0.id == id }
    }

    private var filteredManagers: [LegendsManagerCard] {
        switch filter {
        case .all: return LegendsManagerDatabase.all
        case .owned: return LegendsManagerDatabase.all.filter { store.profile.ownedManagerIDs.contains($0.id) }
        }
    }

    // MARK: - Summary

    private var summaryBand: some View {
        let active = effectiveActiveManager
        let benefit = active.map { "+\($0.tacticalBonus) TEAM STAFF BONUS · AFFINITY LINK: \($0.affinityClub.uppercased())" }
            ?? "NO ACTIVE ASSISTANT — SELECT AN OWNED CARD BELOW"
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                collectionStat(value: "\(store.profile.ownedManagerIDs.count) / \(LegendsManagerDatabase.all.count)",
                               label: "OWNED",
                               color: LegendsPalette.green,
                               identifier: "legends.assistants.summary.owned")
                collectionStat(value: active?.name.uppercased() ?? "NONE",
                               label: "ACTIVE",
                               color: LegendsPalette.blue,
                               identifier: "legends.assistants.summary.active")
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
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.green.opacity(0.24), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.assistants.summary")
    }

    private func collectionStat(value: String, label: String, color: Color, identifier: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: label == "ACTIVE" ? "person.crop.circle.badge.checkmark.fill" : "person.crop.rectangle.stack.fill")
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
                        .background(filter == item ? LegendsPalette.green : .white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(filter == item ? LegendsPalette.green : LegendsPalette.navy.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("legends.assistants.filter.\(item.rawValue)")
                .accessibilityAddTraits(filter == item ? [.isSelected] : [])
            }
            Spacer()
            Text("\(filteredManagers.count) SHOWING")
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
            .background(LegendsPalette.greenWash)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("legends.assistants.feedback")
            .accessibilityLabel(message)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(LegendsPalette.navy.opacity(0.35))
            Text("NO ASSISTANTS OWNED YET")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)
            Text("Win matches for a chance to unlock an assistant.")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.navy.opacity(0.10), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.assistants.empty")
    }

    // MARK: - Card

    private func managerCard(_ manager: LegendsManagerCard) -> some View {
        let owned = store.profile.ownedManagerIDs.contains(manager.id)
        let active = owned && effectiveActiveManager?.id == manager.id

        return Button {
            guard owned else { return }
            Haptics.tap()
            withAnimation(.spring(duration: 0.3)) {
                if active {
                    store.setActiveManager(nil)
                    feedback = "ACTIVE ASSISTANT CLEARED."
                } else {
                    store.setActiveManager(manager.id)
                    feedback = "\(manager.name.uppercased()) SET AS ACTIVE ASSISTANT · +\(manager.tacticalBonus) TEAM STAFF BONUS."
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: owned ? "person.crop.rectangle.stack.fill" : "lock.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(owned ? LegendsPalette.green : LegendsPalette.navy.opacity(0.35))
                        .frame(width: 40, height: 40)
                        .background((owned ? LegendsPalette.green : LegendsPalette.navy).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(owned ? manager.name : "???")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(owned ? LegendsPalette.navy : LegendsPalette.navy.opacity(0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(manager.nation.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if owned {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("+\(manager.tacticalBonus)")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(LegendsPalette.goldDeep)
                            Text("TACTICAL")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                        }
                    }
                }

                if owned {
                    Text(manager.specialty)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.74))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 5) {
                        FlagView(nationality: manager.nation, width: 14)
                        Text("AFFINITY: \(manager.affinityClub.uppercased())")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text("Affinity-club players gain chemistry when this assistant is active.")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    HStack {
                        if active {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(LegendsPalette.green)
                                .clipShape(Capsule())
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityIdentifier("legends.assistants.badge.\(manager.id)")
                        }
                        Spacer()
                        Text(active ? "TAP TO DEACTIVATE" : "TAP TO ACTIVATE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.5))
                    }
                } else {
                    Text("LOCKED — WIN MATCHES FOR A CHANCE TO UNLOCK AN ASSISTANT.")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.orange)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? LegendsPalette.greenWash.opacity(0.55) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? LegendsPalette.green.opacity(0.7) : owned ? LegendsPalette.green.opacity(0.20) : LegendsPalette.navy.opacity(0.10), lineWidth: active ? 1.5 : 1))
            .shadow(color: LegendsPalette.navy.opacity(active ? 0.12 : 0.08), radius: 7, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!owned)
        .accessibilityIdentifier("legends.assistants.card.\(manager.id)")
        .accessibilityLabel(owned
            ? "\(manager.name), \(manager.nation). Tactical bonus plus \(manager.tacticalBonus). Affinity club \(manager.affinityClub). \(active ? "Active assistant." : "Not active.")"
            : "Locked assistant. Win matches for a chance to unlock.")
    }
}
