//
//  TransferNegotiationSheets.swift
//  Retro Season Manager
//
//  Scout reports, transfer-fee negotiation, personal terms and loan
//  negotiation sheets.
//

import SwiftUI

struct TransferBidSheet: View {
    let store: GameStore
    let target: TransferTarget
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Int
    @State private var lastOutcome: GameStore.BidOutcome?
    @State private var sellOnPercentage = 0
    @State private var includeBuyBack = false
    @State private var buyBackFee: Int
    @State private var includedPlayerID: UUID?
    @State private var selectedTab: Tab = .offer

    enum Tab: String, CaseIterable, Identifiable {
        case offer = "Current Offer"
        case interested = "Interested Clubs"
        var id: String { rawValue }
    }

    private let step: Int
    private let buyBackStep: Int

    init(store: GameStore, target: TransferTarget, onResult: @escaping (String) -> Void) {
        self.store = store
        self.target = target
        self.onResult = onResult
        let starting = Int(Double(target.askingPrice) * 0.85)
        _amount = State(initialValue: starting)
        self.step = max(1, target.askingPrice / 20)
        let suggestedBuyBack = max(50, Int(Double(target.player.value) * 1.3))
        self.buyBackFee = suggestedBuyBack
        self.buyBackStep = max(25, suggestedBuyBack / 20)
    }

    private var sellerIndex: Int? { target.sellingClubIndex }
    private var sellerName: String { sellerIndex.map { store.clubs[$0].name } ?? "Free agent" }

    private var sellerUnderPressure: Bool {
        guard let sellerIndex else { return false }
        let seller = store.clubs[sellerIndex]
        return seller.transferBudget < seller.wageBill * 8
    }

    private var interestedClubsCount: Int {
        let ratingFactor = max(0, (target.player.rating - 65) / 8)
        let seed = abs(target.id.hashValue) % 3
        return min(4, ratingFactor + seed)
    }

    private var assistantAdvice: String {
        if sellerUnderPressure {
            return "\(sellerName) are short on transfer funds and may accept a below-value offer."
        }
        if target.player.contractYears <= 1 {
            return "\(target.player.name)'s contract is close to expiry — \(sellerName) may be more willing to do business."
        }
        return "\(target.player.name) isn't near the end of his contract and is unlikely to be sold cheaply."
    }

    private var eligibleMakeweights: [Player] {
        Array(
            store.userClub.players
                .filter { !store.userStarterIDs.contains($0.id) }
                .sorted { $0.value > $1.value }
                .prefix(8)
        )
    }

    private var includedPlayer: Player? {
        includedPlayerID.flatMap { id in store.userClub.players.first { $0.id == id } }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("NEGOTIATE FEE")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(target.player.name)
                        .font(.system(.title3, design: .monospaced).bold())
                    Text("Asking price \(formatMoney(target.askingPrice)) · \(sellerName)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                    if let sellerIndex, store.clubNegotiationStances.indices.contains(sellerIndex) {
                        Text(store.clubNegotiationStances[sellerIndex].displayLabel.uppercased())
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(Retro.highlight.opacity(0.8))
                    }
                }

                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    VStack(spacing: 16) {
                        if let lastOutcome {
                            resultBanner(lastOutcome)
                        }

                        if selectedTab == .interested {
                            interestedClubsPanel
                        } else {

                        assistantAdviceBox

                        VStack(spacing: 10) {
                            Text("YOUR OFFER")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .foregroundStyle(Retro.text.opacity(0.7))
                            HStack(spacing: 20) {
                                stepButton("minus.circle.fill") { amount = max(step, amount - step) }
                                Text(formatMoney(amount))
                                    .font(.system(.title2, design: .monospaced).bold())
                                    .foregroundStyle(amount >= target.askingPrice ? Retro.accent : Color(red: 0.95, green: 0.55, blue: 0.35))
                                    .frame(minWidth: 110)
                                stepButton("plus.circle.fill") { amount += step }
                            }
                        }

                        if let sellerIndex {
                            VStack(spacing: 8) {
                                Text("SELL-ON PERCENTAGE")
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text.opacity(0.7))
                                HStack(spacing: 16) {
                                    stepButton("minus.circle.fill") { sellOnPercentage = max(0, sellOnPercentage - 5) }
                                    Text(sellOnPercentage > 0 ? "\(sellOnPercentage)%" : "None")
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundStyle(sellOnPercentage > 0 ? Retro.highlight : Retro.text.opacity(0.5))
                                        .frame(minWidth: 90)
                                    stepButton("plus.circle.fill") { sellOnPercentage = min(25, sellOnPercentage + 5) }
                                }
                                Text("A cut of any future resale for \(store.clubs[sellerIndex].name) — sweetens the deal.")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.6))
                            }

                            VStack(spacing: 8) {
                                Toggle(isOn: $includeBuyBack) {
                                    Text("BUY-BACK CLAUSE")
                                        .font(.system(.caption2, design: .monospaced).bold())
                                        .foregroundStyle(Retro.text.opacity(0.7))
                                }
                                .tint(Retro.accent)
                                if includeBuyBack {
                                    HStack(spacing: 16) {
                                        stepButton("minus.circle.fill") { buyBackFee = max(buyBackStep, buyBackFee - buyBackStep) }
                                        Text(formatMoney(buyBackFee))
                                            .font(.system(.callout, design: .monospaced).bold())
                                            .foregroundStyle(Retro.highlight)
                                            .frame(minWidth: 90)
                                        stepButton("plus.circle.fill") { buyBackFee += buyBackStep }
                                    }
                                    Text("\(store.clubs[sellerIndex].name) can re-sign him at this fee later. A lower fee helps close the deal now.")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(Retro.text.opacity(0.6))
                                }
                            }

                            if !eligibleMakeweights.isEmpty {
                                VStack(spacing: 8) {
                                    Text("EXCHANGE PLAYER")
                                        .font(.system(.caption2, design: .monospaced).bold())
                                        .foregroundStyle(Retro.text.opacity(0.7))
                                    Picker("Exchange", selection: $includedPlayerID) {
                                        Text("None").tag(UUID?.none)
                                        ForEach(eligibleMakeweights) { p in
                                            Text("\(p.name) (\(formatMoney(p.value)))").tag(Optional(p.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Retro.accent)
                                    if let includedPlayer {
                                        Text("\(includedPlayer.name) goes the other way, cutting the cash you need to find.")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.6))
                                    }
                                }
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
                            makeBid(amount)
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

    private func finish() {
        if let lastOutcome {
            switch lastOutcome {
            case .accepted(let message): onResult(message)
            case .rejected(let reason, _): onResult(reason)
            }
        }
        dismiss()
    }

    private func makeBid(_ offer: Int) {
        Haptics.impact()
        let outcome = store.proposeBid(target, amount: offer, sellOnPercentage: sellOnPercentage,
                                       buyBackFee: includeBuyBack ? buyBackFee : 0, includedPlayer: includedPlayer)
        lastOutcome = outcome
        switch outcome {
        case .accepted: Haptics.success()
        case .rejected: Haptics.warning()
        }
    }

    @ViewBuilder
    private func resultBanner(_ outcome: GameStore.BidOutcome) -> some View {
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
        case .rejected(let reason, let counterPrice):
            VStack(spacing: 6) {
                Text("❌ REJECTED").font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                Text(reason).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
                if let counterPrice {
                    Button {
                        amount = counterPrice
                        makeBid(counterPrice)
                    } label: {
                        Text("Offer \(formatMoney(counterPrice)) instead")
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

    private var assistantAdviceBox: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.fill.questionmark")
                .foregroundStyle(Retro.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("ASSISTANT ADVICE")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.text.opacity(0.6))
                Text(assistantAdvice)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Retro.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var interestedClubsPanel: some View {
        VStack(spacing: 10) {
            if interestedClubsCount == 0 {
                Text("No other clubs are known to be tracking \(target.player.name) right now.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                    .multilineTextAlignment(.center)
            } else {
                Text("\(interestedClubsCount) other club\(interestedClubsCount == 1 ? "" : "s") \(interestedClubsCount == 1 ? "is" : "are") also monitoring this move.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
                Text("Dragging the negotiation out risks losing him to a rival bid — move quickly if you want him.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
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
        var sentence = "Offering \(formatMoney(amount))"
        if let includedPlayer {
            sentence += " plus \(includedPlayer.name)"
        }
        sentence += " for \(target.player.name)"
        if sellOnPercentage > 0 {
            sentence += ", with a \(sellOnPercentage)% sell-on"
        }
        if includeBuyBack {
            sentence += ", and a \(formatMoney(buyBackFee)) buy-back option"
        }
        return sentence + "."
    }
}

/// Personal-terms negotiation for a transfer whose fee is already agreed
/// with the selling club — the final step that actually completes a
/// signing initiated through `TransferBidSheet` or a direct "pay asking"
/// buy, once the player's medical is done and he's ready to talk.
struct PersonalTermsSheet: View {
    let store: GameStore
    let deal: PendingTransferDeal
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wage: Int
    @State private var years = 3
    @State private var lastOutcome: GameStore.ContractOutcome?
    @State private var signingOnFee = 0

    private var demand: Int
    private var step: Int
    private var feeStep: Int

    init(store: GameStore, deal: PendingTransferDeal, onResult: @escaping (String) -> Void) {
        self.store = store
        self.deal = deal
        self.onResult = onResult
        let demand = store.transferWageDemand(deal.player)
        self.demand = demand
        self.step = max(1, demand / 20)
        _wage = State(initialValue: demand)
        self.feeStep = max(25, deal.player.value / 40)
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("PERSONAL TERMS")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(deal.player.name)
                        .font(.system(.title3, design: .monospaced).bold())
                    Text("Fee of \(formatMoney(deal.agreedFee)) already agreed with \(deal.sellingClubName)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                        .multilineTextAlignment(.center)
                    Text("Wants \(formatMoney(demand))/wk to make the move")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                }

                ScrollView {
                    VStack(spacing: 16) {
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
                            Text("A one-off bonus, paid on top of the transfer fee, that sweetens the deal.")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.6))
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
                } else {
                    HStack(spacing: 10) {
                        Button("Cancel") { finish() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Retro.text)
                        Spacer()
                        Button {
                            makeOffer(wage: wage)
                        } label: {
                            Text(lastOutcome == nil ? "PROPOSE TERMS" : "OFFER AGAIN")
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
        let outcome = store.finalizePersonalTerms(deal, wage: offerWage, years: years, signingOnFee: signingOnFee)
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
                Text("✅ AGREED").font(.system(.caption, design: .monospaced).bold()).foregroundStyle(Retro.accent)
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
}

/// Loaning a squad player out: pick a genuinely interested club, decide
/// whether to ask for a fee, and see whether they actually say yes — real
/// loan logic (squad need, wage affordability) instead of a single-tap
/// instant move to a random club.
struct LoanOutSheet: View {
    let store: GameStore
    let player: Player
    let onResult: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    let candidates: [Int]
    @State private var selectedClubIndex: Int?
    @State private var fee = 0
    @State private var lastOutcome: GameStore.LoanOutcome?

    private let feeStep: Int

    init(store: GameStore, player: Player, onResult: @escaping (String) -> Void) {
        self.store = store
        self.player = player
        self.onResult = onResult
        let candidates = store.loanCandidates(for: player)
        self.candidates = candidates
        _selectedClubIndex = State(initialValue: candidates.first)
        self.feeStep = max(10, player.value / 40)
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("LOAN OUT")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(player.name)
                        .font(.system(.title3, design: .monospaced).bold())
                    Text("\(formatMoney(player.wage))/wk comes off your wage bill for the loan.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                if candidates.isEmpty {
                    Spacer()
                    Text("No club has room or a genuine need for him right now.")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if let lastOutcome {
                                resultBanner(lastOutcome)
                            }

                            VStack(spacing: 8) {
                                Text("DESTINATION")
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text.opacity(0.7))
                                Picker("Club", selection: $selectedClubIndex) {
                                    ForEach(candidates, id: \.self) { index in
                                        Text(store.clubs[index].name).tag(Optional(index))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Retro.accent)
                            }

                            VStack(spacing: 8) {
                                Text("LOAN FEE")
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text.opacity(0.7))
                                HStack(spacing: 16) {
                                    stepButton("minus.circle.fill") { fee = max(0, fee - feeStep) }
                                    Text(fee > 0 ? formatMoney(fee) : "None")
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundStyle(fee > 0 ? Retro.highlight : Retro.text.opacity(0.5))
                                        .frame(minWidth: 90)
                                    stepButton("plus.circle.fill") { fee += feeStep }
                                }
                                Text("Asking for a fee makes them less likely to say yes.")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.6))
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
                    } else {
                        HStack(spacing: 10) {
                            Button("Cancel") { finish() }
                                .buttonStyle(.plain)
                                .foregroundStyle(Retro.text)
                            Spacer()
                            Button {
                                propose()
                            } label: {
                                Text(lastOutcome == nil ? "PROPOSE LOAN" : "TRY AGAIN")
                                    .font(.system(.headline, design: .monospaced).bold())
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 12)
                                    .background(Retro.accent)
                                    .foregroundStyle(Retro.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(PressableButtonStyle())
                            .disabled(selectedClubIndex == nil)
                        }
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
            case .rejected(let reason): onResult(reason)
            }
        }
        dismiss()
    }

    private func propose() {
        guard let selectedClubIndex else { return }
        Haptics.impact()
        let outcome = store.proposeLoanOut(player, toClubIndex: selectedClubIndex, fee: fee)
        lastOutcome = outcome
        switch outcome {
        case .accepted: Haptics.success()
        case .rejected: Haptics.warning()
        }
    }

    @ViewBuilder
    private func resultBanner(_ outcome: GameStore.LoanOutcome) -> some View {
        switch outcome {
        case .accepted(let message):
            VStack(spacing: 4) {
                Text("✅ AGREED").font(.system(.caption, design: .monospaced).bold()).foregroundStyle(Retro.accent)
                Text(message).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Retro.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        case .rejected(let reason):
            VStack(spacing: 4) {
                Text("❌ PASSED").font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                Text(reason).font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.85))
                    .multilineTextAlignment(.center)
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
}

