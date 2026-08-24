//
//  TransferHubView.swift
//  Retro Season Manager
//
//  Every live negotiation in one place — deals with fees agreed and
//  waiting on medicals/personal terms, and incoming bids for your own
//  players — instead of scattered across the squad screen and inbox.
//

import SwiftUI

struct TransferHubView: View {
    let store: GameStore
    @State private var message: String?
    @State private var personalTermsDeal: PendingTransferDeal?
    @State private var withdrawDeal: PendingTransferDeal?
    @State private var counterTarget: TransferOffer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let message {
                    Text(message)
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Retro.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if store.pendingTransferDeals.isEmpty && store.pendingOffers.isEmpty {
                    Text("Nothing in progress — deals you agree and bids you receive will show up here.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                }

                if !store.pendingTransferDeals.isEmpty {
                    Panel(title: "YOUR DEALS (\(store.pendingTransferDeals.count))") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(store.pendingTransferDeals) { deal in
                                dealRow(deal)
                            }
                        }
                    }
                }

                if !store.pendingOffers.isEmpty {
                    Panel(title: "OFFERS RECEIVED (\(store.pendingOffers.count))") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(store.pendingOffers) { offer in
                                offerRow(offer)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Retro.background.ignoresSafeArea())
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
        .sheet(item: $counterTarget) { offer in
            CounterSellOfferSheet(store: store, offer: offer) { result in
                message = result
                counterTarget = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("🤝 TRANSFER HUB")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
            HStack {
                Text("TRANSFER WINDOW")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.text.opacity(0.7))
                Spacer()
                Text(store.transferWindowStatus)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(store.isDeadlineDayRush ? Color(red: 0.95, green: 0.35, blue: 0.35)
                                      : (store.transferWindowOpen ? Retro.accent : Retro.highlight))
            }
        }
    }

    private func dealRow(_ deal: PendingTransferDeal) -> some View {
        HStack(spacing: 8) {
            PlayerAvatarView(name: deal.player.name, position: deal.player.detailedPosition.broad, size: 32, age: deal.player.age, nation: deal.player.nationality)
            VStack(alignment: .leading, spacing: 2) {
                Text(deal.player.name)
                    .font(.system(.callout, design: .monospaced).bold())
                Text("\(deal.sellingClubName) · \(formatMoney(deal.agreedFee)) fee agreed")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.65))
                Text(deal.isReady ? "STATUS: READY FOR PERSONAL TERMS" : "STATUS: MEDICAL & PAPERWORK IN PROGRESS")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(deal.isReady ? Retro.accent : Retro.highlight.opacity(0.8))
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

    private func offerRow(_ offer: TransferOffer) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.playerName)
                    .font(.system(.callout, design: .monospaced).bold())
                Text("\(store.clubs[offer.fromClubIndex].name) · \(formatMoney(offer.amount))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.highlight)
                Text("STATUS: AWAITING YOUR RESPONSE")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.text.opacity(0.6))
            }
            Spacer()
            VStack(spacing: 6) {
                Button { message = store.acceptOffer(offer) } label: {
                    Text("ACCEPT")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Retro.accent).foregroundStyle(Retro.background)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                Button { Haptics.tap(); counterTarget = offer } label: {
                    Text("COUNTER")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Retro.highlight.opacity(0.25)).foregroundStyle(Retro.highlight)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                Button { store.rejectOffer(offer); message = "Bid for \(offer.playerName) rejected." } label: {
                    Text("REJECT")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Retro.panel).foregroundStyle(Retro.text)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
