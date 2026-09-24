//
//  ContractNegotiationSheets.swift
//  Retro Season Manager
//
//  Contract renewal and free-agent signing negotiation sheets, in the
//  accepted Career light-card design language (pale canvas, white cards,
//  ink headings, green primary actions, restrained orange/red only for
//  warnings). One authoritative vertical scroll container per sheet, a
//  pinned header with an always-reachable close, and pinned primary
//  actions; monospaced figures for every monetary value.
//
//  Negotiation mechanics are untouched: offers still go through the
//  store's authoritative `proposeRenewal` / `signFreeAgent` paths, and
//  every state machine (tabs, offer/offer-again, counter pills, the
//  outcome toast) behaves exactly as before.
//

import SwiftUI

// MARK: - Shared sheet building blocks (light-card language)

/// Pinned close control shared by the negotiation sheets.
struct SheetCloseButton: View {
    var identifier: String
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("Close")
    }
}

/// A white stat card for one key figure.
struct SheetStatCard: View {
    let title: String
    let value: String
    var accent: Color = CareerPalette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

/// The light-card version of the budget + mood strip shared by the
/// negotiation sheets.
private struct NegotiationInfoStrip: View {
    let store: GameStore
    let player: Player

    var body: some View {
        HStack(spacing: 8) {
            SheetStatCard(title: "TRANSFER BUDGET", value: formatMoney(store.userClub.transferBudget))
            SheetStatCard(title: "WAGE BILL / BUDGET",
                          value: "\(formatMoney(store.userClub.wageBill)) / \(formatMoney(store.userClub.wageBudget))",
                          accent: store.userClub.wageBill <= store.userClub.wageBudget
                              ? CareerPalette.line
                              : Color(red: 0.72, green: 0.42, blue: 0.10))
            VStack(alignment: .trailing, spacing: 3) {
                Text("MOOD")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(CareerPalette.line.opacity(0.15))
                        Capsule().fill(moraleColor).frame(width: geo.size.width * CGFloat(player.morale) / 100)
                    }
                }
                .frame(width: 52, height: 6)
                Text("\(player.morale)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(moraleColor)
                    .monospacedDigit()
            }
            .padding(10)
            .frame(width: 92)
            .background(CareerPalette.surface)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(CareerPalette.line.opacity(0.18)))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }

    private var moraleColor: Color {
        switch player.morale {
        case 70...:   return CareerPalette.line
        case 45..<70: return Retro.gold
        default:      return Color(red: 0.72, green: 0.42, blue: 0.10)
        }
    }
}

/// The offer outcome banner — accepted (green) or declined (restrained
/// orange) with the optional counter-offer pill.
private struct ContractResultBanner: View {
    let outcome: GameStore.ContractOutcome
    /// Applies the counter-offer wage and re-offers (existing behaviour).
    let onCounter: (Int) -> Void

    var body: some View {
        switch outcome {
        case .accepted(let message):
            VStack(spacing: 4) {
                Text("✅ ACCEPTED")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                Text(message)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(CareerPalette.line.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(CareerIdentifiers.contractResult)
            .accessibilityLabel("Offer accepted. \(message)")
        case .rejected(let reason, let counterWage):
            VStack(spacing: 6) {
                Text("❌ DECLINED")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.72, green: 0.42, blue: 0.10))
                    .accessibilityIdentifier(CareerIdentifiers.contractResult)
                    .accessibilityLabel("Offer declined. \(reason)")
                Text(reason)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .multilineTextAlignment(.center)
                if let counterWage {
                    Button {
                        Haptics.tap()
                        onCounter(counterWage)
                    } label: {
                        Text("Offer \(formatMoney(counterWage))/wk instead")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CareerPalette.surface)
                            .foregroundStyle(CareerPalette.line)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(CareerPalette.line.opacity(0.4)))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(CareerIdentifiers.contractCounterButton)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(red: 0.72, green: 0.42, blue: 0.10).opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }
}

/// A +/- stepper control in the light palette.
private struct SheetStepButton: View {
    let icon: String
    var identifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(CareerPalette.line)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(identifier ?? "")
    }
}

private let contractWarningOrange = Color(red: 0.72, green: 0.42, blue: 0.10)

// MARK: - Contract renewal

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
    /// Guards against a double-submitted offer from a double tap.
    @State private var offerInFlight = false

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
        case .starPlayer:       return Retro.gold
        case .firstTeamRegular: return CareerPalette.line
        case .rotation:         return CareerPalette.mutedInk
        case .backup:           return CareerPalette.mutedInk.opacity(0.6)
        case .youthProspect:    return Color(red: 0.22, green: 0.60, blue: 0.30)
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
            CareerPalette.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                // Pinned header — identity, role and close, always visible.
                HStack(spacing: 10) {
                    PlayerAvatarView(name: player.name, position: player.position,
                                     size: 40, age: player.age, nation: player.nationality)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(player.name)
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(CareerPalette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text(squadRole.rawValue.uppercased())
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(roleColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(roleColor.opacity(0.14))
                                .clipShape(Capsule())
                        }
                        Text("CONTRACT NEGOTIATION · \(player.age) YRS · \(player.position.rawValue) · \(player.rating) OVR")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 6)
                    SheetCloseButton(identifier: CareerIdentifiers.contractSheetClose) { finish() }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                // The sheet's one authoritative vertical scroll container.
                ScrollView {
                    VStack(spacing: 12) {
                        if let lastOutcome {
                            ContractResultBanner(outcome: lastOutcome) { counterWage in
                                wage = counterWage
                                makeOffer(wage: counterWage)
                            }
                        }
                        NegotiationInfoStrip(store: store, player: player)
                        if selectedTab == .existing {
                            existingContractCard
                        } else {
                            offerTermsCard
                        }
                        Text(roleFlavour)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .accessibilityIdentifier(CareerIdentifiers.contractSheet)

                // Pinned footer actions — reachable whatever the scroll.
                footer
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(CareerPalette.ink)
        .accessibilityElement(children: .contain)
        // (Sheet root anchor lives on the scroll container below — a
        // container-level identifier on a .contain root clobbers every
        // descendant's identifier, the documented Calendar-rows lesson.)
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if case .accepted(let message) = lastOutcome {
            Button {
                Haptics.tap()
                onResult(message)
                dismiss()
            } label: {
                Text("DONE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(CareerPalette.line)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityIdentifier(CareerIdentifiers.contractDone)
        } else if selectedTab == .offer {
            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    finish()
                } label: {
                    Text("WALK AWAY")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CareerPalette.surface)
                        .foregroundStyle(CareerPalette.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.25)))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(CareerIdentifiers.contractCancel)

                Button {
                    makeOffer(wage: wage)
                } label: {
                    Text(lastOutcome == nil ? "MAKE OFFER" : "OFFER AGAIN")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CareerPalette.line)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(CareerIdentifiers.contractMakeOffer)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        } else {
            Button {
                Haptics.tap()
                finish()
            } label: {
                Text("CLOSE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CareerPalette.surface)
                    .foregroundStyle(CareerPalette.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.25)))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
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
        guard !offerInFlight else { return }
        offerInFlight = true
        defer { offerInFlight = false }
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

    // MARK: Offer terms card

    private var offerTermsCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("WEEKLY WAGE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                HStack(spacing: 20) {
                    SheetStepButton(icon: "minus.circle.fill", identifier: "career.contract.step.minus") { wage = max(1, wage - step) }
                    Text(formatMoney(wage))
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(wage >= demand ? CareerPalette.line : contractWarningOrange)
                        .frame(minWidth: 110)
                        .monospacedDigit()
                        .accessibilityIdentifier(CareerIdentifiers.contractWageValue)
                    SheetStepButton(icon: "plus.circle.fill", identifier: "career.contract.step.plus") { wage += step }
                }
                Text("He is demanding \(formatMoney(demand))/wk")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }

            Divider().overlay(CareerPalette.line.opacity(0.14))

            VStack(spacing: 8) {
                Text("CONTRACT LENGTH")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Picker("Years", selection: $years) {
                    ForEach(1...5, id: \.self) { y in Text("\(y) yr\(y == 1 ? "" : "s")").tag(y) }
                }
                .pickerStyle(.segmented)
            }

            Divider().overlay(CareerPalette.line.opacity(0.14))

            VStack(spacing: 8) {
                Text("SIGNING-ON FEE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                HStack(spacing: 16) {
                    SheetStepButton(icon: "minus.circle.fill") { signingOnFee = max(0, signingOnFee - feeStep) }
                    Text(signingOnFee > 0 ? formatMoney(signingOnFee) : "None")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(signingOnFee > 0 ? Retro.gold : CareerPalette.mutedInk)
                        .frame(minWidth: 90)
                        .monospacedDigit()
                    SheetStepButton(icon: "plus.circle.fill") { signingOnFee += feeStep }
                }
                Text("A one-off bonus, paid from the transfer budget, that sweetens the deal.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .multilineTextAlignment(.center)
            }

            Divider().overlay(CareerPalette.line.opacity(0.14))

            VStack(spacing: 8) {
                Toggle(isOn: $includeReleaseClause) {
                    Text("RELEASE CLAUSE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }
                .tint(CareerPalette.line)
                if includeReleaseClause {
                    HStack(spacing: 16) {
                        SheetStepButton(icon: "minus.circle.fill") { releaseClause = max(clauseStep, releaseClause - clauseStep) }
                        Text(formatMoney(releaseClause))
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink)
                            .frame(minWidth: 90)
                            .monospacedDigit()
                        SheetStepButton(icon: "plus.circle.fill") { releaseClause += clauseStep }
                    }
                    Text("Guarantees any rival bid for him is at least this much.")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                        .multilineTextAlignment(.center)
                }
            }

            offerSummaryBox
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
    }

    private var existingContractCard: some View {
        VStack(spacing: 10) {
            contractRow("Current wage", formatMoney(player.wage) + "/wk")
            contractRow("Years remaining", "\(player.contractYears)")
            contractRow("Contract expiry", "\(store.contractExpiryYear(player))")
            contractRow("Release clause", player.releaseClause.map(formatMoney) ?? "None")
            contractRow("Squad status", squadRole.rawValue)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
    }

    private func contractRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .monospacedDigit()
        }
    }

    private var offerSummaryBox: some View {
        Text(offerSummarySentence)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(CareerPalette.ink)
            .multilineTextAlignment(.center)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Retro.gold.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 9))
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

// MARK: - Free agent personal terms

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
    /// Guards against a double-submitted offer from a double tap.
    @State private var offerInFlight = false

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
        case .starPlayer:       return Retro.gold
        case .firstTeamRegular: return CareerPalette.line
        case .rotation:         return CareerPalette.mutedInk
        case .backup:           return CareerPalette.mutedInk.opacity(0.6)
        case .youthProspect:    return Color(red: 0.22, green: 0.60, blue: 0.30)
        }
    }

    private var newExpiryYear: Int { (store.startYear - 1) + store.season + years }

    var body: some View {
        ZStack {
            CareerPalette.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    PlayerAvatarView(name: player.name, position: player.position,
                                     size: 40, age: player.age, nation: player.nationality)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(player.name)
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(CareerPalette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text(squadRole.rawValue.uppercased())
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(roleColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(roleColor.opacity(0.14))
                                .clipShape(Capsule())
                        }
                        Text("FREE TRANSFER · \(player.age) YRS · \(player.position.rawValue) · \(player.rating) OVR")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 6)
                    SheetCloseButton(identifier: CareerIdentifiers.contractSheetClose) { finish() }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 12) {
                        if let lastOutcome {
                            ContractResultBanner(outcome: lastOutcome) { counterWage in
                                wage = counterWage
                                makeOffer(wage: counterWage)
                            }
                        }
                        NegotiationInfoStrip(store: store, player: player)
                        offerTermsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .accessibilityIdentifier(CareerIdentifiers.contractFreeAgentSheet)

                footer
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(CareerPalette.ink)
        .accessibilityElement(children: .contain)
        // (Sheet root anchor lives on the scroll container above.)
    }

    @ViewBuilder
    private var footer: some View {
        if case .accepted(let message) = lastOutcome {
            Button {
                Haptics.tap()
                onResult(message)
                dismiss()
            } label: {
                Text("DONE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(CareerPalette.line)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityIdentifier(CareerIdentifiers.contractDone)
        } else {
            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    finish()
                } label: {
                    Text("WALK AWAY")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CareerPalette.surface)
                        .foregroundStyle(CareerPalette.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.25)))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(CareerIdentifiers.contractCancel)

                Button {
                    makeOffer(wage: wage)
                } label: {
                    Text(lastOutcome == nil ? "MAKE OFFER" : "OFFER AGAIN")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CareerPalette.line)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(CareerIdentifiers.contractMakeOffer)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
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
        guard !offerInFlight else { return }
        offerInFlight = true
        defer { offerInFlight = false }
        Haptics.impact()
        let outcome = store.signFreeAgent(player, fromClubIndex: fromClubIndex, wage: offerWage, years: years, signingOnFee: signingOnFee)
        lastOutcome = outcome
        switch outcome {
        case .accepted: Haptics.success()
        case .rejected: Haptics.warning()
        }
    }

    private var offerTermsCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("WEEKLY WAGE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                HStack(spacing: 20) {
                    SheetStepButton(icon: "minus.circle.fill", identifier: "career.contract.step.minus") { wage = max(1, wage - step) }
                    Text(formatMoney(wage))
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(wage >= demand ? CareerPalette.line : contractWarningOrange)
                        .frame(minWidth: 110)
                        .monospacedDigit()
                        .accessibilityIdentifier(CareerIdentifiers.contractWageValue)
                    SheetStepButton(icon: "plus.circle.fill", identifier: "career.contract.step.plus") { wage += step }
                }
                Text("No fee — just agree personal terms. Wants \(formatMoney(demand))/wk")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .multilineTextAlignment(.center)
            }

            Divider().overlay(CareerPalette.line.opacity(0.14))

            VStack(spacing: 8) {
                Text("CONTRACT LENGTH")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Picker("Years", selection: $years) {
                    ForEach(1...5, id: \.self) { y in Text("\(y) yr\(y == 1 ? "" : "s")").tag(y) }
                }
                .pickerStyle(.segmented)
            }

            Divider().overlay(CareerPalette.line.opacity(0.14))

            VStack(spacing: 8) {
                Text("SIGNING-ON FEE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                HStack(spacing: 16) {
                    SheetStepButton(icon: "minus.circle.fill") { signingOnFee = max(0, signingOnFee - feeStep) }
                    Text(signingOnFee > 0 ? formatMoney(signingOnFee) : "None")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(signingOnFee > 0 ? Retro.gold : CareerPalette.mutedInk)
                        .frame(minWidth: 90)
                        .monospacedDigit()
                    SheetStepButton(icon: "plus.circle.fill") { signingOnFee += feeStep }
                }
                Text("A one-off bonus, paid from the transfer budget, that sweetens the deal.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .multilineTextAlignment(.center)
            }

            offerSummaryBox
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
    }

    private var offerSummaryBox: some View {
        Text(offerSummarySentence)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(CareerPalette.ink)
            .multilineTextAlignment(.center)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Retro.gold.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var offerSummarySentence: String {
        var sentence = "I'm proposing \(formatMoney(wage)) per week until 30/6/\(newExpiryYear)"
        if signingOnFee > 0 {
            sentence += ", plus a \(formatMoney(signingOnFee)) signing-on fee"
        }
        return sentence + "."
    }
}

// MARK: - Scout reports (already light — unchanged apart from shared chrome)

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
            CareerPalette.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("SCOUT REPORTS")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(CareerPalette.ink)
                        .accessibilityIdentifier("career.scoutReports.screen")
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("career.scoutReports.close")
                }

                if reports.isEmpty {
                    Spacer()
                    Text("No reports filed yet — scout a target, or send scouts out into the world.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
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
        .foregroundStyle(CareerPalette.ink)
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
                        .foregroundStyle(CareerPalette.ink)
                    Spacer()
                    Text("POT ~\(report.potential)")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(CareerPalette.line)
                }
                Text(report.verdict)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("Est. \(formatMoney(report.valueRangeLow))–\(formatMoney(report.valueRangeHigh)) · \(report.confidence)% confidence")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                HStack {
                    Text(report.note)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                    Spacer()
                    if live == nil {
                        Text("NO LONGER AVAILABLE")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(CareerPalette.mutedInk)
                    } else {
                        Text(live.map { formatMoney($0.askingPrice) } ?? "")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(CareerPalette.line)
                    }
                }
            }
            .padding(10)
            .background(CareerPalette.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(CareerPalette.line.opacity(0.16)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(live == nil)
        .accessibilityIdentifier("career.scoutReports.row.\(report.playerID.uuidString)")
    }
}

/// A haggling flow for a transfer-market target: bid below asking price
/// and the selling club may reject outright or counter with a figure
/// they'd actually accept, instead of asking price being the only number
/// that ever works.
