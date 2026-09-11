//
//  LegendsPacksView.swift
//  Retro Season Manager
//
//  Pack shop and the three-card choice flow. Opening a pack reserves three
//  candidates, animates them into view, and only the selected card enters
//  the player library.
//
//  Presentation only: balances, affordability, guaranteed rarities and the
//  pending-decision state all come from the existing profile and store
//  actions. Prices, odds, pools and claim-once behaviour live in
//  LegendsStore+Packs.swift and are untouched here.
//

import SwiftUI

/// Why a pack tile can or cannot be opened right now. Derived only from the
/// authoritative profile state so the shelf can explain itself, and
/// contract-tested without instantiating SwiftUI views.
enum LegendsPackAvailability: Equatable {
    case ready
    case claimed
    case decisionPendingThisPack
    case decisionPendingElsewhere
    case needsTokens(missing: Int)

    var isInteractive: Bool { self == .ready || self == .decisionPendingThisPack }

    init(pack: LegendsPack, profile: LegendsProfile) {
        if pack.id == "starter" && profile.hasClaimedStarterPack && profile.pendingPackID != "starter" {
            self = .claimed
        } else if profile.pendingPackID == pack.id {
            self = .decisionPendingThisPack
        } else if profile.pendingPackID != nil {
            self = .decisionPendingElsewhere
        } else {
            if profile.packTokens >= pack.cost {
                self = .ready
            } else {
                self = .needsTokens(missing: pack.cost - profile.packTokens)
            }
        }
    }
}

struct LegendsPacksView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var openingPack: LegendsPack? = nil

    var body: some View {
        LegendsMenuShell(store: store, title: "PACKS", subtitle: "OPEN YOUR NEXT STORY", icon: "shippingbox.fill", accent: LegendsPalette.purple, onBack: onBack, currentNav: .packs, onNavigate: onNavigate, scrollContent: false) {
            GeometryReader { geo in
                let wide = geo.size.width >= 860
                // One stable scroll container: the shelf scrolls as a whole
                // and nothing inside resets its position (the previous
                // LazyVGrid arrangement could snap back mid-browse).
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        summaryBand
                        if let pendingPackID = store.profile.pendingPackID,
                           let pendingPack = LegendsPackDatabase.all.first(where: { $0.id == pendingPackID }) {
                            pendingBanner(pendingPack)
                        }
                        // Plain rows (not lazy): packs stay in the
                        // accessibility tree even when scrolled off-screen.
                        let packs = displayedPacks
                        let columnCount = wide ? 3 : 2
                        ForEach(stride(from: 0, to: packs.count, by: columnCount).map { start in
                            (id: packs[start].id, packs: Array(packs[start..<min(start + columnCount, packs.count)]))
                        }, id: \.id) { row in
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(row.packs) { pack in
                                    packTile(pack)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .sheet(item: $openingPack) { pack in
            LegendsPackOpeningView(store: store, pack: pack) { openingPack = nil }
        }
        .accessibilityIdentifier("legends.packs.screen")
    }

    /// The free Starter Pack leaves the shelf once claimed — no permanent
    /// CLAIMED tile. It stays visible while its own three-card decision is
    /// still pending so the player can finish choosing before it hides.
    private var displayedPacks: [LegendsPack] {
        LegendsPackDatabase.all.filter { pack in
            guard pack.id == "starter" else { return true }
            return !(store.profile.hasClaimedStarterPack && store.profile.pendingPackID != "starter")
        }
    }

    // MARK: - Balances

    /// Real club balance and pack-token balance, mirrored from the profile. The
    /// shell header already shows them small; this band is the scannable
    /// store-front version.
    private var summaryBand: some View {
        HStack(spacing: 8) {
            balanceStat(value: "\(store.profile.coins)",
                        label: "BALANCE",
                        color: LegendsPalette.goldDeep,
                        identifier: "legends.packs.summary.balance")
            balanceStat(value: "\(store.profile.packTokens)",
                        label: "PACK TOKENS",
                        color: LegendsPalette.green,
                        identifier: "legends.packs.summary.tokens")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.purple.opacity(0.22), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.packs.summary")
    }

    private func balanceStat(value: String, label: String, color: Color, identifier: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: label == "BALANCE" ? "dollarsign.circle.fill" : "shippingbox.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LegendsPalette.navy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.66))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(LegendsPalette.contentBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label.lowercased())")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Pending decision

    private func pendingBanner(_ pack: LegendsPack) -> some View {
        Button {
            openingPack = pack
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.tv.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(LegendsPalette.goldDeep)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PACK DECISION WAITING")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy)
                    Text("Choose one of your \(pack.name) candidates to add to the library.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.72))
                        .lineLimit(2)
                }
                Spacer()
                Text("CONTINUE DECISION")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(LegendsPalette.purple)
                    .clipShape(Capsule())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(14)
            .background(LegendsPalette.goldWash)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.gold.opacity(0.55), lineWidth: 1.5))
            .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("legends.packs.pending")
        .accessibilityLabel("Pack decision waiting. Continue choosing a card from your \(pack.name).")
    }

    // MARK: - Pack tile

    private func packTile(_ pack: LegendsPack) -> some View {
        let availability = LegendsPackAvailability(pack: pack, profile: store.profile)
        let interactive = availability.isInteractive
        return Button {
            Haptics.tap()
            openingPack = pack
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    LegendsPackArtwork(pack: pack, isEnabled: availability == .ready)
                        .frame(maxWidth: .infinity, alignment: .center)
                    if pack.guaranteedMinTier > 0 {
                        Text("GUARANTEED \(pack.guaranteedRarityLabel.uppercased())+")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(LegendsPalette.purpleWash)
                            .clipShape(Capsule())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Text(pack.name)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(interactive ? LegendsPalette.navy : LegendsPalette.navy.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(pack.subtitle)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(interactive ? 0.62 : 0.4))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 24, alignment: .top)
                priceRow(pack, availability: availability)
                actionRow(pack, availability: availability)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tileBackground(availability))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(tileStroke(availability), lineWidth: 1))
            .shadow(color: LegendsPalette.navy.opacity(0.08), radius: 7, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!interactive)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("legends.packs.pack.\(pack.id)")
        .accessibilityLabel(tileAccessibilityLabel(pack, availability: availability))
    }

    private func priceRow(_ pack: LegendsPack, availability: LegendsPackAvailability) -> some View {
        HStack(spacing: 4) {
            if availability != .claimed {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 11))
            }
            Text(priceText(pack, availability: availability))
                .font(.system(.caption, design: .monospaced).bold())
                .monospacedDigit()
        }
        .foregroundStyle(priceColor(availability))
    }

    private func priceText(_ pack: LegendsPack, availability: LegendsPackAvailability) -> String {
        switch availability {
        case .claimed: return "CLAIMED"
        case .decisionPendingThisPack: return "AWAITING DECISION"
        case .decisionPendingElsewhere: return "FINISH OTHER DECISION"
        case .needsTokens(let missing): return "\(pack.cost) TOKENS · NEED \(missing) MORE"
        case .ready: return pack.cost == 0 ? "FREE" : "\(pack.cost)"
        }
    }

    private func actionRow(_ pack: LegendsPack, availability: LegendsPackAvailability) -> some View {
        let label: String
        let color: Color
        switch availability {
        case .ready:
            label = "OPEN PACK"
            color = LegendsPalette.green
        case .decisionPendingThisPack:
            label = "CONTINUE DECISION"
            color = LegendsPalette.purple
        default:
            label = "UNAVAILABLE"
            color = LegendsPalette.navy.opacity(0.38)
        }
        return HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Image(systemName: availability == .ready ? "arrow.right.circle.fill" : "lock.fill")
                .font(.system(size: 10, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func tileBackground(_ availability: LegendsPackAvailability) -> Color {
        switch availability {
        case .ready: return LegendsPalette.purpleWash
        case .decisionPendingThisPack: return LegendsPalette.goldWash
        default: return LegendsPalette.navy.opacity(0.05)
        }
    }

    private func tileStroke(_ availability: LegendsPackAvailability) -> Color {
        switch availability {
        case .ready: return LegendsPalette.purple.opacity(0.35)
        case .decisionPendingThisPack: return LegendsPalette.gold.opacity(0.5)
        default: return LegendsPalette.navy.opacity(0.1)
        }
    }

    private func priceColor(_ availability: LegendsPackAvailability) -> Color {
        switch availability {
        case .ready: return LegendsPalette.goldDeep
        case .needsTokens, .decisionPendingElsewhere: return Retro.warning
        default: return LegendsPalette.navy.opacity(0.4)
        }
    }

    private func tileAccessibilityLabel(_ pack: LegendsPack, availability: LegendsPackAvailability) -> String {
        let guarantee = pack.guaranteedMinTier > 0 ? ", guaranteed \(pack.guaranteedRarityLabel) or better" : ""
        let cost = pack.cost == 0 ? "free" : "\(pack.cost) pack tokens"
        let state: String
        switch availability {
        case .ready: state = "Ready to open"
        case .claimed: state = "Already claimed"
        case .decisionPendingThisPack: state = "Card decision waiting, continue to choose"
        case .decisionPendingElsewhere: state = "Unavailable, finish your other pack decision first"
        case .needsTokens(let missing): state = "Unavailable, need \(missing) more pack tokens"
        }
        return "\(pack.name), \(pack.subtitle)\(guarantee), costs \(cost). \(state)."
    }
}

private struct LegendsPackOpeningView: View {
    let store: LegendsStore
    let pack: LegendsPack
    var onDone: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var compactHeight: Bool { verticalSizeClass == .compact }

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

    /// Slightly larger cards where the landscape width allows it; compact
    /// phones keep the proven 102×141 size that fits three across.
    private var cardSize: CGSize {
        horizontalSizeClass == .regular ? CGSize(width: 118, height: 162) : CGSize(width: 102, height: 141)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [LegendsPalette.navy, LegendsPalette.purple, LegendsPalette.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if let errorMessage {
                    Spacer()
                    Text(errorMessage)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                } else {
                    // Only the title + candidates scroll; the header and the
                    // claim action stay fixed so the choice is always
                    // reachable on compact landscape screens.
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: compactHeight ? 10 : 16) {
                            titleBlock
                            HStack(alignment: .top, spacing: compactHeight ? 10 : 14) {
                                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                                    candidateCard(index: index, result: result)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .padding(.vertical, compactHeight ? 8 : 14)
                        .frame(maxWidth: .infinity)
                    }
                    footer
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
        .accessibilityIdentifier("legends.packopening.screen")
    }

    private var header: some View {
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
            VStack(spacing: 2) {
                Text(pack.name.uppercased())
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if pack.guaranteedMinTier > 0 {
                    Text("GUARANTEED \(pack.guaranteedRarityLabel.uppercased())+")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.gold)
                }
            }
            Spacer()
            LegendsPackArtwork(pack: pack, compact: true)
        }
        .padding(.horizontal, 18)
        .padding(.top, compactHeight ? 8 : 12)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(allRevealed ? "CHOOSE ONE PLAYER" : "YOUR PACK IS OPENING")
                .font(.system(size: compactHeight ? 20 : 24, weight: .black, design: .rounded))
                .foregroundStyle(LegendsPalette.gold)
            Text(allRevealed ? "The other two remain unavailable." : "Three candidates. One becomes part of your story.")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.76))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        Group {
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
                .accessibilityIdentifier("legends.packopening.claim")
            } else {
                Text(allRevealed ? "Tap the player you want to keep" : "Tap each card to reveal it")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("legends.packopening.hint")
            }
        }
        .padding(.bottom, compactHeight ? 12 : 24)
    }

    private func candidateCard(index: Int, result: LegendsPackPullResult) -> some View {
        let isRevealed = revealed.contains(index)
        let isSelected = selectedIndex == index
        // Once a keeper is picked, the other candidates visibly step back
        // (still tappable, so the choice can be changed).
        let isSteppedBack = selectedIndex != nil && !isSelected
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
                    cardFront(result, isSelected: isSelected, isSteppedBack: isSteppedBack)
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
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("legends.packopening.candidate.\(index)")
        .accessibilityLabel(candidateAccessibilityLabel(index: index, result: result, isRevealed: isRevealed, isSelected: isSelected))
    }

    private func candidateAccessibilityLabel(index: Int, result: LegendsPackPullResult, isRevealed: Bool, isSelected: Bool) -> String {
        let ordinal = ["First", "Second", "Third"][min(index, 2)].lowercased()
        if !isRevealed { return "Candidate \(index + 1), unrevealed. Tap to reveal." }
        let card = result.card
        let state = isSelected ? ", selected, tap the add button to keep this player"
            : (pending ? ", \(ordinal) candidate" : ", tap to select this player")
        return "Candidate \(index + 1): \(card.name), \(card.rarity.rawValue)\(state)"
    }

    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(colors: [LegendsPalette.navy, LegendsPalette.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.gold.opacity(0.8), lineWidth: 2))
            .overlay(VStack(spacing: 7) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                Image(systemName: "sparkles").font(.system(size: 26, weight: .black)).foregroundStyle(LegendsPalette.gold)
            }
            // The whole card is rotated while unrevealed. Reverse that
            // rotation here so the back artwork remains upright.
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0)))
            .frame(width: cardSize.width, height: cardSize.height)
            .accessibilityHidden(true)
    }

    private func cardFront(_ result: LegendsPackPullResult, isSelected: Bool, isSteppedBack: Bool) -> some View {
        VStack(spacing: 6) {
            LegendsPlayerCardView(store: store, card: result.card, variant: .reveal, isSelected: isSelected, showsStatus: false)
                .environment(\.colorScheme, .dark)
            Text(isSelected ? "KEEPING" : (isSteppedBack ? "OTHER" : "CANDIDATE"))
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(isSelected ? LegendsPalette.green : .white.opacity(0.62))
        }
        .opacity(isSteppedBack ? 0.55 : 1)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? LegendsPalette.gold : .clear, lineWidth: isSelected ? 3 : 0)
        )
        .frame(width: cardSize.width, height: cardSize.height)
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
