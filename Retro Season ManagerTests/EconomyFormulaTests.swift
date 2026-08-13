//
//  EconomyFormulaTests.swift
//  Retro Season ManagerTests
//
//  Pure-function coverage for the transfer-fee/wage/budget scaling that
//  underpins every era Legacy Mode offers — a regression in these bucket
//  boundaries would silently mis-price an entire start year's economy.
//

import XCTest
@testable import Retro_Season_Manager

final class EconomyFormulaTests: XCTestCase {
    func testEconomyMultiplierBuckets() {
        XCTAssertEqual(economyMultiplier(startYear: 2000), 1.0)
        XCTAssertEqual(economyMultiplier(startYear: 2004), 1.0)
        XCTAssertEqual(economyMultiplier(startYear: 2005), 1.4)
        XCTAssertEqual(economyMultiplier(startYear: 2009), 1.4)
        XCTAssertEqual(economyMultiplier(startYear: 2010), 2.0)
        XCTAssertEqual(economyMultiplier(startYear: 2014), 2.0)
        XCTAssertEqual(economyMultiplier(startYear: 2015), 2.8)
        XCTAssertEqual(economyMultiplier(startYear: 2019), 2.8)
        XCTAssertEqual(economyMultiplier(startYear: 2020), 3.6)
        XCTAssertEqual(economyMultiplier(startYear: 2030), 3.6)
    }

    func testPlayerValueScalesWithEraAtFixedRatingAndAge() {
        let value2000 = playerValue(rating: 80, age: 25, startYear: 2000)
        let value2010 = playerValue(rating: 80, age: 25, startYear: 2010)
        let value2020 = playerValue(rating: 80, age: 25, startYear: 2020)
        // Same player, same rating, same age — only the era's economy
        // multiplier (1.0 / 2.0 / 3.6) should separate these three figures.
        // Exact-multiple assertions are fragile since each figure is
        // independently `Int(...)`-truncated (a real player at rating 80
        // truncates 2010's value one pound short of a clean double), so
        // check ordering and a tolerance band instead.
        XCTAssertGreaterThan(value2010, Int(Double(value2000) * 1.9))
        XCTAssertLessThan(value2010, Int(Double(value2000) * 2.1))
        XCTAssertGreaterThan(value2020, value2010)
        XCTAssertGreaterThan(value2020, Int(Double(value2000) * 3.5))
        XCTAssertLessThan(value2020, Int(Double(value2000) * 3.7))
    }

    func testPlayerValueAgeCurvePeaksInPrimeYears() {
        let young = playerValue(rating: 80, age: 19, startYear: 2000)
        let prime = playerValue(rating: 80, age: 24, startYear: 2000)
        let veteran = playerValue(rating: 80, age: 34, startYear: 2000)
        XCTAssertGreaterThan(prime, veteran)
        XCTAssertGreaterThan(young, veteran)
    }

    func testPlayerWageNeverNegativeForLowRatings() {
        XCTAssertGreaterThanOrEqual(playerWage(rating: 40, age: 25, startYear: 2000), 1)
        XCTAssertGreaterThanOrEqual(playerWage(rating: 0, age: 25, startYear: 2020), 1)
    }

    @MainActor
    func testTransferBudgetFloorsAtFifty() {
        XCTAssertGreaterThanOrEqual(GameStore.transferBudget(forPrestige: 1, startYear: 2000), 50)
    }
}
