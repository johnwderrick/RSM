import SwiftUI

/// The small, persistent facility set available from the Legends Club hub.
/// Levels are stored on `LegendsProfile` as a string-keyed map so older saves
/// decode safely with every facility at level zero.
enum LegendsFacilityKind: String, Codable, CaseIterable, Identifiable, Equatable {
    case trainingCentre
    case youthAcademy
    case scoutingNetwork
    case clubStadium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trainingCentre: return "Training Centre"
        case .youthAcademy: return "Youth Academy"
        case .scoutingNetwork: return "Scouting Network"
        case .clubStadium: return "Club Stadium"
        }
    }

    var subtitle: String {
        switch self {
        case .trainingCentre: return "Turn sessions into better development"
        case .youthAcademy: return "Raise the ceiling of young signings"
        case .scoutingNetwork: return "Make potential reports more precise"
        case .clubStadium: return "Build a stronger home advantage"
        }
    }

    var icon: String {
        switch self {
        case .trainingCentre: return "figure.run"
        case .youthAcademy: return "graduationcap.fill"
        case .scoutingNetwork: return "binoculars.fill"
        case .clubStadium: return "sportscourt.fill"
        }
    }

    /// Base prices deliberately use Balance only. Pack tokens never enter
    /// this table or the upgrade transaction.
    var baseUpgradeCost: Int {
        switch self {
        case .trainingCentre: return 100
        case .youthAcademy: return 120
        case .scoutingNetwork: return 140
        case .clubStadium: return 160
        }
    }

    var maxLevel: Int {
        switch self {
        case .scoutingNetwork: return 3
        case .trainingCentre, .youthAcademy, .clubStadium: return 5
        }
    }

    func upgradeCost(at level: Int) -> Int? {
        guard level >= 0, level < maxLevel else { return nil }
        // Level 0 → 1 is the base price; every following level costs one
        // more base-price unit. This is predictable and visible in the UI.
        return baseUpgradeCost * (level + 1)
    }

    func currentBenefit(at level: Int) -> String {
        let level = min(max(level, 0), maxLevel)
        switch self {
        case .trainingCentre:
            return level == 0 ? "Standard training progress." : "+\(level * 5)% training progress per session."
        case .youthAcademy:
            return level == 0 ? "Standard potential for new careers." : "+\(level) potential for newly signed players aged 23 or younger."
        case .scoutingNetwork:
            if level >= 3 { return "Exact potential is shown for signed players." }
            if level == 2 { return "Sharper potential bands for signed players." }
            if level == 1 { return "Clearer potential reports for signed players." }
            return "Broad potential reports."
        case .clubStadium:
            return level == 0 ? "No home-fixture facility bonus." : "+\(level) team strength for home fixtures."
        }
    }

    func nextBenefit(after level: Int) -> String? {
        guard level < maxLevel else { return nil }
        return currentBenefit(at: level + 1)
    }
}

enum LegendsFacilityUpgradeResult: Equatable {
    case upgraded(kind: LegendsFacilityKind, from: Int, to: Int, cost: Int)
    case insufficientBalance(required: Int, available: Int)
    case maximumLevel
}

/// The Legends Club facilities destination. Facility levels and the Balance
/// transaction are owned by `LegendsStore`; this view only presents their
/// current state and invokes the existing upgrade action.
struct LegendsFacilitiesView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var feedback: String?

    var body: some View {
        LegendsMenuShell(
            store: store,
            title: "FACILITIES",
            subtitle: "UPGRADE THE CLUB",
            icon: "building.2.crop.circle.fill",
            accent: LegendsPalette.gold,
            onBack: onBack,
            currentNav: .club,
            onNavigate: onNavigate
        ) {
            VStack(alignment: .leading, spacing: 14) {
                balanceSummary

                if let feedback {
                    Text(feedback)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LegendsPalette.greenWash)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("legends.facilities.feedback")
                        .accessibilityLabel(feedback)
                }

                Text("INVEST IN THE CLUB")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                    .padding(.top, 2)

                // This is the only scroll container for the destination: the
                // shared shell owns it. The grid adapts from one column on a
                // compact landscape phone to multiple columns when width is
                // available, without nesting another ScrollView.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 12)], spacing: 12) {
                    ForEach(LegendsFacilityKind.allCases) { kind in
                        facilityCard(kind)
                    }
                }
                .accessibilityIdentifier("legends.facilities.cards")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("legends.facilities.screen")
        }
    }

    private var balanceSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(LegendsPalette.goldDeep)
                    .frame(width: 48, height: 48)
                    .background(LegendsPalette.goldWash)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("CLUB BALANCE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                    Text("\(store.profile.coins)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LegendsPalette.navy)
                        .accessibilityIdentifier("legends.facilities.balance")
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("BALANCE ONLY")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.green)
                    Text("TOKENS STAY WITH PACKS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                        .multilineTextAlignment(.trailing)
                }
            }

            Text("Facility upgrades use the club Balance. Pack tokens are never spent here.")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.66))
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.gold.opacity(0.32), lineWidth: 1.2))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.facilities.summary")
    }

    private func facilityCard(_ kind: LegendsFacilityKind) -> some View {
        let level = store.facilityLevel(kind)
        let maxLevel = kind.maxLevel
        let cost = store.facilityUpgradeCost(kind)
        let missing = max(0, (cost ?? 0) - store.facilityBalance)
        let isMaxed = cost == nil
        let canUpgrade = cost != nil && missing == 0
        let accent = facilityAccent(kind)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: kind.icon)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(accent)
                    .frame(width: 42, height: 42)
                    .background(accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.displayName.uppercased())
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(LegendsPalette.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(kind.subtitle.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Text("LV \(level)/\(maxLevel)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(isMaxed ? LegendsPalette.green : accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background((isMaxed ? LegendsPalette.green : accent).opacity(0.13))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("legends.facilities.level.\(kind.rawValue)")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CURRENT BENEFIT")
                    Spacer()
                    Text(level == 0 ? "BASELINE" : "ACTIVE")
                        .foregroundStyle(level == 0 ? LegendsPalette.navy.opacity(0.52) : LegendsPalette.green)
                }
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                Text(kind.currentBenefit(at: level))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }

            if let nextBenefit = kind.nextBenefit(after: level) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT LEVEL BENEFIT")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)
                    Text(nextBenefit)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.78))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
            } else {
                Text("MAXIMUM LEVEL REACHED — BENEFIT FULLY ACTIVE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.green)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("PROGRESS")
                    Spacer()
                    Text("\(level) / \(maxLevel)")
                        .monospacedDigit()
                }
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                LegendsProgressBar(value: Double(level) / Double(maxLevel), tint: accent, height: 8)
                    .accessibilityIdentifier("legends.facilities.progress.\(kind.rawValue)")
            }

            Divider().overlay(LegendsPalette.navy.opacity(0.10))

            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UPGRADE COST")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                    if let cost {
                        Text("\(cost) BALANCE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(canUpgrade ? LegendsPalette.navy : LegendsPalette.orange)
                    } else {
                        Text("MAX LEVEL")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.green)
                    }
                }

                Spacer(minLength: 4)

                Button {
                    Haptics.tap()
                    let result = store.upgradeFacility(kind)
                    handle(result)
                } label: {
                    Text(actionTitle(isMaxed: isMaxed, canUpgrade: canUpgrade, missing: missing))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(isMaxed || !canUpgrade ? LegendsPalette.navy.opacity(0.56) : .white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .frame(minWidth: 118)
                        .background(isMaxed || !canUpgrade ? LegendsPalette.contentBackground : accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!canUpgrade)
                .accessibilityIdentifier("legends.facilities.upgrade.\(kind.rawValue)")
                .accessibilityLabel(isMaxed ? "\(kind.displayName), maximum level reached" : canUpgrade ? "Upgrade \(kind.displayName) for \(cost ?? 0) Balance" : "\(kind.displayName), need \(missing) more Balance")
            }

            Text(availabilityText(isMaxed: isMaxed, canUpgrade: canUpgrade, missing: missing))
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(isMaxed ? LegendsPalette.green : canUpgrade ? LegendsPalette.green : LegendsPalette.orange)
                .lineLimit(2)
                .accessibilityIdentifier("legends.facilities.availability.\(kind.rawValue)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.24), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.08), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.facilities.card.\(kind.rawValue)")
    }

    private func facilityAccent(_ kind: LegendsFacilityKind) -> Color {
        switch kind {
        case .trainingCentre: return LegendsPalette.green
        case .youthAcademy: return LegendsPalette.blue
        case .scoutingNetwork: return LegendsPalette.purple
        case .clubStadium: return LegendsPalette.goldDeep
        }
    }

    private func actionTitle(isMaxed: Bool, canUpgrade: Bool, missing: Int) -> String {
        if isMaxed { return "MAXED" }
        if canUpgrade { return "UPGRADE" }
        return "NEED \(missing) MORE"
    }

    private func availabilityText(isMaxed: Bool, canUpgrade: Bool, missing: Int) -> String {
        if isMaxed { return "AVAILABLE STATE · MAXIMUM LEVEL" }
        if canUpgrade { return "AVAILABLE · BALANCE COVERS THIS UPGRADE" }
        return "UNAVAILABLE · NEED \(missing) MORE BALANCE"
    }

    private func handle(_ result: LegendsFacilityUpgradeResult) {
        switch result {
        case .upgraded(let kind, _, let to, let cost):
            Haptics.success()
            feedback = "\(kind.displayName.uppercased()) UPGRADED TO LEVEL \(to). \(cost) BALANCE SPENT."
        case .insufficientBalance(let required, let available):
            feedback = "UPGRADE UNAVAILABLE. NEED \(required - available) MORE BALANCE."
        case .maximumLevel:
            feedback = "THIS FACILITY IS ALREADY AT MAXIMUM LEVEL."
        }
    }
}
