import XCTest
@testable import Retro_Season_Manager

/// Playability simulation (not a pass/fail gate). Models a realistic long-run
/// Legends save using the live division-schedule path (14-fixture campaigns),
/// rebuilding the squad each season and spending earned coins/tokens on packs,
/// so the trajectory reveals pacing, economy, difficulty and retirement-turnover
/// problems. Prints a per-campaign log plus a summary for human review.
@MainActor
final class LegendsPlayabilitySimulationTests: XCTestCase {
    func testLongRunPlayabilityTrajectory() async throws {
        let original = await Task { @MainActor in LegendsStore() }.value.profile
        defer {
            Task { @MainActor in
                let restore = LegendsStore()
                restore.profile = original
                restore.persist()
            }
        }

        let store = await Task { @MainActor in LegendsStore() }.value
        store.profile = .starter()
        store.profile.hasClaimedStarterPack = false
        store.ensureDivisionSchedule()

        let campaignLength = store.divisionMatchCount // 14 for an 8-club double round-robin
        var lines: [String] = []
        var totalRetirements = 0
        var packsBought = 0
        var coinPacks = 0
        var tokenPacks = 0
        var deadEndReason: String? = nil

        // Column header: campaign | division | rating | vsDifficult | coins | tokens | owned | retired
        lines.append("campaign | div        | rat | dif | coins | tokens | owned/\(LegendsCardDatabase.all.count) | ret")
        for campaign in 1...45 {
            // Season start: field the strongest available XI. A retirement at
            // the previous season's boundary may have opened slots; refill now.
            rebuildSquad(store)
            if !hasFullXI(store) {
                deadEndReason = "Cannot field 11 at season \(campaign) start: owned=\(store.profile.ownedCardIDs.count)"
                break
            }

            var campaignRetired = 0
            for _ in 0..<campaignLength {
                // Refill (as a player would) if a mid-campaign retirement opens
                // a slot before the next match.
                if !hasFullXI(store) { _ = fillEmptySlots(store) }
                guard store.currentTeamRating > 0, let s = store.playMatch() else { break }
                if let sa = s.seasonAdvance {
                    totalRetirements += sa.retiredCards.count
                    campaignRetired += sa.retiredCards.count
                }
            }

            // Off-season economy: spend on the best affordable packs and sign
            // the strongest unsigned cards from the library.
            spendOnPacks(store, coins: &coinPacks, tokens: &tokenPacks, total: &packsBought)
            signBestAvailable(store)



            let division = store.profile.division
            let difficulty = 90 - division.rawValue * 4
            let rating = store.currentTeamRating
            lines.append(String(
                format: "%8d | %-4@ (%2d) | %3d | %3d | %5d | %6d | %3d/%d | \(campaignRetired)",
                campaign,
                division.displayName as NSString,
                division.rawValue,
                rating,
                difficulty,
                store.profile.coins,
                store.profile.packTokens,
                store.profile.ownedCardIDs.count,
                LegendsCardDatabase.all.count))
            if deadEndReason != nil { break }
        }

        print("""

        ============= LEGENDS PLAYABILITY SIMULATION =============
        division campaign length (fixtures): \(campaignLength)   matchesPerSeason (aging): \(LegendsStore.matchesPerSeason)
        RATING vs DIFFICULTY note: opponent base rating in a division = 90 - division*4.
        \(lines.joined(separator: "\n"))
        ---- totals ----
        packs opened (coin / token): \(packsBought) (\(coinPacks) / \(tokenPacks))
        total retirements: \(totalRetirements)
        final: div \(store.profile.division.displayName) rat \(store.currentTeamRating) coins \(store.profile.coins) tokens \(store.profile.packTokens) owned \(store.profile.ownedCardIDs.count)/\(LegendsCardDatabase.all.count)
        dead end: \(deadEndReason ?? "none")
        ==========================================================
        """)
    }

    private func hasFullXI(_ store: LegendsStore) -> Bool {
        store.profile.startingXICardIDs.compactMap { $0 }.count == store.startingXISlots.count
    }

    /// The unique player names currently in the whole squad, so the harness
    /// honours the game's "one season of a player per squad" rule the same way
    /// `removeFromSquad` enforces it (fielding two same-named cards would
    /// silently clear the first).
    private func squadNames(_ store: LegendsStore) -> Set<String> {
        let ids = store.profile.startingXICardIDs.compactMap { $0 } + store.profile.benchCardIDs.compactMap { $0 }
        return Set(ids.compactMap { id in LegendsCardDatabase.all.first { $0.id == id }?.name })
    }

    /// Strongest currently-owned, non-retired, not-already-fielded, and not
    /// sharing a name with an already-fielded card.
    private func strongestSpare(_ store: LegendsStore, fielded: Set<String>) -> LegendsCard? {
        let usedNames = squadNames(store)
        return LegendsCardDatabase.all
            .filter { store.profile.ownedCardIDs.contains($0.id) && !store.isRetired($0)
                      && !fielded.contains($0.id) && !usedNames.contains($0.name) }
            .max { store.effectiveOverall(for: $0) < store.effectiveOverall(for: $1) }
    }

    @discardableResult
    private func fillEmptySlots(_ store: LegendsStore) -> Bool {
        var fielded = Set(store.profile.startingXICardIDs.compactMap { $0 })
        var ok = true
        for index in store.startingXISlots.indices where store.profile.startingXICardIDs[index] == nil {
            guard let card = strongestSpare(store, fielded: fielded) else {
                ok = false
                let usedNames = squadNames(store)
                let eligible = store.profile.ownedCardIDs.filter { id in
                    guard let card = LegendsCardDatabase.all.first(where: { $0.id == id }) else { return false }
                    return !store.isRetired(card) && !fielded.contains(id) && !usedNames.contains(card.name)
                }.count
                print("[trace] nil XI slot \(index) of \(store.startingXISlots.count); eligible spares=\(eligible)")
                continue
            }
            store.assign(cardID: card.id, toXISlot: index)
            fielded.insert(card.id)
        }
        return ok
    }

    private func rebuildSquad(_ store: LegendsStore) {
        _ = fillEmptySlots(store)
        var fielded = Set(store.profile.startingXICardIDs.compactMap { $0 })
        // Re-run to promote better new cards into the XI as they're acquired.
        for index in store.startingXISlots.indices {
            guard let current = store.profile.startingXICardIDs[index],
                  let card = store.profile.startingXICardIDs[index].flatMap({ id in LegendsCardDatabase.all.first { $0.id == id } }) else { continue }
            _ = card
            // Leave valid filled slots as-is; the off-season signing below covers growth.
            _ = current
        }
        // Bench: fill empties with best spares.
        for index in store.profile.benchCardIDs.indices where store.profile.benchCardIDs[index] == nil {
            guard let card = strongestSpare(store, fielded: fielded) else { break }
            store.assign(cardID: card.id, toBenchSlot: index)
            fielded.insert(card.id)
        }
    }

    private func spendOnPacks(_ store: LegendsStore, coins: inout Int, tokens: inout Int, total: inout Int) {
        // Spend coins upward: keep buying the best affine pack the balance allows.
        while let pack = LegendsPackDatabase.all
            .filter({ $0.currency == .coins && $0.cost > 0 && store.profile.coins >= $0.cost })
            .max(by: { $0.cost < $1.cost }) {
            if (try? store.openPack(pack)) != nil { total += 1; coins += 1 } else { break }
        }
        // Spend tokens on the best affine token pack.
        while let pack = LegendsPackDatabase.all
            .filter({ $0.currency == .tokens && $0.cost > 0 && store.profile.packTokens >= $0.cost })
            .max(by: { $0.cost < $1.cost }) {
            if (try? store.openPack(pack)) != nil { total += 1; tokens += 1 } else { break }
        }
    }

    /// Fills any empty bench slot with the strongest signed-up-able spare
    /// (honouring name-uniqueness) and promotes the best bench card into the
    /// XI when it beats a current occupant — a realistic roster upgrade loop.
    private func signBestAvailable(_ store: LegendsStore) {
        var fielded = Set(store.profile.startingXICardIDs.compactMap { $0 })
        for index in store.profile.benchCardIDs.indices where store.profile.benchCardIDs[index] == nil {
            guard let card = strongestSpare(store, fielded: fielded) else { break }
            store.assign(cardID: card.id, toBenchSlot: index)
            fielded.insert(card.id)
        }
        // Promote the highest-rated, name-safe bench card into a weaker XI slot.
        var updated = true
        while updated {
            updated = false
            guard let bestBench = bestBenchCard(store, excluding: fielded) else { break }
            for index in store.startingXISlots.indices {
                guard let currentID = store.profile.startingXICardIDs[index],
                      let current = LegendsCardDatabase.all.first(where: { $0.id == currentID }),
                      store.effectiveOverall(for: bestBench) > store.effectiveOverall(for: current),
                      store.profile.benchCardIDs.contains(bestBench.id) else { continue }
                store.profile.benchCardIDs[store.profile.benchCardIDs.firstIndex(of: bestBench.id)!] = currentID
                store.profile.startingXICardIDs[index] = bestBench.id
                fielded.insert(bestBench.id)
                updated = true
                break
            }
        }
        _ = store.persist()
    }

    private func bestBenchCard(_ store: LegendsStore, excluding fielded: Set<String>) -> LegendsCard? {
        store.profile.benchCardIDs.compactMap { $0 }
            .compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
            .filter { !store.isRetired($0) && !fielded.contains($0.id) }
            .max { store.effectiveOverall(for: $0) < store.effectiveOverall(for: $1) }
    }
}
