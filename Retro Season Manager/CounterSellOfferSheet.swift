//
//  CounterSellOfferSheet.swift
//  Retro Season Manager
//
//  The seller's side of a real negotiation: reject a rival's bid outright,
//  or name a higher asking price and see whether they meet it, improve
//  their offer, or walk away — mirroring the buyer's TransferBidSheet
//  negotiation from the other side of the table.
//

import SwiftUI

struct CounterSellOfferSheet: View {
    let store: GameStore
    let offer: TransferOffer
    let onDone: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var askingAmount: Double
    @State private var theirLatestOffer: Int
    @State private var lastResultReason: String?

    init(store: GameStore, offer: TransferOffer, onDone: @escaping (String) -> Void) {
        self.store = store
        self.offer = offer
        self.onDone = onDone
        _askingAmount = State(initialValue: Double(offer.amount) * 1.15)
        _theirLatestOffer = State(initialValue: offer.amount)
    }

    private var buyerClub: Club? {
        store.clubs.indices.contains(offer.fromClubIndex) ? store.clubs[offer.fromClubIndex] : nil
    }

    var body: some View {
        ZStack {
            CareerPalette.canvas.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("career.transfers.countersell.close")
                }

                VStack(spacing: 4) {
                    Text(offer.playerName.uppercased())
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                    Text("\(buyerClub?.name ?? "Unknown club") want to sign him")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }

                Panel(title: "THEIR OFFER") {
                    HStack {
                        Text(formatMoney(theirLatestOffer))
                            .font(.system(size: 19, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.line)
                        Spacer()
                    }
                }

                Panel(title: "YOUR ASKING PRICE") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formatMoney(Int(askingAmount)))
                            .font(.system(size: 19, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink)
                        Slider(value: $askingAmount, in: Double(theirLatestOffer)...Double(offer.amount) * 2.2, step: 100)
                            .tint(CareerPalette.line)
                    }
                }

                if let lastResultReason {
                    Text(lastResultReason)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink.opacity(0.85))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CareerPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(CareerPalette.line.opacity(0.16)))
                        .accessibilityIdentifier("career.transfers.countersell.result")
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        Haptics.tap()
                        submitCounter()
                    } label: {
                        Text("SEND COUNTER: \(formatMoney(Int(askingAmount)))")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(CareerPalette.line)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("career.transfers.countersell.send")

                    Button {
                        Haptics.tap()
                        var acceptedOffer = offer
                        acceptedOffer.amount = theirLatestOffer
                        onDone(store.acceptOffer(acceptedOffer))
                    } label: {
                        Text("ACCEPT THEIR OFFER: \(formatMoney(theirLatestOffer))")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("career.transfers.countersell.accept")
                }
            }
            .padding(24)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(CareerPalette.ink)
    }

    private func submitCounter() {
        var negotiatingOffer = offer
        negotiatingOffer.amount = theirLatestOffer
        let outcome = store.counterSellOffer(negotiatingOffer, askingAmount: Int(askingAmount))
        switch outcome {
        case .accepted(let message):
            onDone(message)
        case .rejected(let reason, let counterPrice):
            if let counterPrice {
                lastResultReason = reason
                theirLatestOffer = counterPrice
                askingAmount = max(askingAmount, Double(counterPrice))
            } else {
                onDone(reason)
            }
        }
    }
}
