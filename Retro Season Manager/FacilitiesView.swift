//
//  FacilitiesView.swift
//  Retro Season Manager
//
//  Club Facilities: the 8 investable pieces of infrastructure (training
//  ground, youth academy, medical centre, scouting network, stadium,
//  hospitality, museum, club shop) with visual level progression and a
//  one-tap upgrade — the mechanism behind a small club slowly becoming
//  a giant.
//
//  Presented in the accepted Career light-card design language (pale
//  canvas, white cards, ink headings, green accents, gold only for
//  emphasis, monospaced figures). Every figure comes from the
//  authoritative GameStore facilities APIs — `facilityUpgradeCost` owns
//  prices and max-level detection, `investInFacility` owns the spend,
//  level bump, news story and ledger entry. Facilities spend the club's
//  TRANSFER BUDGET (never Legends Balance or pack tokens); the summary
//  says so explicitly.
//
//  The Club sidebar destination has exactly one vertical scroll
//  container and stable `career.facilities.*` identifiers for UI tests.
//

import SwiftUI

struct FacilitiesView: View {
    let store: GameStore

    private var levelCount: Int {
        FacilityKind.allCases.filter { $0.level(in: store.userClub) > 0 }.count
    }

    var body: some View {
        ZStack {
            CareerPalette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryBand
                    ForEach(FacilityKind.allCases) { kind in
                        FacilityCard(store: store, kind: kind)
                    }
                    endAnchor
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier(CareerIdentifiers.facilitiesScroll)
        }
        .font(.system(.body, design: .monospaced))
    }

    // MARK: Summary band

    private var summaryBand: some View {
        HStack(spacing: 14) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("CLUB FACILITIES")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(store.userClub.name) · SEASON \(store.season)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("TRANSFER BUDGET")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Text(formatMoney(store.userClub.transferBudget))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(CareerIdentifiers.facilitiesBudget)
                    .accessibilityLabel("Transfer budget \(formatMoney(store.userClub.transferBudget))")
                Text("facilities spend from this budget")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.8))
            }
        }
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.facilitiesSummary)
        .accessibilityLabel("""
        Club facilities. \(store.userClub.name), season \(store.season). \
        Transfer budget \(formatMoney(store.userClub.transferBudget)). \
        \(levelCount) of \(FacilityKind.allCases.count) facilities developed \
        — upgrades spend from the transfer budget.
        """)
    }

    private var endAnchor: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityIdentifier(CareerIdentifiers.facilitiesEnd)
    }
}

/// One facility in the light-card row style: tier bar, current level and
/// effect, next cost and benefit, and an unambiguous action state —
/// affordable (green UPGRADE), insufficient budget (disabled UPGRADE +
/// shortfall line), or MAX LEVEL (gold badge, no button).
private struct FacilityCard: View {
    let store: GameStore
    let kind: FacilityKind
    @State private var message: String?

    private var level: Int { kind.level(in: store.userClub) }
    private var cost: Int? { store.facilityUpgradeCost(kind, forClubIndex: store.userClubIndex) }
    private var canAfford: Bool { cost.map { store.userClub.transferBudget >= $0 } ?? false }
    private var shortfall: Int? { cost.map { max(0, $0 - store.userClub.transferBudget) } }

    /// What one more level buys, from the same ladder the store narrates.
    private var nextBenefit: String? {
        guard cost != nil else { return nil }
        return kind.effectBlurb(level + 1)
    }

    // Broken-out lines (the inline versions made this card slow to
    // type-check).
    private func nextCostLine(_ cost: Int) -> some View {
        Text("Next: \(formatMoney(cost))")
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(canAfford ? CareerPalette.line : Retro.warning)
            .accessibilityIdentifier(CareerIdentifiers.facilitiesCost(kind))
    }

    private func nextBenefitLine(_ benefit: String) -> some View {
        Text(benefit)
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(CareerPalette.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func shortfallLine(_ shortfall: Int) -> some View {
        Text("Need \(formatMoney(shortfall)) more in the transfer budget")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(Retro.warning)
            .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerBlock
            FacilityLevelBar(level: level)
            Text(kind.effectBlurb(level))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(CareerPalette.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top) {
                nextStepsColumn
                Spacer(minLength: 8)
                upgradeButton
            }

            if let message {
                Text(message)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(CareerIdentifiers.facilitiesCard(kind) + ".message")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.facilitiesCard(kind))
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: Card sections (broken out so the compiler stays fast)

    private var headerBlock: some View {
        HStack(spacing: 8) {
            Image(systemName: kind.icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 26, height: 26)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.displayName.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text(FacilityLevelBar.tierLabel(for: kind, level: level))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
            Text("LVL \(level)/5")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(level >= 5 ? Retro.gold : CareerPalette.line)
                .accessibilityIdentifier(CareerIdentifiers.facilitiesLevel(kind))
        }
    }

    @ViewBuilder
    private var nextStepsColumn: some View {
        if let cost {
            nextCostLine(cost)
            if let nextBenefit {
                nextBenefitLine(nextBenefit)
            }
            if let shortfall, shortfall > 0 {
                shortfallLine(shortfall)
            }
        } else {
            Text("Fully developed — nothing left to build")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Retro.gold)
                .accessibilityIdentifier(CareerIdentifiers.facilitiesMax(kind))
        }
    }

    @ViewBuilder
    private var upgradeButton: some View {
        if let cost {
            let enabled = canAfford
            let background = enabled
                ? CareerPalette.line
                : CareerPalette.mutedInk.opacity(0.16)
            let labelColor = enabled
                ? CareerPalette.surface
                : CareerPalette.mutedInk.opacity(0.7)
            Button {
                Haptics.tap()
                message = store.investInFacility(kind)
            } label: {
                Text("UPGRADE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(background)
                    .foregroundStyle(labelColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!enabled)
            .accessibilityIdentifier(CareerIdentifiers.facilitiesUpgrade(kind))
            .accessibilityLabel(enabled
                ? "Upgrade \(kind.displayName) for \(formatMoney(cost))"
                : "Upgrade \(kind.displayName) — needs \(formatMoney(cost)), insufficient transfer budget")
        }
    }

    private var accessibilitySummary: String {
        var parts = ["\(kind.displayName), level \(level) of 5",
                     kind.tierLabel(level),
                     kind.effectBlurb(level)]
        if let cost {
            parts.append(canAfford
                ? "Next upgrade \(formatMoney(cost)), affordable"
                : "Next upgrade \(formatMoney(cost)), insufficient transfer budget")
        } else {
            parts.append("Maximum level reached")
        }
        return parts.joined(separator: ". ")
    }
}

/// A row of 5 small blocks showing a facility's level, re-tinted for the
/// pale canvas: grey while unbuilt, then green fills as it develops —
/// gold at the cap. A level number alone doesn't read as progression the
/// way a filling bar does.
private struct FacilityLevelBar: View {
    let level: Int
    private let maxLevel = 5

    static func tierLabel(for kind: FacilityKind, level: Int) -> String {
        kind.tierLabel(level)
    }

    private var fillColor: Color {
        level >= 5 ? Retro.gold : CareerPalette.line
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<maxLevel, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < level ? fillColor : CareerPalette.line.opacity(0.14))
                    .frame(width: 22, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress \(level) of 5")
    }
}
