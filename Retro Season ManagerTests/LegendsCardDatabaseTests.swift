//
//  LegendsCardDatabaseTests.swift
//  Retro Season ManagerTests
//
//  Guards the RSM Legends card database against the same class of
//  hand-authoring slip SquadDataIntegrityTests catches for Career Mode's
//  squads: a duplicate or out-of-range entry should fail here, not ship.
//

import XCTest
@testable import Retro_Season_Manager

final class LegendsCardDatabaseTests: XCTestCase {
    func testEveryCardHasAUniqueID() {
        let ids = LegendsCardDatabase.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate card IDs found in LegendsCardDatabase")
    }

    func testEveryCardHasAttributesInRange() {
        for card in LegendsCardDatabase.all {
            for (label, value) in [("overall", card.overall), ("pace", card.pace), ("shooting", card.shooting),
                                    ("passing", card.passing), ("dribbling", card.dribbling),
                                    ("defending", card.defending), ("physical", card.physical)] {
                XCTAssertTrue((1...99).contains(value), "\(card.id) has \(label)=\(value), expected 1...99")
            }
        }
    }

    func testEveryCardHasNonEmptyFlavorText() {
        for card in LegendsCardDatabase.all {
            XCTAssertFalse(card.name.trimmingCharacters(in: .whitespaces).isEmpty, "\(card.id) has an empty name")
            XCTAssertFalse(card.specialAbility.trimmingCharacters(in: .whitespaces).isEmpty, "\(card.id) has an empty special ability")
            XCTAssertFalse(card.biography.trimmingCharacters(in: .whitespaces).isEmpty, "\(card.id) has an empty biography")
        }
    }

    func testDatabaseCoversEveryEra() {
        let coveredEras = Set(LegendsCardDatabase.all.map(\.era))
        XCTAssertEqual(coveredEras, Set(LegendsEra.allCases), "Missing cards for: \(Set(LegendsEra.allCases).subtracting(coveredEras))")
    }

    /// Regression guard for a real gap: the original 40-card pass had 14
    /// strikers and exactly 1 goalkeeper, 0 left-backs and 0 right-backs
    /// — impossible to field a realistic XI in any formation. Every
    /// `DetailedPosition` a Starting XI slot can actually ask for needs
    /// real depth, not just one token card.
    func testEveryFieldedPositionHasRealDepth() {
        let minimumPerPosition = 2
        for position in DetailedPosition.allCases {
            let count = LegendsCardDatabase.all.filter { $0.position == position }.count
            XCTAssertGreaterThanOrEqual(count, minimumPerPosition, "\(position.rawValue) only has \(count) card(s)")
        }
    }
}
