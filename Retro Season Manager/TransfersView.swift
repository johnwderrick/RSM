//
//  TransfersView.swift
//  Retro Season Manager
//
//  The Transfers & Finances tab: the ledger, the transfer market
//  list, and their supporting rows.
//

import SwiftUI

// MARK: - Transfers & finances

/// What a player profile sheet is showing, and the action it offers.
enum ProfileContext: Identifiable {
    case squad(Player)
    case market(TransferTarget)
    /// A player from any other club, found via search — can be bid on.
    case scouted(Player, clubIndex: Int)

    var id: UUID {
        switch self {
        case .squad(let player):  return player.id
        case .market(let target): return target.id
        case .scouted(let player, _): return player.id
        }
    }
}

/// This season's income/expenditure, in order — transfers, wages sold,
/// gate receipts, investments, prize money, and the season-opening reset.
struct LedgerView: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var income: Int { store.seasonLedger.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount } }
    private var expenditure: Int { store.seasonLedger.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SEASON LEDGER")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                HStack(spacing: 14) {
                    statLine("Income", formatMoney(income), Retro.accent)
                    statLine("Expenditure", formatMoney(expenditure), Color(red: 0.9, green: 0.4, blue: 0.35))
                    statLine("Net", formatMoney(income + expenditure), Retro.highlight)
                }
                .padding(10)
                .background(Retro.panel.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                if store.seasonLedger.isEmpty {
                    Text("No transactions yet this season.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(store.seasonLedger) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.category)
                                            .font(.system(.caption, design: .monospaced).bold())
                                            .foregroundStyle(Retro.text)
                                        Text(entry.detail)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(Retro.text.opacity(0.7))
                                    }
                                    Spacer()
                                    Text(formatMoney(entry.amount))
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundStyle(entry.amount >= 0 ? Retro.accent : Color(red: 0.9, green: 0.4, blue: 0.35))
                                }
                                .padding(10)
                                .background(Retro.panel.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func statLine(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TransfersView: View {
    let store: GameStore
    @State private var tab = 0
    @State private var profile: ProfileContext?
    @State private var message: String?
    @State private var showingLedger = false
    @State private var personalTermsDeal: PendingTransferDeal?
    @State private var withdrawDeal: PendingTransferDeal?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    financesPanel
                    boardPanel
                }

                infrastructurePanel
                backroomStaffPanel
                if !store.pendingTransferDeals.isEmpty {
                    pendingDealsPanel
                }
                if !store.playersOnLoanFromUser().isEmpty {
                    loanedOutPanel
                }

                HStack {
                    Text("TRANSFER WINDOW")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.text.opacity(0.8))
                    Spacer()
                    Text(store.transferWindowStatus)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(store.isDeadlineDayRush ? Color(red: 0.95, green: 0.35, blue: 0.35)
                                          : (store.transferWindowOpen ? Retro.accent : Retro.highlight))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Retro.panel.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Picker("", selection: $tab) {
                    Text("My Squad").tag(0)
                    Text("Market").tag(1)
                    Text("Youth (\(store.youthProspects.count))").tag(2)
                }
                .pickerStyle(.segmented)

                if let message {
                    Text(message)
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Retro.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if tab == 1 {
                    let suggestions = store.suggestedTransferTargets(limit: 3)
                    if !suggestions.isEmpty {
                        suggestedTargetsPanel(suggestions)
                    }
                }
                if tab == 0 { squadList } else if tab == 1 { marketList } else { youthList }
            }
            .padding(14)
        }
        .sheet(item: $profile) { context in
            PlayerProfileSheet(store: store, context: context) { message = $0 }
        }
        .sheet(item: $personalTermsDeal) { deal in
            PersonalTermsSheet(store: store, deal: deal) { message = $0 }
        }
        .sheet(item: $withdrawDeal) { deal in
            ConfirmActionSheet(
                title: "Break off talks with \(deal.player.name)?",
                message: "He'll return to \(deal.sellingClubName) and this deal is off. This can't be undone.",
                confirmLabel: "WITHDRAW"
            ) {
                message = store.withdrawPendingDeal(deal)
            }
        }
    }

    private var pendingDealsPanel: some View {
        Panel(title: "PENDING TRANSFERS") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.pendingTransferDeals) { deal in
                    HStack(spacing: 8) {
                        PlayerAvatarView(name: deal.player.name, position: deal.player.detailedPosition.broad, size: 30, age: deal.player.age, nation: deal.player.nationality)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(deal.player.name)
                                .font(.system(.callout, design: .monospaced).bold())
                            Text(deal.isReady
                                 ? "Ready to talk terms — \(formatMoney(deal.agreedFee)) fee agreed"
                                 : "Medical & paperwork in progress — \(formatMoney(deal.agreedFee)) fee agreed")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(deal.isReady ? Retro.accent : Retro.text.opacity(0.65))
                        }
                        Spacer()
                        if deal.isReady {
                            Button {
                                Haptics.tap()
                                personalTermsDeal = deal
                            } label: {
                                Text("TALK TERMS")
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Retro.accent)
                                    .foregroundStyle(Retro.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(PressableButtonStyle())
                        } else {
                            Text("⏳").font(.system(.caption, design: .monospaced))
                        }
                        Button {
                            Haptics.tap()
                            withdrawDeal = deal
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(Retro.text.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var financesPanel: some View {
        Panel(title: "FINANCES") {
            VStack(alignment: .leading, spacing: 4) {
                statLine("Transfer budget", formatMoney(store.userClub.transferBudget), Retro.accent)
                let wageHeadroom = store.userClub.wageBudget - store.userClub.wageBill
                statLine("Wage bill / wk", "\(formatMoney(store.userClub.wageBill)) of \(formatMoney(store.userClub.wageBudget))",
                         wageHeadroom < 0 ? .red : Retro.text)
                statLine("Squad size", "\(store.userClub.players.count) / 30", Retro.text)
                Button { showingLedger = true } label: {
                    Text("VIEW SEASON LEDGER")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Retro.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingLedger) {
            LedgerView(store: store)
        }
    }

    private var boardPanel: some View {
        Panel(title: "THE BOARD") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Objective: \(store.boardObjective)")
                    .font(.system(.callout, design: .monospaced))
                ConfidenceBar(value: store.boardConfidence, trend: store.boardConfidenceTrend)
                statLine("Job security", store.jobSecurity,
                         store.boardConfidence >= 45 ? Retro.accent : Retro.highlight)
                statLine("Your contract", "\(store.managerContractYears) year\(store.managerContractYears == 1 ? "" : "s") left",
                         store.managerContractYears <= 1 ? Retro.highlight : Retro.text.opacity(0.85))
                Button {
                    Haptics.tap()
                    message = store.requestBudgetIncrease()
                } label: {
                    Text(store.daysUntilNextBudgetRequest.map { "ASK AGAIN IN \($0)D" } ?? "REQUEST MORE BUDGET")
                        .font(.system(.caption, design: .monospaced).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(store.daysUntilNextBudgetRequest == nil ? Retro.accent : Retro.panel)
                        .foregroundStyle(store.daysUntilNextBudgetRequest == nil ? Retro.background : Retro.text.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(store.daysUntilNextBudgetRequest != nil)
                if store.boardConfidence <= 40 {
                    Button {
                        Haptics.tap()
                        message = store.requestClearTheAirMeeting()
                    } label: {
                        Text(store.daysUntilNextClearAirMeeting.map { "ASK AGAIN IN \($0)D" } ?? "CALL CLEAR-THE-AIR MEETING")
                            .font(.system(.caption, design: .monospaced).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(store.daysUntilNextClearAirMeeting == nil ? Color(red: 0.9, green: 0.4, blue: 0.35) : Retro.panel)
                            .foregroundStyle(store.daysUntilNextClearAirMeeting == nil ? Retro.background : Retro.text.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(store.daysUntilNextClearAirMeeting != nil)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var loanedOutPanel: some View {
        Panel(title: "PLAYERS ON LOAN") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(store.playersOnLoanFromUser(), id: \.player.id) { entry in
                    HStack(spacing: 8) {
                        Text(entry.player.name)
                            .font(.system(.callout, design: .monospaced))
                        Spacer()
                        Text("at \(store.clubs[entry.clubIndex].name)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.7))
                        Button {
                            Haptics.tap()
                            message = store.recallFromLoan(entry.player)
                        } label: {
                            Text("RECALL")
                                .font(.system(.caption2, design: .monospaced).bold())
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Retro.panel)
                                .foregroundStyle(Retro.highlight)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }

    private var infrastructurePanel: some View {
        Panel(title: "CLUB INFRASTRUCTURE") {
            HStack(alignment: .top, spacing: 14) {
                investmentCard(
                    title: "YOUTH ACADEMY",
                    level: store.userClub.youthFacilityLevel,
                    cost: store.youthUpgradeCost(forClubIndex: store.userClubIndex),
                    detail: "Bigger, more frequent intakes with better prospects.",
                    action: {
                        message = store.investInYouthAcademy()
                    }
                )
                investmentCard(
                    title: "STADIUM",
                    level: store.userClub.stadiumExpansionLevel,
                    cost: store.stadiumUpgradeCost(forClubIndex: store.userClubIndex),
                    detail: "Capacity: \(store.stadiumInfo(forClubIndex: store.userClubIndex).capacity.formatted()) — a fuller ground boosts home advantage.",
                    action: {
                        message = store.investInStadium()
                    }
                )
                ticketPriceCard
            }
        }
    }

    private var ticketPriceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TICKET PRICES")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            HStack(spacing: 10) {
                stepButton("minus.circle.fill") {
                    message = store.setTicketPriceLevel(store.userClub.ticketPriceLevel - 1)
                }
                Text(["Cheap", "Low", "Standard", "High", "Premium"][store.userClub.ticketPriceLevel - 1])
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .frame(minWidth: 70)
                stepButton("plus.circle.fill") {
                    message = store.setTicketPriceLevel(store.userClub.ticketPriceLevel + 1)
                }
            }
            Text("Higher prices earn more per head but cost attendance and fan goodwill.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Retro.background.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Retro.accent)
        }
        .buttonStyle(.plain)
    }

    private var backroomStaffPanel: some View {
        Panel(title: "BACKROOM STAFF") {
            HStack(alignment: .top, spacing: 14) {
                ForEach(StaffRole.allCases) { role in
                    staffCard(role)
                }
            }
        }
    }

    private func staffCard(_ role: StaffRole) -> some View {
        let level = store.staffLevel(role)
        let name = store.backroomStaff.first { $0.role == role }?.name
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(role.rawValue.uppercased())
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < level ? Retro.accent : Retro.text.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            Text(name ?? "Vacant")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(name == nil ? Retro.text.opacity(0.5) : Retro.text)
            Text(role.effectDescription)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Menu {
                ForEach(1...3, id: \.self) { hireLevel in
                    Button("Level \(hireLevel) — \(formatMoney(store.staffHireCost(level: hireLevel)))") {
                        message = store.hireStaff(role: role, level: hireLevel)
                    }
                }
            } label: {
                Text(level == 0 ? "HIRE" : "REPLACE")
                    .font(.system(.caption, design: .monospaced).bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Retro.accent)
                    .foregroundStyle(Retro.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Retro.background.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func investmentCard(title: String, level: Int, cost: Int?, detail: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < level ? Retro.accent : Retro.text.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            Text(detail)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Haptics.tap()
                action()
            } label: {
                Text(cost.map { "INVEST (\(formatMoney($0)))" } ?? "MAX LEVEL")
                    .font(.system(.caption, design: .monospaced).bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(cost == nil ? Retro.panel : Retro.accent)
                    .foregroundStyle(cost == nil ? Retro.text.opacity(0.5) : Retro.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(cost == nil || store.userClub.transferBudget < (cost ?? 0))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Retro.background.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statLine(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(Retro.text.opacity(0.85))
            Spacer()
            Text(value).foregroundStyle(color).bold()
        }
        .font(.system(.callout, design: .monospaced))
    }

    private var squadList: some View {
        VStack(spacing: 4) {
            ForEach(sortedSquad) { player in
                Button { profile = .squad(player) } label: {
                    TransferRow(position: player.position.rawValue,
                                name: player.name,
                                subtitle: "Age \(player.age) · \(player.rating) OVR\(player.isTransferListed ? " · LISTED" : "")",
                                trailing: formatMoney(player.value),
                                dimmed: !player.isAvailable)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func suggestedTargetsPanel(_ suggestions: [TransferTarget]) -> some View {
        Panel(title: "SUGGESTED TARGETS") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Would plug a thin spot in the squad, and fits the budget.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
                ForEach(suggestions) { target in
                    Button { profile = .market(target) } label: {
                        TransferRow(position: target.player.detailedPosition.rawValue,
                                    name: target.player.name,
                                    subtitle: sellerName(target) + " · \(target.player.rating) OVR",
                                    trailing: priceLabel(for: target),
                                    dimmed: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var marketList: some View {
        VStack(spacing: 4) {
            if store.transferMarket.isEmpty {
                Text("No players available right now.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
            ForEach(store.transferMarket.sorted { $0.player.rating > $1.player.rating }) { target in
                let affordable = target.sellingClubIndex == nil
                    ? store.userClub.wageBill + target.player.wage <= store.userClub.wageBudget
                    : store.userClub.transferBudget >= target.askingPrice
                        && store.userClub.wageBill + target.player.wage <= store.userClub.wageBudget
                Button { profile = .market(target) } label: {
                    TransferRow(position: target.player.position.rawValue,
                                name: target.player.name,
                                subtitle: sellerName(target) + " · \(target.player.rating) OVR" + scoutTag(target),
                                trailing: priceLabel(for: target),
                                dimmed: !affordable)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var youthList: some View {
        VStack(spacing: 4) {
            Text("Prospects from your academy — promote the best, release the rest.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
            if store.youthProspects.isEmpty {
                Text("No prospects — the next intake arrives next season.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.85))
            }
            ForEach(store.youthProspects) { prospect in
                HStack(spacing: 8) {
                    Text(prospect.position.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.background)
                        .frame(width: 36).padding(.vertical, 4)
                        .background(Retro.accent).clipShape(RoundedRectangle(cornerRadius: 4))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(prospect.name).font(.system(.callout, design: .monospaced).bold())
                        Text("Age \(prospect.age) · \(prospect.rating) OVR")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.75))
                    }
                    Spacer()
                    Button { message = store.promoteYouth(prospect) } label: {
                        Text("PROMOTE")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Retro.accent).foregroundStyle(Retro.background)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    Button { message = store.releaseYouth(prospect) } label: {
                        Text("RELEASE")
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Retro.panel).foregroundStyle(Retro.text)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Retro.panel.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var sortedSquad: [Player] {
        store.userClub.players.sorted {
            if $0.position.order != $1.position.order { return $0.position.order < $1.position.order }
            return $0.rating > $1.rating
        }
    }

    private func sellerName(_ target: TransferTarget) -> String {
        if let index = target.sellingClubIndex { return store.clubs[index].shortName }
        return "Free agent"
    }

    private func priceLabel(for target: TransferTarget) -> String {
        target.sellingClubIndex == nil ? "FREE" : formatMoney(target.askingPrice)
    }

    private func scoutTag(_ target: TransferTarget) -> String {
        switch store.scoutState(for: target) {
        case .unscouted:              return ""
        case .inProgress:             return " · 🔍scouting"
        case .scouted(let report):    return " · POT ~\(report.potential)"
        }
    }
}

struct TransferRow: View {
    let position: String
    let name: String
    let subtitle: String
    let trailing: String
    let dimmed: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(position)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Retro.background)
                .frame(width: 36)
                .padding(.vertical, 4)
                .background(Retro.accent)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(.callout, design: .monospaced).bold())
                Text(subtitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.75))
            }
            Spacer()
            Text(trailing)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Retro.panel.opacity(dimmed ? 0.3 : 0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(dimmed ? 0.7 : 1)
    }
}

/// A thin bar showing board confidence.
/// The colour scheme shared by every board-confidence display — green when
/// safe, amber when it's worth worrying, red once it's genuine sacking risk.
func confidenceColor(_ value: Int) -> Color {
    switch value {
    case 60...:   return Retro.accent
    case 30..<60: return Retro.highlight
    default:      return Color(red: 0.9, green: 0.35, blue: 0.35)
    }
}

/// A small arrow reflecting the change in board confidence from the last
/// result — empty string while flat or with no result yet.
func confidenceTrendArrow(_ trend: Int) -> String {
    if trend > 0 { return "▲" }
    if trend < 0 { return "▼" }
    return ""
}

struct ConfidenceBar: View {
    let value: Int
    var trend: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Retro.text.opacity(0.2))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 8)
            Text("Confidence \(value)% \(confidenceTrendArrow(trend))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))
        }
    }

    private var color: Color { confidenceColor(value) }
}

