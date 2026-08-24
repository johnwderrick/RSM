//
//  PlayerProfileSheet.swift
//  Retro Season Manager
//
//  The player profile sheet shown from squad, search and transfer
//  contexts alike.
//

import SwiftUI

// MARK: - Player profile

struct PlayerProfileSheet: View {
    let store: GameStore
    let context: ProfileContext
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingContractOffer = false
    @State private var showingBidOffer = false
    @State private var showingFreeAgentOffer = false
    @State private var showingTerminateConfirm = false
    @State private var showingLoanOut = false

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                header
                shortlistButton
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        attributesGrid
                        profileInfoPanel
                        attributesPanel
                        seasonPanel
                        if case .market(let target) = context { scoutSection(target) }
                        statusLine
                    }
                }
                actionButton
            }
            .padding(20)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .sheet(isPresented: $showingContractOffer) {
            ContractOfferSheet(store: store, player: player) { result in
                onAction(result)
                showingContractOffer = false
                dismiss()
            }
        }
        .sheet(isPresented: $showingBidOffer) {
            if case .market(let target) = context {
                TransferBidSheet(store: store, target: target) { result in
                    onAction(result)
                    showingBidOffer = false
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingFreeAgentOffer) {
            let fromClubIndex: Int? = { if case .scouted(_, let clubIndex) = context { return clubIndex }; return nil }()
            FreeAgentContractSheet(store: store, player: player, fromClubIndex: fromClubIndex) { result in
                onAction(result)
                showingFreeAgentOffer = false
                dismiss()
            }
        }
        .sheet(isPresented: $showingTerminateConfirm) {
            ConfirmActionSheet(
                title: "Release \(player.name)?",
                message: "The club pays a severance of \(formatMoney(max(50, player.wage * 4))) and his squad slot is freed immediately. This can't be undone.",
                confirmLabel: "TERMINATE CONTRACT"
            ) {
                onAction(store.terminateContract(player))
                dismiss()
            }
        }
        .sheet(isPresented: $showingLoanOut) {
            LoanOutSheet(store: store, player: player) { result in
                onAction(result)
                showingLoanOut = false
                dismiss()
            }
        }
    }

    /// The freshest copy of the player (squad players may have changed).
    private var player: Player {
        switch context {
        case .squad(let p):  return store.currentPlayer(p.id) ?? p
        case .market(let t): return t.player
        case .scouted(let p, _): return p
        }
    }

    private var shortlistButton: some View {
        let isShortlisted = store.isShortlisted(player.id)
        return Button {
            Haptics.tap()
            store.toggleShortlist(player.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isShortlisted ? "star.fill" : "star")
                Text(isShortlisted ? "SHORTLISTED" : "ADD TO SHORTLIST")
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(isShortlisted ? Retro.background : Retro.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isShortlisted ? Retro.highlight : Retro.panel.opacity(0.7))
            .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                PlayerPortraitView(name: player.name, position: player.position, age: player.age, nation: player.nationality, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text("Age \(player.age) · \(player.detailedPosition.fullName) · \(player.foot)")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                    HStack(spacing: 5) {
                        FlagView(nationality: player.nationality, width: 16)
                        Text(player.nationality)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.85))
                    }
                    OverallRatingView(rating: player.rating)
                }
                Spacer()
                VStack {
                    Text("\(player.rating)")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                    Text("OVR").font(.system(.caption2, design: .monospaced))
                }
            }
            if player.isAcademyProduct {
                Text("🎓 ACADEMY GRADUATE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Retro.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            if !player.secondaryPositions.isEmpty {
                HStack(spacing: 6) {
                    Text("ALSO PLAYS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                    ForEach(player.secondaryPositions, id: \.self) { role in
                        Text(role.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Retro.text)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Retro.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
    }

    private var attributesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            attribute("Value", formatMoney(player.value))
            attribute("Wage / wk", formatMoney(player.wage))
            attribute("Morale", player.moraleLabel)
            attribute("Contract", "Until \(store.contractExpiryYear(player))")
            attribute("Fitness", "\(player.fitnessLabel) (\(player.fitness)%)")
            attribute("Durability", player.durability.label)
            attribute("Personality", player.personality.label)
            if let clause = player.releaseClause {
                attribute("Release clause", formatMoney(clause))
            }
            if let clause = player.sellOnClause {
                attribute("Sell-on owed", "\(clause.percentage)% to \(clause.club)")
            }
            if let clause = player.buyBackClause {
                attribute("Buy-back", "\(formatMoney(clause.fee)) — \(clause.club)")
            }
        }
    }

    @ViewBuilder
    private func scoutSection(_ target: TransferTarget) -> some View {
        Panel(title: "SCOUTING") {
            switch store.scoutState(for: target) {
            case .unscouted:
                Text("Not yet scouted. Assign a scout to reveal potential and a recommendation.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            case .inProgress:
                Text("🔍 Scout watching — report due in a few days.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.highlight)
            case .scouted(let report):
                VStack(alignment: .leading, spacing: 4) {
                    Text("Potential ~\(report.potential)")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text(report.verdict)
                        .font(.system(.footnote, design: .monospaced))
                    Text(report.note)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                    Text("Estimated value \(formatMoney(report.valueRangeLow))–\(formatMoney(report.valueRangeHigh)) · \(report.confidence)% confidence")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.highlight.opacity(0.85))
                }
            }
        }
    }

    private func attribute(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))
            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Retro.panel.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var seasonPanel: some View {
        Panel(title: "THIS SEASON") {
            HStack {
                Text("Apps \(player.apps)")
                Spacer()
                Text(player.averageRating.map { String(format: "Avg %.2f", $0) } ?? "Avg —")
                Spacer()
                Text("Goals \(player.goals)")
            }
            .font(.system(.callout, design: .monospaced))
        }
    }

    private var profileInfoPanel: some View {
        Panel(title: "PROFILE") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                infoCell("Foot", player.foot)
                infoCell("Status", statusText)
                infoCell("Form", player.formGuide.isEmpty ? "—" : player.formGuide.map(String.init).joined(separator: "-"))
                infoCell("Ability", String(repeating: "★", count: player.stars) + String(repeating: "☆", count: 5 - player.stars))
                if let joined = store.clubTenureStart[player.id] {
                    infoCell("At the club", "Since Season \(joined)")
                }
            }
        }
    }

    private var statusText: String {
        switch context {
        case .squad:                     return store.squadStatus(for: player)
        case .market:                    return "Transfer target"
        case .scouted(_, let clubIndex):
            return store.clubs.indices.contains(clubIndex) ? store.clubs[clubIndex].name : "Unattached"
        }
    }

    private func infoCell(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Retro.text.opacity(0.8))
            Spacer()
            Text(value).bold().foregroundStyle(Retro.accent)
        }
        .font(.system(.footnote, design: .monospaced))
    }

    private var attributesPanel: some View {
        Panel(title: "ATTRIBUTES") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(player.attributeOrder, id: \.self) { name in
                    AttributeBar(name: name, value: player.attributes[name] ?? 0)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        VStack(alignment: .leading, spacing: 4) {
            if player.isInjured {
                if let date = store.expectedReturnDate(for: player) {
                    badge("⚠️ Injured — expected back \(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
                } else {
                    badge("⚠️ Injured — out ~\(player.injuryWeeks) wk\(player.injuryWeeks == 1 ? "" : "s")")
                }
            }
            if player.isSuspended {
                badge("⛔ Suspended for \(player.suspensionMatches) match\(player.suspensionMatches == 1 ? "" : "es")")
            }
            if player.isOnLoan {
                badge("↩︎ On loan — returns to parent club at season end")
            }
            if player.wantsToLeave {
                badge("💢 Unsettled — has asked to leave")
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(Retro.highlight)
            .font(.system(.footnote, design: .monospaced))
    }

    @ViewBuilder
    private var actionButton: some View {
        switch context {
        case .squad(let p):
            VStack(spacing: 8) {
                if !p.isOnLoan {
                    HStack(spacing: 8) {
                        pill(store.captainID == p.id ? "CAPTAIN ✓" : "CAPTAIN", filled: store.captainID == p.id) {
                            store.setCaptain(p); onAction("\(p.name) is now club captain."); dismiss()
                        }
                        pill(store.penaltyTakerID == p.id ? "PENS ✓" : "PENS", filled: store.penaltyTakerID == p.id) {
                            store.setPenaltyTaker(p); onAction("\(p.name) is on penalties."); dismiss()
                        }
                        pill(store.freeKickTakerID == p.id ? "FREE-KICKS ✓" : "FREE-KICKS", filled: store.freeKickTakerID == p.id) {
                            store.setFreeKickTaker(p); onAction("\(p.name) takes free-kicks."); dismiss()
                        }
                        pill(store.cornerTakerID == p.id ? "CORNERS ✓" : "CORNERS", filled: store.cornerTakerID == p.id) {
                            store.setCornerTaker(p); onAction("\(p.name) takes corners."); dismiss()
                        }
                    }
                    if p.wantsToLeave && !p.isTransferListed {
                        HStack(spacing: 8) {
                            pill("TALK ROUND", filled: false) {
                                onAction(store.respondToTransferRequest(p, agreeToList: false)); dismiss()
                            }
                            pill("AGREE TO LIST", filled: false) {
                                onAction(store.respondToTransferRequest(p, agreeToList: true)); dismiss()
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        pill("NEGOTIATE (\(formatMoney(store.renewalDemand(p)))/wk)", filled: false) {
                            Haptics.tap()
                            showingContractOffer = true
                        }
                        pill(p.isTransferListed ? "UNLIST" : "LIST", filled: false) {
                            store.toggleTransferList(p)
                            onAction(p.isTransferListed ? "\(p.name) taken off the list." : "\(p.name) listed.")
                            dismiss()
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain).foregroundStyle(Retro.text)
                    Spacer()
                    if !p.isOnLoan {
                        pill("LOAN OUT", filled: false, enabled: store.transferWindowOpen) {
                            Haptics.tap()
                            showingLoanOut = true
                        }
                        if store.canTerminateContract(p) {
                            pill("TERMINATE", filled: false, enabled: true) {
                                Haptics.tap()
                                showingTerminateConfirm = true
                            }
                        }
                        pill("SELL \(formatMoney(Int(Double(p.value) * 0.9)))",
                             filled: true, enabled: store.transferWindowOpen) {
                            onAction(store.sellPlayer(p)); dismiss()
                        }
                    }
                }
            }
        case .market(let target):
            let isFreeAgent = target.sellingClubIndex == nil
            let canBuy = store.transferWindowOpen && store.userClub.transferBudget >= target.askingPrice
                && store.userClub.wageBill + target.player.wage <= store.userClub.wageBudget
            let canSignFree = store.transferWindowOpen
                && store.userClub.wageBill + target.player.wage <= store.userClub.wageBudget
            let scouting: Bool = { if case .scouted = store.scoutState(for: target) { return false }; if case .inProgress = store.scoutState(for: target) { return false }; return true }()
            HStack(spacing: 8) {
                Button("Close") { dismiss() }
                    .buttonStyle(.plain).foregroundStyle(Retro.text)
                Spacer()
                if scouting {
                    pill("SCOUT", filled: false) { store.scout(target); onAction("Scout sent to watch \(target.player.name)."); dismiss() }
                }
                if target.sellingClubIndex != nil {
                    pill("LOAN", filled: false, enabled: store.transferWindowOpen) {
                        onAction(store.loanIn(target)); dismiss()
                    }
                }
                if isFreeAgent {
                    pill(store.transferWindowOpen ? "SIGN (FREE)" : "CLOSED",
                         filled: true, enabled: canSignFree) {
                        Haptics.tap()
                        showingFreeAgentOffer = true
                    }
                } else {
                    // Negotiating is the featured path — a real back-and-forth
                    // over the fee, not a one-tap purchase. Paying full asking
                    // price outright is still there for anyone in a hurry, just
                    // no longer the primary button.
                    pill(store.transferWindowOpen ? "PAY ASKING \(formatMoney(target.askingPrice))" : "CLOSED",
                         filled: false, enabled: canBuy) {
                        onAction(store.buyPlayer(target)); dismiss()
                    }
                    pill("NEGOTIATE", filled: true, enabled: store.transferWindowOpen) {
                        Haptics.tap()
                        showingBidOffer = true
                    }
                }
            }
        case .scouted(let p, let clubIndex):
            let isFreeAgent = p.contractYears <= 0
            let fee = store.negotiatedFee(for: p)
            let canBid = store.transferWindowOpen && store.userClub.transferBudget >= fee
                && store.userClub.wageBill + p.wage <= store.userClub.wageBudget
            let canSignFree = store.transferWindowOpen
                && store.userClub.wageBill + p.wage <= store.userClub.wageBudget
            HStack(spacing: 8) {
                Button("Close") { dismiss() }
                    .buttonStyle(.plain).foregroundStyle(Retro.text)
                Spacer()
                if isFreeAgent {
                    pill(store.transferWindowOpen ? "SIGN (FREE)" : "WINDOW CLOSED",
                         filled: true, enabled: canSignFree) {
                        Haptics.tap()
                        showingFreeAgentOffer = true
                    }
                } else {
                    pill(store.transferWindowOpen ? "OFFER \(formatMoney(fee))" : "WINDOW CLOSED",
                         filled: true, enabled: canBid) {
                        onAction(store.signFromSearch(clubIndex: clubIndex, playerID: p.id)); dismiss()
                    }
                }
            }
        }
    }

    private func pill(_ title: String, filled: Bool, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            filled ? Haptics.impact() : Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.system(.callout, design: .monospaced).bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(filled ? (enabled ? Retro.accent : Retro.panel) : Retro.panel)
                .foregroundStyle(filled ? (enabled ? Retro.background : Retro.text.opacity(0.5)) : Retro.text)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: (filled && enabled) ? Retro.accent.opacity(0.35) : .clear, radius: 5, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
    }
}

/// A two-way contract negotiation: pick a wage and length, the player
/// accepts or turns it down depending on how it stacks up against their
/// demand, morale, and — for very short or very long deals — their age.
