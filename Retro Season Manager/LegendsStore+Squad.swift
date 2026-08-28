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

/// Presentation-only controls for the Player Library. Keeping these
/// value types outside the view makes filtering/sorting deterministic and
/// easy to exercise without rendering SwiftUI.
enum LegendsLibrarySort: String, CaseIterable, Identifiable {
    case rating = "RATING"
    case name = "NAME"
    case age = "AGE"
    case position = "POSITION"
    case projectedPrime = "PRIME AGE"
    case profile = "PROFILE"
    case careerStage = "CAREER STAGE"
    case seasonsAtClub = "SEASONS AT CLUB"
    case retirement = "RETIREMENT"
    case favourite = "FAVOURITES"
    case rarity = "RARITY"

    var id: String { rawValue }
}

enum LegendsLibraryGroup: String, CaseIterable, Identifiable {
    case none = "ALL CARDS"
    case player = "BY PLAYER"
    case position = "BY POSITION"

    var id: String { rawValue }
}

struct LegendsLibraryQuery {
    var position: DetailedPosition?
    var rarity: LegendsRarity?
    var era: LegendsEra?
    var sort: LegendsLibrarySort
    var group: LegendsLibraryGroup
    var searchText: String
    var signed: Bool?
    var favouriteOnly: Bool
    var duplicateOnly: Bool
    var finalSeasonOnly: Bool
    var minimumOverall: Int?
    var maximumOverall: Int?

    nonisolated init(position: DetailedPosition? = nil,
                     rarity: LegendsRarity? = nil,
                     era: LegendsEra? = nil,
                     sort: LegendsLibrarySort = .rating,
                     group: LegendsLibraryGroup = .none,
                     searchText: String = "",
                     signed: Bool? = nil,
                     favouriteOnly: Bool = false,
                     duplicateOnly: Bool = false,
                     finalSeasonOnly: Bool = false,
                     minimumOverall: Int? = nil,
                     maximumOverall: Int? = nil) {
        self.position = position
        self.rarity = rarity
        self.era = era
        self.sort = sort
        self.group = group
        self.searchText = searchText
        self.signed = signed
        self.favouriteOnly = favouriteOnly
        self.duplicateOnly = duplicateOnly
        self.finalSeasonOnly = finalSeasonOnly
        self.minimumOverall = minimumOverall
        self.maximumOverall = maximumOverall
    }
}

extension LegendsStore {
    func libraryCards(query: LegendsLibraryQuery = LegendsLibraryQuery(),
                      excludingActive: Bool = true) -> [LegendsCard] {
        let signedIDs = profile.activatedCardIDs
        let search = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = LegendsCardDatabase.all.filter { card in
            profile.ownedCardIDs.contains(card.id)
                && (!excludingActive || !signedIDs.contains(card.id))
                && !isRetired(card)
                && (query.signed == nil || query.signed == signedIDs.contains(card.id))
                && (!query.favouriteOnly || profile.favouriteCardIDs.contains(card.id))
                && (!query.duplicateOnly || isExactDuplicate(card))
                && (!query.finalSeasonOnly || isFinalSeason(card))
                && (query.minimumOverall == nil || effectiveOverall(for: card) >= query.minimumOverall!)
                && (query.maximumOverall == nil || effectiveOverall(for: card) <= query.maximumOverall!)
                && (query.position == nil || canPlay(card, in: query.position!))
                && (query.rarity == nil || card.rarity == query.rarity!)
                && (query.era == nil || card.era == query.era!)
                && (search.isEmpty || card.name.lowercased().contains(search)
                    || card.club.lowercased().contains(search)
                    || card.nation.lowercased().contains(search))
        }
        return filtered.sorted { lhs, rhs in
            switch query.sort {
            case .rating:
                let left = effectiveOverall(for: lhs)
                let right = effectiveOverall(for: rhs)
                return left != right ? left > right : lhs.name < rhs.name
            case .name:
                return lhs.name != rhs.name ? lhs.name < rhs.name : lhs.season < rhs.season
            case .age:
                let left = effectiveAge(for: lhs)
                let right = effectiveAge(for: rhs)
                return left != right ? left < right : lhs.name < rhs.name
            case .position:
                return lhs.position.rawValue != rhs.position.rawValue ? lhs.position.rawValue < rhs.position.rawValue : lhs.name < rhs.name
            case .projectedPrime:
                let left = profile.playerCareers[lhs.id]?.peakStartAge ?? lhs.age
                let right = profile.playerCareers[rhs.id]?.peakStartAge ?? rhs.age
                return left != right ? left < right : lhs.name < rhs.name
            case .profile:
                let left = profile.playerCareers[lhs.id]?.lifecycleProfile.rawValue ?? "UNSIGNED"
                let right = profile.playerCareers[rhs.id]?.lifecycleProfile.rawValue ?? "UNSIGNED"
                return left != right ? left < right : lhs.name < rhs.name
            case .careerStage:
                let left = profile.playerCareers[lhs.id].map { _ in playerCareerStage(for: lhs) } ?? "UNSIGNED"
                let right = profile.playerCareers[rhs.id].map { _ in playerCareerStage(for: rhs) } ?? "UNSIGNED"
                return left != right ? left < right : lhs.name < rhs.name
            case .seasonsAtClub:
                let left = profile.playerCareers[lhs.id]?.appearances ?? 0
                let right = profile.playerCareers[rhs.id]?.appearances ?? 0
                return left != right ? left > right : lhs.name < rhs.name
            case .retirement:
                let left = profile.playerCareers[lhs.id].map { $0.intendedRetirementAge - effectiveAge(for: lhs) } ?? Int.max
                let right = profile.playerCareers[rhs.id].map { $0.intendedRetirementAge - effectiveAge(for: rhs) } ?? Int.max
                return left != right ? left < right : lhs.name < rhs.name
            case .favourite:
                let left = profile.favouriteCardIDs.contains(lhs.id)
                let right = profile.favouriteCardIDs.contains(rhs.id)
                return left != right ? left && !right : lhs.name < rhs.name
            case .rarity:
                return lhs.rarity.tier != rhs.rarity.tier ? lhs.rarity.tier > rhs.rarity.tier : lhs.name < rhs.name
            }
        }
    }

    func libraryGroups(query: LegendsLibraryQuery = LegendsLibraryQuery()) -> [(key: String, cards: [LegendsCard])] {
        let cards = libraryCards(query: query)
        guard query.group != .none else { return [(key: "ALL CARDS", cards: cards)] }
        let grouped = Dictionary(grouping: cards) { card in
            switch query.group {
            case .player: return card.name
            case .position: return card.position.broad.rawValue
            case .none: return "ALL CARDS"
            }
        }
        return grouped.keys.sorted().map { key in
            (key: key, cards: grouped[key] ?? [])
        }
    }
}

/// A single position in the squad — either a Starting XI index or a bench
/// index — used to identify the two sides of a drag-and-drop swap on the
/// Squad screen.
enum LegendsSquadSlot: Hashable {
    case xi(Int)
    case bench(Int)

    /// A plain string encoding for drag payloads (`.onDrag`/`.onDrop` move
    /// data as `NSItemProvider` text, not typed Swift values).
    var dragString: String {
        switch self {
        case .xi(let i): return "xi:\(i)"
        case .bench(let i): return "bench:\(i)"
        }
    }

    init?(dragString: String) {
        let parts = dragString.split(separator: ":")
        guard parts.count == 2, let index = Int(parts[1]) else { return nil }
        switch parts[0] {
        case "xi": self = .xi(index)
        case "bench": self = .bench(index)
        default: return nil
        }
    }
}

extension LegendsStore {
    var formation: Formation {
        Formation.all.first { $0.name == profile.formationName } ?? Formation.all[0]
    }

    /// The Starting XI's slot roles, in the same order as
    /// `profile.startingXICardIDs` — goalkeeper first, then the defense,
    /// midfield and attack rows, derived the same way Career Mode's own
    /// `PitchView` derives them from a `Formation`.
    var startingXISlots: [DetailedPosition] {
        formation.slotRoles()
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
    /// card can never occupy two slots at once. Also clears out any
    /// *other* card that shares this one's `name`: several cards in the
    /// database are different seasons of the same real-ish player (e.g.
    /// "L. Miessi" 2005/06 and 2011/12), and only one version of a given
    /// player is allowed in the squad at once, same as any collectible
    /// card game — you can't field two seasons of the same person.
    private func removeFromSquad(_ cardID: String) {
        let name = LegendsCardDatabase.all.first { $0.id == cardID }?.name
        func matches(_ otherID: String?) -> Bool {
            guard let otherID else { return false }
            if otherID == cardID { return true }
            guard let name else { return false }
            return LegendsCardDatabase.all.first { $0.id == otherID }?.name == name
        }
        for i in profile.startingXICardIDs.indices where matches(profile.startingXICardIDs[i]) {
            if profile.startingXICardIDs[i] == profile.captainCardID { profile.captainCardID = nil }
            profile.startingXICardIDs[i] = nil
        }
        for i in profile.benchCardIDs.indices where matches(profile.benchCardIDs[i]) {
            profile.benchCardIDs[i] = nil
        }
    }

    /// Whether a card is a natural fit for a detailed formation slot.
    /// Pickers use this to avoid presenting players who cannot play the
    /// position being replaced.
    func canPlay(_ card: LegendsCard, in slot: DetailedPosition) -> Bool {
        if card.position == slot { return true }
        return card.position.relatedRoles.contains(slot)
    }

    /// A retired card (LegendsStore+Aging.swift) can't be fielded — the
    /// whole point of retirement is forcing a replacement, not letting
    /// the same aged-out card just get reassigned straight back in.
    private func isAssignable(_ cardID: String) -> Bool {
        guard profile.ownedCardIDs.contains(cardID), let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }) else { return false }
        return !isRetired(card)
    }

    func assign(cardID: String, toXISlot index: Int) {
        guard isAssignable(cardID), profile.startingXICardIDs.indices.contains(index),
              let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }), isSigned(card) else { return }
        removeFromSquad(cardID)
        profile.startingXICardIDs[index] = cardID
        profile.activatedCardIDs.insert(cardID)
        persist()
    }

    func assign(cardID: String, toBenchSlot index: Int) {
        guard isAssignable(cardID), profile.benchCardIDs.indices.contains(index),
              let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }), isSigned(card) else { return }
        removeFromSquad(cardID)
        profile.benchCardIDs[index] = cardID
        profile.activatedCardIDs.insert(cardID)
        persist()
    }

    func moveToReserves(cardID: String) {
        guard let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }), isSigned(card) else { return }
        for index in profile.startingXICardIDs.indices where profile.startingXICardIDs[index] == cardID {
            if profile.captainCardID == cardID { profile.captainCardID = nil }
            profile.startingXICardIDs[index] = nil
        }
        for index in profile.benchCardIDs.indices where profile.benchCardIDs[index] == cardID {
            profile.benchCardIDs[index] = nil
        }
        persist()
    }

    func assignToStartingXI(cardID: String, slot index: Int) -> Bool {
        guard let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }), isSigned(card),
              profile.startingXICardIDs.indices.contains(index) else { return false }
        assign(cardID: cardID, toXISlot: index)
        return profile.startingXICardIDs[index] == cardID
    }

    func assignToBench(cardID: String, slot index: Int) -> Bool {
        guard let card = LegendsCardDatabase.all.first(where: { $0.id == cardID }), isSigned(card),
              profile.benchCardIDs.indices.contains(index) else { return false }
        assign(cardID: cardID, toBenchSlot: index)
        return profile.benchCardIDs[index] == cardID
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

    /// Exchanges whatever's in two squad slots (XI or bench, any
    /// combination) — the drag-and-drop swap on the Squad screen.
    /// Deliberately bypasses `assign(cardID:...)`: that method's
    /// same-name duplicate-removal exists for introducing a *new* card
    /// into the squad, and would wrongly clear the other slot involved
    /// in a swap between two cards already legally fielded. A swap
    /// against an empty slot behaves like a plain move.
    func swapSquadSlots(_ a: LegendsSquadSlot, _ b: LegendsSquadSlot) {
        guard a != b else { return }

        func read(_ slot: LegendsSquadSlot) -> String? {
            switch slot {
            case .xi(let i): return profile.startingXICardIDs.indices.contains(i) ? profile.startingXICardIDs[i] : nil
            case .bench(let i): return profile.benchCardIDs.indices.contains(i) ? profile.benchCardIDs[i] : nil
            }
        }
        func write(_ slot: LegendsSquadSlot, _ cardID: String?) {
            switch slot {
            case .xi(let i): if profile.startingXICardIDs.indices.contains(i) { profile.startingXICardIDs[i] = cardID }
            case .bench(let i): if profile.benchCardIDs.indices.contains(i) { profile.benchCardIDs[i] = cardID }
            }
        }

        let cardA = read(a)
        let cardB = read(b)
        write(a, cardB)
        write(b, cardA)
        if let cardA { profile.activatedCardIDs.insert(cardA) }
        if let cardB { profile.activatedCardIDs.insert(cardB) }

        // The captain follows their card ID, not a slot — but if this
        // swap moved the captain out of the XI onto the bench, the
        // "captain must be a Starting XI player" invariant (see
        // setCaptain) needs re-enforcing, same as clearXISlot already does.
        if let captain = profile.captainCardID, !profile.startingXICardIDs.contains(captain) {
            profile.captainCardID = nil
        }
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

    /// Average effective overall across the Starting XI's midfield and
    /// forward slots — counts by where a card is actually fielded, not
    /// its own printed position, so a striker played out of position at
    /// CB doesn't inflate this. 0 until the whole XI is filled, same
    /// convention as `currentTeamRating`. Feeds both the Squad screen's
    /// stat row and the live match engine's per-minute strength calc.
    var attackRating: Int {
        averageRating { $0.broad == .midfielder || $0.broad == .forward }
    }

    /// Average effective overall across the Starting XI's goalkeeper and
    /// defender slots.
    var defenceRating: Int {
        averageRating { $0 == .goalkeeper || $0.broad == .defender }
    }

    private func averageRating(where matchesSlot: (DetailedPosition) -> Bool) -> Int {
        let slots = startingXISlots
        let ids = profile.startingXICardIDs
        guard ids.count == slots.count, ids.allSatisfy({ $0 != nil }) else { return 0 }
        let cards = ids.compactMap { $0 }.compactMap { id in LegendsCardDatabase.all.first { $0.id == id } }
        guard cards.count == ids.count else { return 0 }

        var total = 0
        var count = 0
        for (index, slot) in slots.enumerated() where matchesSlot(slot) {
            total += effectiveOverall(for: cards[index])
            count += 1
        }
        guard count > 0 else { return 0 }
        return Int((Double(total) / Double(count)).rounded())
    }
}
