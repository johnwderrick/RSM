//
//  LegendsSeasonSoakTests.swift
//  Retro Season ManagerTests
//
//  TEMPORARY exploratory soak test — drives LegendsStore directly through
//  many matches/seasons (bypassing the live match UI, which would take
//  real time) to surface any invariant violations, crashes, or dead-end
//  states across the aging/retirement/pack-opening/promotion systems
//  working together over a long play session. Not meant to stay in the
//  suite long-term as a strict pass/fail gate — logs a summary for human
//  review instead of asserting on every soft outcome.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsSeasonSoakTests: XCTestCase {
    func testSimulateManySeasons() async throws {
        // This test persists dozens of times over a simulated 150-match,
        // 15-season run — same shared on-disk legends_profile.json every
        // other Legends test's `LegendsStore()` construction reads from
        // (xcodebuild test isn't sandboxed per-test). Save the real
        // pre-test profile and restore it afterward, same pattern
        // LegendsProfileRoundTripTests uses, so this doesn't leak
        // 15 seasons of aging/upgrades into sibling test classes that
        // don't happen to reset every field this run touches.
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

        var matchesPlayed = 0
        var seasonsAdvanced = 0
        var totalRetirements = 0
        var packsOpened = 0
        var promotions = 0
        var stoppedEarlyReason: String? = nil
        var retirementLog: [String] = []

        let iterationCap = 150 // ~10 seasons at matchesPerSeason=14

        for i in 0..<iterationCap {
            let filled = refillSquadIfNeeded(store)
            if !filled {
                stoppedEarlyReason = "Ran out of legal replacement cards to fill the squad at iteration \(i) (season \(store.profile.currentSeason))"
                break
            }

            XCTAssertGreaterThan(store.currentTeamRating, 0, "Team rating should be nonzero with a confirmed-full XI at iteration \(i)")
            XCTAssertLessThanOrEqual(store.currentTeamRating, 99)
            XCTAssertGreaterThanOrEqual(store.attackRating, 0)
            XCTAssertGreaterThanOrEqual(store.defenceRating, 0)
            XCTAssertGreaterThanOrEqual(store.totalChemistry, 0)
            XCTAssertLessThanOrEqual(store.totalChemistry, 33)

            let coinsBefore = store.profile.coins
            let tokensBefore = store.profile.packTokens
            let divisionBefore = store.profile.division

            guard let summary = store.playMatch() else {
                stoppedEarlyReason = "playMatch() returned nil at iteration \(i) despite a confirmed-full XI"
                break
            }
            matchesPlayed += 1

            XCTAssertGreaterThanOrEqual(store.profile.coins, coinsBefore, "Coins should never decrease from playing a match")
            XCTAssertGreaterThanOrEqual(store.profile.packTokens, tokensBefore, "Tokens should never decrease from playing a match")
            XCTAssertGreaterThanOrEqual(summary.coinsEarned, 0)
            XCTAssertGreaterThanOrEqual(summary.xpEarned, 0)
            // Completed challenges pay coins/tokens directly into
            // profile.coins/packTokens (LegendsStore+Challenges.swift's
            // grant(_:)) on top of the base match-outcome reward, so the
            // full delta is coinsEarned + every completed challenge's own
            // coinReward, not coinsEarned alone.
            let challengeCoins = summary.completedChallenges.reduce(0) { $0 + $1.challenge.coinReward }
            let challengeTokens = summary.completedChallenges.reduce(0) { $0 + $1.challenge.tokenReward }
            let seasonCoins = summary.divisionSeasonResult?.reward.coins ?? 0
            let seasonTokens = summary.divisionSeasonResult?.reward.tokens ?? 0
            XCTAssertEqual(store.profile.coins, coinsBefore + summary.coinsEarned + challengeCoins + seasonCoins)
            XCTAssertEqual(store.profile.packTokens, tokensBefore + summary.tokensEarned + challengeTokens + seasonTokens)
            XCTAssertGreaterThanOrEqual(store.profile.managerLevel, 1)

            if summary.promoted {
                promotions += 1
                XCTAssertNotEqual(store.profile.division, divisionBefore)
                XCTAssertLessThan(store.profile.division.rawValue, divisionBefore.rawValue, "Promotion should move to a lower (better) division rawValue")
            }

            if let seasonAdvance = summary.seasonAdvance {
                seasonsAdvanced += 1
                totalRetirements += seasonAdvance.retiredCards.count
                XCTAssertEqual(store.profile.currentSeason, seasonAdvance.newSeason)
                for card in seasonAdvance.retiredCards {
                    retirementLog.append("season \(seasonAdvance.newSeason): \(card.name) (\(card.position.rawValue), retired at effective age \(seasonAdvance.retiredAges[card.id] ?? LegendsStore.retirementAge))")
                }
            }

            // Interleave pack-opening every few matches, same as a real
            // player spending earned currency as they go.
            if i % 4 == 0 {
                let affordable = LegendsPackDatabase.all.filter { pack in
                    (pack.currency == .coins && store.profile.coins >= pack.cost && pack.cost > 0) ||
                    (pack.currency == .tokens && store.profile.packTokens >= pack.cost && pack.cost > 0)
                }
                if let pack = affordable.max(by: { $0.cost < $1.cost }) {
                    let ownedBefore = store.profile.ownedCardIDs.count
                    if let results = try? store.openPack(pack) {
                        packsOpened += 1
                        XCTAssertEqual(results.count, pack.cardCount, "\(pack.id) should always pull exactly cardCount cards")
                        XCTAssertGreaterThanOrEqual(store.profile.ownedCardIDs.count, ownedBefore)
                        for result in results {
                            XCTAssertTrue(store.profile.ownedCardIDs.contains(result.card.id))
                        }
                    }
                }
            }
        }

        print("""

        ================= LEGENDS SEASON SOAK SUMMARY =================
        matches played:       \(matchesPlayed)
        seasons advanced:     \(seasonsAdvanced)
        promotions:           \(promotions)
        total retirements:    \(totalRetirements)
        packs opened:         \(packsOpened)
        final coins:          \(store.profile.coins)
        final tokens:         \(store.profile.packTokens)
        final division:       \(store.profile.division.displayName)
        final divisionWins:   \(store.profile.divisionWins)
        final teamRating:     \(store.currentTeamRating)
        final attack/defence: \(store.attackRating)/\(store.defenceRating)
        final chemistry:      \(store.totalChemistry)/33
        manager level/XP:     \(store.profile.managerLevel)/\(store.profile.managerXP)
        owned cards:          \(store.profile.ownedCardIDs.count)/\(LegendsCardDatabase.all.count)
        stopped early:        \(stoppedEarlyReason ?? "no — ran the full \(iterationCap)-match cap")
        ---- retirements (first 20) ----
        \(retirementLog.prefix(20).joined(separator: "\n"))
        =================================================================
        """)
    }

    /// Fills every empty XI/bench slot with the strongest currently-owned,
    /// non-retired, not-already-fielded card. Returns false if a slot
    /// couldn't be filled (ran out of eligible replacements) — a
    /// legitimate "you need more cards" dead end, not asserted as a
    /// failure by the caller.
    @discardableResult
    private func refillSquadIfNeeded(_ store: LegendsStore) -> Bool {
        for index in store.startingXISlots.indices where store.profile.startingXICardIDs[index] == nil {
            guard let replacement = bestReplacement(store) else { return false }
            store.signPlayer(cardID: replacement)
            store.assign(cardID: replacement, toXISlot: index)
        }
        for index in store.profile.benchCardIDs.indices where store.profile.benchCardIDs[index] == nil {
            guard let replacement = bestReplacement(store) else { return false }
            store.signPlayer(cardID: replacement)
            store.assign(cardID: replacement, toBenchSlot: index)
        }
        return true
    }

    private func bestReplacement(_ store: LegendsStore) -> String? {
        let usedIDs = Set((store.profile.startingXICardIDs + store.profile.benchCardIDs).compactMap { $0 })
        // By name, not just ID — assign()/removeFromSquad() evict by name
        // (one version of a real player at a time), so picking another
        // season of someone already fielded would silently bump them.
        let usedNames = Set(usedIDs.compactMap { id in LegendsCardDatabase.all.first { $0.id == id }?.name })
        let candidates = LegendsCardDatabase.all.filter {
            store.profile.ownedCardIDs.contains($0.id) && !usedNames.contains($0.name) && !store.isRetired($0)
        }
        return candidates.max { store.effectiveOverall(for: $0) < store.effectiveOverall(for: $1) }?.id
    }
}
