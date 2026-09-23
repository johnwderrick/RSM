//
//  PlayerNationalityTests.swift
//  Retro Season Manager
//
//  Focused coverage for the authoritative `knownPlayerNationalities`
//  catalogue: every mapped player resolves through every creation path
//  (historical squads, marquee arrivals, foreign stars, transfer-market
//  copies, pending deals), the repair path is safe and idempotent, and
//  save/load round trips never alter identity or nationality.
//

import XCTest
@testable import Retro_Season_Manager

@MainActor
final class PlayerNationalityTests: XCTestCase {

    // MARK: - Catalogue integrity

    func testEveryCataloguedPlayerResolvesThroughMakePlayer() {
        XCTAssertGreaterThan(GameStore.knownPlayerNationalities.count, 200)
        // Every catalogued nationality must resolve through makePlayer, and
        // every non-home-nation flag must render (the pack has no England/
        // Scotland/Northern Ireland assets by design — those render blank).
        let flagless = Set(["England", "Scotland", "Northern Ireland"])
        let assets = Set(["Afghanistan", "Albania", "Algeria", "Andorra", "Angola",
            "Argentina", "Armenia", "Australia", "Austria", "Azerbaijan", "Bahrain",
            "Bangladesh", "Belarus", "Belgium", "Benin", "Bolivia", "BosniaandHerzegovina",
            "Botswana", "Brazil", "Brunei", "Bulgaria", "BurkinaFaso", "Burundi", "Cambodia",
            "Cameroon", "Canada", "CapeVerde", "CentralAfricanRepublic", "Chad", "Chile",
            "ChinaPR", "Colombia", "Comoros", "Congo", "CookIslands", "CostaRica",
            "CotedIvoire", "Croatia", "Cuba", "Cyprus", "Czechia", "DRCongo", "Denmark",
            "Djibouti", "DominicanRepublic", "Ecuador", "Egypt", "ElSalvador",
            "EquatorialGuinea", "Eritrea", "Estonia", "Eswatini", "Ethiopia", "Fiji",
            "Finland", "France", "Gabon", "Gambia", "Georgia", "Germany", "Ghana",
            "Gibraltar", "Greece", "Guatemala", "Guinea", "GuineaBissau", "Haiti",
            "Honduras", "HongKong", "Hungary", "Iceland", "India", "Indonesia", "Iran",
            "Iraq", "Ireland", "Israel", "Italy", "Jamaica", "Japan", "Jordan",
            "Kazakhstan", "Kenya", "KoreaRepublic", "Kuwait", "KyrgyzRepublic", "Laos",
            "Latvia", "Lebanon", "Liberia", "Libya", "Liechtenstein", "Lithuania",
            "Luxembourg", "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta",
            "Mauritania", "Mauritius", "Mexico", "Moldova", "Mongolia", "Montenegro",
            "Morocco", "Mozambique", "Myanmar", "Namibia", "Nepal", "Netherlands",
            "NewZealand", "Nicaragua", "Niger", "Nigeria", "NorthMacedonia", "Norway",
            "Oman", "Palestine", "Panama", "Paraguay", "Peru", "Philippines", "Poland",
            "Portugal", "Qatar", "RepublicofIreland", "Romania", "Russia", "Rwanda",
            "SaudiArabia", "Senegal", "Serbia", "Seychelles", "SierraLeone", "Singapore",
            "Slovakia", "Slovenia", "SouthAfrica", "SouthSudan", "Spain", "SriLanka",
            "Sudan", "Sweden", "Switzerland", "Syria", "Tajikistan", "Tanzania",
            "Thailand", "Togo", "Tunisia", "Turkiye", "UAE", "USA", "Uganda", "Ukraine",
            "Uruguay", "Uzbekistan", "Vanuatu", "Venezuela", "Wales", "Zambia"])
        let aliases = ["Czech Republic": "Czechia", "Ivory Coast": "Cote d'Ivoire"]
        for (name, nationality) in GameStore.knownPlayerNationalities {
            let player = GameStore.makePlayer(name: name, position: .midfielder,
                                              age: 27, rating: 80)
            XCTAssertEqual(player.nationality, nationality,
                           "\(name) must resolve through the catalogue")
            if flagless.contains(nationality) { continue }
            let slug = (aliases[nationality] ?? nationality).filter { $0.isLetter || $0.isNumber }
            XCTAssertTrue(assets.contains(slug),
                          "\(name) maps to \(nationality) which has no flag asset (\(slug))")
        }
    }

    func testCollidingNamesAreDeliberatelyAbsent() {
        // These fictional names describe *different* real players in
        // different rosters, so the name-keyed catalogue must not map them.
        for name in ["Thiago Cerezo", "Jose Alvarenga", "James Marshall",
                     "Manuel Salaberri"] {
            XCTAssertNil(GameStore.knownPlayerNationalities[name],
                         "\(name) is shared by different real players and must stay unmapped")
        }
    }

    // MARK: - Multi-era consistency

    /// Continuity players keep the same fictional name as they age across
    /// the 2000/2010/2020 starts; the catalogue (keyed by name) must give
    /// them one nationality in every era.
    func testMultiEraContinuityPlayersResolveInEveryEra() {
        let continuity: [(club: String, name: String, nationality: String)] = [
            ("Bernabéu Whites", "Cristiano Renaldo", "Portugal"),
            ("Camp Blaugrana", "Lionel Mesi", "Argentina"),
            ("White Hart Athletic", "Gareth Baile", "Wales"),
        ]
        for year in [2010, 2020] {
            for entry in continuity {
                let squad = GameStore.makeSquad(name: entry.club, prestige: 80, startYear: year)
                XCTAssertEqual(squad.first { $0.name == entry.name }?.nationality,
                               entry.nationality, "\(entry.name) in \(year)")
            }
        }
    }

    // MARK: - Creation paths

    func testHistoricalSquadCreationUsesCatalogue() {
        let expectations: [(club: String, year: Int, name: String, nationality: String)] = [
            ("Old Trafford Reds", 2000, "Roy Cahill", "Republic of Ireland"),
            ("Old Trafford Reds", 2000, "Ian Castellan", "Netherlands"),
            ("Highbury", 2000, "Thierry Almeida", "France"),
            ("Highbury", 2000, "Patrick Amara", "France"),
            ("Highbury", 2000, "Dennis Verhoeven", "Netherlands"),
            ("San Siro Rossoneri", 2010, "Andrea Pirlio", "Italy"),
        ]
        for entry in expectations {
            let squad = GameStore.makeSquad(name: entry.club, prestige: 80, startYear: entry.year)
            XCTAssertEqual(squad.first { $0.name == entry.name }?.nationality,
                           entry.nationality, "\(entry.name) in \(entry.year)")
        }
    }

    func testMarqueeArrivalsUseCatalogue() {
        for arrival in MarqueePlayers.arrivals {
            XCTAssertEqual(GameStore.knownPlayerNationalities[arrival.name], arrival.nationality,
                           arrival.name)
            let player = GameStore.makePlayer(name: arrival.name,
                                              position: arrival.detailedPosition.broad,
                                              detailedPosition: arrival.detailedPosition,
                                              secondaryPositions: arrival.secondaryPositions,
                                              nationality: arrival.nationality,
                                              age: arrival.age, rating: arrival.rating)
            XCTAssertEqual(player.nationality, arrival.nationality, arrival.name)
        }
    }

    func testForeignStarsUseCatalogue() {
        var club = Club(name: "Tiber Reds", shortName: "TIB",
                        players: GameStore.makeSquad(prestige: 72, startYear: 2000))
        GameStore.applyForeignStars(to: &club)
        XCTAssertEqual(club.players.first { $0.name == "Francesco Amadori" }?.nationality, "Italy")
        XCTAssertEqual(club.players.first { $0.name == "Gabriel Ordoñez" }?.nationality, "Argentina")
    }

    // MARK: - Repair path

    func testExistingSaveCorrectsKnownPlayerWithWrongNationality() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.newGame(clubIndex: 0, managerName: "Repair Tester")
        var known = GameStore.makePlayer(name: "Andrea Pirlio", position: .midfielder,
                                         age: 24, rating: 90)
        known.nationality = "Portugal" // wrong on purpose
        let knownID = known.id
        store.clubs[0].players[0] = known

        XCTAssertTrue(store.repairKnownPlayerNationalities())
        XCTAssertEqual(store.clubs[0].players[0].id, knownID)
        XCTAssertEqual(store.clubs[0].players[0].nationality, "Italy")
        XCTAssertFalse(store.repairKnownPlayerNationalities(),
                       "Repair must be idempotent")
    }

    func testRepairPropagatesToMarketAndPendingDealCopies() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.newGame(clubIndex: 0, managerName: "Copy Tester")
        var known = GameStore.makePlayer(name: "Kylian Mbape", position: .forward,
                                         age: 21, rating: 91)
        known.nationality = "England" // wrong on purpose
        let knownID = known.id
        store.clubs[1].players[0] = known
        store.transferMarket = [
            TransferTarget(player: known, sellingClubIndex: 1, askingPrice: 2_000),
        ]
        store.pendingTransferDeals = [
            PendingTransferDeal(id: UUID(), player: known, sellingClubIndex: 1,
                                sellingClubName: store.clubs[1].name, agreedFee: 2_000,
                                sellOnPercentage: 0, buyBackFee: 0,
                                includedPlayerID: nil, includedPlayerName: nil,
                                readyDate: store.currentDate),
        ]

        XCTAssertTrue(store.repairKnownPlayerNationalities())
        let repaired = GameStore.knownPlayerNationalities["Kylian Mbape"] ?? ""
        XCTAssertEqual(store.clubs[1].players[0].nationality, repaired)
        XCTAssertEqual(store.transferMarket[0].player.nationality, repaired)
        XCTAssertEqual(store.pendingTransferDeals[0].player.nationality, repaired)
        // Identity untouched everywhere.
        XCTAssertEqual(store.clubs[1].players[0].id, knownID)
        XCTAssertEqual(store.transferMarket[0].player.id, knownID)
        XCTAssertEqual(store.pendingTransferDeals[0].player.id, knownID)
    }

    func testRepeatedSaveLoadCyclesPreserveRepairedNationalityAndIdentity() async throws {
        let store = await Task { @MainActor in GameStore() }.value
        store.newGame(clubIndex: 0, managerName: "Roundtrip Tester")
        guard let saveID = store.currentSaveID else {
            XCTFail("newGame() did not set currentSaveID")
            return
        }
        defer { GameStore.deleteSave(id: saveID) }
        var known = GameStore.makePlayer(name: "Andrea Pirlio", position: .midfielder,
                                         age: 24, rating: 90)
        known.nationality = "England" // wrong on purpose
        let knownID = known.id
        let originalRating = known.rating
        store.clubs[0].players[0] = known
        XCTAssertTrue(store.repairKnownPlayerNationalities())
        let repaired = store.clubs[0].players[0].nationality
        XCTAssertEqual(repaired, "Italy")

        // newGame() wrote the pre-injection squad, so persist the repaired
        // squad explicitly; loadSavedGame(id:) then re-reads the same slot.
        store.persist()
        for _ in 0..<3 {
            let reloaded = await Task { @MainActor in GameStore() }.value
            XCTAssertTrue(reloaded.loadSavedGame(id: saveID))
            let player = try XCTUnwrap(reloaded.clubs[0].players.first { $0.id == knownID })
            XCTAssertEqual(player.nationality, repaired)
            XCTAssertEqual(player.rating, originalRating)
            XCTAssertFalse(reloaded.repairKnownPlayerNationalities(),
                           "Round trips must not reopen the repair")
        }
    }

    // MARK: - Identity safety

    func testRepairChangesNothingButNationality() async {
        let store = await Task { @MainActor in GameStore() }.value
        store.newGame(clubIndex: 0, managerName: "Identity Tester")
        var known = GameStore.makePlayer(name: "Robert Lewandowsky", position: .forward,
                                         age: 21, rating: 85)
        known.nationality = "England" // wrong on purpose
        let before = known
        store.clubs[0].players[0] = known
        XCTAssertTrue(store.repairKnownPlayerNationalities())
        let after = store.clubs[0].players[0]
        XCTAssertEqual(after.id, before.id)
        XCTAssertEqual(after.name, before.name)
        XCTAssertEqual(after.position, before.position)
        XCTAssertEqual(after.age, before.age)
        XCTAssertEqual(after.rating, before.rating)
        XCTAssertEqual(after.value, before.value)
        XCTAssertEqual(after.wage, before.wage)
        XCTAssertEqual(after.contractYears, before.contractYears)
    }
}
