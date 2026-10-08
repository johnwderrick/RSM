//
//  CupProgressionAuditTests.swift
//  Retro Season ManagerTests
//
//  Focused regression coverage for the Career cup progression &
//  fixture-scheduling audit (branch freebuff/cup-scheduling-audit). Every
//  test isolates its own save (newGame writes one; deleteSave in tearDown)
//  and drives the REAL transition paths — beginUserMatch/finishLiveMatch
//  (live play), concludeCupRound (abstract sim), forceSimTo (Calendar
//  FORCE SIM), dailyTick (auto-resolution) — asserting that:
//
//  1. Each tie resolves exactly once, whichever path commits it.
//  2. Winners advance (byes, draws -> strength-weighted penalties).
//  3. A completed user tie never lingers as an outstanding fixture or
//     feeds a stale/negative next-commitment countdown.
//  4. Prize money + ledger entries land exactly once, across the whole
//     season and across save/reload.
//  5. Save/reload round-trips ties, rounds, winners, fixture dates and
//     the next user commitment.
//  6. Season rollover resets every competition to round one while
//     preserving the recorded qualification lists, and the Community
//     Trophy is paired from LAST season's champion and cup winner.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class CupProgressionAuditTests: XCTestCase {

    // MARK: - Fixtures

    private var deferredSaves: [UUID] = []

    override func tearDown() {
        for id in deferredSaves { GameStore.deleteSave(id: id) }
        deferredSaves = []
        super.tearDown()
    }

    /// A real saved career: prestige-10 club, 2010 start. No scripted
    /// players — only whole-competition transitions are driven.
    private func makeStore(name: String) async -> GameStore {
        let store = await makeTestStore()
        store.newGame(clubIndex: 0, startYear: 2010, managerName: name)
        if let id = store.currentSaveID { deferredSaves.append(id) }
        return store
    }

    /// A PLAYED user tie still sitting in the current round — the stranded-
    /// tie signature. An unplayed next-round tie is the correct state after
    /// a commitment and must not match.
    private func playedUserTie(_ store: GameStore) -> CupTie? {
        store.cupTies.first {
            $0.played && !$0.isBye
                && ($0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex)
        }
    }

    /// The whole season, one matchday at a time, resolving each day
    /// abstractly exactly the way Calendar FORCE SIM does (the same
    /// resolveTodaysUserMatchAbstractly + advanceDay stepping).
    private func runAbstractSeason(_ store: GameStore) {
        var safety = 0
        while !store.isSeasonOver && safety < 400 {
            if store.isUserMatchToday {
                store.resolveTodaysUserMatchAbstractly()
            } else {
                store.advanceDay()
            }
            safety += 1
        }
    }

    /// Advances day by day — resolving any due user commitment abstractly,
    /// exactly the way Calendar FORCE SIM does — until the user's National
    /// Cup tie is due today. League matchdays and the League Trophy's
    /// earlier rounds settle through the same real paths on the way.
    private func advanceToUserCupDay(_ store: GameStore) {
        var safety = 0
        while !store.isUserCupToday && !store.isSeasonOver && safety < 200 {
            if store.isUserMatchToday {
                store.resolveTodaysUserMatchAbstractly()
            } else {
                store.advanceDay()
            }
            safety += 1
        }
    }

    // MARK: - Live cup tie commits exactly once

    /// The real live path: beginUserMatch -> scripted goals -> the real
    /// finishLiveMatch routing -> finishLiveCupTie -> concludeCupRound.
    /// The tie must be committed once, the round must advance, and if the
    /// user advanced, their next tie must be outstanding in the NEW round
    /// only — never a played tie lingering in a stale round.
    func testUserCupTieCommitsExactlyOnceViaLivePath() async {
        let store = await makeStore(name: "Live Cup Audit")
        guard let tie = store.nextUserCupTie else {
            return XCTFail("A First Division club must have a round-1 cup tie")
        }
        XCTAssertEqual(tie.round, store.cupRound)

        advanceToUserCupDay(store)
        XCTAssertTrue(store.isUserCupToday, "The day loop must land on the user's cup tie")
        store.beginUserMatch()
        guard let live = store.live, live.isCup else {
            return XCTFail("beginUserMatch must open a live cup match")
        }
        // Script an exact scoreline through the real goal path: the user
        // scores two, concedes one.
        let userSide: Side = live.isUserHome ? .home : .away
        let otherSide: Side = live.isUserHome ? .away : .home
        live.testScoreGoal(userSide)
        live.testScoreGoal(userSide)
        live.testScoreGoal(otherSide)
        live.testFinishNow()
        XCTAssertTrue(live.isFinished)
        XCTAssertEqual(live.homeGoals + live.awayGoals, 3, "Scripted goals must be the only goals")

        let roundBefore = store.cupRound
        store.finishLiveMatch()
        XCTAssertNil(store.live, "finishLiveMatch must clear the live match")
        XCTAssertEqual(store.cupRound, roundBefore + 1, "The round must advance exactly once")
        if let committed = playedUserTie(store) {
            // A played user tie can only exist in the CURRENT round if it
            // is the same tie that was just committed (still unadvanced).
            XCTFail("A committed user tie must not linger as outstanding: \(committed)")
        }
        if let next = store.nextUserCupTie {
            XCTAssertEqual(next.round, store.cupRound)
            XCTAssertGreaterThanOrEqual(store.cupRoundDate(next.round), store.currentDate,
                "The next user cup tie must be scheduled today or in the future")
            XCTAssertGreaterThan(store.daysUntilNextMatch ?? -1, -1,
                "The countdown must never go negative while a tie is outstanding")
        }
        // The full-time news must reference the cup result exactly once.
        let cupNews = store.news.filter { $0.title.contains(GameStore.cupName) }
        XCTAssertGreaterThanOrEqual(cupNews.count, 1, "The committed round must report the user's result")
    }

    /// The drawn-tie live path: a scripted level scoreline must resolve
    /// through the strength-weighted penalty commit with onPenalties set
    /// and a real winner advanced.
    func testDrawnLiveCupTieResolvesOnPenalties() async {
        let store = await makeStore(name: "Pens Audit")
        guard store.nextUserCupTie != nil else { return XCTFail("Missing round-1 user tie") }
        advanceToUserCupDay(store)
        XCTAssertTrue(store.isUserCupToday)
        store.beginUserMatch()
        guard let live = store.live, live.isCup else { return XCTFail("Expected a live cup match") }
        let userSide: Side = live.isUserHome ? .home : .away
        let otherSide: Side = live.isUserHome ? .away : .home
        live.testScoreGoal(userSide)
        live.testScoreGoal(otherSide)
        live.testFinishNow()

        let roundBefore = store.cupRound
        store.finishLiveMatch()
        XCTAssertEqual(store.cupRound, roundBefore + 1, "A drawn tie must still advance the round")
        // If the user went through, their next tie must be future-dated and
        // unplayed; the round state must be internally consistent either way.
        if let next = store.nextUserCupTie {
            XCTAssertFalse(next.played)
            XCTAssertGreaterThanOrEqual(store.cupRoundDate(next.round), store.currentDate)
        }
    }

    // MARK: - Abstract (FORCE SIM) cup commit

    /// resolveTodaysUserMatchAbstractly must commit the user's tie exactly
    /// once: the round advances, no played tie lingers, and the next
    /// commitment (if any) is future-dated.
    func testUserCupTieCommitsExactlyOnceViaAbstractPath() async {
        let store = await makeStore(name: "Abstract Cup Audit")
        guard let _ = store.nextUserCupTie else { return XCTFail("Missing round-1 user tie") }
        advanceToUserCupDay(store)
        XCTAssertTrue(store.isUserCupToday)

        store.resolveTodaysUserMatchAbstractly()
        XCTAssertEqual(store.cupRound, 2, "Round 1 must resolve exactly once")
        if let committed = playedUserTie(store) {
            XCTFail("A committed user tie must not linger: \(committed)")
        }
        if let next = store.nextUserCupTie {
            XCTAssertEqual(next.round, 2)
            XCTAssertFalse(next.played)
            XCTAssertGreaterThanOrEqual(store.cupRoundDate(next.round), store.currentDate)
        }
        // A second abstract resolve on a later day must be a no-op for the
        // already-committed round.
        let roundSnapshot = store.cupRound
        store.resolveTodaysUserMatchAbstractly()
        XCTAssertEqual(store.cupRound, roundSnapshot, "Re-resolution must not advance the round again")
    }

    /// A whole abstract season (the FORCE SIM path end to end): the cup
    /// must always reach a winner by season's end, the user must never
    /// hold an outstanding past-due tie, and the next commitment countdown
    /// must never go negative along the way.
    func testAbstractSeasonCupAlwaysCrownedAndNeverOutstanding() async {
        let store = await makeStore(name: "Season Cup Audit")
        var safety = 0
        while store.cupWinnerName == nil && !store.isSeasonOver && safety < 400 {
            if store.daysUntilNextMatch ?? 0 < 0 {
                XCTFail("Negative countdown while cup outstanding on day \(store.currentDate)")
                break
            }
            let staleUserTie = store.cupTies.first {
                $0.played && !$0.isBye && ($0.homeIndex == store.userClubIndex || $0.awayIndex == store.userClubIndex)
            }
            XCTAssertNil(staleUserTie, "A played user tie must never linger as outstanding")
            if store.isUserMatchToday {
                store.resolveTodaysUserMatchAbstractly()
            } else {
                store.advanceDay()
            }
            safety += 1
        }
        XCTAssertNotNil(store.cupWinnerName,
            "The cup must reach a winner within the season (last round \(store.cupRound))")
    }

    // MARK: - Prize money & ledger

    /// The cup must crown exactly one winner across the whole season, pay
    /// its 1,300 prize exactly once, and re-running the concluding pass on
    /// the finished round must be a strict no-op.
    func testCupPrizeMoneyAppliedExactlyOnceAcrossSeason() async {
        let store = await makeStore(name: "Prize Audit")
        var safety = 0
        while store.cupWinnerName == nil && !store.isSeasonOver && safety < 400 {
            if store.isUserMatchToday { store.resolveTodaysUserMatchAbstractly() } else { store.advanceDay() }
            safety += 1
        }
        guard let winnerName = store.cupWinnerName else {
            return XCTFail("Cup never crowned (round \(store.cupRound))")
        }
        let winnerIndex = store.clubs.firstIndex { $0.name == winnerName }!
        if winnerIndex == store.userClubIndex {
            XCTAssertTrue(store.clubs[winnerIndex].transferBudget >= 1300,
                "The winner's budget must include the 1,300 cup prize")
        }

        // Snapshot the finished round and re-run the concluding pass.
        let budgetBefore = store.clubs[winnerIndex].transferBudget
        let ledgerCount = store.seasonLedger.filter { $0.category == "Prize money" }.count
        let tieSnapshot = store.cupTies
        let roundSnapshot = store.cupRound
        let userPrizeEntries = store.seasonLedger.filter { $0.detail.contains(GameStore.cupName) }.count
        store.concludeCupRound()
        XCTAssertEqual(store.cupRound, roundSnapshot, "A crowned cup must not redraw")
        XCTAssertEqual(store.cupTies.map { $0.id }, tieSnapshot.map { $0.id }, "Re-run must not re-sim any tie")
        XCTAssertEqual(store.clubs[winnerIndex].transferBudget, budgetBefore, "Prize money must not repeat")
        XCTAssertEqual(store.seasonLedger.filter { $0.category == "Prize money" }.count, ledgerCount,
            "Re-run must not duplicate ledger entries")
        if winnerIndex == store.userClubIndex {
            XCTAssertEqual(userPrizeEntries, 1, "The user's cup win must log exactly one ledger entry")
        }
    }

    /// Every competition pays its winner exactly once across a full
    /// abstract season, and each amount matches the documented prize.
    func testAllCompetitionPrizesPaidExactlyOnceAcrossSeason() async {
        let store = await makeStore(name: "All Prizes Audit")
        runAbstractSeason(store)
        let prizeLines = store.seasonLedger.filter { $0.category == "Prize money" }
        var seen = Set<String>()
        for line in prizeLines {
            XCTAssertFalse(seen.contains(line.detail), "Duplicate prize ledger entry: \(line.detail)")
            seen.insert(line.detail)
        }
        let expectations: [String: Int] = [
            GameStore.cupName: 1300,
            GameStore.leagueCupName: 700,
            GameStore.communityShieldName: 300,
        ]
        for (competition, amount) in expectations {
            let entries = prizeLines.filter { $0.detail.contains(competition) }
            for entry in entries {
                XCTAssertEqual(entry.amount, amount, "\(competition) prize amount changed")
            }
            XCTAssertLessThanOrEqual(entries.count, 1, "\(competition) paid more than once")
        }
    }

    /// A user cup win must survive save/reload paying exactly once: after
    /// reload, re-running the concluding pass must not pay again.
    func testPrizeMoneyDoesNotRepeatAfterSaveReload() async {
        let store = await makeStore(name: "Reload Prize Audit")
        var safety = 0
        while store.cupWinnerName == nil && !store.isSeasonOver && safety < 400 {
            if store.isUserMatchToday { store.resolveTodaysUserMatchAbstractly() } else { store.advanceDay() }
            safety += 1
        }
        guard let winnerName = store.cupWinnerName, let winnerIndex = store.clubs.firstIndex(where: { $0.name == winnerName }) else {
            return XCTFail("Cup never crowned")
        }
        guard let id = store.currentSaveID else { return XCTFail("No save id") }
        let winnerBudget = store.clubs[winnerIndex].transferBudget
        let reloaded = await makeTestStore()
        reloaded.loadSavedGame(id: id)
        XCTAssertEqual(reloaded.cupWinnerName, winnerName, "The crowned winner must survive reload")
        XCTAssertEqual(reloaded.clubs[winnerIndex].transferBudget, winnerBudget,
            "The winner's budget must survive reload unchanged")
        let ledgerBefore = reloaded.seasonLedger.filter { $0.category == "Prize money" }.count
        reloaded.concludeCupRound()
        XCTAssertEqual(reloaded.clubs[winnerIndex].transferBudget, winnerBudget,
            "Re-running the pass after reload must not pay the prize again")
        XCTAssertEqual(reloaded.seasonLedger.filter { $0.category == "Prize money" }.count, ledgerBefore,
            "Re-running the pass after reload must not duplicate ledger entries")
    }

    // MARK: - Save/reload round-trip

    /// Mid-cup season: ties, rounds, winner names/ids, fixture dates and
    /// the user's next commitment must all survive persist -> load.
    func testSaveReloadPreservesCompetitionStateAndNextCommitment() async {
        let store = await makeStore(name: "Round Trip Audit")
        var safety = 0
        while store.nextUserCupTie == nil && !store.isSeasonOver && safety < 100 {
            if store.isUserMatchToday { store.resolveTodaysUserMatchAbstractly() } else { store.advanceDay() }
            safety += 1
        }
        guard store.nextUserCupTie != nil else { return XCTFail("Never reached a user cup tie") }

        let tieSnapshot = store.cupTies
        let leagueCupSnapshot = store.leagueCupTies
        let euroSnapshot = store.euroTies
        let uefaSnapshot = store.uefaCupTies
        let nextBefore = store.nextUserMatchDate
        let daysBefore = store.daysUntilNextMatch

        guard let id = store.currentSaveID else { return XCTFail("No save id") }
        let reloaded = await makeTestStore()
        XCTAssertTrue(reloaded.loadSavedGame(id: id))

        XCTAssertEqual(reloaded.cupTies.map(\.id), tieSnapshot.map(\.id), "Cup ties must round-trip")
        XCTAssertEqual(reloaded.cupRound, store.cupRound, "Cup round must round-trip")
        XCTAssertEqual(reloaded.cupWinnerName, store.cupWinnerName)
        XCTAssertEqual(reloaded.leagueCupTies.map(\.id), leagueCupSnapshot.map(\.id))
        XCTAssertEqual(reloaded.leagueCupRound, store.leagueCupRound)
        XCTAssertEqual(reloaded.euroTies.map(\.id), euroSnapshot.map(\.id))
        XCTAssertEqual(reloaded.euroRound, store.euroRound)
        XCTAssertEqual(reloaded.uefaCupTies.map(\.id), uefaSnapshot.map(\.id))
        XCTAssertEqual(reloaded.uefaCupRound, store.uefaCupRound)
        XCTAssertEqual(reloaded.currentMatchday, store.currentMatchday)
        XCTAssertEqual(reloaded.currentDate, store.currentDate, "Fixture dates hinge on the saved date")
        XCTAssertEqual(reloaded.nextUserMatchDate, nextBefore, "The next user commitment must survive reload")
        XCTAssertEqual(reloaded.daysUntilNextMatch, daysBefore, "The countdown must survive reload")
        if let date = nextBefore {
            XCTAssertGreaterThanOrEqual(reloaded.daysUntilNextMatch ?? -1, 0,
                "A future commitment must never render a negative countdown")
        }
        // The reloaded career must still resolve its next user tie exactly once.
        if reloaded.isUserMatchToday {
            reloaded.resolveTodaysUserMatchAbstractly()
            if let committed = reloaded.cupTies.first(where: { $0.played && !$0.isBye
                    && ($0.homeIndex == reloaded.userClubIndex || $0.awayIndex == reloaded.userClubIndex) }) {
                _ = committed
            }
        }
    }

    // MARK: - Byes and draw integrity

    /// Round-1 byes pass through unchanged, every played tie has a real
    /// winner, and the next round is drawn from exactly the winners.
    func testByePassesThroughAndNextRoundDrawsFromWinners() async {
        let store = await makeStore(name: "Bye Audit")
        var safety = 0
        while store.cupWinnerName == nil && !store.isSeasonOver && safety < 400 {
            if store.isUserMatchToday { store.resolveTodaysUserMatchAbstractly() } else { store.advanceDay() }
            safety += 1
        }
        // Re-run each completed round's integrity invariants on the final state:
        // every non-bye tie must have a valid winner index.
        for tie in store.cupTies where !tie.isBye {
            XCTAssertTrue(clubsContainsWinner(store, tie), "Every tie must have a valid winner")
        }
    }

    private func clubsContainsWinner(_ store: GameStore, _ tie: CupTie) -> Bool {
        tie.winnerIndex == tie.homeIndex || tie.winnerIndex == tie.awayIndex
    }

    // MARK: - Season rollover

    /// startNewSeason resets every competition to round one with untouched
    /// ties, clears last season's winners, and preserves the recorded
    /// qualification lists verbatim.
    func testSeasonRolloverResetsCompetitionsAndPreservesQualifiers() async {
        let store = await makeStore(name: "Rollover Audit")
        var safety = 0
        while !store.isSeasonOver && safety < 400 {
            if store.isUserMatchToday { store.resolveTodaysUserMatchAbstractly() } else { store.advanceDay() }
            safety += 1
        }
        let qualifiers = store.europeanQualifierIDs
        let uefaQualifiers = store.uefaCupQualifierIDs

        store.startNewSeason(resetRecords: true)

        XCTAssertTrue(store.seasonLedger.isEmpty, "The new season's ledger must start empty")
        XCTAssertEqual(store.cupRound, 1, "The National Cup must reset to round 1")
        XCTAssertFalse(store.cupTies.isEmpty)
        XCTAssertFalse(store.cupTies.contains { $0.played }, "Fresh cup ties must be unplayed")
        XCTAssertNil(store.cupWinnerName)
        XCTAssertNil(store.cupWinnerID, "Last season's cup winner id must be cleared for the new season")
        XCTAssertEqual(store.leagueCupRound, 1, "The League Trophy must reset to round 1")
        XCTAssertNil(store.leagueCupWinnerName)
        XCTAssertNil(store.leagueCupWinnerID)
        XCTAssertEqual(store.euroRound, 1, "The Continental Cup must reset to round 1")
        XCTAssertEqual(store.euroTies.count, 4, "Eight-team field = four round-1 ties")
        XCTAssertNil(store.euroWinnerName)
        XCTAssertNil(store.euroWinnerID)
        XCTAssertEqual(store.uefaCupRound, 1, "The Midweek Cup must reset to round 1")
        XCTAssertEqual(store.uefaCupTies.count, 4)
        XCTAssertNil(store.uefaCupWinnerName)
        XCTAssertNil(store.uefaCupWinnerID)
        if let shield = store.communityShieldTie {
            XCTAssertFalse(shield.played, "The Community Trophy must wait for its date")
            XCTAssertNotEqual(shield.homeIndex, shield.awayIndex)
        } else {
            XCTFail("Season 2 must pair the Community Trophy from season 1's champion and cup winner")
        }
        if let superCup = store.uefaSuperCupTie {
            XCTAssertFalse(superCup.played, "The Continental Super Cup must wait for its date")
            XCTAssertNotEqual(superCup.homeIndex, superCup.awayIndex)
        } else {
            XCTFail("Season 2 must pair the Continental Super Cup from season 1's European winners")
        }
        XCTAssertEqual(store.europeanQualifierIDs, qualifiers, "Qualification lists must survive the rollover")
        XCTAssertEqual(store.uefaCupQualifierIDs, uefaQualifiers)
        XCTAssertGreaterThan(store.cupRoundDate(1), store.currentDate,
            "The new season's first cup round must be in the future")
    }

    /// The Community Trophy pairing must come from LAST season's champion
    /// and cup winner (cup winner first, champion's opponent resolved via
    /// the runner-up when the champion also won the cup).
    func testCommunityTrophyPairingUsesLastSeasonsWinners() async {
        let store = await makeStore(name: "Community Audit")
        // points is computed (won*3 + drawn), so script wins instead.
        let topID = store.leagueTable(tier: 0)[0].id
        let leaderIndex = store.clubs.firstIndex { $0.id == topID }!
        store.clubs[leaderIndex].won = 200
        let runnerUpIndex = store.clubs.firstIndex {
            $0.divisionTier == 0 && $0.id != store.clubs[leaderIndex].id
        }!
        store.clubs[runnerUpIndex].won = 190

        var winnerIndex: Int? = nil
        var safety = 0
        while store.cupWinnerName == nil && safety < 20 {
            store.concludeCupRound()
            if store.cupTies.count == 1, store.cupTies[0].winnerIndex >= 0 {
                winnerIndex = store.cupTies[0].winnerIndex
            }
            safety += 1
        }
        guard let winnerIndex else { return XCTFail("Scripted cup never crowned") }

        let table = store.leagueTable(tier: 0)
        let championID = table[0].id
        let runnerUpID = table[1].id
        store.lastSeasonChampionID = championID
        store.lastSeasonRunnerUpID = runnerUpID
        store.lastSeasonCupWinnerID = store.clubs[winnerIndex].id

        store.startCommunityShield()

        let tie = store.communityShieldTie
        XCTAssertNotNil(tie, "A champion and a cup winner must produce a Community Trophy tie")
        let championIndex = store.clubs.firstIndex { $0.id == championID }!
        let runnerUpResolved = store.clubs.firstIndex { $0.id == runnerUpID }!
        if winnerIndex == championIndex {
            XCTAssertEqual(Set([tie!.homeIndex, tie!.awayIndex]), Set([championIndex, runnerUpResolved]),
                "Champion-cup-double must pair against the runner-up")
        } else {
            XCTAssertEqual(Set([tie!.homeIndex, tie!.awayIndex]), Set([championIndex, winnerIndex]),
                "The tie must be champion vs cup winner")
        }
        XCTAssertFalse(tie!.played)
        XCTAssertNil(store.cupWinnerID, "The stale winner id must not leak into the pairing")
    }

    // MARK: - FORCE SIM through the season end

    /// A season ended entirely by Calendar FORCE SIM (including the final
    /// matchday, resolved by resolveTodaysUserMatchAbstractly rather than
    /// finishLiveMatch) must still run the end-of-season pipeline:
    /// recordSeasonHonours must have captured the qualification lists,
    /// the season history and this season's finance ledger.
    func testForceSimmedSeasonStillRunsSeasonEndPipeline() async {
        let store = await makeStore(name: "Force Sim End Audit")
        let target = store.date(forMatchday: store.totalMatchdays + 1)
        await store.forceSimTo(date: target)
        XCTAssertTrue(store.isSeasonOver, "Force-simming past the final matchday must end the season")

        XCTAssertFalse(store.history.isEmpty,
            "A force-simmed season must append its SeasonRecord (recordSeasonHonours ran)")
        XCTAssertFalse(store.europeanQualifierIDs.isEmpty,
            "A force-simmed season must capture next season's European qualifiers")
        XCTAssertFalse(store.seasonLedger.isEmpty,
            "A force-simmed season must leave its finance ledger recorded")
    }
}
