//
//  LegendsStore+Squad.swift
//  Retro Season Manager
//
//  Squad Builder logic (Phase 5) — Starting XI, Bench, Captain and
//  Formation. Chemistry (Phase 6) is deliberately not computed here.
//  Reuses Career Mode's own Formation/DetailedPosition.expected(...)
//  rather than inventing a parallel formation system.
//

import Foundation

extension LegendsStore {
    var formation: Formation {
        Formation.all.first { $0.name == profile.formationName } ?? Formation.all[0]
    }

    /// The Starting XI's slot roles, in the same order as
    /// `profile.startingXICardIDs` — goalkeeper first, then the defense,
    /// midfield and attack rows, derived the same way Career Mode's own
    /// `PitchView` derives them from a `Formation`.
    var startingXISlots: [DetailedPosition] {
        let f = formation
        var slots: [DetailedPosition] = [.goalkeeper]
        for i in 0..<f.defenders {
            slots.append(.expected(for: .defender, indexInRow: i, rowCount: f.defenders))
        }
        for i in 0..<f.midfielders {
            slots.append(.expected(for: .midfielder, indexInRow: i, rowCount: f.midfielders, wideIsWinger: f.wideMidfieldersAreWingers))
        }
        for i in 0..<f.forwards {
            slots.append(.expected(for: .forward, indexInRow: i, rowCount: f.forwards))
        }
        return slots
    }

    /// Switches formation, resizing `startingXICardIDs` to match — cards
    /// beyond the new slot count move to the bench (space permitting)
    /// rather than being dropped from the squad outright.
    func setFormation(_ name: String) {
        guard Formation.all.contains(where: { $0.name == name }) else { return }
        profile.formationName = name
        let newCount = startingXISlots.count
        if profile.startingXICardIDs.count > newCount {
            let overflow = profile.startingXICardIDs[newCount...].compactMap { $0 }
            profile.startingXICardIDs = Array(profile.startingXICardIDs.prefix(newCount))
            for cardID in overflow {
                if let emptyBench = profile.benchCardIDs.firstIndex(where: { $0 == nil }) {
                    profile.benchCardIDs[emptyBench] = cardID
                } else if profile.captainCardID == cardID {
                    profile.captainCardID = nil
                }
            }
        } else if profile.startingXICardIDs.count < newCount {
            profile.startingXICardIDs += Array(repeating: nil, count: newCount - profile.startingXICardIDs.count)
        }
        persist()
    }

    /// Removes a card from wherever it currently sits in the squad (XI
    /// or bench) — every assignment goes through this first so the same
    /// card can never occupy two slots at once.
    private func removeFromSquad(_ cardID: String) {
        for i in profile.startingXICardIDs.indices where profile.startingXICardIDs[i] == cardID {
            profile.startingXICardIDs[i] = nil
        }
        for i in profile.benchCardIDs.indices where profile.benchCardIDs[i] == cardID {
            profile.benchCardIDs[i] = nil
        }
    }

    func assign(cardID: String, toXISlot index: Int) {
        guard profile.ownedCardIDs.contains(cardID), profile.startingXICardIDs.indices.contains(index) else { return }
        removeFromSquad(cardID)
        profile.startingXICardIDs[index] = cardID
        persist()
    }

    func assign(cardID: String, toBenchSlot index: Int) {
        guard profile.ownedCardIDs.contains(cardID), profile.benchCardIDs.indices.contains(index) else { return }
        removeFromSquad(cardID)
        profile.benchCardIDs[index] = cardID
        persist()
    }

    func clearXISlot(_ index: Int) {
        guard profile.startingXICardIDs.indices.contains(index) else { return }
        if profile.startingXICardIDs[index] == profile.captainCardID { profile.captainCardID = nil }
        profile.startingXICardIDs[index] = nil
        persist()
    }

    func clearBenchSlot(_ index: Int) {
        guard profile.benchCardIDs.indices.contains(index) else { return }
        profile.benchCardIDs[index] = nil
        persist()
    }

    /// The captain must be a Starting XI player — the UI only offers the
    /// option there, but this guards the invariant regardless.
    func setCaptain(cardID: String?) {
        guard cardID == nil || profile.startingXICardIDs.contains(cardID) else { return }
        profile.captainCardID = cardID
        persist()
    }

    /// Average effective overall across a filled Starting XI, rounded to
    /// the nearest whole rating; 0 with any slot still empty, matching
    /// the home screen's existing "—" placeholder for an unset squad.
    var currentTeamRating: Int {
        let ids = profile.startingXICardIDs.compactMap { $0 }
        guard ids.count == startingXISlots.count, !ids.isEmpty else { return 0 }
        let cards = ids.compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
        guard cards.count == ids.count else { return 0 }
        let total = cards.reduce(0) { $0 + effectiveOverall(for: $1) }
        return Int((Double(total) / Double(cards.count)).rounded())
    }
}
