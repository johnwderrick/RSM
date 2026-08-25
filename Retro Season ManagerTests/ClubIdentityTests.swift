//
//  ClubIdentityTests.swift
//  Retro Season ManagerTests
//
//  Guards item 8 of the improvement directive: ClubIdentity assignment at
//  newGame(), and the mechanical hooks it drives across transfers, youth
//  development, world-event news/facilities, AI sacking decisions, and
//  cup performance.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class ClubIdentityTests: XCTestCase {

    private func freshStore() async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2000, managerName: "Club Identity Test")
        return store
    }

    // MARK: - Assignment

    func testEveryClubGetsAnIdentityAfterNewGame() async {
        let store = await freshStore()
        XCTAssertEqual(store.clubIdentities.count, store.clubs.count)
    }

    func testKnownClubsGetTheirHandAuthoredOverride() async {
        let store = await freshStore()
        for (name, expected) in ClubIdentity.knownIdentities {
            guard let index = store.clubs.firstIndex(where: { $0.name == name }) else { continue }
            XCTAssertEqual(store.clubIdentity(forClubIndex: index), expected, "\(name) should always get its override identity")
        }
    }

    func testDerivedIdentityWeightingFavoursUnderdogForLowPrestigeBottomTier() {
        var underdogCount = 0
        let trials = 2000
        for _ in 0..<trials where GameStore.deriveClubIdentity(prestige: 40, tier: 3) == .underdog {
            underdogCount += 1
        }
        // Flat weighting across 10 identities would land ~10%; the
        // low-prestige/bottom-tier bonus should push this well above that.
        XCTAssertGreaterThan(underdogCount, trials / 6)
    }

    // MARK: - Transfer behaviour

    func testSellingClubIsPickedAsSellerMoreOftenThanTalentHoarder() async {
        let store = await freshStore()
        // Isolate exactly four AI clubs as transfer candidates by excluding
        // every other club from processAITransfer()'s `divisionTier < 4`
        // pool — at least 3 is essential: with only 2 candidates, whichever
        // isn't picked as buyer is *always* the seller regardless of any
        // weighting, since weightedRandomIndex over a single remaining
        // candidate can't express a preference at all.
        for index in store.clubs.indices where index != store.userClubIndex {
            store.clubs[index].divisionTier = 4
        }
        let isolated = store.clubs.indices.filter { $0 != store.userClubIndex }.prefix(4)
        guard isolated.count == 4 else { return XCTFail("Expected at least four AI clubs") }
        for index in isolated { store.clubs[index].divisionTier = 0 }
        let sellingIndex = isolated[isolated.startIndex]
        let hoarderIndex = isolated[isolated.index(after: isolated.startIndex)]
        store.clubIdentities[sellingIndex] = .sellingClub
        store.clubIdentities[hoarderIndex] = .talentHoarder

        var sellingLosses = 0
        var hoarderLosses = 0
        for _ in 0..<200 {
            let before = (store.clubs[sellingIndex].players.count, store.clubs[hoarderIndex].players.count)
            store.processAITransfer()
            if store.clubs[sellingIndex].players.count < before.0 { sellingLosses += 1 }
            if store.clubs[hoarderIndex].players.count < before.1 { hoarderLosses += 1 }
        }
        XCTAssertGreaterThan(sellingLosses, hoarderLosses)
    }

    // MARK: - World events (news, facilities)

    func testFinancialPowerhouseRollsTakeoversMoreOftenThanDefault() async {
        let store = await freshStore()
        guard let plainIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex }),
              let powerhouseIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex && $0 != plainIndex }) else {
            return XCTFail("Expected at least two AI clubs")
        }
        store.clubIdentities[plainIndex] = .underdog
        store.clubIdentities[powerhouseIndex] = .financialPowerhouse

        var plainTakeovers = 0
        var powerhouseTakeovers = 0
        for _ in 0..<1500 {
            store.clubs[plainIndex].prestige = 60
            store.clubs[powerhouseIndex].prestige = 60
            store.news = []
            store.simulateWorldEvents()
            if store.news.contains(where: { $0.title == "Club takeover" && $0.clubName == store.clubs[plainIndex].name }) {
                plainTakeovers += 1
            }
            if store.news.contains(where: { $0.title == "Club takeover" && $0.clubName == store.clubs[powerhouseIndex].name }) {
                powerhouseTakeovers += 1
            }
        }
        XCTAssertGreaterThan(powerhouseTakeovers, plainTakeovers)
    }

    func testCrisisClubRollsFinancialDistressMoreOftenThanDefault() async {
        let store = await freshStore()
        guard let plainIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex }),
              let crisisIndex = store.clubs.indices.first(where: { $0 != store.userClubIndex && $0 != plainIndex }) else {
            return XCTFail("Expected at least two AI clubs")
        }
        store.clubIdentities[plainIndex] = .underdog
        store.clubIdentities[crisisIndex] = .crisisClub

        var plainDistress = 0
        var crisisDistress = 0
        for _ in 0..<1500 {
            store.news = []
            store.simulateWorldEvents()
            let distressTitles: Set<String> = ["Club bankruptcy", "Financial crisis"]
            if store.news.contains(where: { distressTitles.contains($0.title) && $0.clubName == store.clubs[plainIndex].name }) {
                plainDistress += 1
            }
            if store.news.contains(where: { distressTitles.contains($0.title) && $0.clubName == store.clubs[crisisIndex].name }) {
                crisisDistress += 1
            }
        }
        XCTAssertGreaterThan(crisisDistress, plainDistress)
    }

    // MARK: - AI decisions (sacking candidacy)

    func testSleepingGiantWellBelowItsPrestigeRankBecomesASackingCandidate() async {
        let store = await freshStore()
        let tier = 1
        let tierIndices = store.clubs.indices.filter { store.clubs[$0].divisionTier == tier }
        guard tierIndices.count >= 20 else { return XCTFail("Expected a full 20-club division") }

        // A clean, fully deterministic table: strictly descending wins by
        // array order, so array position `n` lands at table rank `n`.
        for (rank, index) in tierIndices.enumerated() {
            let wins = max(0, 19 - rank)
            store.clubs[index].played = 19
            store.clubs[index].won = wins
            store.clubs[index].drawn = 0
            store.clubs[index].lost = 19 - wins
            store.clubs[index].goalsFor = 30
            store.clubs[index].goalsAgainst = 10
            store.clubs[index].prestige = 50
        }
        // 16th place (index 15) — clearly outside the bottom-4 — but the
        // highest prestige in the whole division, so only the identity's
        // widened rule (not the existing bottom-4 rule) can flag it.
        let targetIndex = tierIndices[15]
        store.clubs[targetIndex].prestige = 90
        store.clubIdentities[targetIndex] = .sleepingGiant

        var sacked = false
        for _ in 0..<6000 {
            let before = store.managers[targetIndex]
            store.checkRivalManagerSackings()
            if store.managers[targetIndex] != before { sacked = true; break }
        }
        XCTAssertTrue(sacked, "A Sleeping Giant sitting well below its prestige-implied rank should eventually become a sacking candidate")
    }

    // MARK: - Cup performance

    /// `simCupTie` itself is Monte Carlo (Poisson goals, a penalty-shootout
    /// coin flip on a draw) — comparing two independent 800-trial batches
    /// of *match outcomes* was flaky by construction: the Cup Specialist
    /// multiplier is a modest 8% strength bump, small enough that ordinary
    /// sample-to-sample variance across two unrelated random batches could
    /// (and did, on CI) outweigh it and flip the comparison. The
    /// multiplier's actual effect lives entirely in the deterministic
    /// strength-ratio calculation, not in the goals/penalties randomness
    /// layered on top of it — so this asserts on that calculation directly,
    /// via the `cupTieHomeStrengthShare` helper `simCupTie` itself now
    /// calls, rather than on a statistical proxy for it. Same real
    /// gameplay path, zero sampling noise.
    func testCupSpecialistRaisesCupTieStrengthShare() async {
        let store = await freshStore()
        guard let a = store.clubs.indices.first(where: { $0 != store.userClubIndex }),
              let b = store.clubs.indices.first(where: { $0 != store.userClubIndex && $0 != a }) else {
            return XCTFail("Expected at least two AI clubs")
        }
        // Both clubs start from a controlled, non-Cup-Specialist identity
        // so the baseline reading can't already be inflated by whatever
        // identity newGame() happened to assign either club.
        store.clubIdentities[a] = .underdog
        store.clubIdentities[b] = .underdog

        let baselineShare = store.cupTieHomeStrengthShare(a, b)

        store.clubIdentities[a] = .cupSpecialist
        let boostedShare = store.cupTieHomeStrengthShare(a, b)

        XCTAssertGreaterThan(boostedShare, baselineShare,
                             "Flagging club A as Cup Specialist should raise its home strength share against the same opponent")
    }
}
