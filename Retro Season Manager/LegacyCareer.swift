//
//  LegacyCareer.swift
//  Retro Season Manager
//
//  A permanent, read-only snapshot of a finished career — captured once,
//  the moment the manager leaves a completed career, so the story
//  survives even though the active save itself is deleted (see
//  `GameStore.returnToMenuAfterCareer`). Storage mirrors `SaveSlots.swift`:
//  a lightweight index for instant list rendering, plus one full record
//  per career on disk.
//

import Foundation

/// One beat in an archived career's timeline — a frozen `Codable` copy of
/// `CareerMoment`, since that type isn't itself `Codable` (it's built
/// fresh from live state every time `careerTimeline()` runs).
struct LegacyCareerMoment: Codable, Identifiable {
    var id = UUID()
    let season: Int
    let year: Int
    let icon: String
    let headline: String
    let detail: String
}

/// A single-number rating for a whole career, banded into a tier — a
/// summary judgment for comparing archived careers at a glance without
/// reading the full story. See `LegacyScoring.score(...)` for the formula.
enum LegacyTier: String, Codable {
    case legend = "Legend"
    case distinguished = "Distinguished"
    case accomplished = "Accomplished"
    case journeyman = "Journeyman"
    case modest = "Modest Career"

    static func forScore(_ score: Int) -> LegacyTier {
        switch score {
        case 500...:    return .legend
        case 300..<500: return .distinguished
        case 150..<300: return .accomplished
        case 50..<150:  return .journeyman
        default:        return .modest
        }
    }
}

/// The Legacy Score formula — trophies count for the most since they're
/// the clearest signal of a well-run career, club legends and achievement
/// points reward long-term squad building and standout moments, and raw
/// seasons managed gives a small, deliberately modest credit for
/// longevity alone (so a 30-season career isn't automatically "better"
/// than a 10-season one stacked with silverware).
enum LegacyScoring {
    static func score(trophyCount: Int, seasonsManaged: Int, achievementPoints: Int, legendCount: Int) -> Int {
        trophyCount * 15 + legendCount * 10 + seasonsManaged * 2 + achievementPoints
    }
}

/// Lightweight metadata for the "past careers" list, kept separate from
/// the full archived record so the list renders instantly without
/// decoding every career on disk — same split as `SaveSlotInfo`/`SaveState`.
struct LegacyCareerInfo: Codable, Identifiable, Equatable {
    let id: UUID
    let managerName: String
    let clubName: String
    let startYear: Int
    let endYear: Int
    let seasonsManaged: Int
    let trophyCount: Int
    let finalDivisionName: String
    let legacyScore: Int
    let legacyTier: LegacyTier
    let archivedDate: Date

    /// `legacyScore`/`legacyTier` were added after the type shipped — a
    /// leniently-decoded default keeps any career already archived before
    /// that readable instead of vanishing from the list.
    init(id: UUID, managerName: String, clubName: String, startYear: Int, endYear: Int, seasonsManaged: Int,
         trophyCount: Int, finalDivisionName: String, legacyScore: Int, legacyTier: LegacyTier, archivedDate: Date) {
        self.id = id
        self.managerName = managerName
        self.clubName = clubName
        self.startYear = startYear
        self.endYear = endYear
        self.seasonsManaged = seasonsManaged
        self.trophyCount = trophyCount
        self.finalDivisionName = finalDivisionName
        self.legacyScore = legacyScore
        self.legacyTier = legacyTier
        self.archivedDate = archivedDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        managerName = try c.decode(String.self, forKey: .managerName)
        clubName = try c.decode(String.self, forKey: .clubName)
        startYear = try c.decode(Int.self, forKey: .startYear)
        endYear = try c.decode(Int.self, forKey: .endYear)
        seasonsManaged = try c.decode(Int.self, forKey: .seasonsManaged)
        trophyCount = try c.decode(Int.self, forKey: .trophyCount)
        finalDivisionName = try c.decode(String.self, forKey: .finalDivisionName)
        archivedDate = try c.decode(Date.self, forKey: .archivedDate)
        legacyScore = try c.decodeIfPresent(Int.self, forKey: .legacyScore) ?? 0
        legacyTier = try c.decodeIfPresent(LegacyTier.self, forKey: .legacyTier) ?? .forScore(legacyScore)
    }
}

/// The full archived record of a finished career — everything
/// `CareerEndView`/`ManagerOfficeView` show, frozen at the moment the
/// manager walked away.
struct LegacyCareer: Codable, Identifiable {
    let id: UUID
    let managerName: String
    let clubName: String
    let startYear: Int
    let endYear: Int
    let seasonsManaged: Int
    let finalDivisionName: String
    let careerHonours: [String]
    let autobiography: String
    let timeline: [LegacyCareerMoment]
    let achievementUnlocks: [AchievementUnlock]
    let careerAchievementPoints: Int
    let clubLegends: [ClubLegend]
    let history: [SeasonRecord]
    let careerRecordByClub: [String: ClubCareerRecord]
    let legacyScore: Int
    let legacyTier: LegacyTier
    /// Pre-formatted record-book lines (top scorer, most appearances,
    /// record signing, biggest sale, most Man of the Match awards) —
    /// computed once at archive time from data that isn't otherwise kept
    /// in this snapshot, the same way `autobiography` freezes prose
    /// rather than storing the raw beats to re-render later.
    let recordBook: [String]
    let archivedDate: Date

    init(id: UUID, managerName: String, clubName: String, startYear: Int, endYear: Int, seasonsManaged: Int,
         finalDivisionName: String, careerHonours: [String], autobiography: String, timeline: [LegacyCareerMoment],
         achievementUnlocks: [AchievementUnlock], careerAchievementPoints: Int, clubLegends: [ClubLegend],
         history: [SeasonRecord], careerRecordByClub: [String: ClubCareerRecord], legacyScore: Int,
         legacyTier: LegacyTier, recordBook: [String], archivedDate: Date) {
        self.id = id
        self.managerName = managerName
        self.clubName = clubName
        self.startYear = startYear
        self.endYear = endYear
        self.seasonsManaged = seasonsManaged
        self.finalDivisionName = finalDivisionName
        self.careerHonours = careerHonours
        self.autobiography = autobiography
        self.timeline = timeline
        self.achievementUnlocks = achievementUnlocks
        self.careerAchievementPoints = careerAchievementPoints
        self.clubLegends = clubLegends
        self.history = history
        self.careerRecordByClub = careerRecordByClub
        self.legacyScore = legacyScore
        self.legacyTier = legacyTier
        self.recordBook = recordBook
        self.archivedDate = archivedDate
    }

    /// `legacyScore`/`legacyTier`/`recordBook` were added after the type
    /// shipped — leniently decoded so a career archived before that still
    /// opens instead of failing to load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        managerName = try c.decode(String.self, forKey: .managerName)
        clubName = try c.decode(String.self, forKey: .clubName)
        startYear = try c.decode(Int.self, forKey: .startYear)
        endYear = try c.decode(Int.self, forKey: .endYear)
        seasonsManaged = try c.decode(Int.self, forKey: .seasonsManaged)
        finalDivisionName = try c.decode(String.self, forKey: .finalDivisionName)
        careerHonours = try c.decode([String].self, forKey: .careerHonours)
        autobiography = try c.decode(String.self, forKey: .autobiography)
        timeline = try c.decode([LegacyCareerMoment].self, forKey: .timeline)
        achievementUnlocks = try c.decode([AchievementUnlock].self, forKey: .achievementUnlocks)
        careerAchievementPoints = try c.decode(Int.self, forKey: .careerAchievementPoints)
        clubLegends = try c.decode([ClubLegend].self, forKey: .clubLegends)
        history = try c.decode([SeasonRecord].self, forKey: .history)
        careerRecordByClub = try c.decode([String: ClubCareerRecord].self, forKey: .careerRecordByClub)
        archivedDate = try c.decode(Date.self, forKey: .archivedDate)
        legacyScore = try c.decodeIfPresent(Int.self, forKey: .legacyScore) ?? 0
        legacyTier = try c.decodeIfPresent(LegacyTier.self, forKey: .legacyTier) ?? .forScore(legacyScore)
        recordBook = try c.decodeIfPresent([String].self, forKey: .recordBook) ?? []
    }
}

enum LegacyArchive {
    private static var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("legacy", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static var indexURL: URL { directory.appendingPathComponent("index.json") }

    private static func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    /// Every archived career, most recently archived first.
    static func all() -> [LegacyCareerInfo] {
        guard let data = try? Data(contentsOf: indexURL),
              let list = try? JSONDecoder().decode([LegacyCareerInfo].self, from: data) else { return [] }
        return list.sorted { $0.archivedDate > $1.archivedDate }
    }

    private static func writeIndex(_ list: [LegacyCareerInfo]) {
        if let data = try? JSONEncoder().encode(list) { try? data.write(to: indexURL) }
    }

    /// Permanently archives a finished career.
    static func archive(_ career: LegacyCareer) {
        guard let data = try? JSONEncoder().encode(career) else { return }
        try? data.write(to: fileURL(for: career.id))
        var list = all()
        list.append(LegacyCareerInfo(id: career.id, managerName: career.managerName, clubName: career.clubName,
                                     startYear: career.startYear, endYear: career.endYear,
                                     seasonsManaged: career.seasonsManaged, trophyCount: career.careerHonours.count,
                                     finalDivisionName: career.finalDivisionName, legacyScore: career.legacyScore,
                                     legacyTier: career.legacyTier, archivedDate: career.archivedDate))
        writeIndex(list)
    }

    static func load(id: UUID) -> LegacyCareer? {
        guard let data = try? Data(contentsOf: fileURL(for: id)) else { return nil }
        return try? JSONDecoder().decode(LegacyCareer.self, from: data)
    }

    static func remove(id: UUID) {
        writeIndex(all().filter { $0.id != id })
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }
}
