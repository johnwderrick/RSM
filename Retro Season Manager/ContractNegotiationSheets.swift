//
//  ContractNegotiationSheets.swift
//  Retro Season Manager
//
//  Contract renewal and free-agent signing negotiation sheets.
//

import SwiftUI

struct ContractOfferSheet: View {
    let store: GameStore
    let player: Player
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wage: Int
    @State private var years = 3
    @State private var lastOutcome: GameStore.ContractOutcome?
    @State private var includeReleaseClause = false
    @State private var releaseClause: Int
    @State private var signingOnFee = 0
    @State private var selectedTab: Tab = .offer

    enum Tab: String, CaseIterable, Identifiable {
        case offer = "Current Offer"
        case existing = "Existing Contract"
        var id: String { rawValue }
    }

    private var demand: Int
    private var step: Int
    private var clauseStep: Int
    private var feeStep: Int

    init(store: GameStore, player: Player, onResult: @escaping (String) -> Void) {
        self.store = store
        self.player = player
        self.onResult = onResult
        let demand = store.renewalDemand(player)
        self.demand = demand
        self.step = max(1, demand / 20)
        _wage = State(initialValue: demand)
        let suggestedClause = max(500, player.value * 2)
        self.clauseStep = max(100, suggestedClause / 20)
        _releaseClause = State(initialValue: suggestedClause)
        self.feeStep = max(25, player.value / 40)
    }

    private var newExpiryYear: Int { (store.startYear - 1) + store.season + years }

    private var squadRole: SquadRole { store.squadRole(for: player) }

    private var roleColor: Color {
        switch squadRole {
        case .starPlayer:       return Retro.highlight
        case .firstTeamRegular: return Retro.accent
        case .rotation:         return Color(red: 0.55, green: 0.70, blue: 0.95)
        case .backup:           return Retro.text.opacity(0.6)
        case .youthProspect:    return Color(red: 0.55, green: 0.85, blue: 0.55)
        }
    }

    private var roleFlavour: String {
        switch squadRole {
        case .starPlayer:       return "He knows he's one of your best — expect him to push hard for top wages."
        case .firstTeamRegular: return "A trusted regular in the side — a fair, market-rate deal keeps him happy."
        case .rotation:         return "In and out of the side — reasonable terms, nothing outlandish."
        case .backup:           return "Fringe squad player — happy to sign for less if it means staying part of things."
        case .youthProspect:    return "Academy prospect — game time matters more to him than the wage packet."
        }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("CONTRACT NEGOTIATION")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(player.name)
                        .font(.system(.title3, design: .monospaced).bold())
                    Text(squadRole.rawValue.uppercased())
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(roleColor)
                        .clipShape(Capsule())
                    Text("Currently wants \(formatMoney(demand))/wk")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                    Text(roleFlavour)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    VStack(spacing: 16) {
                        infoStrip

                        if let lastOutcome {
                            resultBanner(lastOutcome)
                        }

                        if selectedTab == .existing {
                            existingContractPanel
                        } else {

                        VStack(spacing: 10) {
                            Text("WEEKLY WAGE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 20) {
                                stepButton("minus.circle.fill") { wage = max(1, wage - step) }
                                Text(formatMoney(wage))
                                    .font(.system(.title2, design: .monospaced).bold())
                                    .foregroundStyle(wage >= demand ? Retro.accent : Color(red: 0.95, green: 0.55, blue: 0.35))
                                    .frame(minWidth: 110)
                                stepButton("plus.circle.fill") { wage += step }
                            }
                        }

                        VStack(spacing: 10) {
                            Text("CONTRACT LENGTH")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            Picker("Years", selection: $years) {
                                ForEach(1...5, id: \.self) { y in Text("\(y) yr\(y == 1 ? "" : "s")").tag(y) }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(spacing: 8) {
                            Text("SIGNING-ON FEE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 16) {
                                stepButton("minus.circle.fill") { signingOnFee = max(0, signingOnFee - feeStep) }
                                Text(signingOnFee > 0 ? formatMoney(signingOnFee) : "None")
                                    .font(.system(.callout, design: .monospaced).bold())
                                    .foregroundStyle(signingOnFee > 0 ? Retro.highlight : Retro.text.opacity(0.5))
                                    .frame(minWidth: 90)
                                stepButton("plus.circle.fill") { signingOnFee += feeStep }
                            }
                            Text("A one-off bonus, paid from the transfer budget, that sweetens the deal.")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.6))
                        }

                        VStack(spacing: 8) {
                            Toggle(isOn: $includeReleaseClause) {
                                Text("RELEASE CLAUSE")
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text.opacity(0.7))
                            }
                            .tint(Retro.accent)
                            if includeReleaseClause {
                                HStack(spacing: 16) {
                                    stepButton("minus.circle.fill") { releaseClause = max(clauseStep, releaseClause - clauseStep) }
                                    Text(formatMoney(releaseClause))
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundStyle(Retro.highlight)
                                        .frame(minWidth: 90)
                                    stepButton("plus.circle.fill") { releaseClause += clauseStep }
                                }
                                Text("Guarantees any rival bid for him is at least this much.")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.6))
                            }
                        }

                        offerSummaryBox

                        }
                    }
                    .padding(.vertical, 4)
                }

                if case .accepted(let message) = lastOutcome {
                    Button {
                        onResult(message)
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(.system(.headline, design: .monospaced).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Retro.accent)
                            .foregroundStyle(Retro.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                } else if selectedTab == .offer {
                    HStack(spacing: 10) {
                        Button("Cancel") { finish() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Retro.text)
                        Spacer()
                        Button {
                            makeOffer(wage: wage)
                        } label: {
                            Text(lastOutcome == nil ? "MAKE OFFER" : "OFFER AGAIN")
                                .font(.system(.headline, design: .monospaced).bold())
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Retro.accent)
                                .foregroundStyle(Retro.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                } else {
                    Button("Close") { finish() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    /// Leaves the sheet, passing the last outcome's message up (if there
    /// was one) so the caller's toast still reflects what happened.
    private func finish() {
        if let lastOutcome {
            switch lastOutcome {
            case .accepted(let message): onResult(message)
            case .rejected(let reason, _): onResult(reason)
            }
        }
        dismiss()
    }

    private func makeOffer(wage offerWage: Int) {
        Haptics.impact()
        let outcome = store.proposeRenewal(player, wage: offerWage, years: years,
                                           releaseClause: includeReleaseClause ? releaseClause : nil,
                                           signingOnFee: signingOnFee)
        lastOutcome = outcome
        switch outcome {
        case .accepted: Haptics.success()
        case .rejected: Haptics.warning()
        }
    }

    @ViewBuilder
    private func resultBanner(_ outcome: GameStore.ContractOutcome) -> some View {
        switch outcome {
        case .accepted(let message):
            VStack(spacing: 4) {
                Text("✅ ACCEPTED").font(.system(.caption, design: .monospaced).bold()).foregroundStyle(Retro.accent)
                Text(message).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Retro.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .rejected(let reason, let counterWage):
            VStack(spacing: 6) {
                Text("❌ DECLINED").font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                Text(reason).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
                if let counterWage {
                    Button {
                        wage = counterWage
                        makeOffer(wage: counterWage)
                    } label: {
                        Text("Offer \(formatMoney(counterWage))/wk instead")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Retro.highlight)
                            .foregroundStyle(Retro.background)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Retro.accent)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var infoStrip: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRANSFER BUDGET").font(.system(.caption2, design: .monospaced).bold()).foregroundStyle(Retro.text.opacity(0.6))
                Text(formatMoney(store.userClub.transferBudget)).font(.system(.callout, design: .monospaced).bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("MOOD").font(.system(.caption2, design: .monospaced).bold()).foregroundStyle(Retro.text.opacity(0.6))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Retro.text.opacity(0.15))
                        Capsule().fill(moraleColor).frame(width: geo.size.width * CGFloat(player.morale) / 100)
                    }
                }
                .frame(width: 70, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Retro.text.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var moraleColor: Color {
        switch player.morale {
        case 70...:   return Retro.accent
        case 45..<70: return Retro.highlight
        default:      return Color(red: 0.95, green: 0.45, blue: 0.35)
        }
    }

    private var existingContractPanel: some View {
        VStack(spacing: 14) {
            contractRow("Current wage", formatMoney(player.wage) + "/wk")
            contractRow("Years remaining", "\(player.contractYears)")
            contractRow("Contract expiry", "\(store.contractExpiryYear(player))")
            contractRow("Release clause", player.releaseClause.map(formatMoney) ?? "None")
            contractRow("Squad status", squadRole.rawValue)
        }
        .padding(.vertical, 8)
    }

    private func contractRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
        }
        .padding(.horizontal, 4)
    }

    private var offerSummaryBox: some View {
        Text(offerSummarySentence)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Retro.text.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Retro.text.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var offerSummarySentence: String {
        var sentence = "I'm proposing \(formatMoney(wage)) per week until 30/6/\(newExpiryYear)"
        if signingOnFee > 0 {
            sentence += ", plus a \(formatMoney(signingOnFee)) signing-on fee"
        }
        if includeReleaseClause {
            sentence += ", with a \(formatMoney(releaseClause)) release clause"
        }
        return sentence + "."
    }
}

/// Signing a free agent (or a search-found player with an already-expired
/// contract) — no transfer fee exists to negotiate, so this is personal
/// terms only: wage and contract length, same negotiation feel as a
/// renewal but landing the player at your club instead of keeping them put.
struct FreeAgentContractSheet: View {
    let store: GameStore
    let player: Player
    let fromClubIndex: Int?
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wage: Int
    @State private var years = 3
    @State private var lastOutcome: GameStore.ContractOutcome?
    @State private var signingOnFee = 0

    private var demand: Int
    private var step: Int
    private var feeStep: Int

    init(store: GameStore, player: Player, fromClubIndex: Int?, onResult: @escaping (String) -> Void) {
        self.store = store
        self.player = player
        self.fromClubIndex = fromClubIndex
        self.onResult = onResult
        let demand = store.freeAgentWageDemand(player)
        self.demand = demand
        self.step = max(1, demand / 20)
        _wage = State(initialValue: demand)
        self.feeStep = max(25, player.value / 40)
    }

    private var squadRole: SquadRole { store.squadRole(for: player) }

    private var roleColor: Color {
        switch squadRole {
        case .starPlayer:       return Retro.highlight
        case .firstTeamRegular: return Retro.accent
        case .rotation:         return Color(red: 0.55, green: 0.70, blue: 0.95)
        case .backup:           return Retro.text.opacity(0.6)
        case .youthProspect:    return Color(red: 0.55, green: 0.85, blue: 0.55)
        }
    }

    private var newExpiryYear: Int { (store.startYear - 1) + store.season + years }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("FREE TRANSFER")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(player.name)
                        .font(.system(.title3, design: .monospaced).bold())
                    Text(squadRole.rawValue.uppercased())
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(roleColor)
                        .clipShape(Capsule())
                    Text("No fee — just agree personal terms. Wants \(formatMoney(demand))/wk")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                ScrollView {
                    VStack(spacing: 16) {
                        infoStrip

                        if let lastOutcome {
                            resultBanner(lastOutcome)
                        }

                        VStack(spacing: 10) {
                            Text("WEEKLY WAGE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 20) {
                                stepButton("minus.circle.fill") { wage = max(1, wage - step) }
                                Text(formatMoney(wage))
                                    .font(.system(.title2, design: .monospaced).bold())
                                    .foregroundStyle(wage >= demand ? Retro.accent : Color(red: 0.95, green: 0.55, blue: 0.35))
                                    .frame(minWidth: 110)
                                stepButton("plus.circle.fill") { wage += step }
                            }
                        }

                        VStack(spacing: 10) {
                            Text("CONTRACT LENGTH")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            Picker("Years", selection: $years) {
                                ForEach(1...5, id: \.self) { y in Text("\(y) yr\(y == 1 ? "" : "s")").tag(y) }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(spacing: 8) {
                            Text("SIGNING-ON FEE")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 16) {
                                stepButton("minus.circle.fill") { signingOnFee = max(0, signingOnFee - feeStep) }
                                Text(signingOnFee > 0 ? formatMoney(signingOnFee) : "None")
                                    .font(.system(.callout, design: .monospaced).bold())
                                    .foregroundStyle(signingOnFee > 0 ? Retro.highlight : Retro.text.opacity(0.5))
                                    .frame(minWidth: 90)
                                stepButton("plus.circle.fill") { signingOnFee += feeStep }
                            }
                            Text("A one-off bonus, paid from the transfer budget, that sweetens the deal.")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.6))
                        }

                        offerSummaryBox
                    }
                    .padding(.vertical, 4)
                }

                if case .accepted(let message) = lastOutcome {
                    Button {
                        onResult(message)
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(.system(.headline, design: .monospaced).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Retro.accent)
                            .foregroundStyle(Retro.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                } else {
                    HStack(spacing: 10) {
                        Button("Cancel") { finish() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Retro.text)
                        Spacer()
                        Button {
                            makeOffer(wage: wage)
                        } label: {
                            Text(lastOutcome == nil ? "MAKE OFFER" : "OFFER AGAIN")
                                .font(.system(.headline, design: .monospaced).bold())
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(Retro.accent)
                                .foregroundStyle(Retro.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func finish() {
        if let lastOutcome {
            switch lastOutcome {
            case .accepted(let message): onResult(message)
            case .rejected(let reason, _): onResult(reason)
            }
        }
        dismiss()
    }

    private func makeOffer(wage offerWage: Int) {
        Haptics.impact()
        let outcome = store.signFreeAgent(player, fromClubIndex: fromClubIndex, wage: offerWage, years: years, signingOnFee: signingOnFee)
        lastOutcome = outcome
        switch outcome {
        case .accepted: Haptics.success()
        case .rejected: Haptics.warning()
        }
    }

    @ViewBuilder
    private func resultBanner(_ outcome: GameStore.ContractOutcome) -> some View {
        switch outcome {
        case .accepted(let message):
            VStack(spacing: 4) {
                Text("✅ SIGNED").font(.system(.caption, design: .monospaced).bold()).foregroundStyle(Retro.accent)
                Text(message).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Retro.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .rejected(let reason, let counterWage):
            VStack(spacing: 6) {
                Text("❌ DECLINED").font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                Text(reason).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
                if let counterWage {
                    Button {
                        wage = counterWage
                        makeOffer(wage: counterWage)
                    } label: {
                        Text("Offer \(formatMoney(counterWage))/wk instead")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Retro.highlight)
                            .foregroundStyle(Retro.background)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Retro.accent)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var infoStrip: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRANSFER BUDGET").font(.system(.caption2, design: .monospaced).bold()).foregroundStyle(Retro.text.opacity(0.6))
                Text(formatMoney(store.userClub.transferBudget)).font(.system(.callout, design: .monospaced).bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("MOOD").font(.system(.caption2, design: .monospaced).bold()).foregroundStyle(Retro.text.opacity(0.6))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Retro.text.opacity(0.15))
                        Capsule().fill(moraleColor).frame(width: geo.size.width * CGFloat(player.morale) / 100)
                    }
                }
                .frame(width: 70, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Retro.text.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var moraleColor: Color {
        switch player.morale {
        case 70...:   return Retro.accent
        case 45..<70: return Retro.highlight
        default:      return Color(red: 0.95, green: 0.45, blue: 0.35)
        }
    }

    private var offerSummaryBox: some View {
        Text(offerSummarySentence)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Retro.text.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Retro.text.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var offerSummarySentence: String {
        var sentence = "I'm proposing \(formatMoney(wage)) per week until 30/6/\(newExpiryYear)"
        if signingOnFee > 0 {
            sentence += ", plus a \(formatMoney(signingOnFee)) signing-on fee"
        }
        return sentence + "."
    }
}

/// Every scouting assessment filed so far, in one list — findings from a
/// specific "scout this player" assignment and from a broader world/youth
/// scouting mission alike. A report whose target has since left the
/// transfer market (sold elsewhere, window closed) still shows, just
/// without a way to act on it.
struct ScoutReportsSheet: View {
    let store: GameStore
    let onSelect: (ProfileContext) -> Void
    @Environment(\.dismiss) private var dismiss

    private var reports: [ScoutReport] {
        store.scoutedReports.values.sorted { $0.potential > $1.potential }
    }

    private func target(for report: ScoutReport) -> TransferTarget? {
        store.transferMarket.first { $0.player.id == report.playerID }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("SCOUT REPORTS")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Retro.text.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                if reports.isEmpty {
                    Spacer()
                    Text("No reports filed yet — scout a target, or send scouts out into the world.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(reports.enumerated()), id: \.offset) { _, report in
                                reportRow(report)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func reportRow(_ report: ScoutReport) -> some View {
        let live = target(for: report)
        return Button {
            guard let live else { return }
            Haptics.tap()
            onSelect(.market(live))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(report.playerName)
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                    Spacer()
                    Text("POT ~\(report.potential)")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                }
                Text(report.verdict)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
                Text("Est. \(formatMoney(report.valueRangeLow))–\(formatMoney(report.valueRangeHigh)) · \(report.confidence)% confidence")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.highlight.opacity(0.8))
                HStack {
                    Text(report.note)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                    Spacer()
                    if live == nil {
                        Text("NO LONGER AVAILABLE")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.text.opacity(0.5))
                    } else {
                        Text(live.map { formatMoney($0.askingPrice) } ?? "")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.accent)
                    }
                }
            }
            .padding(10)
            .background(Retro.panel.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(live == nil)
    }
}

/// A haggling flow for a transfer-market target: bid below asking price
/// and the selling club may reject outright or counter with a figure
/// they'd actually accept, instead of asking price being the only number
/// that ever works.
