import Foundation

/// Central balancing policy for the offline Legends career loop.
/// Keep lifecycle numbers here so views and persistence never own gameplay rules.
struct LegendsCareerLifecyclePolicy: Codable, Hashable {
    enum DevelopmentProfile: String, Codable, CaseIterable, Hashable {
        case earlyDeveloper = "EARLY DEVELOPER"
        case standardDeveloper = "STANDARD DEVELOPER"
        case lateDeveloper = "LATE DEVELOPER"
        case prodigy = "PRODIGY"
    }

    let profile: DevelopmentProfile
    let peakStartOffset: Int
    let peakEndOffset: Int
    let retirementAgeRange: ClosedRange<Int>
    let growthMultiplier: Double
    let annualDecline: Int

    var minimumRetirementAge: Int { retirementAgeRange.lowerBound }
    var maximumRetirementAge: Int { retirementAgeRange.upperBound }

    static func configuration(for profile: DevelopmentProfile) -> LegendsCareerLifecyclePolicy {
        switch profile {
        case .earlyDeveloper:
            return .init(profile: profile, peakStartOffset: -1, peakEndOffset: 3, retirementAgeRange: 32...35, growthMultiplier: 1.25, annualDecline: 2)
        case .standardDeveloper:
            return .init(profile: profile, peakStartOffset: 0, peakEndOffset: 4, retirementAgeRange: 34...37, growthMultiplier: 1.0, annualDecline: 1)
        case .lateDeveloper:
            return .init(profile: profile, peakStartOffset: 2, peakEndOffset: 6, retirementAgeRange: 36...39, growthMultiplier: 0.8, annualDecline: 1)
        case .prodigy:
            return .init(profile: profile, peakStartOffset: -2, peakEndOffset: 4, retirementAgeRange: 35...38, growthMultiplier: 1.35, annualDecline: 1)
        }
    }

    static func profile(for cardID: String) -> DevelopmentProfile {
        let seed = stableSeed(cardID) % 100
        switch seed {
        case 0..<8: return .prodigy
        case 8..<30: return .earlyDeveloper
        case 30..<58: return .lateDeveloper
        default: return .standardDeveloper
        }
    }

    static func stableSeed(_ value: String) -> Int {
        value.unicodeScalars.reduce(23) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
    }

    static func retirementAge(for cardID: String, position: DetailedPosition, profile: DevelopmentProfile) -> Int {
        let policy = configuration(for: profile)
        let selected = policy.retirementAgeRange.lowerBound
            + stableSeed("retirement|\(cardID)|\(profile.rawValue)") % policy.retirementAgeRange.count
        let adjusted = position.broad == .goalkeeper ? selected + 2 : selected
        return min(41, adjusted)
    }
}
