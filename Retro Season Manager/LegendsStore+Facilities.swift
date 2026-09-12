import Foundation

extension LegendsStore {
    func facilityLevel(_ kind: LegendsFacilityKind) -> Int {
        min(kind.maxLevel, max(0, profile.facilityLevels[kind.rawValue] ?? 0))
    }

    func facilityUpgradeCost(_ kind: LegendsFacilityKind) -> Int? {
        kind.upgradeCost(at: facilityLevel(kind))
    }

    var facilityBalance: Int { profile.coins }

    /// A readable, deterministic report used by Player Details. Higher
    /// scouting levels reveal a tighter band, then the stored ceiling.
    func scoutingReport(for card: LegendsCard) -> String {
        guard let career = profile.playerCareers[card.id] else {
            return potentialDescription(for: card)
        }
        switch facilityLevel(.scoutingNetwork) {
        case 0:
            return potentialDescription(for: card)
        case 1:
            return "\(potentialDescription(for: card)) · CONFIDENCE IMPROVED"
        case 2:
            let lower = max(career.startingOverall, career.potential - 2)
            return "\(potentialDescription(for: card)) · EST. CEILING \(lower)-\(career.potential)"
        default:
            return "EST. CEILING \(career.potential)"
        }
    }

    /// Facility-specific mechanical hooks. Keeping them as named values makes
    /// the benefits auditable and lets tests prove each effect without using
    /// random match outcomes.
    var trainingCentreProgressMultiplier: Double {
        1.0 + Double(facilityLevel(.trainingCentre)) * 0.05
    }

    var clubStadiumMatchStrengthBonus: Double {
        Double(facilityLevel(.clubStadium))
    }

    @discardableResult
    func upgradeFacility(_ kind: LegendsFacilityKind) -> LegendsFacilityUpgradeResult {
        let current = facilityLevel(kind)
        guard let cost = kind.upgradeCost(at: current) else { return .maximumLevel }
        guard profile.coins >= cost else {
            return .insufficientBalance(required: cost, available: profile.coins)
        }
        // This is the sole mutation point: one exact Balance deduction and
        // one level increment, followed by one persistence write.
        profile.coins -= cost
        profile.facilityLevels[kind.rawValue] = current + 1
        persist()
        return .upgraded(kind: kind, from: current, to: current + 1, cost: cost)
    }

    /// New careers only: the Youth Academy must never rewrite existing
    /// potential or any saved career state.
    func makeNewCareerState(for card: LegendsCard) -> LegendsPlayerCareer {
        Self.makeCareerState(for: card, signedSeason: profile.currentSeason,
                              youthAcademyLevel: facilityLevel(.youthAcademy))
    }
}
