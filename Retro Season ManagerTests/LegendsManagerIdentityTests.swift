import UIKit
import XCTest
@testable import Retro_Season_Manager

@MainActor
final class LegendsManagerIdentityTests: XCTestCase {
    /// The manager-creation flow shows the manager full-body. Every archetype
    /// must therefore ship both artwork assets, and the full-body art must be
    /// genuinely tall (aspect < 0.6) so the aspect-fit presentation displays
    /// the complete figure — regression guard for the confirmed cropping
    /// defect where a 0.63 card frame with scaledToFill cut ~24% of the body.
    func testEveryArchetypeShipsTallFullBodyArtworkForCreationFlow() throws {
        for archetype in LegendsManagerArchetype.allCases {
            let portrait = UIImage(named: archetype.portraitAsset)
            XCTAssertNotNil(portrait, "Missing portrait asset for \(archetype)")
            let fullBody = try XCTUnwrap(UIImage(named: archetype.fullBodyAsset),
                                         "Missing full-body asset for \(archetype)")
            let aspect = fullBody.size.width / fullBody.size.height
            XCTAssertLessThan(aspect, 0.6,
                              "\(archetype.fullBodyAsset) should be a tall full-body image; got aspect \(aspect)")
            XCTAssertGreaterThan(fullBody.size.height, portrait?.size.height ?? 0,
                                 "Full-body art should be taller than the portrait crop for \(archetype)")
        }
    }

    func testExactlyFiveArchetypesHaveDistinctIdentityData() {
        XCTAssertEqual(LegendsManagerArchetype.allCases.count, 5)
        XCTAssertEqual(Set(LegendsManagerArchetype.allCases.map(\.nickname)).count, 5)
        XCTAssertEqual(Set(LegendsManagerArchetype.allCases.map(\.trait)).count, 5)
        XCTAssertTrue(LegendsManagerArchetype.allCases.allSatisfy { !$0.description.isEmpty && !$0.formation.isEmpty })
    }

    func testNamesAcceptUnicodeApostrophesAndHyphensButRejectBlankOrPunctuation() {
        XCTAssertTrue(LegendsManagerIdentityValidation.validName("  José  "))
        XCTAssertTrue(LegendsManagerIdentityValidation.validName("O'Neill"))
        XCTAssertTrue(LegendsManagerIdentityValidation.validName("Anne-Marie"))
        XCTAssertEqual(LegendsManagerIdentityValidation.cleanName("  Anne   Marie "), "Anne Marie")
        XCTAssertFalse(LegendsManagerIdentityValidation.validName("   "))
        XCTAssertFalse(LegendsManagerIdentityValidation.validName("James!"))
    }

    func testManagerProfileRoundTripsWithoutDuplicatingLevelAndXP() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var profile = LegendsManagerProfile(firstName: "Alex", surname: "Morgan-Son", nationalityCode: "Scotland", dateOfBirth: date, archetype: .maverick)
        profile.reputation = 42
        profile.earnedNicknames.insert(.entertainer)
        profile.activeNickname = .entertainer
        profile.careerStats.matches = 12
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(LegendsManagerProfile.self, from: data)
        XCTAssertEqual(decoded, profile)
        XCTAssertEqual(decoded.archetype, .maverick)
        XCTAssertEqual(decoded.activeNickname, .entertainer)
    }

    func testNewStarterProfileNeedsIdentityButKeepsLegendsStateSeparate() throws {
        let starter = LegendsProfile.starter()
        XCTAssertNil(starter.managerProfile)
        XCTAssertEqual(starter.managerLevel, 1)
        XCTAssertEqual(starter.coins, 500)
        let data = try JSONEncoder().encode(starter)
        let decoded = try JSONDecoder().decode(LegendsProfile.self, from: data)
        XCTAssertNil(decoded.managerProfile)
        XCTAssertEqual(decoded.ownedCardIDs, starter.ownedCardIDs)
    }

    // MARK: - Manager identity editing

    /// Makes an established manager like the UI-test fixture, with a career
    /// the edit must never touch.
    private func establishedManager(archetype: LegendsManagerArchetype = .architect) -> LegendsManagerProfile {
        var manager = LegendsManagerProfile(firstName: "Alex", surname: "Ferguson",
                                            nationalityCode: "Scotland",
                                            dateOfBirth: Date(timeIntervalSince1970: 315_532_800),
                                            archetype: archetype)
        manager.reputation = 44
        manager.careerStats.matches = 37
        manager.careerStats.wins = 21
        manager.careerStats.promotions = 2
        manager.careerStats.trophies = 1
        manager.careerStats.packsOpened = 12
        manager.earnedNicknames = [.architect, .collector]
        manager.activeNickname = .architect
        return manager
    }

    /// An identity edit changes only identity fields; XP, level (stored on
    /// the LegendsProfile), statistics, reputation, earned nicknames and the
    /// active nickname are preserved. Progression state on the surrounding
    /// profile — coins, tokens, division, facilities, squad and reports —
    /// must also be untouched.
    func testIdentityEditChangesOnlyIdentityFields() throws {
        let store = LegendsStore()
        let before = store.profile
        store.profile.managerProfile = establishedManager()

        let changedDOB = Date(timeIntervalSince1970: 473_577_600)
        let changed = store.applyManagerIdentityEdit(firstName: "  José   Maria ", surname: "O'Neill-Gray",
                                                     nationalityCode: "Brazil",
                                                     dateOfBirth: changedDOB,
                                                     archetype: .maverick)
        XCTAssertTrue(changed)
        let manager = try XCTUnwrap(store.profile.managerProfile)
        XCTAssertEqual(manager.firstName, "José Maria")
        XCTAssertEqual(manager.surname, "O'Neill-Gray")
        XCTAssertEqual(manager.nationalityCode, "Brazil")
        XCTAssertEqual(manager.dateOfBirth, changedDOB)
        XCTAssertEqual(manager.archetype, .maverick)

        // Directly derived identity presentation follows the edit…
        XCTAssertEqual(manager.displayName, "José Maria O'Neill-Gray")
        // …but the new archetype's nickname/trait are NOT granted, and every
        // earned/progression field is untouched.
        XCTAssertEqual(manager.earnedNicknames, [.architect, .collector])
        XCTAssertEqual(manager.activeNickname, .architect)
        XCTAssertEqual(manager.reputation, 44)
        XCTAssertEqual(manager.careerStats, establishedManager().careerStats)
        XCTAssertEqual(store.profile.managerLevel, before.managerLevel)
        XCTAssertEqual(store.profile.managerXP, before.managerXP)
        XCTAssertEqual(store.profile.coins, before.coins)
        XCTAssertEqual(store.profile.packTokens, before.packTokens)
        XCTAssertEqual(store.profile.division, before.division)
        XCTAssertEqual(store.profile.ownedCardIDs, before.ownedCardIDs)
        XCTAssertEqual(store.profile.startingXICardIDs, before.startingXICardIDs)
        XCTAssertEqual(store.profile.facilityLevels, before.facilityLevels)
        XCTAssertEqual(store.profile.seasonReports, before.seasonReports)
    }

    /// Invalid edits must be rejected with no change to any field.
    func testInvalidIdentityEditsAreRejectedWithoutChange() {
        let store = LegendsStore()
        store.profile.managerProfile = establishedManager()
        let original = store.profile.managerProfile

        // Underage DOB (age 29 at 2026-01-01 would fail; this is age 20).
        XCTAssertFalse(store.applyManagerIdentityEdit(firstName: "Sam", surname: "Young",
                                                      nationalityCode: "Wales",
                                                      dateOfBirth: Date(timeIntervalSince1970: 1_467_331_200),
                                                      archetype: .architect))
        // Invalid surname (punctuation).
        XCTAssertFalse(store.applyManagerIdentityEdit(firstName: "Sam", surname: "Ferg!",
                                                      nationalityCode: "Wales",
                                                      dateOfBirth: Date(timeIntervalSince1970: 473_577_600),
                                                      archetype: .architect))
        XCTAssertEqual(store.profile.managerProfile, original, "A rejected edit must leave the stored manager untouched")
    }

    /// Re-applying the same confirmed edit is a no-op: idempotent, exactly
    /// the same manager, exactly the same profile.
    func testRepeatedEditApplicationsAreIdempotent() {
        let store = LegendsStore()
        store.profile.managerProfile = establishedManager()
        let dob = Date(timeIntervalSince1970: 473_577_600)

        XCTAssertTrue(store.applyManagerIdentityEdit(firstName: "Rita", surname: "Marley",
                                                     nationalityCode: "Brazil",
                                                     dateOfBirth: dob, archetype: .general))
        let onceManager = store.profile.managerProfile
        let onceProfile = store.profile
        for _ in 0..<3 {
            XCTAssertTrue(store.applyManagerIdentityEdit(firstName: "Rita", surname: "Marley",
                                                         nationalityCode: "Brazil",
                                                         dateOfBirth: dob, archetype: .general))
        }
        XCTAssertEqual(store.profile.managerProfile, onceManager)
        XCTAssertEqual(store.profile.managerLevel, onceProfile.managerLevel)
        XCTAssertEqual(store.profile.managerXP, onceProfile.managerXP)
        XCTAssertEqual(store.profile.coins, onceProfile.coins)
        XCTAssertEqual(store.profile.packTokens, onceProfile.packTokens)
        XCTAssertEqual(store.profile.division, onceProfile.division)
        XCTAssertEqual(store.profile.ownedCardIDs, onceProfile.ownedCardIDs)
        XCTAssertEqual(store.profile.facilityLevels, onceProfile.facilityLevels)
        XCTAssertEqual(store.profile.seasonReports, onceProfile.seasonReports)
    }

    /// With no manager created there is nothing to edit; the store method
    /// must refuse. (LegendsStore loads the one shared on-disk save, so the
    /// no-manager precondition is established explicitly rather than
    /// assumed from disk state left by another test.)
    func testEditWithoutManagerIsRefused() {
        let store = LegendsStore()
        store.profile.managerProfile = nil
        XCTAssertFalse(store.applyManagerIdentityEdit(firstName: "A", surname: "B",
                                                      nationalityCode: "England",
                                                      dateOfBirth: Date(timeIntervalSince1970: 473_577_600),
                                                      archetype: .strategist))
        XCTAssertNil(store.profile.managerProfile)
    }

    /// The edited manager (identity-only change) round-trips through the
    /// profile save format unchanged.
    func testEditedManagerRoundTripsThroughProfileSave() throws {
        let store = LegendsStore()
        store.profile.managerProfile = establishedManager()
        let dob = Date(timeIntervalSince1970: 473_577_600)
        XCTAssertTrue(store.applyManagerIdentityEdit(firstName: "Nova", surname: "Reyes",
                                                     nationalityCode: "Japan",
                                                     dateOfBirth: dob, archetype: .professor))
        let data = try JSONEncoder().encode(store.profile)
        let decoded = try JSONDecoder().decode(LegendsProfile.self, from: data)
        XCTAssertEqual(decoded.managerProfile, store.profile.managerProfile)
        XCTAssertEqual(decoded.managerProfile?.archetype, .professor)
        XCTAssertEqual(decoded.managerProfile?.careerStats, store.profile.managerProfile?.careerStats)
    }

    func testManagerAgeAndDateBounds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let age38 = calendar.date(from: DateComponents(year: 1988, month: 1, day: 1))!
        let age29 = calendar.date(from: DateComponents(year: 1997, month: 1, day: 1))!
        let age71 = calendar.date(from: DateComponents(year: 1955, month: 1, day: 1))!
        XCTAssertTrue(LegendsManagerIdentityValidation.validDateOfBirth(age38, now: now, calendar: calendar))
        XCTAssertFalse(LegendsManagerIdentityValidation.validDateOfBirth(age29, now: now, calendar: calendar))
        XCTAssertFalse(LegendsManagerIdentityValidation.validDateOfBirth(age71, now: now, calendar: calendar))
        XCTAssertEqual(LegendsManagerProfile(firstName: "A", surname: "B", nationalityCode: "England", dateOfBirth: age38, archetype: .architect).age(referenceDate: now, calendar: calendar), 38)
    }
}
