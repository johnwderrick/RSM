import Foundation

/// The one lifecycle state an owned Legends player can occupy. Assignment to
/// the XI or bench is deliberately separate from this state: a signed reserve
/// remains an active career even when not selected for matchday.
enum LegendsOwnedPlayerState: String, Codable, Hashable {
    case unsigned = "UNSIGNED"
    case signed = "SIGNED"
    case retired = "RETIRED"
}

enum LegendsSquadAssignment: String, Codable, Hashable {
    case reserves = "RESERVES"
    case startingXI = "STARTING XI"
    case bench = "BENCH"
}

/// One authoritative owned career instance. `playerDefinitionID` points to
/// the static card definition; every mutable career fact remains in the
/// existing LegendsPlayerCareer record keyed by that same definition ID.
/// This registry supplies the missing ownership/state/acquisition boundary
/// without copying player objects into Library and Squad arrays.
struct LegendsOwnedPlayerRecord: Codable, Hashable, Identifiable {
    let careerID: String
    let playerDefinitionID: String
    var state: LegendsOwnedPlayerState
    var acquiredSeason: Int
    var acquisitionMethod: String
    var isNew: Bool

    var id: String { careerID }
}

extension LegendsStore {
    /// Reconciles the new registry with old saves. Existing career IDs are
    /// preserved; old activated/career records become signed, while owned
    /// cards with no career record remain unsigned and frozen.
    func migrateOwnedPlayerRecords() {
        var records = profile.ownedPlayerRecords.filter { !$0.value.playerDefinitionID.isEmpty }

        // Preserve records already written by the new schema exactly. This
        // makes migration idempotent and prevents stale legacy flags from
        // turning an explicitly unsigned player back into a signed one.
        // Duplicate current records are repaired deterministically; retired
        // history remains separate so a later pack can start a new generation.
        let currentDefinitions = Set(profile.ownedCardIDs)
        for definitionID in currentDefinitions {
            let current = records.values
                .filter { $0.playerDefinitionID == definitionID && $0.state != .retired }
                .sorted { $0.careerID < $1.careerID }
            if current.count > 1 {
                let keeper = current.sorted {
                    statePriority($0.state) != statePriority($1.state)
                        ? statePriority($0.state) > statePriority($1.state)
                        : $0.careerID < $1.careerID
                }.first!
                for duplicate in current where duplicate.careerID != keeper.careerID {
                    records.removeValue(forKey: duplicate.careerID)
                }
            }
            guard !records.values.contains(where: { $0.playerDefinitionID == definitionID && $0.state != .retired }) else { continue }

            // No new-schema record exists: infer state once from the old
            // save. Assignment, activation, or a career record means the
            // career had started; plain ownership remains unsigned.
            let assigned = profile.startingXICardIDs.contains(definitionID) || profile.benchCardIDs.contains(definitionID)
            let signed = assigned || profile.activatedCardIDs.contains(definitionID) || profile.playerCareers[definitionID] != nil
            let careerID = profile.playerCareers[definitionID]?.careerID ?? "legacy-\(definitionID)"
            records[careerID] = LegendsOwnedPlayerRecord(careerID: careerID,
                                                         playerDefinitionID: definitionID,
                                                         state: signed ? .signed : .unsigned,
                                                         acquiredSeason: profile.currentSeason,
                                                         acquisitionMethod: "LEGENDS SAVE MIGRATION",
                                                         isNew: false)
        }

        // Keep retired records reachable even when the definition is packed
        // again; each future active record gets a distinct career ID.
        for entry in profile.legendsHall where records[entry.id] == nil {
            records[entry.id] = LegendsOwnedPlayerRecord(careerID: entry.id,
                                                         playerDefinitionID: entry.cardID,
                                                         state: .retired,
                                                         acquiredSeason: entry.signedSeason,
                                                         acquisitionMethod: "COMPLETED CAREER",
                                                         isNew: false)
        }
        profile.ownedPlayerRecords = records
    }

    private func statePriority(_ state: LegendsOwnedPlayerState) -> Int {
        switch state {
        case .unsigned: return 0
        case .signed: return 1
        case .retired: return 2
        }
    }

    func registerAcquisition(cardID: String, method: String) {
        migrateOwnedPlayerRecords()
        guard !profile.ownedPlayerRecords.values.contains(where: { $0.playerDefinitionID == cardID && $0.state != .retired }) else {
            return
        }
        let careerID = UUID().uuidString
        profile.ownedPlayerRecords[careerID] = LegendsOwnedPlayerRecord(careerID: careerID,
                                                                          playerDefinitionID: cardID,
                                                                          state: .unsigned,
                                                                          acquiredSeason: profile.currentSeason,
                                                                          acquisitionMethod: method,
                                                                          isNew: true)
    }

    func ownedPlayerRecord(for card: LegendsCard) -> LegendsOwnedPlayerRecord? {
        migrateOwnedPlayerRecords()
        return profile.ownedPlayerRecords.values
            .filter { $0.playerDefinitionID == card.id }
            .sorted {
                if $0.state != $1.state { return statePriority($0.state) > statePriority($1.state) }
                return $0.careerID < $1.careerID
            }
            .first
    }

    func ownedPlayerState(for card: LegendsCard) -> LegendsOwnedPlayerState {
        if let record = ownedPlayerRecord(for: card) { return record.state }
        if profile.legendsHall.contains(where: { $0.cardID == card.id }) { return .retired }
        return profile.ownedCardIDs.contains(card.id) ? .unsigned : .unsigned
    }

    func isUnsigned(_ card: LegendsCard) -> Bool {
        ownedPlayerState(for: card) == .unsigned
    }

    func isSigned(_ card: LegendsCard) -> Bool {
        ownedPlayerState(for: card) == .signed && !isRetired(card)
    }

    func assignment(for card: LegendsCard) -> LegendsSquadAssignment {
        if profile.startingXICardIDs.contains(card.id) { return .startingXI }
        if profile.benchCardIDs.contains(card.id) { return .bench }
        return .reserves
    }

    var unsignedPlayers: [LegendsCard] {
        migrateOwnedPlayerRecords()
        return LegendsCardDatabase.all.filter { profile.ownedCardIDs.contains($0.id) && isUnsigned($0) }
    }

    var activeClubPlayers: [LegendsCard] {
        migrateOwnedPlayerRecords()
        return LegendsCardDatabase.all.filter { profile.ownedCardIDs.contains($0.id) && isSigned($0) }
    }

    var reservePlayers: [LegendsCard] {
        activeClubPlayers.filter { assignment(for: $0) == .reserves }
    }

    /// Starts a career without assigning the player to any matchday slot.
    /// This is the only normal unsigned → signed transition.
    @discardableResult
    func signPlayer(cardID: String) -> Bool {
        migrateOwnedPlayerRecords()
        guard profile.ownedCardIDs.contains(cardID),
              let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }),
              ownedPlayerState(for: card) == .unsigned else { return false }
        profile.activatedCardIDs.insert(cardID)
        startCareerIfNeeded(for: card)
        if let recordID = profile.ownedPlayerRecords.first(where: { $0.value.playerDefinitionID == cardID })?.key,
           var record = profile.ownedPlayerRecords[recordID] {
            record.state = .signed
            record.isNew = false
            profile.ownedPlayerRecords[recordID] = record
        }
        persist()
        return true
    }

    func markPlayerViewed(cardID: String) {
        migrateOwnedPlayerRecords()
        guard let recordID = profile.ownedPlayerRecords.first(where: { $0.value.playerDefinitionID == cardID })?.key,
              var record = profile.ownedPlayerRecords[recordID] else { return }
        record.isNew = false
        profile.ownedPlayerRecords[recordID] = record
        persist()
    }

    func markRetired(cardID: String) {
        migrateOwnedPlayerRecords()
        guard let recordID = profile.ownedPlayerRecords.first(where: { $0.value.playerDefinitionID == cardID })?.key,
              var record = profile.ownedPlayerRecords[recordID] else { return }
        record.state = .retired
        record.isNew = false
        profile.ownedPlayerRecords[recordID] = record
    }

    /// Production assignment is intentionally signed-only. Signing and
    /// matchday selection are separate irreversible lifecycle decisions.
    func ensureSignedForAssignment(cardID: String) -> Bool {
        guard let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else { return false }
        return isSigned(card)
    }
}
