//
//  PostMatchVerdictTests.swift
//  Retro Season ManagerTests
//
//  Pins the full-time presentation verdict — the outcome word, colour
//  and flavor line the redesigned overlay leads with — to the win /
//  draw / loss classification. Purely presentational: the overlay
//  derives it from the finished match, while `finishLiveMatch` keeps
//  its own authoritative result handling.
//

import XCTest
@testable import Retro_Season_Manager

final class PostMatchVerdictTests: XCTestCase {

    func testVerdictMapsWinDrawLoss() {
        XCTAssertEqual(PostMatchVerdict(won: true, drew: false), .win)
        XCTAssertEqual(PostMatchVerdict(won: false, drew: true), .draw)
        XCTAssertEqual(PostMatchVerdict(won: false, drew: false), .loss)
        // A win wins even if a draw flag were inconsistently set.
        XCTAssertEqual(PostMatchVerdict(won: true, drew: true), .win)
    }

    func testVerdictTitlesColorsAndFlavorsAreDistinct() {
        let verdicts: [PostMatchVerdict] = [.win, .draw, .loss]
        XCTAssertEqual(Set(verdicts.map { $0.title }), ["VICTORY", "DRAW", "DEFEAT"],
                       "Each verdict gets its own presentation word")
        XCTAssertEqual(Set(verdicts.map { $0.flavor }).count, 3,
                       "Each verdict gets its own flavor line")
        // The defeat must not reuse the accent/highlight hues the UI
        // reserves for good outcomes.
        XCTAssertNotEqual(PostMatchVerdict.loss.color, PostMatchVerdict.win.color)
        XCTAssertNotEqual(PostMatchVerdict.loss.color, PostMatchVerdict.draw.color)
    }
}
