//
//  LegendsPacksView.swift
//  Retro Season Manager
//
//  Pack shop + the animated opening reveal (Phase 4): cards flip one by
//  one, high-rarity pulls get a confetti burst, duplicates show their
//  upgrade progress.
//

import SwiftUI

struct LegendsPacksView: View {
    let store: LegendsStore
    var onBack: () -> Void

    @State private var openingPack: LegendsPack? = nil

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                header
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(LegendsPackDatabase.all) { pack in
                            packTile(pack)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .fullScreenCover(item: $openingPack) { pack in
            LegendsPackOpeningView(store: store, pack: pack) { openingPack = nil }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    Haptics.tap()
                    onBack()
                } label: {
                    Text("‹ Back")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                }
                .buttonStyle(PressableButtonStyle())
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Text("PACKS")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)

            HStack(spacing: 16) {
                Label("\(store.profile.coins)", systemImage: "dollarsign.circle.fill")
                Label("\(store.profile.packTokens)", systemImage: "shippingbox.fill")
            }
            .font(.system(.footnote, design: .monospaced).bold())
            .foregroundStyle(Retro.text.opacity(0.85))
        }
    }

    private func packTile(_ pack: LegendsPack) -> some View {
        let affordable = pack.currency == .coins ? store.profile.coins >= pack.cost : store.profile.packTokens >= pack.cost
        return Button {
            Haptics.tap()
            openingPack = pack
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(affordable ? Retro.accent : Retro.text.opacity(0.3))
                Text(pack.name)
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(affordable ? Retro.text : Retro.text.opacity(0.4))
                Text(pack.subtitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("GUARANTEED: \(pack.guaranteedRarityLabel.uppercased())+")
                    .font(.system(size: 9, design: .monospaced).bold())
                    .foregroundStyle(Retro.gold.opacity(0.85))
                HStack(spacing: 4) {
                    Image(systemName: pack.currency == .coins ? "dollarsign.circle.fill" : "shippingbox.fill")
                        .font(.system(size: 11))
                    Text(pack.cost == 0 ? "FREE" : "\(pack.cost)")
                        .font(.system(.caption, design: .monospaced).bold())
                }
                .foregroundStyle(affordable ? Retro.highlight : Retro.warning)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .padding(12)
            .background(
                LinearGradient(colors: [Retro.panel.opacity(0.95), Retro.panel.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Retro.accent.opacity(affordable ? 0.4 : 0.1), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!affordable)
    }
}

private struct LegendsPackOpeningView: View {
    let store: LegendsStore
    let pack: LegendsPack
    var onDone: () -> Void

    @State private var results: [LegendsPackPullResult] = []
    @State private var revealedCount = 0
    @State private var flipped: Set<Int> = []
    @State private var burstIndex: Int? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(pack.name.uppercased())
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                    .padding(.top, 20)

                if results.isEmpty && errorMessage == nil {
                    Spacer()
                    ProgressView().tint(Retro.accent)
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    Text(errorMessage)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.warning)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                } else {
                    Spacer()
                    HStack(spacing: 16) {
                        ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                            cardSlot(index: index, result: result)
                        }
                    }
                    Spacer()
                    if revealedCount >= results.count {
                        Button {
                            Haptics.success()
                            onDone()
                        } label: {
                            Text("CONTINUE")
                                .font(.system(.headline, design: .monospaced).bold())
                                .foregroundStyle(Retro.background)
                                .frame(maxWidth: 260)
                                .padding(.vertical, 14)
                                .background(Retro.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.bottom, 30)
                        .transition(.opacity)
                    } else {
                        Text("Tap each card to reveal it")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.6))
                            .padding(.bottom, 30)
                    }
                }
            }
        }
        .onAppear {
            do {
                results = try store.openPack(pack)
            } catch {
                errorMessage = "Couldn't open this pack."
            }
        }
    }

    private func cardSlot(index: Int, result: LegendsPackPullResult) -> some View {
        let isFlipped = flipped.contains(index)
        return ZStack {
            cardBack
                .opacity(isFlipped ? 0 : 1)
            cardFront(result)
                .opacity(isFlipped ? 1 : 0)
                .overlay {
                    if burstIndex == index {
                        ConfettiBurst()
                    }
                }
        }
        .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(duration: 0.5), value: isFlipped)
        .onTapGesture {
            guard !isFlipped else { return }
            Haptics.tap()
            flipped.insert(index)
            revealedCount += 1
            if result.card.rarity.tier >= 5 {
                burstIndex = index
                Haptics.success()
                SoundManager.shared.play(.trophyLift)
            }
        }
    }

    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Retro.panel)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Retro.accent.opacity(0.5), lineWidth: 1))
            .overlay(Image(systemName: "questionmark").font(.system(size: 26)).foregroundStyle(Retro.accent.opacity(0.6)))
            .frame(width: 96, height: 130)
    }

    private func cardFront(_ result: LegendsPackPullResult) -> some View {
        VStack(spacing: 6) {
            Text(result.card.position.rawValue)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.background)
                .padding(4)
                .background(Circle().fill(result.card.rarity.tint))
            Text(result.card.name)
                .font(.system(size: 10, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(store.effectiveOverall(for: result.card))")
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(result.card.rarity.tint)
            if !result.isNewCard {
                Text(result.grantedUpgrade ? "UPGRADED +1" : "DUPLICATE")
                    .font(.system(size: 8, design: .monospaced).bold())
                    .foregroundStyle(result.grantedUpgrade ? Retro.gold : Retro.text.opacity(0.5))
            } else {
                Text("NEW")
                    .font(.system(size: 8, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
            }
        }
        .frame(width: 96, height: 130)
        .padding(6)
        .background(Retro.panel.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(result.card.rarity.tint, lineWidth: 2))
    }
}

/// A one-shot burst of small tinted particles for high-rarity reveals —
/// no external dependency, just a handful of animated shapes.
private struct ConfettiBurst: View {
    @State private var expanded = false

    private let particles: [(angle: Double, distance: CGFloat, color: Color)] = (0..<14).map { i in
        (angle: Double(i) * (360.0 / 14.0), distance: CGFloat.random(in: 40...80),
         color: [Retro.gold, Retro.emerald, Retro.royalBlue, Retro.pureWhite].randomElement()!)
    }

    var body: some View {
        ZStack {
            ForEach(0..<particles.count, id: \.self) { i in
                let p = particles[i]
                Circle()
                    .fill(p.color)
                    .frame(width: 5, height: 5)
                    .offset(x: expanded ? cos(p.angle * .pi / 180) * p.distance : 0,
                            y: expanded ? sin(p.angle * .pi / 180) * p.distance : 0)
                    .opacity(expanded ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { expanded = true }
        }
        .allowsHitTesting(false)
    }
}
