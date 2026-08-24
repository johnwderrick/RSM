//
//  LegendsStoreTestSupport.swift
//  Retro Season ManagerTests
//
//  Shared fixture helper for tests that populate `profile.ownedCardIDs`
//  directly rather than going through the real pack-opening/signing flow
//  (LegendsOwnedPlayers.swift). Production code intentionally keeps
//  "owned" and "signed" as separate steps — assign(cardID:toXISlot:) and
//  assign(cardID:toBenchSlot:) both require isSigned(_:), so a fixture
//  that only sets ownedCardIDs would have every assign() call silently
//  no-op. Call this right after setting ownedCardIDs in any test that
//  isn't itself specifically exercising the unsigned state (that gate
//  has its own dedicated coverage in LegendsOwnedPlayersTests.swift).
//

import Foundation
@testable import Retro_Season_Manager

@MainActor
extension LegendsStore {
    func signAllOwnedCardsForTesting() {
        // Clear first: `LegendsStore()` loads whatever's actually on disk
        // (xcodebuild test isn't sandboxed per-test — see the git-status
        // note in the project bible), so a stale `.retired` record left by
        // an earlier test's real persist() would otherwise outrank the
        // freshly-added `.signed` one below in ownedPlayerRecord(for:)'s
        // priority sort (retired > signed), silently keeping the card
        // unsignable no matter what this method does.
        profile.ownedPlayerRecords = [:]
        for cardID in profile.ownedCardIDs {
            let careerID = UUID().uuidString
            profile.ownedPlayerRecords[careerID] = LegendsOwnedPlayerRecord(
                careerID: careerID,
                playerDefinitionID: cardID,
                state: .signed,
                acquiredSeason: profile.currentSeason,
                acquisitionMethod: "test",
                isNew: false)
        }
        // Deliberately does NOT call startCareerIfNeeded(for:) — several
        // tests (e.g. LegendsAgingTests' "no career record" aging-penalty
        // path, testUnsignedCollectionCardStaysFrozenAndHasNoCareer) rely
        // on isSigned(_:) being true without a playerCareers entry existing.
        // A test that specifically needs the real signPlayer(cardID:) side
        // effects (starting the career) should call it directly instead of
        // this helper.
    }
}
