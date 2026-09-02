//
//  LegendsPacksView.swift
//  Retro Season Manager
//
//  Pack shop and the three-card choice flow. Opening a pack reserves three
//  candidates, animates them into view, and only the selected card enters
//  the player library.
//

import SwiftUI

struct LegendsPacksView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var openingPack: LegendsPack? = nil

    var body: some View {
        LegendsMenuShell(store: store, title: "PACKS", subtitle: "OPEN YOUR NEXT STORY", icon: "shippingbox.fill", accent: LegendsPalette.purple, onBack: onBack, currentNav: .packs, onNavigate: onNavigate, scrollContent: false) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let pendingPackID = store.profile.pendingPackID,
                       let pendingPack = LegendsPackDatabase.all.first(where: { $0.id == pendingPackID }) {
                        pendingBanner(pendingPack)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(LegendsPackDatabase.all) { pack in
                            packTile(pack)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(item: $openingPack) { pack in
            LegendsPackOpeningView(store: store, pack: pack) { openingPack = nil }
        }
    }

    private func pendingBanner(_ pack: LegendsPack) -> some View {
        Button {
            openingPack = pack
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.tv.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(LegendsPalette.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PACK DECISION WAITING")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy)
                    Text("Choose one of your three candidates to add to the library.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.66))
                }
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .foregroundStyle(LegendsPalette.purple)
            }
            .padding(14)
            .background(LegendsPalette.goldWash)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.gold.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func packTile(_ pack: LegendsPack) -> some View {
        let claimed = pack.id == "starter" && store.profile.hasClaimedStarterPack
        let pending = store.profile.pendingPackID != nil
        let affordable = !claimed && !pending && (pack.currency == .coins ? store.profile.coins >= pack.cost : store.profile.packTokens >= pack.cost)
        return Button {
            Haptics.tap()
            openingPack = pack
        } label: {
            VStack(spacing: 8) {
                LegendsPackArtwork(pack: pack, isEnabled: affordable)
                Text(pack.name)
                    .font(.system(.footnote, design: .rounded).weight(.black))
                    .foregroundStyle(affordable ? LegendsPalette.navy : LegendsPalette.navy.opacity(0.4))
                Text(pack.subtitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if pack.guaranteedMinTier > 0 {
                    Text("GUARANTEED: \(pack.guaranteedRarityLabel.uppercased())+")
                        .font(.system(size: 9, design: .monospaced).bold())
                        .foregroundStyle(LegendsPalette.purple)
                }
                HStack(spacing: 4) {
                    if !claimed {
                        Image(systemName: pack.currency == .coins ? "dollarsign.circle.fill" : "shippingbox.fill")
                            .font(.system(size: 11))
                    }
                    Text(claimed ? "CLAIMED" : (pending ? "FINISH DECISION" : (pack.cost == 0 ? "FREE" : "\(pack.cost)")))
                        .font(.system(.caption, design: .monospaced).bold())
                }
                .foregroundStyle(claimed ? LegendsPalette.navy.opacity(0.4) : (affordable ? LegendsPalette.goldDeep : Retro.warning))
            }
            .frame(maxWidth: .infinity, minHeight: 206)
            .padding(14)
            .background(affordable ? LegendsPalette.purpleWash : LegendsPalette.navy.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.purple.opacity(affordable ? 0.35 : 0.1), lineWidth: 1))
            .shadow(color: LegendsPalette.navy.opacity(0.08), radius: 7, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(claimed || (pending && store.profile.pendingPackID != pack.id))
    }
}

private struct LegendsPackOpeningView: View {
    let store: LegendsStore
    let pack: LegendsPack
    var onDone: () -> Void

    @State private var results: [LegendsPackPullResult] = []
    @State private var revealed = Set<Int>()
    @State private var selectedIndex: Int? = nil
    @State private var burstIndex: Int? = nil
    @State private var errorMessage: String? = nil
    @State private var entry = false
    @State private var claimedCardID: String? = nil
    @State private var showingSignChoice = false

    private var pending: Bool { store.profile.pendingPackID != nil }
    private var allRevealed: Bool { revealed.count == results.count && !results.isEmpty }

    var body: some View {
        ZStack {
            LinearGradient(colors: [LegendsPalette.navy, LegendsPalette.purple, LegendsPalette.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button {
                        Haptics.tap()
                        onDone()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Close pack opening")
                    .buttonStyle(PressableButtonStyle())
                    Spacer()
                    Text(pack.name.uppercased())
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    LegendsPackArtwork(pack: pack, compact: true)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                if let errorMessage {
                    Spacer()
                    Text(errorMessage)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Spacer()
                } else {
                    VStack(spacing: 6) {
                        Text(allRevealed ? "CHOOSE ONE PLAYER" : "YOUR PACK IS OPENING")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(LegendsPalette.gold)
                        Text(allRevealed ? "The other two remain unavailable." : "Three candidates. One becomes part of your story.")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.76))
                    }
                    .padding(.top, 8)

                    Spacer()
                    HStack(spacing: 10) {
                        ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                            candidateCard(index: index, result: result)
                        }
                    }
                    .padding(.horizontal, 12)
                    Spacer()

                    if let selectedIndex {
                        Button {
                            Haptics.success()
                            do {
                                let claimed = try store.claimPreparedPack(at: selectedIndex)
                                claimedCardID = claimed.card.id
                                self.selectedIndex = nil
                                showingSignChoice = true
                            } catch {
                                errorMessage = "This player could not be added right now."
                            }
                        } label: {
                            Text("ADD PLAYER TO LIBRARY")
                                .font(.system(.headline, design: .monospaced).bold())
                                .foregroundStyle(LegendsPalette.navy)
                                .frame(maxWidth: 320)
                                .padding(.vertical, 14)
                                .background(LegendsPalette.green)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.bottom, 24)
                    } else {
                        Text(allRevealed ? "Tap the player you want to keep" : "Tap each card to reveal it")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.68))
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .alert("PLAYER ACQUIRED", isPresented: $showingSignChoice) {
            Button("ADD TO COLLECTION") {
                if let claimedCardID { store.markPlayerViewed(cardID: claimedCardID) }
                onDone()
            }
            if let claimedCardID {
                Button("SIGN NOW") {
                    _ = store.signPlayer(cardID: claimedCardID)
                    onDone()
                }
            }
        } message: {
            if let claimedCardID,
               let card = LegendsCardDatabase.all.first(where: { $0.id == claimedCardID }) {
                Text("\(card.name) is waiting in your Collection. Sign now to start the career, or keep the player unsigned with their age frozen.")
            } else {
                Text("Choose whether to begin this player's career now or keep them unsigned in your Collection.")
            }
        }
        .onAppear {
            if store.profile.pendingPackID == pack.id {
                results = store.pendingPackResults()
            } else if store.profile.pendingPackID == nil {
                do { results = try store.preparePack(pack) }
                catch { errorMessage = "This pack cannot be opened right now." }
            } else {
                errorMessage = "Finish the other pack decision first."
            }
            withAnimation(.easeOut(duration: 0.45)) { entry = true }
        }
    }

    private func candidateCard(index: Int, result: LegendsPackPullResult) -> some View {
        let isRevealed = revealed.contains(index)
        let isSelected = selectedIndex == index
        return Button {
            guard isRevealed || allRevealed else {
                Haptics.tap()
                revealed.insert(index)
                if result.card.rarity.tier >= 5 {
                    burstIndex = index
                    Haptics.success()
                    SoundManager.shared.play(.trophyLift)
                }
                return
            }
            guard allRevealed else { return }
            Haptics.tap()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                selectedIndex = isSelected ? nil : index
            }
        } label: {
            ZStack {
                if isRevealed {
                    cardFront(result, isSelected: isSelected)
                } else {
                    cardBack
                }
                if burstIndex == index {
                    ConfettiBurst(particleCount: result.card.rarity.tier >= 6 ? 22 : 14, duration: 0.9)
                }
            }
            .rotation3DEffect(.degrees(isRevealed ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            .offset(y: entry ? 0 : 80)
            .opacity(entry ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(Double(index) * 0.12), value: entry)
        }
        .buttonStyle(.plain)
    }

    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(colors: [LegendsPalette.navy, LegendsPalette.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.gold.opacity(0.8), lineWidth: 2))
            .overlay(VStack(spacing: 7) {
                Text("RSM").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.white)
                Image(systemName: "sparkles").font(.system(size: 26, weight: .black)).foregroundStyle(LegendsPalette.gold)
            })
            .frame(width: 102, height: 142)
    }

    private func cardFront(_ result: LegendsPackPullResult, isSelected: Bool) -> some View {
        VStack(spacing: 6) {
            LegendsPlayerCardView(store: store, card: result.card, variant: .reveal, isSelected: isSelected, showsStatus: false)
                .environment(\.colorScheme, .dark)
            Text(isSelected ? "KEEPING" : "CANDIDATE")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(isSelected ? LegendsPalette.green : .white.opacity(0.62))
        }
        .frame(width: 102, height: 142)
    }
}

private struct ConfettiBurst: View {
    let duration: Double
    let particles: [(angle: Double, distance: CGFloat, color: Color)]
    @State private var expanded = false

    init(particleCount: Int = 14, duration: Double = 0.7) {
        self.duration = duration
        self.particles = (0..<particleCount).map { i in
            (angle: Double(i) * (360.0 / Double(particleCount)), distance: CGFloat.random(in: 40...80),
             color: [LegendsPalette.gold, LegendsPalette.green, LegendsPalette.blue, .white].randomElement()!)
        }
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
        .onAppear { withAnimation(.easeOut(duration: duration)) { expanded = true } }
        .allowsHitTesting(false)
    }
}
