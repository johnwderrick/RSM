//
//  CareerFixtureCalendarTests.swift
//  Retro Season ManagerTests
//
//  Pins the DEBUG Career UI-test fixtures to a coherent calendar. The
//  shared navigation fixture must reach its matchday-4 state through
//  the real day loop, so any knockout round between matchdays 3 and 4
//  resolves the way a real CONTINUE tap resolves it. Teleporting past
//  the League Trophy's first round used to strand the user's live tie
//  in the past — the round processors only fire when the user has no
//  tie left, so a stale tie kept feeding `nextUserMatchDate` and the
//  dashboard counted down to a negative "Next match in -12 days".
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class CareerFixtureCalendarTests: XCTestCase {

    /// After the navigation fixture, the user's next commitment — the
    /// exact minimum the dashboard countdown renders — must be today or
    /// in the future, and the current League Trophy round must never
    /// hold an already-played user tie (the stranded-tie signature).
    func testNavigationFixtureLeavesNoPastDueUserCommitment() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerNavigationFixtureForDebug()

        XCTAssertFalse(store.isSeasonOver, "Fixture must not exhaust the season")
        XCTAssertEqual(store.currentMatchday, 4, "Fixture must stop on matchday 4")

        if let next = store.nextUserMatchDate {
            XCTAssertGreaterThanOrEqual(next, store.currentDate,
                "The user's next commitment must be today or in the future, never past-due")
        }

        let userIndex = store.userClubIndex
        let userLeagueCupTies = store.leagueCupTies.filter {
            !$0.isBye && ($0.homeIndex == userIndex || $0.awayIndex == userIndex)
        }
        // The user can be knocked out in round one, so the current round
        // need not contain a user tie. Any live tie that remains must be
        // scheduled for today or later, never stranded behind the clock.
        for tie in userLeagueCupTies where !tie.played {
            XCTAssertGreaterThanOrEqual(store.leagueCupRoundDate(tie.round), store.currentDate,
                "An unplayed user tie must never linger behind the current date")
        }
    }

    /// The pre-match fixture lands on a user match day, and the exact
    /// sequence the live-match UI suite drives — begin, skip to full
    /// time, CONTINUE's commit — must leave the next commitment in the
    /// future and let SKIP TO MATCH reach a real upcoming match.
    func testPreMatchFixtureStaysCoherentThroughFullTimeAndSkip() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.prepareCareerPreMatchFixtureForDebug(skipPrompts: true)

        XCTAssertTrue(store.isUserMatchToday, "Pre-match fixture must land on a user match day")
        XCTAssertTrue(store.isCupMatchDay || store.isUserLeagueToday,
                      "The match day must come from a real scheduled competition")

        store.beginUserMatch()
        store.live?.skipToEnd()
        store.finishLiveMatch()
        XCTAssertNil(store.live, "Full time must commit the match")

        if let next = store.nextUserMatchDate {
            XCTAssertGreaterThan(next, store.currentDate,
                "After full time the next commitment must be in the future")
        }

        // The SKIP TO MATCH fast-forward must reach a real upcoming match:
        // the day it lands on must be strictly after the post-match date
        // (new pending offers may legitimately interrupt the skip, so
        // retry past them the way repeated CONTINUE taps would).
        let postMatchDate = store.currentDate
        var attempts = 0
        while !store.isUserMatchToday && !store.isSeasonOver && attempts < 5 {
            await store.advanceToNextMatch()
            attempts += 1
        }
        XCTAssertTrue(store.isUserMatchToday || store.isSeasonOver,
                      "SKIP TO MATCH must reach a valid upcoming match")
        if store.isUserMatchToday {
            XCTAssertGreaterThan(store.currentDate, postMatchDate,
                                 "The reached match day must be strictly after the post-match date")
        }
    }
}
