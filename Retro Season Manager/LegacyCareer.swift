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

/// A single named record-holder for a career's museum stats — the club's
/// biggest win, a player's goal/appearance/MOTM tally, or a season's final
/// position — kept as real numbers (not baked prose) so a museum can
/// re-sort and compare them across every archived career.
struct LegacyRecordHolder: Codable {
    let name: String
    let value: Int
    let detail: String
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
    /// Count of earned silverware, excluding promotion which is a separate honour.
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
    /// Structured museum stats, kept as real numbers rather than baked
    /// prose so cross-career aggregation (`LegacyArchive.greatestPlayers`
    /// etc.) can re-sort and compare them — added after the type first
    /// shipped, so all seven are Optional/lenient-decoded like
    /// `legacyScore`/`recordBook` before them.
    let topScorer: LegacyRecordHolder?
    let topAppearances: LegacyRecordHolder?
    let topMOTM: LegacyRecordHolder?
    let recordWin: LegacyRecordHolder?
    let bestSeason: LegacyRecordHolder?
    /// Top 3 sales + top 3 signings by fee — reuses the existing
    /// `TransferHistoryEntry` type directly.
    let topTransfers: [TransferHistoryEntry]?
    /// Only `.major`/`.historic` importance front pages — not the full
    /// (possibly 600-entry) newspaper archive, to keep the per-career file
    /// size sane while preserving the genuinely front-page-worthy moments.
    let frontPages: [Newspaper]?

    init(id: UUID, managerName: String, clubName: String, startYear: Int, endYear: Int, seasonsManaged: Int,
         finalDivisionName: String, careerHonours: [String], autobiography: String, timeline: [LegacyCareerMoment],
         achievementUnlocks: [AchievementUnlock], careerAchievementPoints: Int, clubLegends: [ClubLegend],
         history: [SeasonRecord], careerRecordByClub: [String: ClubCareerRecord], legacyScore: Int,
         legacyTier: LegacyTier, recordBook: [String], archivedDate: Date,
         topScorer: LegacyRecordHolder? = nil, topAppearances: LegacyRecordHolder? = nil,
         topMOTM: LegacyRecordHolder? = nil, recordWin: LegacyRecordHolder? = nil,
         bestSeason: LegacyRecordHolder? = nil, topTransfers: [TransferHistoryEntry]? = nil,
         frontPages: [Newspaper]? = nil) {
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
        self.topScorer = topScorer
        self.topAppearances = topAppearances
        self.topMOTM = topMOTM
        self.recordWin = recordWin
        self.bestSeason = bestSeason
        self.topTransfers = topTransfers
        self.frontPages = frontPages
    }

    /// `legacyScore`/`legacyTier`/`recordBook` were added after the type
    /// shipped — leniently decoded so a career archived before that still
    /// opens instead of failing to load. Same treatment for the seven
    /// museum fields added afterward.
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
        topScorer = try c.decodeIfPresent(LegacyRecordHolder.self, forKey: .topScorer)
        topAppearances = try c.decodeIfPresent(LegacyRecordHolder.self, forKey: .topAppearances)
        topMOTM = try c.decodeIfPresent(LegacyRecordHolder.self, forKey: .topMOTM)
        recordWin = try c.decodeIfPresent(LegacyRecordHolder.self, forKey: .recordWin)
        bestSeason = try c.decodeIfPresent(LegacyRecordHolder.self, forKey: .bestSeason)
        topTransfers = try c.decodeIfPresent([TransferHistoryEntry].self, forKey: .topTransfers)
        frontPages = try c.decodeIfPresent([Newspaper].self, forKey: .frontPages)
    }
}

enum LegacyArchive {
    private static var careerEndUITestArchiveConfigured = false
    private static var isolatedCareerArchiveRoot: URL?

#if DEBUG
    enum DebugWriteFailure { case careerFile, index }
    /// Consumed by the next matching write; exercises archive failures
    /// deterministically inside an isolated test root.
    static var debugFailNextWrite: DebugWriteFailure?
    static var debugFailNextRemoval = false
#endif

    private static let damagedIndexPrefix = "index.damaged-"

    /// Routes archive reads and writes into a disposable test-only root.
    /// Production documents and the Museum UI fixture are unchanged.
    static func useIsolatedRootForTesting(_ root: URL?) {
        isolatedCareerArchiveRoot = root
    }

    private static var configuredTestRoot: URL? { isolatedCareerArchiveRoot }

    /// Isolates the CareerEnd UI fixture from the user's real archive. It
    /// clears only a dedicated cache subdirectory for this explicit test
    /// launch argument; Documents/legacy is never touched. Directory
    /// selection is derived from the launch argument at each access so the
    /// app's archive writer and menu reader cannot disagree about the root.
    static func configureCareerEndUITestArchiveForDebug() {
        guard ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_END"),
              !careerEndUITestArchiveConfigured else { return }
        careerEndUITestArchiveConfigured = true
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let isolated = caches.appendingPathComponent("career-end-ui-test-legacy", isDirectory: true)
        try? FileManager.default.removeItem(at: isolated)
        try? FileManager.default.createDirectory(at: isolated, withIntermediateDirectories: true)
    }

    static var directoryForTesting: URL {
        directory
    }

    private static var directory: URL {
        #if DEBUG
        if let isolated = configuredTestRoot {
            try? FileManager.default.createDirectory(at: isolated, withIntermediateDirectories: true)
            return isolated
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_END") {
            return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("career-end-ui-test-legacy", isDirectory: true)
        }
        #endif
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

    /// Every archived career, most recently archived first. Reads never
    /// write: entries whose file is gone are dropped, and complete career
    /// files the index does not list (an archive interrupted before its index
    /// write) are adopted, so a finished career is never hidden by that gap.
    static func all() -> [LegacyCareerInfo] {
        reconciled(recordedIndex() ?? []).sorted { $0.archivedDate > $1.archivedDate }
    }

    /// The index as recorded on disk, or nil when it is missing, unreadable or damaged.
    private static func recordedIndex() -> [LegacyCareerInfo]? {
        guard let data = try? Data(contentsOf: indexURL) else { return nil }
        return try? JSONDecoder().decode([LegacyCareerInfo].self, from: data)
    }

    /// The list a write must start from. A damaged index is copied aside
    /// first, so the bytes that failed to decode are never overwritten.
    private static func writableList() -> [LegacyCareerInfo]? {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return reconciled([]) }
        guard let data = try? Data(contentsOf: indexURL) else { return nil }
        if let recorded = try? JSONDecoder().decode([LegacyCareerInfo].self, from: data) {
            return reconciled(recorded)
        }
        guard keepDamagedIndex(data) else { return nil }
        return reconciled([])
    }

    /// Copies damaged index bytes beside the careers. Identical bytes are kept
    /// once, so repeated failed attempts do not pile up copies.
    private static func keepDamagedIndex(_ data: Data) -> Bool {
        let siblings = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let alreadyKept = siblings
            .filter { $0.lastPathComponent.hasPrefix(damagedIndexPrefix) }
            .contains { (try? Data(contentsOf: $0)) == data }
        if alreadyKept { return true }
        let backup = directory.appendingPathComponent("\(damagedIndexPrefix)\(UUID().uuidString).json")
        return (try? data.write(to: backup, options: .atomic)) != nil
    }

    private static func reconciled(_ recorded: [LegacyCareerInfo]) -> [LegacyCareerInfo] {
        let fm = FileManager.default
        var list = recorded.filter { fm.fileExists(atPath: fileURL(for: $0.id).path) }
        let known = Set(list.map(\.id))
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "json" {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  !known.contains(id),
                  let data = try? Data(contentsOf: url),
                  let career = try? JSONDecoder().decode(LegacyCareer.self, from: data),
                  career.id == id else { continue }
            list.append(info(for: career))
        }
        return list
    }

    /// The index entry for a career, derived entirely from the snapshot itself.
    private static func info(for career: LegacyCareer) -> LegacyCareerInfo {
        LegacyCareerInfo(id: career.id, managerName: career.managerName, clubName: career.clubName,
                         startYear: career.startYear, endYear: career.endYear,
                         seasonsManaged: career.seasonsManaged, trophyCount: trophyCount(career),
                         finalDivisionName: career.finalDivisionName, legacyScore: career.legacyScore,
                         legacyTier: career.legacyTier, archivedDate: career.archivedDate)
    }

    @discardableResult
    private static func writeIndex(_ list: [LegacyCareerInfo]) -> Bool {
#if DEBUG
        if debugFailNextWrite == .index {
            debugFailNextWrite = nil
            return false
        }
#endif
        guard let data = try? JSONEncoder().encode(list) else { return false }
        do {
            try data.write(to: indexURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func writeCareerFile(_ data: Data, id: UUID) -> Bool {
#if DEBUG
        if debugFailNextWrite == .careerFile {
            debugFailNextWrite = nil
            return false
        }
#endif
        return (try? data.write(to: fileURL(for: id), options: .atomic)) != nil
    }

    /// Permanently archives a finished career. Returns true once the career
    /// is preserved. The id is the career's stable identity: a repeated
    /// archive, including a retry after a failure, never lists it twice and
    /// never replaces the snapshot that was already kept.
    @discardableResult
    static func archive(_ career: LegacyCareer) -> Bool {
        guard let data = try? JSONEncoder().encode(career),
              var list = writableList() else { return false }
        // Covers both a listed career and an orphaned snapshot, which
        // `writableList` adopts. Either way the career is already preserved.
        if list.contains(where: { $0.id == career.id }) {
            // An index entry and an existing file do not prove the frozen
            // snapshot is readable. Never discard the active save on that
            // basis, or silently overwrite damaged archive bytes.
            return load(id: career.id)?.id == career.id
        }
        // The snapshot is written first. An interruption before the index write
        // leaves a complete orphan file, which reads adopt.
        guard writeCareerFile(data, id: career.id) else { return false }
        list.append(info(for: career))
        guard writeIndex(list) else {
            try? FileManager.default.removeItem(at: fileURL(for: career.id))
            return false
        }
        return true
    }

    /// Aggregates match records for the archived career without inventing
    /// totals when older archives have no club records.
    static func careerRecord(_ career: LegacyCareer) -> ClubCareerRecord {
        career.careerRecordByClub.values.reduce(into: ClubCareerRecord()) { total, record in
            total.wins += record.wins
            total.draws += record.draws
            total.losses += record.losses
            total.goalsFor += record.goalsFor
            total.goalsAgainst += record.goalsAgainst
            total.homeWins += record.homeWins
            total.homeDraws += record.homeDraws
            total.homeLosses += record.homeLosses
            total.awayWins += record.awayWins
            total.awayDraws += record.awayDraws
            total.awayLosses += record.awayLosses
        }
    }

    /// Per-club match records, sorted by managed seasons then name for
    /// stable Museum output, including records from repeat stints.
    static func clubRecords(_ career: LegacyCareer) -> [(club: String, record: ClubCareerRecord)] {
        let managedSeasons = Dictionary(grouping: career.history, by: \.userClub)
        return career.careerRecordByClub.map { (club: $0.key, record: $0.value) }
            .sorted {
                let a = managedSeasons[$0.club]?.count ?? 0
                let b = managedSeasons[$1.club]?.count ?? 0
                if a != b { return a > b }
                return $0.club < $1.club
            }
    }

    /// Honours associated with each managed club and season are decoded
    /// from the existing "(season label)" suffix used by careerHonours.
    /// Promotion follows the manager's club from that season, just like
    /// league and cup honours.
    static func clubHonours(_ career: LegacyCareer, club: String) -> [String] {
        clubHonours(history: career.history, honours: career.careerHonours, club: club)
    }

    static func clubHonours(history: [SeasonRecord], honours: [String], club: String) -> [String] {
        honours.filter { honour in
            guard let open = honour.lastIndex(of: "("), let close = honour.lastIndex(of: ")"), open < close else { return false }
            let label = String(honour[honour.index(after: open)..<close])
            let matchingSeasons = history.filter { $0.label == label }
            // Duplicate labels can occur in old or hand-built history. A
            // title identifies the club from the champion field; cup honours
            // carry their winner's name. Prefer those concrete IDs/names over
            // assigning every matching honour to the first club for that label.
            if honour.localizedCaseInsensitiveContains("title") {
                let honourText = honour.hasPrefix("🏆") ? String(honour.dropFirst()) : honour
                let titleName = String(honourText.split(separator: "(", maxSplits: 1).first ?? "")
                    .trimmingCharacters(in: .whitespaces)
                let divisionTitle = titleName.range(of: " title", options: .caseInsensitive) != nil
                return matchingSeasons.contains { record in
                    guard record.userClub == club, record.userPosition == 1,
                          record.champion == club else { return false }
                    guard divisionTitle else { return true }
                    let division = String(titleName[..<(titleName.range(of: " title", options: .caseInsensitive)?.lowerBound ?? titleName.endIndex)])
                    return record.userDivision.caseInsensitiveCompare(division) == .orderedSame
                }
            }
            if honour.contains("Promoted") {
                return matchingSeasons.contains { $0.userClub == club }
            }
            if honour.contains("🏆") {
                let prize = String(honour.dropFirst().split(separator: "(", maxSplits: 1).first ?? "")
                    .trimmingCharacters(in: .whitespaces)
                return matchingSeasons.contains { record in
                    guard record.userClub == club else { return false }
                    switch prize {
                    case GameStore.cupName: return record.cupWinner == club
                    case GameStore.euroName: return record.euroWinner == club
                    case GameStore.communityShieldName: return record.communityShieldWinner == club
                    // Each competition is checked against its own winner
                    // field. A nil field is an older record that never stored
                    // that winner, so the conservative managed-season fallback
                    // applies. No other competition's winner can validate it.
                    case GameStore.uefaCupName: return record.uefaCupWinner.map { $0 == club } ?? true
                    case GameStore.leagueCupName: return record.leagueCupWinner.map { $0 == club } ?? true
                    case GameStore.uefaSuperCupName: return record.uefaSuperCupWinner.map { $0 == club } ?? true
                    default:
                        // Unknown prize labels keep the managed-season fallback.
                        return true
                    }
                }
            }
            return matchingSeasons.contains { $0.userClub == club }
        }
    }

    /// Totals available from the archived match records. Older archives
    /// without per-club records yield zero rather than inferred totals.
    static func matchSummary(_ career: LegacyCareer) -> (matches: Int, wins: Int, draws: Int, losses: Int,
                                                        goalsFor: Int, goalsAgainst: Int) {
        let record = careerRecord(career)
        return (record.matches, record.wins, record.draws, record.losses,
                record.goalsFor, record.goalsAgainst)
    }

    static func load(id: UUID) -> LegacyCareer? {
        guard let data = try? Data(contentsOf: fileURL(for: id)) else { return nil }
        return try? JSONDecoder().decode(LegacyCareer.self, from: data)
    }

    /// Deletes an archived career. The file goes first: if that fails, the
    /// career stays listed and unchanged. The index entry is then dropped
    /// best-effort, since reads ignore entries whose file is gone.
    @discardableResult
    static func remove(id: UUID) -> Bool {
        #if DEBUG
        if debugFailNextRemoval {
            debugFailNextRemoval = false
            return false
        }
        #endif
        let url = fileURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            guard (try? FileManager.default.removeItem(at: url)) != nil else { return false }
        }
        if let list = writableList() {
            writeIndex(list.filter { $0.id != id })
        }
        return true
    }
}

// MARK: - Museum aggregation

/// Pure, SwiftUI-free cross-career reductions over a set of already-loaded
/// `LegacyCareer` records — the museum views call these after decoding
/// every archived career (the same `compactMap { LegacyArchive.load(id:) }`
/// pattern `GlobalRecordBookView` already uses), kept here rather than
/// inline in a View so they're independently testable.
extension LegacyArchive {

    static func trophyCount(_ career: LegacyCareer) -> Int {
        career.careerHonours.filter { $0.contains("🏆") || !$0.contains("Promoted") }.count
    }

    /// Corrects metadata totals written by older versions that counted
    /// promotion honours as trophies; undecodable career files remain omitted.
    static func refreshedIndex() -> [LegacyCareerInfo] {
        all().map { info in
            guard let career = load(id: info.id) else { return info }
            return LegacyCareerInfo(id: info.id, managerName: info.managerName, clubName: info.clubName,
                                   startYear: info.startYear, endYear: info.endYear,
                                   seasonsManaged: info.seasonsManaged, trophyCount: trophyCount(career),
                                   finalDivisionName: info.finalDivisionName, legacyScore: info.legacyScore,
                                   legacyTier: info.legacyTier, archivedDate: info.archivedDate)
        }
    }

    static func trophyTally(from careers: [LegacyCareer]) -> [(honour: String, career: String)] {
        careers.flatMap { career in
            career.careerHonours.filter { $0.contains("🏆") || !$0.contains("Promoted") }
                .map { (honour: $0, career: "\(career.managerName) at \(career.clubName)") }
        }
    }

    /// Every archived career, best legacy score first.
    static func greatestManagers(from careers: [LegacyCareer], limit: Int) -> [LegacyCareer] {
        Array(careers.sorted { $0.legacyScore > $1.legacyScore }.prefix(limit))
    }

    /// Every club legend across every archived career, flattened and
    /// ranked by legend score — `ClubLegend` is already a full record
    /// (stats + biography), so no new player-side data is needed.
    static func greatestPlayers(from careers: [LegacyCareer], limit: Int) -> [(legend: ClubLegend, career: String)] {
        let flattened = careers.flatMap { career in
            career.clubLegends.map { (legend: $0, career: "\(career.managerName) at \(career.clubName)") }
        }
        return Array(flattened.sorted { $0.legend.legendScore > $1.legend.legendScore }.prefix(limit))
    }

    /// The single best-of across every career for one of the five
    /// `LegacyRecordHolder` fields — careers archived before these fields
    /// existed simply have `nil` and are skipped, not treated as an error.
    private static func recordHolder(from careers: [LegacyCareer], _ keyPath: KeyPath<LegacyCareer, LegacyRecordHolder?>,
                                      maximize: Bool) -> (holder: LegacyRecordHolder, career: String)? {
        let candidates = careers.compactMap { career -> (LegacyRecordHolder, String)? in
            guard let holder = career[keyPath: keyPath] else { return nil }
            return (holder, "\(career.managerName) at \(career.clubName)")
        }
        let best = maximize ? candidates.max { $0.0.value < $1.0.value } : candidates.min { $0.0.value < $1.0.value }
        return best.map { (holder: $0.0, career: $0.1) }
    }

    static func globalTopScorer(from careers: [LegacyCareer]) -> (holder: LegacyRecordHolder, career: String)? {
        recordHolder(from: careers, \.topScorer, maximize: true)
    }

    static func globalTopAppearances(from careers: [LegacyCareer]) -> (holder: LegacyRecordHolder, career: String)? {
        recordHolder(from: careers, \.topAppearances, maximize: true)
    }

    static func globalTopMOTM(from careers: [LegacyCareer]) -> (holder: LegacyRecordHolder, career: String)? {
        recordHolder(from: careers, \.topMOTM, maximize: true)
    }

    static func globalRecordWin(from careers: [LegacyCareer]) -> (holder: LegacyRecordHolder, career: String)? {
        recordHolder(from: careers, \.recordWin, maximize: true)
    }

    /// "Best" here means the lowest final league position (1st place),
    /// the one record-holder reduction that minimizes rather than maximizes.
    static func globalBestSeason(from careers: [LegacyCareer]) -> (holder: LegacyRecordHolder, career: String)? {
        recordHolder(from: careers, \.bestSeason, maximize: false)
    }

    /// Every career's preserved top transfers, flattened and re-sorted by
    /// fee — careers archived before `topTransfers` existed contribute
    /// nothing here, not an error.
    static func globalTopTransfers(from careers: [LegacyCareer], limit: Int) -> [(entry: TransferHistoryEntry, career: String)] {
        let flattened = careers.flatMap { career in
            (career.topTransfers ?? []).map { (entry: $0, career: "\(career.managerName) at \(career.clubName)") }
        }
        return Array(flattened.sorted { ($0.entry.fee ?? 0) > ($1.entry.fee ?? 0) }.prefix(limit))
    }
}
