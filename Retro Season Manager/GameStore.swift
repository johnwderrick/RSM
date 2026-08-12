//
//  GameStore.swift
//  Retro Season Manager
//
//  The game engine: squad generation, fixtures, match simulation
//  and league bookkeeping. All game state lives here.
//

import Foundation
import Observation

/// A short description of a single match result, used for the news feed.
struct MatchReport: Identifiable {
    let id = UUID()
    let matchday: Int
    let homeName: String
    let awayName: String
    let homeGoals: Int
    let awayGoals: Int
    let scorers: [String]
    let involvesUser: Bool

    var scoreline: String { "\(homeName) \(homeGoals) - \(awayGoals) \(awayName)" }
}

/// A unified description of the user's next match (league or cup).
struct UserMatchInfo {
    let homeIndex: Int
    let awayIndex: Int
    let isCup: Bool
    let label: String
}

/// The persistent snapshot of a game, written to disk between sessions.
struct SaveState: Codable {
    var season: Int
    var currentMatchday: Int
    var userClubIndex: Int
    var formationName: String
    var currentDate: Date
    var boardObjective: String
    var boardConfidence: Int
    var fanConfidence: Int?
    var boardConfidenceTrend: Int?
    var managers: [String]
    var starterIDs: [UUID]
    var clubs: [Club]
    var fixtures: [Fixture]
    var cupTies: [CupTie]
    var cupRound: Int
    var cupWinnerName: String?
    var leagueCupTies: [CupTie]
    var leagueCupRound: Int
    var leagueCupWinnerName: String?
    var leagueCupWinnerID: UUID?
    var careerHonours: [String]
    var lastHonourSeason: Int
    var euroTies: [CupTie]
    var euroRound: Int
    var euroWinnerName: String?
    var euroWinnerID: UUID?
    var europeanQualifierIDs: [UUID]
    var uefaCupTies: [CupTie]
    var uefaCupRound: Int
    var uefaCupWinnerName: String?
    var uefaCupWinnerID: UUID?
    var uefaCupQualifierIDs: [UUID]
    var uefaSuperCupTie: CupTie?
    var uefaSuperCupWinnerName: String?
    var lastSeasonEuroWinnerID: UUID?
    var lastSeasonUefaCupWinnerID: UUID?
    var managerReputation: Int
    var pendingJobOffers: [JobOffer]
    var pendingClubSwitch: Int?
    var wasSacked: Bool
    var captainID: UUID?
    var penaltyTakerID: UUID?
    var freeKickTakerID: UUID?
    var cornerTakerID: UUID?
    var communityShieldTie: CupTie?
    var communityShieldWinnerName: String?
    var cupWinnerID: UUID?
    var lastSeasonChampionID: UUID?
    var lastSeasonRunnerUpID: UUID?
    var lastSeasonCupWinnerID: UUID?
    var history: [SeasonRecord]
    var youthProspects: [Player]
    var allTimeScorers: [String: Int]
    /// Optional: added after `SaveState` was first written, so an older
    /// save simply won't have it — falls back to empty at load instead of
    /// failing the whole decode.
    var allTimeAppearances: [String: Int]?
    var careerRecordByClub: [String: ClubCareerRecord]?
    var motmTally: [String: Int]?
    var clubTenureStart: [UUID: Int]?
    var seasonLedger: [LedgerEntry]?
    var transferHistory: [TransferHistoryEntry]?
    var lastBudgetRequestDate: Date?
    var lastClearAirDate: Date?
    var trainingFocus: TrainingFocus
    var hallOfFame: [String: HallEntry]
    var difficulty: Difficulty
    var shortlistedPlayerIDs: Set<UUID>
    var friendlyFixtures: [Fixture]
    var formationSwitchedDate: Date?
    var autoPickAssist: Bool
    var delegateToAssistant: Bool?
    var preferredMentality: Mentality?
    var backroomStaff: [StaffMember]?
    var slotPins: [String: UUID]
    var firedDatedEventIDs: Set<String>
    var managerContractYears: Int?
    var startYear: Int?
    var pendingTransferDeals: [PendingTransferDeal]?
    var unlockedAchievements: Set<AchievementKind>?
}

@MainActor
@Observable
final class GameStore {

    // MARK: - State

    private(set) var clubs: [Club] = []
    private(set) var fixtures: [Fixture] = []
    /// Two throwaway pre-season friendlies, auto-resolved as the calendar
    /// reaches them — sharpen fitness and let new signings get minutes
    /// without any risk to league form. `matchday` is repurposed as a 0/1
    /// index into `friendlyDate(_:)` rather than a real matchday.
    private(set) var friendlyFixtures: [Fixture] = []
    private(set) var userClubIndex: Int = 0
    private(set) var currentMatchday: Int = 1
    private(set) var season: Int = 1
    /// The real-world calendar year a career began in — season 1 is
    /// `startYear`/`startYear+1`. Lets a career start in 2000, 2010, or any
    /// future year `Self.availableStartYears` offers, while `season` itself
    /// stays a simple relative counter everywhere else in the engine.
    private(set) var startYear: Int = 2000
    private(set) var lastReports: [MatchReport] = []

    /// One manager name per club, index-aligned with `clubs`.
    private(set) var managers: [String] = []

    /// The live match currently in progress, if any.
    var live: LiveMatch?
    /// Whether the pre-match hub is currently showing.
    var atPreMatch = false
    /// Set around a heavy synchronous operation (new game, season rollover,
    /// a long calendar sim) so the UI can show a loading screen.
    var isBusy = false
    var busyMessage = "Loading…"
    /// A pending press-conference question, if any.
    private(set) var pendingPressQuestion: PressQuestion?
    private(set) var pendingTeamTalk: PressQuestion?

    /// Players currently available to sign.
    private(set) var transferMarket: [TransferTarget] = []
    /// The board's objective for the season.
    private(set) var boardObjective = ""
    /// Board confidence in the manager, 0...100.
    private(set) var boardConfidence = 60
    /// A separate pulse from the boardroom's — fans care about recent
    /// results and performances viscerally, not the season's objective,
    /// so this can sour (or recover) faster than board confidence does.
    private(set) var fanConfidence = 60
    /// The change in board confidence from the last result — positive
    /// means it's rising, negative falling, for a trend indicator.
    private(set) var boardConfidenceTrend = 0

    /// The current in-game date.
    private(set) var currentDate = Date()
    /// The dated news / inbox feed, newest first.
    private(set) var news: [NewsItem] = []
    /// Rival clubs' outstanding bids for the user's players.
    private(set) var pendingOffers: [TransferOffer] = []
    /// Tracks the transfer window state between day ticks.
    private var windowWasOpen = false
    /// A same-day cache for `starRatings`, since the underlying league-wide
    /// strength pass is expensive and callers may ask for it many times
    /// while nothing about the squads has actually changed.
    private var starRatingsCache: [Int: Int] = [:]
    private var starRatingsCacheDate: Date?
    /// Whether this season's one-off "deadline day" news has already fired.
    private var deadlineDayAnnounced = false
    /// The user's transfer budget at the moment the window last opened, so
    /// the board can react to net spend when it closes again.
    private var transferBudgetAtWindowOpen = 0

    /// Completed scout reports, keyed by transfer-target id.
    private(set) var scoutedReports: [UUID: ScoutReport] = [:]
    /// Targets currently being scouted, with the date the report is due.
    private(set) var scoutingDue: [UUID: Date] = [:]

    /// How many rounds a bid negotiation for a given target has gone
    /// through this window — a selling club's patience for lowball offers
    /// isn't infinite, and repeated haggling narrows the gap rather than
    /// repeating the same counter forever. Cleared whenever the market
    /// regenerates, same lifetime as the targets it tracks.
    private var negotiationRounds: [UUID: Int] = [:]

    /// Players the manager has bookmarked for later — a lightweight watchlist,
    /// independent of the full scouting flow.
    private(set) var shortlistedPlayerIDs: Set<UUID> = []
    /// Shortlisted players already alerted on this season, so the same
    /// "entering his final year" news doesn't repeat every day.
    private var shortlistAlertedIDs: Set<UUID> = []
    /// Whether the objective-at-risk warning has already fired this season.
    private var objectiveRiskWarned = false

    /// IDs of one-off, real-world-dated events (ownership changes, marquee
    /// player arrivals/transfers, real transfer headlines) already fired
    /// this career. These fire on "today's date has reached or passed the
    /// trigger date and it hasn't fired yet" rather than an exact-day
    /// match — an exact match would silently and permanently skip an
    /// event for any save whose calendar had already passed that date
    /// before the event existed in the game (e.g. a new dated event added
    /// mid-session, or force-simming straight past it).
    private(set) var firedDatedEventIDs: Set<String> = []

    /// Year*12+month of the last Manager of the Month check, and each
    /// club's points total as of that check — lets the award measure
    /// points earned *this month* without a full match-by-match log.
    private var lastMonthlyAwardKey = 0
    private var monthlyAwardBaseline: [UUID: Int] = [:]

    /// The domestic cup's current-round ties.
    private(set) var cupTies: [CupTie] = []
    /// The current cup round (1-based), or 0 if not running.
    private(set) var cupRound = 0
    /// The winner of this season's cup, once decided.
    private(set) var cupWinnerName: String?
    private(set) var cupWinnerID: UUID?
    static let cupName = "National Cup"

    /// The League Trophy — a second, smaller knockout run alongside the National Cup.
    private(set) var leagueCupTies: [CupTie] = []
    private(set) var leagueCupRound = 0
    private(set) var leagueCupWinnerName: String?
    private(set) var leagueCupWinnerID: UUID?
    static let leagueCupName = "League Trophy"

    /// The season-opening Community Trophy: last season's champion vs cup winner.
    private(set) var communityShieldTie: CupTie?
    private(set) var communityShieldWinnerName: String?
    private var lastSeasonChampionID: UUID?
    private var lastSeasonRunnerUpID: UUID?
    private var lastSeasonCupWinnerID: UUID?
    static let communityShieldName = "Community Trophy"

    /// The Continental Cup contested by the top-4 First Division clubs.
    private(set) var euroTies: [CupTie] = []
    private(set) var euroRound = 0
    private(set) var euroWinnerName: String?
    private(set) var euroWinnerID: UUID?
    /// Club ids that qualified for Europe (captured at the previous season's end).
    private(set) var europeanQualifierIDs: [UUID] = []
    static let euroName = "Continental Cup"

    /// The Midweek Cup — Europe's second club competition, contested by clubs
    /// that miss out on the Continental Cup: the next-best English clubs plus
    /// the foreign giants not drawn into the Continental Cup that season.
    private(set) var uefaCupTies: [CupTie] = []
    private(set) var uefaCupRound = 0
    private(set) var uefaCupWinnerName: String?
    private(set) var uefaCupWinnerID: UUID?
    /// Club ids that qualified for the Midweek Cup (captured at the previous season's end).
    private(set) var uefaCupQualifierIDs: [UUID] = []
    static let uefaCupName = "Midweek Cup"

    /// The season-opening Continental Super Cup: last season's Continental Cup
    /// winner vs last season's Midweek Cup winner.
    private(set) var uefaSuperCupTie: CupTie?
    private(set) var uefaSuperCupWinnerName: String?
    private var lastSeasonEuroWinnerID: UUID?
    private var lastSeasonUefaCupWinnerID: UUID?
    static let uefaSuperCupName = "Continental Super Cup"

    /// This season's random split of the foreign pool between the European
    /// Cup and the Midweek Cup — recomputed once each season.
    private var seasonForeignAllocation: (europe: [Int], uefa: [Int]) = ([], [])

    /// The manager's career honours, newest last.
    private(set) var careerHonours: [String] = []
    /// Career milestones unlocked so far — distinct from `careerHonours`,
    /// which just logs what was won; these are specific feats worth
    /// calling out and collecting on their own screen.
    private(set) var unlockedAchievements: Set<AchievementKind> = []
    /// A record of every completed season, newest last.
    private(set) var history: [SeasonRecord] = []
    /// Career goal tallies across the whole game, keyed by player name.
    private(set) var allTimeScorers: [String: Int] = [:]
    private(set) var allTimeAppearances: [String: Int] = [:]
    private(set) var careerRecordByClub: [String: ClubCareerRecord] = [:]
    /// Man of the Match awards, by player name, across the whole career.
    private(set) var motmTally: [String: Int] = [:]
    /// The season a player was first seen at the user's club, keyed by id
    /// — tracks unbroken service toward a ten-year testimonial.
    private(set) var clubTenureStart: [UUID: Int] = [:]

    /// The career's leading Man of the Match winner, and their tally.
    func topCareerMOTM() -> (name: String, count: Int)? {
        motmTally.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }
    /// This season's finance ledger for the user's club — reset at each
    /// season rollover, not kept across the whole career.
    private(set) var seasonLedger: [LedgerEntry] = []
    /// Every signing, sale and loan move involving the user's club across
    /// the whole career — unlike `seasonLedger`, this never resets.
    private(set) var transferHistory: [TransferHistoryEntry] = []
    /// Deals where a fee has been agreed but personal terms haven't —
    /// see `PendingTransferDeal`.
    private(set) var pendingTransferDeals: [PendingTransferDeal] = []

    /// Records one line in the permanent transfer history.
    func logTransferHistory(_ playerName: String, action: String, otherClub: String?, fee: Int?) {
        transferHistory.insert(TransferHistoryEntry(date: currentDate, playerName: playerName, action: action,
                                                     otherClub: otherClub, fee: fee), at: 0)
    }
    /// The last time the manager formally asked the board for extra
    /// transfer funds — gated to once every couple of months.
    private(set) var lastBudgetRequestDate: Date?

    /// Records one line in this season's finance ledger.
    func logLedger(_ category: String, amount: Int, _ detail: String) {
        seasonLedger.insert(LedgerEntry(date: currentDate, category: category, amount: amount, detail: detail), at: 0)
    }

    /// Days until the manager can next ask the board for more money, or
    /// nil if a request can be made right now.
    var daysUntilNextBudgetRequest: Int? {
        guard let last = lastBudgetRequestDate,
              let days = Self.calendar.dateComponents([.day], from: last, to: currentDate).day,
              days < 60 else { return nil }
        return 60 - days
    }

    /// Formally asks the board for extra transfer funds. Success chance
    /// scales with board confidence — you're more likely to get a "yes"
    /// when the board already trusts you, and a refusal costs a little
    /// of that trust for having asked.
    @discardableResult
    func requestBudgetIncrease() -> String {
        guard daysUntilNextBudgetRequest == nil else {
            return "The board already gave their answer recently — try again later."
        }
        lastBudgetRequestDate = currentDate
        let approved = Double.random(in: 0..<1) < Double(boardConfidence) / 100.0
        if approved {
            let bonus = max(200, Int(Double(userClub.transferBudget) * Double.random(in: 0.10...0.25)))
            clubs[userClubIndex].transferBudget += bonus
            logLedger("Board request", amount: bonus, "Board approved extra transfer funds")
            addNews(.board, "Budget request approved",
                    "The board have agreed to release an extra \(formatMoney(bonus)) for transfers.")
            persist()
            return "The board approved your request — \(formatMoney(bonus)) added to the transfer budget."
        } else {
            boardConfidence = max(0, boardConfidence - 3)
            addNews(.board, "Budget request denied", "The board turned down your request for extra transfer funds.")
            persist()
            return "The board turned down your request."
        }
    }

    /// The last time the manager called a crisis meeting with the board.
    private(set) var lastClearAirDate: Date?

    /// Days until the manager can next request a clear-the-air meeting.
    var daysUntilNextClearAirMeeting: Int? {
        guard let last = lastClearAirDate,
              let days = Self.calendar.dateComponents([.day], from: last, to: currentDate).day,
              days < 45 else { return nil }
        return 45 - days
    }

    /// A crisis meeting with the board, only worth calling when things are
    /// genuinely under pressure — a coin-flip chance of a real reprieve,
    /// but no guarantee, and it doesn't cost anything either way.
    @discardableResult
    func requestClearTheAirMeeting() -> String {
        guard boardConfidence <= 40 else {
            return "The board don't feel the need for crisis talks right now."
        }
        guard daysUntilNextClearAirMeeting == nil else {
            return "You've already had that conversation recently."
        }
        lastClearAirDate = currentDate
        if Double.random(in: 0..<1) < 0.55 {
            boardConfidence = min(100, boardConfidence + 15)
            addNews(.board, "Clear-the-air meeting", "The board come away reassured after a frank conversation with the manager.")
            persist()
            return "The board are reassured — confidence has improved."
        } else {
            addNews(.board, "Clear-the-air meeting", "The meeting did little to ease the board's concerns.")
            persist()
            return "The meeting didn't go as hoped — the board remain unconvinced."
        }
    }

    /// Peak spells of players the user has managed (Hall of Fame), keyed by name.
    private(set) var hallOfFame: [String: HallEntry] = [:]
    private var lastHonourSeason = 0
    /// Set once the 30-season career has been ended by the manager.
    private(set) var careerEnded = false

    /// The manager's reputation, 0...100, driving job offers.
    private(set) var managerReputation = 45
    /// End-of-season job offers from rival clubs.
    private(set) var pendingJobOffers: [JobOffer] = []
    /// A club move accepted at season's end, applied next season.
    private(set) var pendingClubSwitch: Int?
    /// Whether the board sacked the manager this season.
    private(set) var wasSacked = false
    /// Years left on the manager's own contract at the current club — a
    /// separate, positive-or-negative moment from being sacked mid-tenure.
    private(set) var managerContractYears = 3

    /// A word describing the manager's standing.
    var reputationLabel: String {
        switch managerReputation {
        case 80...:   return "World-class"
        case 65..<80: return "Respected"
        case 50..<65: return "Established"
        case 35..<50: return "Up-and-coming"
        default:      return "Unproven"
        }
    }

    /// The career runs for 30 seasons (2000/01 → 2029/30).
    static let maxSeasons = 30

    /// The season as a "2000/01" style label.
    var seasonLabel: String {
        let start = (startYear - 1) + season
        return "\(start)/\(String(format: "%02d", (start + 1) % 100))"
    }

    /// Whether the final season has finished.
    var isFinalSeason: Bool { season >= Self.maxSeasons }

    /// The manager's chosen formation for the user's club.
    /// Changing it re-fills the starting XI with the best available side
    /// for the new shape.
    var formation: Formation = Formation.all[0] {
        didSet {
            if hasStarted && oldValue.name != formation.name {
                formationSwitchedDate = currentDate
                slotPins = [:]   // a different shape has different slot geometry
            }
            autoPickLineup()
        }
    }

    /// Explicit pitch-slot placements the manager has dragged into
    /// position on the tactics screen, keyed by "<position>-<index>".
    /// Purely a presentation concern — the match engine only cares who's
    /// in the XI, not which visual slot they're drawn in — but persisted
    /// so a carefully arranged formation survives a reload. A pin for a
    /// player who's no longer an available starter is simply ignored by
    /// whoever renders it, and falls back to the automatic best-fit slot.
    private(set) var slotPins: [String: UUID] = [:]

    /// Places a player in a specific pitch slot, or clears that slot if
    /// `playerID` is nil (used when a swap displaces a slot to empty).
    func setSlotPin(_ key: String, playerID: UUID?) {
        if let playerID {
            slotPins[key] = playerID
        } else {
            slotPins.removeValue(forKey: key)
        }
        persist()
    }

    /// Clears every manual pitch-slot placement, handing slot arrangement
    /// back to the automatic best-fit algorithm — an escape hatch if a
    /// drag has left the pitch in a confusing state.
    func resetSlotPins() {
        slotPins = [:]
        persist()
    }

    /// The date the manager last switched to a genuinely different
    /// formation — nil at game/save load, so the very first formation
    /// carries no penalty. A freshly switched shape takes a few matches
    /// to bed in, mirroring real tactical unfamiliarity.
    private(set) var formationSwitchedDate: Date?

    /// Whether the current formation is still bedding in — surfaced to the
    /// UI so a dip in results after a tactical switch isn't a mystery.
    var isFormationBeddingIn: Bool { formationFamiliarity < 1.0 }

    /// A small, tapering rating penalty applied to the user's XI while the
    /// current formation is still bedding in.
    private var formationFamiliarity: Double {
        guard let switchedDate = formationSwitchedDate else { return 1.0 }
        let days = Self.calendar.dateComponents([.day], from: switchedDate, to: currentDate).day ?? 999
        switch days {
        case ..<7:   return 0.93
        case 7..<14: return 0.97
        case 14..<21: return 0.99
        default: return 1.0
        }
    }

    /// The IDs of the players in the user's hand-picked starting XI.
    private(set) var userStarterIDs: Set<UUID> = []

    /// Assigned squad roles for the user's club.
    private(set) var captainID: UUID?
    private(set) var penaltyTakerID: UUID?
    private(set) var freeKickTakerID: UUID?
    private(set) var cornerTakerID: UUID?

    /// This season's youth-academy prospects the manager can promote.
    private(set) var youthProspects: [Player] = []
    /// The squad's weekly training emphasis.
    var trainingFocus: TrainingFocus = .balanced
    /// The chosen game difficulty.
    var difficulty: Difficulty = .normal

    /// True once a club has been chosen and the season is under way.
    private(set) var hasStarted = false

    /// Clubs per division.
    static let divisionSize = 20
    /// The names of the four English divisions, top to bottom.
    static let divisionNames = ["First Division", "Second Division", "Third Division", "Fourth Division"]

    func divisionName(_ tier: Int) -> String {
        Self.divisionNames.indices.contains(tier) ? Self.divisionNames[tier] : "Division \(tier + 1)"
    }

    /// Total number of matchdays — a double round-robin within one division.
    var totalMatchdays: Int { (Self.divisionSize - 1) * 2 }

    var isSeasonOver: Bool { currentMatchday > totalMatchdays }

    var userClub: Club { clubs[userClubIndex] }
    var userDivisionTier: Int { userClub.divisionTier }

    /// The global indices of the clubs in a division.
    func clubIndices(inTier tier: Int) -> [Int] {
        clubs.indices.filter { clubs[$0].divisionTier == tier }
    }

    // MARK: - Club catalogue

    /// Real club name pools for each division (used up to `divisionSize`).
    /// The First Division tier is the actual 2000/01 top flight, ordered by
    /// final league position so prestige (which decays by pool index) lines
    /// up with real sporting merit that season.
    private static let tierPools: [[String]] = [
        // First Division (2000/01 final table order)
        ["Old Trafford Reds", "Highbury", "Mersey Reds", "Elland Athletic", "Portman Rovers", "Stamford Blues", "Wearside",
         "Aston Rovers", "Valley Rovers", "Solent", "Tyneside", "White Hart Athletic", "Filbert Foxes",
         "Teesside", "Upton Athletic", "Goodison Blues", "Pride Rams", "Etihad Blues", "Highfield Athletic", "Valley Parade"],
        // Second Division (absorbs the 2000/01 Division One clubs displaced from the pool above)
        ["Craven Cottagers", "Ewood Rovers", "Trotters", "Molineux Old Gold", "Bramall Blades", "Hillsborough Owls", "Vicarage Hornets",
         "Selhurst Eagles", "Elm Royals", "Britannia Potters", "Ninian Bluebirds", "Turf Clarets", "Deepdale North End", "Loftus Hoops", "The Den Lions",
         "Boothferry Tigers", "Ashton Robins", "Home Park Argyle", "Oakwell Reds", "Springfield Latics", "Carrow Canaries"],
        // Third Division
        ["Fratton Blues", "Bloomfield Tangerines", "Boundary Athletic", "Griffin Bees", "Vetch Swans", "London Road Posh", "Bescot Saddlers",
         "Layer Us", "Priestfield Gills", "Prenton Rovers", "Dean Court Cherries", "Belle Rovers", "Huish Glovers", "Amex Seagulls",
         "Sixfields Cobblers", "Millmoor Millers", "Saltergate Spireites", "Gigg Shakers", "Vale Park", "Elland Athletic Road Terriers"],
        // Fourth Division
        ["Victoria Pool", "Spotland Dale", "Blundell Mariners", "Meadow Magpies", "Field Stags", "Gresty Railwaymen", "Sincil Imps",
         "Feethams Quakers", "Brunton Cumbrians", "St James Grecians", "Plainmoor Gulls", "Glanford Iron", "Whaddon Robins", "Moss Silkmen",
         "Meadow Shrews", "Roots Shrimpers", "Brisbane Os", "Memorial Pirates", "County Robins", "Racecourse Reds"],
    ]

    private static let tierBasePrestige = [84, 70, 60, 52]

    /// Curated primary colours for well-known clubs (visible on the dark UI).
    private static let clubColors: [String: [Double]] = [
        "Stamford Blues": [0.15, 0.35, 0.85], "Etihad Blues": [0.45, 0.75, 0.95],
        "Mersey Reds": [0.90, 0.20, 0.25], "Old Trafford Reds": [0.95, 0.25, 0.20],
        "Highbury": [0.95, 0.20, 0.22], "White Hart Athletic": [0.62, 0.68, 0.95],
        "Goodison Blues": [0.25, 0.45, 0.95], "Tyneside": [0.80, 0.80, 0.85],
        "Elland Athletic": [0.95, 0.85, 0.35], "Aston Rovers": [0.55, 0.20, 0.45],
        "Upton Athletic": [0.70, 0.30, 0.40], "Filbert Foxes": [0.30, 0.55, 0.95],
        "Solent": [0.95, 0.35, 0.35], "Molineux Old Gold": [0.95, 0.70, 0.25],
        "Portman Rovers": [0.20, 0.40, 0.80], "Wearside": [0.85, 0.15, 0.15],
        "Valley Rovers": [0.82, 0.12, 0.20], "Highfield Athletic": [0.35, 0.65, 0.92],
        "Valley Parade": [0.55, 0.15, 0.25], "Teesside": [0.80, 0.15, 0.15],
        "Bernabéu Whites": [0.65, 0.68, 0.78], "Camp Blaugrana": [0.55, 0.15, 0.55],
        "Bavarian Reds": [0.85, 0.15, 0.15], "Turin Bianconeri": [0.15, 0.15, 0.15],
        "San Siro Rossoneri": [0.85, 0.15, 0.15], "San Siro Nerazzurri": [0.15, 0.25, 0.55],
        "Amsterdam Godenzonen": [0.85, 0.15, 0.15], "Dragão Dragons": [0.15, 0.35, 0.65],
    ]

    private static let colorPalette: [[Double]] = [
        [0.90, 0.35, 0.35], [0.35, 0.62, 0.95], [0.95, 0.66, 0.25], [0.62, 0.42, 0.88],
        [0.35, 0.80, 0.55], [0.95, 0.52, 0.72], [0.42, 0.82, 0.86], [0.88, 0.82, 0.35],
        [0.95, 0.48, 0.28], [0.58, 0.78, 0.38],
    ]

    /// A stable primary colour for any club name.
    private static func clubColor(name: String) -> [Double] {
        if let curated = clubColors[name] { return curated }
        let hash = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colorPalette[hash % colorPalette.count]
    }

    /// A club's starting transfer budget (in £000s) from its prestige,
    /// baseline calibrated to year-2000 spending — a big top-flight club
    /// has a few tens of millions to spend, not hundreds — then scaled up
    /// by `economyMultiplier` for a later career start.
    private static func transferBudget(forPrestige prestige: Int, startYear: Int = 2000) -> Int {
        let base = pow(Double(prestige) / 45.0, 7.0) * 247.0
        return max(50, Int(base * economyMultiplier(startYear: startYear)))
    }

    /// Sentinel division for foreign clubs (they sit outside the pyramid but
    /// live in `clubs` so all index-based match code works for them too).
    static let foreignTier = 9
    /// The eight European giants outside the English pyramid, with a
    /// prestige range roughly matching their real 2000/01 stature — four
    /// go into the Continental Cup each season, four into the Midweek Cup.
    private static let foreignPool: [(name: String, prestige: ClosedRange<Int>)] = [
        ("Bernabéu Whites", 87...92), ("Camp Blaugrana", 86...91), ("Bavarian Reds", 85...90),
        ("Turin Bianconeri", 85...90), ("San Siro Rossoneri", 84...89), ("San Siro Nerazzurri", 83...88),
        ("Amsterdam Godenzonen", 77...83), ("Dragão Dragons", 75...81),
    ]

    /// A unique three-letter code for a club name.
    private static func uniqueCode(for name: String, used: inout Set<String>) -> String {
        let letters = name.uppercased().filter { $0.isLetter }
        var base = String(letters.prefix(3))
        while base.count < 3 { base += "X" }
        var code = base
        var suffix = 1
        while used.contains(code) {
            code = String(letters.prefix(2)) + "\(suffix)"
            suffix += 1
        }
        used.insert(code)
        return code
    }

    /// The full catalogue, generated deterministically (tier-major order).
    static func catalogueEntries() -> [(name: String, short: String, prestige: Int, tier: Int)] {
        var result: [(name: String, short: String, prestige: Int, tier: Int)] = []
        var used = Set<String>()
        for tier in tierPools.indices {
            let pool = Array(tierPools[tier].prefix(divisionSize))
            for (i, name) in pool.enumerated() {
                let prestige = clampRating(tierBasePrestige[tier] - Int(Double(i) * 0.9))
                result.append((name, uniqueCode(for: name, used: &used), prestige, tier))
            }
        }
        return result
    }

    /// Clubs the player can choose from, grouped by division.
    var clubsByDivision: [(tier: Int, name: String, clubs: [(index: Int, name: String, short: String)])] {
        let entries = Self.catalogueEntries()
        return (0..<Self.divisionNames.count).map { tier in
            let clubsInTier = entries.enumerated()
                .filter { $0.element.tier == tier }
                .map { (index: $0.offset, name: $0.element.name, short: $0.element.short) }
            return (tier, divisionName(tier), clubsInTier)
        }
    }

    /// A preview of what a club offers, shown on the confirmation screen before starting a new game.
    struct ClubPreview {
        let name: String
        let short: String
        let divisionName: String
        let divisionRank: Int
        let divisionSize: Int
        let prestige: Int
        let stars: Int
        let estimatedBudget: Int
        let boardObjective: String
        let colorRGB: [Double]
    }

    /// Builds a preview for a club without starting a game, using the same
    /// deterministic catalogue that `newGame(clubIndex:)` draws from.
    func clubPreview(forClubIndex index: Int, startYear: Int = 2000) -> ClubPreview? {
        let entries = Self.catalogueEntries()
        guard entries.indices.contains(index) else { return nil }
        let entry = entries[index]

        let tierEntries = entries.enumerated()
            .filter { $0.element.tier == entry.tier }
            .sorted { $0.element.prestige > $1.element.prestige }
        let rank = (tierEntries.firstIndex { $0.offset == index } ?? 0) + 1

        var budget = Self.transferBudget(forPrestige: entry.prestige, startYear: startYear)
        // Mirror newGame's retroactive ownership-change bump, so the
        // preview a manager sees before committing already reflects it —
        // otherwise a 2010+ Chelsea/Man City-equivalent would look
        // deceptively ordinary right up until the squad actually loads.
        for change in OwnershipChanges.all where change.year < startYear && change.club == entry.name {
            budget = max(0, budget + Int(Double(change.budgetInjection) * economyMultiplier(startYear: startYear)))
        }

        let objective: String
        if entry.tier == 0 {
            objective = rank <= 1 ? "Win the league"
                : rank <= 4 ? "Qualify for Europe (top 4)"
                : rank <= Self.divisionSize / 2 ? "Finish in the top half"
                : "Avoid relegation"
        } else {
            objective = rank <= 2 ? "Win automatic promotion (top 2)"
                : rank <= 6 ? "Reach the play-offs (top 6)"
                : rank <= Self.divisionSize / 2 ? "Finish in the top half"
                : (entry.tier == Self.divisionNames.count - 1 ? "Finish mid-table" : "Avoid relegation")
        }

        let stars: Int
        switch entry.prestige {
        case 86...:   stars = 5
        case 78..<86: stars = 4
        case 68..<78: stars = 3
        case 58..<68: stars = 2
        default:      stars = 1
        }

        return ClubPreview(name: entry.name, short: entry.short, divisionName: divisionName(entry.tier),
                           divisionRank: rank, divisionSize: tierEntries.count, prestige: entry.prestige,
                           stars: stars, estimatedBudget: budget, boardObjective: objective,
                           colorRGB: Self.clubColor(name: entry.name))
    }

    // MARK: - New game

    /// Builds the four-division pyramid with generated squads and fixtures.
    /// - Parameter clubIndex: The club the manager will control.
    func newGame(clubIndex: Int, startYear: Int = 2000) {
        currentSaveID = UUID()
        self.startYear = startYear
        clubs = Self.catalogueEntries().map { entry in
            var club = Club(name: entry.name,
                            shortName: entry.short,
                            players: Self.makeSquad(name: entry.name, prestige: entry.prestige, startYear: startYear))
            club.prestige = entry.prestige
            club.transferBudget = Self.transferBudget(forPrestige: entry.prestige, startYear: startYear)
            club.wageBudget = Int(Double(club.wageBill) * 1.4)
            club.divisionTier = entry.tier
            club.colorRGB = Self.clubColor(name: entry.name)
            return club
        }
        // A start year later than 2000 means some real-world ownership
        // changes (Stamford Blues 2003, Etihad Blues 2008, etc.) have
        // already happened by kickoff — the live news event for these is
        // skipped for anything dated before `startYear` (see
        // `checkOwnershipChanges`), so their cumulative budget/prestige
        // effect needs to be baked into the starting numbers directly
        // instead, or a 2010+ Chelsea/Man City-equivalent would start with
        // no trace of the takeover that actually defined their era.
        for change in OwnershipChanges.all where change.year < startYear {
            guard let index = clubs.firstIndex(where: { $0.name == change.club }) else { continue }
            let scaled = Int(Double(change.budgetInjection) * economyMultiplier(startYear: startYear))
            clubs[index].transferBudget = max(0, clubs[index].transferBudget + scaled)
            clubs[index].wageBudget = max(0, clubs[index].wageBudget + scaled / 6)
            if change.prestigeBoost != 0 {
                clubs[index].prestige = min(95, clubs[index].prestige + change.prestigeBoost)
            }
        }
        // Eight European giants outside the pyramid — four go into the
        // Continental Cup each season, four into the Midweek Cup.
        var usedCodes = Set(clubs.map { $0.shortName })
        for (name, prestigeRange) in Self.foreignPool {
            let prestige = Int.random(in: prestigeRange)
            var club = Club(name: name,
                            shortName: Self.uniqueCode(for: name, used: &usedCodes),
                            players: Self.makeSquad(name: name, prestige: prestige, startYear: startYear))
            club.prestige = prestige
            club.divisionTier = Self.foreignTier
            club.colorRGB = Self.clubColor(name: name)
            club.wageBudget = Int(Double(club.wageBill) * 1.4)
            clubs.append(club)
        }
        // Non-playable clubs from Spain, France, Italy and Germany's top two
        // divisions — background depth for a genuinely continental European
        // Cup / Midweek Cup field. Squads are generated, not researched.
        for division in ForeignLeagues.all {
            let prestigeRange = division.tier == 1 ? 62...78 : 48...62
            for name in division.clubs {
                let prestige = Int.random(in: prestigeRange)
                var club = Club(name: name,
                                shortName: Self.uniqueCode(for: name, used: &usedCodes),
                                players: Self.makeSquad(prestige: prestige, startYear: startYear))
                club.prestige = prestige
                club.divisionTier = division.divisionTier
                club.colorRGB = Self.clubColor(name: name)
                Self.applyForeignStars(to: &club, startYear: startYear)
                club.wageBudget = Int(Double(club.wageBill) * 1.4)
                clubs.append(club)
            }
        }
        managers = clubs.map { _ in Self.randomManagerName() }
        userClubIndex = clubIndex
        season = 1
        formationSwitchedDate = nil
        slotPins = [:]
        formation = Formation.all[0]
        startNewSeason(resetRecords: false)
        seedInjuries()
        generateTransferMarket()
        setBoardObjective()
        news = []
        unreadNewsIDs = []
        pendingOffers = []
        shortlistedPlayerIDs = []
        firedDatedEventIDs = []
        lastMonthlyAwardKey = 0
        monthlyAwardBaseline = [:]
        careerHonours = []
        history = []
        allTimeScorers = [:]
        allTimeAppearances = [:]
        careerRecordByClub = [:]
        motmTally = [:]
        clubTenureStart = [:]
        seasonLedger = []
        transferHistory = []
        pendingTransferDeals = []
        lastBudgetRequestDate = nil
        hallOfFame = [:]
        lastHonourSeason = 0
        careerEnded = false
        managerReputation = 40 + (3 - userDivisionTier) * 5   // PL 55 … Fourth Division 40
        fanConfidence = 60
        backroomStaff = []
        pendingJobOffers = []
        pendingClubSwitch = nil
        wasSacked = false
        captainID = nil; penaltyTakerID = nil; freeKickTakerID = nil; cornerTakerID = nil
        validateRoles()
        windowWasOpen = transferWindowOpen
        deadlineDayAnnounced = false
        transferBudgetAtWindowOpen = transferWindowOpen ? userClub.transferBudget : 0
        addNews(.info, "Welcome to \(userClub.name)", "Season \(season) begins. The board's objective: \(boardObjective).")
        hasStarted = true
        persist()
    }

    /// Regenerates fixtures and (optionally) clears season records.
    private func startNewSeason(resetRecords: Bool) {
        if resetRecords {
            for index in clubs.indices { clubs[index].resetSeason() }
            seasonLedger = []
            shortlistAlertedIDs = []
            objectiveRiskWarned = false
        }
        fixtures = makeAllFixtures()
        currentMatchday = 1
        lastReports = []
        currentDate = seasonStartDate
        // dailyTick never visits the season's own opening day (currentDate
        // jumps straight to it above), so anything date-triggered has to
        // be checked explicitly here too, or an event dated exactly to a
        // season's 1 July opener — like Ferro's fictional 2005 arrival — would
        // never fire under any circumstances, not just a missed one.
        checkRealTransferHeadlines()
        checkOwnershipChanges()
        checkMarqueePlayerArrivals()
        checkMarqueePlayerTransfers()
        allocateForeignClubsForSeason()
        startCup()
        startLeagueCup()
        startEuropeanCup()
        startUefaCup()
        startCommunityShield()
        startUefaSuperCup()
        generateYouthIntake()
        scheduleFriendlies()
        shuffleForeignDivisions()
    }

    /// A light touch of promotion/relegation for the four non-playable
    /// countries: one club swaps up, one swaps down, each season after the
    /// first (season 1 keeps the researched real-world placements). These
    /// clubs don't play a simulated table, so this stands in for it —
    /// enough that the European draw's background field isn't frozen forever.
    private func shuffleForeignDivisions() {
        guard season > 1 else { return }
        var promotedNames: [String] = []
        var relegatedNames: [String] = []
        for pair in [(ForeignLeagues.spainTier1, ForeignLeagues.spainTier2),
                     (ForeignLeagues.italyTier1, ForeignLeagues.italyTier2),
                     (ForeignLeagues.germanyTier1, ForeignLeagues.germanyTier2),
                     (ForeignLeagues.franceTier1, ForeignLeagues.franceTier2)] {
            let (tier1, tier2) = pair
            guard Double.random(in: 0..<1) < 0.6 else { continue }   // not every country shuffles every season
            guard let relegated = clubs.indices.filter({ clubs[$0].divisionTier == tier1 }).randomElement(),
                  let promoted = clubs.indices.filter({ clubs[$0].divisionTier == tier2 }).randomElement() else { continue }
            clubs[relegated].divisionTier = tier2
            clubs[relegated].prestige = Int.random(in: 48...62)
            clubs[promoted].divisionTier = tier1
            clubs[promoted].prestige = Int.random(in: 62...78)
            relegatedNames.append(clubs[relegated].name)
            promotedNames.append(clubs[promoted].name)
        }
        if !promotedNames.isEmpty {
            addNews(.world, "European football: promotion & relegation",
                    "Up: \(promotedNames.joined(separator: ", ")). Down: \(relegatedNames.joined(separator: ", ")).")
        }
    }

    /// Picks two distinct domestic opponents for the user's pre-season
    /// friendlies. Home/away alternates so both a home and away friendly
    /// happen most seasons.
    private func scheduleFriendlies() {
        let candidates = clubs.indices.filter { $0 != userClubIndex && clubs[$0].divisionTier < 4 }
        let opponents = Array(candidates.shuffled().prefix(2))
        friendlyFixtures = opponents.enumerated().map { offset, opponent in
            let isHome = offset % 2 == 0
            return Fixture(matchday: offset,
                           homeIndex: isHome ? userClubIndex : opponent,
                           awayIndex: isHome ? opponent : userClubIndex)
        }
    }

    /// Returns to the main menu (the game is saved automatically).
    func quitToMenu() {
        persist()
        hasStarted = false
    }

    // MARK: - Persistence

    /// The save slot currently open. Nil until a game is started or loaded.
    private(set) var currentSaveID: UUID?

    private static var legacySaveURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("fm_save.json")
    }

    /// Whether any saved career exists on disk — including a pre-multi-slot
    /// save that hasn't been migrated into the slot system yet.
    static var hasSavedGame: Bool {
        !SaveSlots.all().isEmpty || FileManager.default.fileExists(atPath: legacySaveURL.path)
    }

    /// Every save slot, most recently played first.
    static func savedGames() -> [SaveSlotInfo] {
        migrateLegacySaveIfNeeded()
        return SaveSlots.all()
    }

    /// A one-off migration: the game used to keep a single fixed save file.
    /// If that file is still there and hasn't been folded into a slot yet,
    /// give it a slot of its own so nobody's career is silently dropped.
    private static func migrateLegacySaveIfNeeded() {
        guard SaveSlots.all().isEmpty,
              let data = try? Data(contentsOf: legacySaveURL),
              let state = try? JSONDecoder().decode(SaveState.self, from: data) else { return }
        let id = UUID()
        try? data.write(to: SaveSlots.fileURL(for: id))
        let clubName = state.clubs.indices.contains(state.userClubIndex) ? state.clubs[state.userClubIndex].name : "Unknown"
        SaveSlots.upsert(SaveSlotInfo(id: id, clubName: clubName, managerName: "Manager",
                                       season: state.season, divisionName: "", lastPlayed: state.currentDate))
        try? FileManager.default.removeItem(at: legacySaveURL)
    }

    /// Removes a save slot from disk.
    static func deleteSave(id: UUID) {
        SaveSlots.remove(id)
    }

    /// Writes the essential game state to disk.
    func persist() {
        guard hasStarted else { return }
        let state = SaveState(season: season,
                              currentMatchday: currentMatchday,
                              userClubIndex: userClubIndex,
                              formationName: formation.name,
                              currentDate: currentDate,
                              boardObjective: boardObjective,
                              boardConfidence: boardConfidence,
                              fanConfidence: fanConfidence,
                              boardConfidenceTrend: boardConfidenceTrend,
                              managers: managers,
                              starterIDs: Array(userStarterIDs),
                              clubs: clubs,
                              fixtures: fixtures,
                              cupTies: cupTies,
                              cupRound: cupRound,
                              cupWinnerName: cupWinnerName,
                              leagueCupTies: leagueCupTies,
                              leagueCupRound: leagueCupRound,
                              leagueCupWinnerName: leagueCupWinnerName,
                              leagueCupWinnerID: leagueCupWinnerID,
                              careerHonours: careerHonours,
                              lastHonourSeason: lastHonourSeason,
                              euroTies: euroTies,
                              euroRound: euroRound,
                              euroWinnerName: euroWinnerName,
                              euroWinnerID: euroWinnerID,
                              europeanQualifierIDs: europeanQualifierIDs,
                              uefaCupTies: uefaCupTies,
                              uefaCupRound: uefaCupRound,
                              uefaCupWinnerName: uefaCupWinnerName,
                              uefaCupWinnerID: uefaCupWinnerID,
                              uefaCupQualifierIDs: uefaCupQualifierIDs,
                              uefaSuperCupTie: uefaSuperCupTie,
                              uefaSuperCupWinnerName: uefaSuperCupWinnerName,
                              lastSeasonEuroWinnerID: lastSeasonEuroWinnerID,
                              lastSeasonUefaCupWinnerID: lastSeasonUefaCupWinnerID,
                              managerReputation: managerReputation,
                              pendingJobOffers: pendingJobOffers,
                              pendingClubSwitch: pendingClubSwitch,
                              wasSacked: wasSacked,
                              captainID: captainID,
                              penaltyTakerID: penaltyTakerID,
                              freeKickTakerID: freeKickTakerID,
                              cornerTakerID: cornerTakerID,
                              communityShieldTie: communityShieldTie,
                              communityShieldWinnerName: communityShieldWinnerName,
                              cupWinnerID: cupWinnerID,
                              lastSeasonChampionID: lastSeasonChampionID,
                              lastSeasonRunnerUpID: lastSeasonRunnerUpID,
                              lastSeasonCupWinnerID: lastSeasonCupWinnerID,
                              history: history,
                              youthProspects: youthProspects,
                              allTimeScorers: allTimeScorers,
                              allTimeAppearances: allTimeAppearances,
                              careerRecordByClub: careerRecordByClub,
                              motmTally: motmTally,
                              clubTenureStart: clubTenureStart,
                              seasonLedger: seasonLedger,
                              transferHistory: transferHistory,
                              lastBudgetRequestDate: lastBudgetRequestDate,
                              lastClearAirDate: lastClearAirDate,
                              trainingFocus: trainingFocus,
                              hallOfFame: hallOfFame,
                              difficulty: difficulty,
                              shortlistedPlayerIDs: shortlistedPlayerIDs,
                              friendlyFixtures: friendlyFixtures,
                              formationSwitchedDate: formationSwitchedDate,
                              autoPickAssist: autoPickAssist,
                              delegateToAssistant: delegateToAssistant,
                              preferredMentality: preferredMentality,
                              backroomStaff: backroomStaff,
                              slotPins: slotPins,
                              firedDatedEventIDs: firedDatedEventIDs,
                              managerContractYears: managerContractYears,
                              startYear: startYear,
                              pendingTransferDeals: pendingTransferDeals,
                              unlockedAchievements: unlockedAchievements)
        guard let id = currentSaveID, let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: SaveSlots.fileURL(for: id))
        SaveSlots.upsert(SaveSlotInfo(id: id, clubName: userClub.name, managerName: "Manager",
                                       season: season, divisionName: divisionName(userDivisionTier),
                                       lastPlayed: Date()))
    }

    /// Restores a saved game from a specific slot, regenerating transient state.
    @discardableResult
    func loadSavedGame(id: UUID) -> Bool {
        guard let data = try? Data(contentsOf: SaveSlots.fileURL(for: id)),
              let state = try? JSONDecoder().decode(SaveState.self, from: data) else { return false }
        currentSaveID = id
        clubs = state.clubs
        fixtures = state.fixtures
        userClubIndex = state.userClubIndex
        currentMatchday = state.currentMatchday
        season = state.season
        currentDate = state.currentDate
        managers = state.managers
        boardObjective = state.boardObjective
        boardConfidence = state.boardConfidence
        fanConfidence = state.fanConfidence ?? 60
        boardConfidenceTrend = state.boardConfidenceTrend ?? 0
        // Set the formation first (its didSet auto-picks), then restore the XI.
        formation = Formation.all.first { $0.name == state.formationName } ?? Formation.all[0]
        userStarterIDs = Set(state.starterIDs)
        captainID = state.captainID
        penaltyTakerID = state.penaltyTakerID
        freeKickTakerID = state.freeKickTakerID
        cornerTakerID = state.cornerTakerID
        communityShieldTie = state.communityShieldTie
        communityShieldWinnerName = state.communityShieldWinnerName
        cupWinnerID = state.cupWinnerID
        lastSeasonChampionID = state.lastSeasonChampionID
        lastSeasonRunnerUpID = state.lastSeasonRunnerUpID
        lastSeasonCupWinnerID = state.lastSeasonCupWinnerID
        history = state.history
        youthProspects = state.youthProspects
        allTimeScorers = state.allTimeScorers
        allTimeAppearances = state.allTimeAppearances ?? [:]
        careerRecordByClub = state.careerRecordByClub ?? [:]
        motmTally = state.motmTally ?? [:]
        clubTenureStart = state.clubTenureStart ?? [:]
        seasonLedger = state.seasonLedger ?? []
        transferHistory = state.transferHistory ?? []
        lastBudgetRequestDate = state.lastBudgetRequestDate
        lastClearAirDate = state.lastClearAirDate
        trainingFocus = state.trainingFocus
        hallOfFame = state.hallOfFame
        difficulty = state.difficulty
        shortlistedPlayerIDs = state.shortlistedPlayerIDs
        friendlyFixtures = state.friendlyFixtures
        formationSwitchedDate = state.formationSwitchedDate
        autoPickAssist = state.autoPickAssist
        delegateToAssistant = state.delegateToAssistant ?? false
        preferredMentality = state.preferredMentality ?? .balanced
        backroomStaff = state.backroomStaff ?? []
        slotPins = state.slotPins
        firedDatedEventIDs = state.firedDatedEventIDs
        cupTies = state.cupTies
        cupRound = state.cupRound
        cupWinnerName = state.cupWinnerName
        leagueCupTies = state.leagueCupTies
        leagueCupRound = state.leagueCupRound
        leagueCupWinnerName = state.leagueCupWinnerName
        leagueCupWinnerID = state.leagueCupWinnerID
        careerHonours = state.careerHonours
        lastHonourSeason = state.lastHonourSeason
        euroTies = state.euroTies
        euroRound = state.euroRound
        euroWinnerName = state.euroWinnerName
        euroWinnerID = state.euroWinnerID
        europeanQualifierIDs = state.europeanQualifierIDs
        uefaCupTies = state.uefaCupTies
        uefaCupRound = state.uefaCupRound
        uefaCupWinnerName = state.uefaCupWinnerName
        uefaCupWinnerID = state.uefaCupWinnerID
        uefaCupQualifierIDs = state.uefaCupQualifierIDs
        uefaSuperCupTie = state.uefaSuperCupTie
        uefaSuperCupWinnerName = state.uefaSuperCupWinnerName
        lastSeasonEuroWinnerID = state.lastSeasonEuroWinnerID
        lastSeasonUefaCupWinnerID = state.lastSeasonUefaCupWinnerID
        managerReputation = state.managerReputation
        pendingJobOffers = state.pendingJobOffers
        pendingClubSwitch = state.pendingClubSwitch
        wasSacked = state.wasSacked
        managerContractYears = state.managerContractYears ?? 3
        startYear = state.startYear ?? 2000
        pendingTransferDeals = state.pendingTransferDeals ?? []
        unlockedAchievements = state.unlockedAchievements ?? []
        careerEnded = false
        // Rebuild transient state.
        news = []
        unreadNewsIDs = []
        pendingOffers = []
        scoutedReports = [:]
        scoutingDue = [:]
        generateTransferMarket()
        windowWasOpen = transferWindowOpen
        deadlineDayAnnounced = false
        transferBudgetAtWindowOpen = transferWindowOpen ? userClub.transferBudget : 0
        live = nil
        atPreMatch = false
        hasStarted = true
        addNews(.info, "Save loaded", "Welcome back to \(userClub.name). It's \(currentDate.formatted(.dateTime.day().month(.wide).year())).")
        return true
    }

    /// Starts the next season: ages and develops squads, resets transfer
    /// budgets, re-opens the transfer market and resets the board.
    func startNextSeason() {
        guard season < Self.maxSeasons else { endCareer(); return }
        resetTransferBudgets()     // fresh budget for the new season, from several factors
        awardSeasonHonours()       // Team of the Season / Golden Boot flavour news
        resolveForeignDomesticCups() // Copa del Rey / Coppa Italia / DFB-Pokal / Coupe de France
        applyPromotionRelegation() // shuffle clubs between divisions
        returnLoans()              // loanees go back to their parent clubs
        processContracts()         // run down deals; release the expired
        progressSquads()           // age, develop, retire, youth intake
        validateRoles()            // reassign captain/penalty/free-kick if the holder retired or left
        season += 1
        startNewSeason(resetRecords: true)
        logLedger("Season budget", amount: userClub.transferBudget, "Fresh budget for the new season")
        let commercial = Self.commercialRevenue(forPrestige: userClub.prestige, startYear: startYear)
        logLedger("Commercial", amount: commercial, "Kit sponsorship deal")
        addNews(.board, "Sponsorship deal",
                "\(userClub.name) agree a new kit sponsorship deal worth \(formatMoney(commercial)) for the season.")
        // Apply an accepted move (or forced move after a sacking).
        if let newClub = pendingClubSwitch, clubs.indices.contains(newClub) {
            userClubIndex = newClub
            managerContractYears = Int.random(in: 2...4)
            addNews(.board, "New chapter", "You are the new manager of \(clubs[newClub].name).")
        }
        pendingClubSwitch = nil
        pendingJobOffers = []
        wasSacked = false
        generateTransferMarket()
        setBoardObjective()
        autoPickLineup()
        pendingOffers = []
        windowWasOpen = transferWindowOpen
        deadlineDayAnnounced = false
        transferBudgetAtWindowOpen = transferWindowOpen ? userClub.transferBudget : 0
        addNews(.board, "Season \(season)", "A new campaign begins. Objective: \(boardObjective).")
        persist()
    }

    // MARK: - Season progression

    /// The relative worth of each division, top-heavy like the real game's
    /// finances — a First Division budget dwarfs a Fourth Division one.
    private static let tierBudgetScale: [Double] = [1.0, 0.30, 0.10, 0.035]

    /// Pays end-of-season prize money by final position, scaled down within
    /// each division so lower tiers stay small relative to the top flight.
    private static func seasonBudgetBonus(tier: Int, position: Int, startYear: Int = 2000) -> Int {
        let scale = tierBudgetScale[min(tier, tierBudgetScale.count - 1)]
        let base = 5_500.0 * scale
        let positionFactor = Double(divisionSize - position + 1) / Double(divisionSize)
        return max(30, Int(base * (0.4 + 0.6 * positionFactor) * economyMultiplier(startYear: startYear)))
    }

    /// A one-off bonus for silverware won this season, folded into the
    /// budget reset below rather than left as the old permanent add-on —
    /// most finals land after the transfer window has already closed, so
    /// the reward is really about strengthening the squad next season.
    private func seasonTrophyBonus(for club: Club) -> Int {
        var bonus = 0
        if cupWinnerID == club.id { bonus += 1_300 }
        if leagueCupWinnerID == club.id { bonus += 700 }
        if euroWinnerID == club.id { bonus += 3_500 }
        if uefaCupWinnerID == club.id { bonus += 1_800 }
        if communityShieldWinnerName == club.name { bonus += 300 }
        if uefaSuperCupWinnerName == club.name { bonus += 500 }
        return Int(Double(bonus) * economyMultiplier(startYear: startYear))
    }

    /// Resets every English-pyramid club's transfer budget for the new
    /// season, rather than letting it accumulate forever. Built from
    /// several factors: the club's underlying stature (prestige), how it
    /// finished the season just gone, any silverware it picked up, and a
    /// small board-mood swing (a strong sponsor renewal, an unexpectedly
    /// costly injury crisis) so it isn't perfectly predictable.
    private func resetTransferBudgets() {
        for tier in 0..<Self.divisionNames.count {
            for (position, club) in leagueTable(tier: tier).enumerated() {
                guard let index = clubs.firstIndex(where: { $0.id == club.id }) else { continue }
                let baseline = Self.transferBudget(forPrestige: club.prestige, startYear: startYear)
                let positionBonus = Self.seasonBudgetBonus(tier: tier, position: position + 1, startYear: startYear)
                let trophyBonus = seasonTrophyBonus(for: club)
                let commercial = Self.commercialRevenue(forPrestige: club.prestige, startYear: startYear)
                let boardMood = Double.random(in: 0.85...1.15)
                let newBudget = max(50, Int(Double(baseline + positionBonus + trophyBonus + commercial) * boardMood))
                clubs[index].transferBudget = newBudget
                clubs[index].wageBudget += positionBonus / 4
            }
        }
    }

    /// A season's kit-sponsorship income, scaled by prestige — bigger
    /// clubs land bigger commercial deals. Folded into the season budget
    /// reset alongside prize money and cup form.
    private static func commercialRevenue(forPrestige prestige: Int, startYear: Int = 2000) -> Int {
        let base = pow(Double(prestige) / 45.0, 5.0) * 60.0
        return max(20, Int(base * economyMultiplier(startYear: startYear)))
    }

    /// Flavour end-of-season news: the top division's champions, and the
    /// pyramid's outright top scorer — run before `startNewSeason` resets
    /// records, so this season's tallies are still live.
    private func awardSeasonHonours() {
        if let champion = leagueTable(tier: 0).first, let index = clubs.firstIndex(where: { $0.id == champion.id }) {
            addNews(.board, "Team of the Season",
                    "\(champion.name) are crowned \(divisionName(0)) champions under \(managers[index]), finishing on \(champion.points) points.")
        }
        let scorers = clubs.indices.filter { clubs[$0].divisionTier < 4 }
            .flatMap { clubIndex in clubs[clubIndex].players.map { (player: $0, clubName: clubs[clubIndex].name) } }
        if let top = scorers.filter({ $0.player.goals > 0 }).max(by: { $0.player.goals < $1.player.goals }) {
            addNews(.board, "Golden Boot",
                    "\(top.player.name) (\(top.clubName)) finishes the season as the pyramid's top scorer with \(top.player.goals) goals.")
        }
        awardManagerOfTheSeason()
        awardYoungPlayerOfTheSeason()
    }

    /// The pyramid's best young performer this season — any player 23 or
    /// under, ranked by season average match rating (a minimum handful of
    /// appearances so it isn't decided by one or two good cameos).
    private func awardYoungPlayerOfTheSeason() {
        let candidates = clubs.indices.filter { clubs[$0].divisionTier < 4 }
            .flatMap { clubIndex in clubs[clubIndex].players.map { (player: $0, clubName: clubs[clubIndex].name) } }
            .filter { $0.player.age <= 23 && $0.player.apps >= 10 }
        guard let best = candidates.max(by: { ($0.player.averageRating ?? 0) < ($1.player.averageRating ?? 0) }) else { return }
        addNews(.board, "Young Player of the Season",
                "\(best.player.name) (\(best.clubName)), age \(best.player.age), is named the pyramid's Young Player of the Season.")
    }

    /// The pyramid's Manager of the Season: whoever's club finished
    /// furthest above where their squad's raw prestige would have
    /// predicted — a reward for a genuine overachievement, across any
    /// division, not just whoever happened to win the biggest one.
    private func awardManagerOfTheSeason() {
        var best: (clubName: String, manager: String, overachievement: Int)?
        for tier in 0..<Self.divisionNames.count {
            let byPrestige = clubs.filter { $0.divisionTier == tier }.sorted { $0.prestige > $1.prestige }
            let table = leagueTable(tier: tier)
            for (actualIndex, club) in table.enumerated() {
                guard let prestigeRank = byPrestige.firstIndex(where: { $0.id == club.id }),
                      let clubIndex = clubs.firstIndex(where: { $0.id == club.id }) else { continue }
                let overachievement = prestigeRank - actualIndex
                if overachievement > (best?.overachievement ?? 0) {
                    best = (club.name, managers[clubIndex], overachievement)
                }
            }
        }
        guard let best, best.overachievement > 0 else { return }
        addNews(.board, "Manager of the Season",
                "\(best.manager) (\(best.clubName)) takes Manager of the Season, defying expectations by finishing \(best.overachievement) place\(best.overachievement == 1 ? "" : "s") higher than their squad's reputation suggested.")
    }

    /// Auto-promotes the top two, promotes a play-off winner (from 3rd–6th),
    /// and relegates the bottom three of each division.
    private func applyPromotionRelegation() {
        var moves: [(id: UUID, newTier: Int)] = []
        var playoffMessages: [(title: String, body: String)] = []

        for tier in 0..<Self.divisionNames.count {
            let table = leagueTable(tier: tier)
            if tier > 0 {
                // Automatic promotion.
                for club in table.prefix(2) { moves.append((club.id, tier - 1)) }
                // Play-offs for positions 3–6.
                let contenders = Array(table.dropFirst(2).prefix(4))
                if let winner = simulatePlayoff(contenders) {
                    moves.append((winner.id, tier - 1))
                    playoffMessages.append(("\(divisionName(tier)) play-offs",
                        "\(winner.name) win the play-off final and are promoted to the \(divisionName(tier - 1))!"))
                }
            }
            if tier < Self.divisionNames.count - 1 {
                for club in table.suffix(3) { moves.append((club.id, tier + 1)) }
            }
        }

        let userOldTier = userDivisionTier
        for move in moves {
            if let index = clubs.firstIndex(where: { $0.id == move.id }) {
                clubs[index].divisionTier = move.newTier
            }
        }
        for message in playoffMessages { addNews(.result, message.title, message.body) }

        let userNewTier = userDivisionTier
        if userNewTier < userOldTier {
            addNews(.board, "Promotion!", "\(userClub.name) are promoted to the \(divisionName(userNewTier))!")
        } else if userNewTier > userOldTier {
            addNews(.board, "Relegation", "\(userClub.name) are relegated to the \(divisionName(userNewTier)).")
        }
    }

    /// Simulates a four-team play-off (3v6, 4v5, then final) and returns the
    /// promoted club, weighting each tie by squad strength.
    private func simulatePlayoff(_ contenders: [Club]) -> Club? {
        guard contenders.count >= 4 else { return contenders.first }
        let semi1 = playoffWinner(contenders[0], contenders[3])   // 3rd v 6th
        let semi2 = playoffWinner(contenders[1], contenders[2])   // 4th v 5th
        return playoffWinner(semi1, semi2)
    }

    private func playoffWinner(_ a: Club, _ b: Club) -> Club {
        let strengthA = strengthValue(bestXI(for: a, formation: aiFormation(for: a)))
        let strengthB = strengthValue(bestXI(for: b, formation: aiFormation(for: b)))
        let probabilityA = strengthA / (strengthA + strengthB)
        return Double.random(in: 0..<1) < probabilityA ? a : b
    }

    /// Ages every player a year, develops the young, declines the old,
    /// retires veterans and refreshes squads with youth intake.
    ///
    /// Mutates each surviving player in place rather than rebuilding them
    /// via `makePlayer` — that used to hand out a fresh random `id` and a
    /// re-rolled `detailedPosition`/`secondaryPositions` for every player,
    /// every season. The new `id` orphaned anything that remembered the
    /// old one (the shortlist, captain/penalty/free-kick roles), and the
    /// random role reassignment meant a real player's known position
    /// (e.g. a converted winger at right wing) silently scrambled after one season.
    private func progressSquads() {
        for clubIndex in clubs.indices {
            var kept: [Player] = []
            var retirees: [Player] = []
            for var player in clubs[clubIndex].players {
                let age = player.age + 1
                var rating = player.rating
                switch age {
                case ..<24:   rating += Int.random(in: 0...2)
                case 24...29: rating += Int.random(in: -1...1)
                case 30...32: rating -= Int.random(in: 0...2)
                default:      rating -= Int.random(in: 1...3)
                }
                rating = min(94, max(40, rating))
                // Veterans retire; everyone else carries on with reset season stats.
                if age >= 38 || (age >= 35 && Bool.random()) {
                    var retiree = player
                    retiree.age = age
                    retirees.append(retiree)
                    continue
                }
                player.age = age
                player.rating = rating
                player.value = playerValue(rating: rating, age: age, startYear: startYear)
                player.wage = playerWage(rating: rating, age: age, startYear: startYear)
                player.attributes = makeAttributes(position: player.position, rating: rating)
                player.isTransferListed = false
                player.wantsToLeave = false
                kept.append(player)
            }
            clubs[clubIndex].players = kept
            ensureSquad(clubIndex: clubIndex)

            // Only worth a headline for the user's own club, and only for
            // players who actually made a mark — not every departing
            // squad-filler youth-team player.
            if clubIndex == userClubIndex {
                for retiree in retirees where retiree.rating >= 65 {
                    addNews(.board, "Retirement",
                            "\(retiree.name) has announced his retirement from professional football, at \(retiree.age).")
                }
                // Ten years' unbroken service earns a testimonial — tenure is
                // only tracked from when this save started, so a player
                // already long-serving when a career begins won't be
                // credited for time served before that.
                for player in kept {
                    if clubTenureStart[player.id] == nil {
                        clubTenureStart[player.id] = season
                    } else if let start = clubTenureStart[player.id], season - start == 10 {
                        let bonus = 400
                        clubs[clubIndex].transferBudget += bonus
                        logLedger("Testimonial", amount: bonus, "\(player.name)'s testimonial match")
                        addNews(.board, "Testimonial match",
                                "\(player.name) is awarded a testimonial match for ten years' service to \(userClub.name) — gate proceeds boost the transfer budget.")
                    }
                }
                let currentIDs = Set(kept.map { $0.id })
                clubTenureStart = clubTenureStart.filter { currentIDs.contains($0.key) }
            }
        }
    }

    /// Tops up a club with generated youngsters to keep a full squad.
    private func ensureSquad(clubIndex: Int) {
        let minimums: [(Position, Int)] = [(.goalkeeper, 2), (.defender, 6), (.midfielder, 6), (.forward, 4)]
        for (position, minimum) in minimums {
            var count = clubs[clubIndex].players.filter { $0.position == position }.count
            while count < minimum {
                let rating = Self.clampRating(clubs[clubIndex].prestige + Int.random(in: -20 ... -3))
                clubs[clubIndex].players.append(
                    Self.makePlayer(position: position, age: Int.random(in: 17...20), rating: rating, startYear: startYear))
                count += 1
            }
        }
    }

    // MARK: - Transfer market

    /// Builds a fresh market of surplus players and free agents.
    private func generateTransferMarket() {
        var targets: [TransferTarget] = []
        for index in clubs.indices where index != userClubIndex && clubs[index].divisionTier < 4 {
            let surplus = clubs[index].players.sorted { $0.rating < $1.rating }.prefix(3)
            for player in surplus {
                targets.append(TransferTarget(player: player, sellingClubIndex: index,
                                              askingPrice: Int(Double(player.value) * Double.random(in: 1.1...1.5))))
            }
        }
        for _ in 0..<6 {
            let player = Self.makeFreeAgent(startYear: startYear)
            targets.append(TransferTarget(player: player, sellingClubIndex: nil, askingPrice: player.value))
        }
        transferMarket = targets.shuffled()
        scoutedReports = [:]
        scoutingDue = [:]
        negotiationRounds = [:]
    }

    /// English football's transfer deadline in 2000/01 was a single date —
    /// 31 March — not the two-window (summer/January) system, which wasn't
    /// introduced until the 2002/03 season.
    private var transferDeadlineDate: Date {
        let deadlineYear = Self.calendar.component(.year, from: seasonStartDate) + 1
        return Self.calendar.date(from: DateComponents(year: deadlineYear, month: 3, day: 31)) ?? seasonStartDate
    }

    var transferWindowOpen: Bool {
        currentDate <= transferDeadlineDate
    }

    /// Days left until the window shuts, while it's still open.
    var daysUntilTransferDeadline: Int? {
        guard transferWindowOpen else { return nil }
        let days = Self.calendar.dateComponents([.day], from: currentDate, to: transferDeadlineDate).day ?? 0
        return max(0, days)
    }

    /// The final couple of days before the deadline — AI activity spikes.
    var isDeadlineDayRush: Bool {
        guard let days = daysUntilTransferDeadline else { return false }
        return days <= 2
    }

    /// A label for the window state.
    var transferWindowStatus: String {
        guard transferWindowOpen else { return "CLOSED — reopens for the new season" }
        if let days = daysUntilTransferDeadline, days <= 2 {
            return days == 0 ? "DEADLINE DAY" : "OPEN — \(days) day\(days == 1 ? "" : "s") to deadline"
        }
        return "OPEN — until the 31 March deadline"
    }

    /// Signs a player from the market. Returns a message for the UI.
    @discardableResult
    func buyPlayer(_ target: TransferTarget) -> String {
        guard transferWindowOpen else { return "The transfer window is closed." }
        guard transferMarket.contains(where: { $0.id == target.id }) else {
            return "That player is no longer available."
        }
        guard userClub.transferBudget >= target.askingPrice else {
            return "Not enough transfer budget (need \(formatMoney(target.askingPrice)))."
        }
        guard userClub.wageBill + target.player.wage <= userClub.wageBudget else {
            return "Wage budget won't stretch that far (\(formatMoney(target.player.wage))/wk needed, \(formatMoney(max(0, userClub.wageBudget - userClub.wageBill)))/wk free)."
        }
        guard userClub.players.count < 30 else { return "Your squad is full (30 players)." }
        return beginPersonalTermsWait(target, price: target.askingPrice, sellOnPercentage: 0, buyBackFee: 0, includedPlayer: nil)
    }

    /// Moves a deal from "fee agreed" to "medical & personal terms
    /// pending" — the player leaves the seller's squad right away (a club
    /// doesn't keep playing someone it's agreed to sell) but doesn't join
    /// yours until personal terms are actually settled days later, same as
    /// a real transfer. No money changes hands yet.
    private func beginPersonalTermsWait(_ target: TransferTarget, price: Int, sellOnPercentage: Int, buyBackFee: Int, includedPlayer: Player?) -> String {
        guard let sellerIndex = target.sellingClubIndex,
              let playerIndex = clubs[sellerIndex].players.firstIndex(where: { $0.id == target.player.id }) else {
            return "That deal has fallen through."
        }
        let player = clubs[sellerIndex].players.remove(at: playerIndex)
        transferMarket.removeAll { $0.id == target.id }
        let readyDate = Self.calendar.date(byAdding: .day, value: Int.random(in: 1...3), to: currentDate) ?? currentDate
        let deal = PendingTransferDeal(id: UUID(), player: player, sellingClubIndex: sellerIndex,
                                       sellingClubName: clubs[sellerIndex].name, agreedFee: price,
                                       sellOnPercentage: sellOnPercentage, buyBackFee: buyBackFee,
                                       includedPlayerID: includedPlayer?.id, includedPlayerName: includedPlayer?.name,
                                       readyDate: readyDate)
        pendingTransferDeals.append(deal)
        let message = "Fee of \(formatMoney(price)) agreed with \(clubs[sellerIndex].name) for \(player.name) — medical and personal terms to follow."
        addNews(.transfer, "Fee agreed", message, player: player, clubName: clubs[sellerIndex].name)
        persist()
        return message
    }

    /// Checks every pending deal's medical/paperwork clock, called once a
    /// day — when it runs out, the manager is told the player's ready to
    /// actually discuss personal terms.
    private func checkPendingTransferDeals() {
        for index in pendingTransferDeals.indices
        where !pendingTransferDeals[index].isReady && currentDate >= pendingTransferDeals[index].readyDate {
            pendingTransferDeals[index].isReady = true
            let deal = pendingTransferDeals[index]
            addNews(.transfer, "\(deal.player.name) ready to talk terms",
                    "\(deal.player.name)'s medical is done — he's ready to discuss personal terms about his move from \(deal.sellingClubName).",
                    player: deal.player, clubName: deal.sellingClubName)
        }
    }

    /// The wage a player would want to actually sign for a new club, for
    /// the personal-terms negotiation UI — a modest step up on what he was
    /// on before, same shape as `freeAgentWageDemand`.
    func transferWageDemand(_ player: Player) -> Int {
        Int(Double(player.wage) * 1.15) + 1
    }

    /// Settles personal terms on a pending transfer deal — the step that
    /// actually completes the move. Money, the player and any makeweight
    /// only move on success; a rejection leaves the deal open to retry
    /// (or to walk away from via `withdrawPendingDeal`).
    @discardableResult
    func finalizePersonalTerms(_ deal: PendingTransferDeal, wage: Int, years: Int, signingOnFee: Int = 0) -> ContractOutcome {
        guard let dealIndex = pendingTransferDeals.firstIndex(where: { $0.id == deal.id }) else {
            return .rejected(reason: "That deal is no longer on the table.", counterWage: nil)
        }
        guard pendingTransferDeals[dealIndex].isReady else {
            return .rejected(reason: "\(deal.player.name) isn't ready to talk terms yet.", counterWage: nil)
        }
        guard userClub.wageBill + wage <= userClub.wageBudget else {
            return .rejected(reason: "The board won't sanction that wage — it would break the club's wage budget.", counterWage: nil)
        }
        guard userClub.transferBudget >= deal.agreedFee + signingOnFee else {
            return .rejected(reason: "The transfer budget can no longer cover the \(formatMoney(deal.agreedFee)) fee plus that signing-on fee.", counterWage: nil)
        }
        guard userClub.players.count < 30 else {
            return .rejected(reason: "Your squad is full (30 players).", counterWage: nil)
        }

        let demand = transferWageDemand(deal.player)
        let wageRatio = Double(wage) / Double(max(demand, 1))
        var chance = 0.55 + (wageRatio - 1.0) * 1.2
        chance += (Double(deal.player.morale) - 50) / 300
        chance += deal.player.personality.renewalChanceAdjustment
        chance += min(0.08, Double(signingOnFee) / Double(max(demand, 1)) * 0.02)
        chance = min(0.97, max(0.05, chance))

        guard Double.random(in: 0..<1) < chance else {
            let reason = wageRatio < 0.9
                ? "\(deal.player.name) felt \(formatMoney(wage))/wk fell well short of what he wanted to make the move."
                : "\(deal.player.name) wasn't quite convinced by those personal terms."
            let counterWage = wageRatio < 1.05 ? Int(Double(demand) * 1.08) : nil
            return .rejected(reason: reason, counterWage: counterWage)
        }

        var extras = ""
        clubs[deal.sellingClubIndex].transferBudget += deal.agreedFee
        if let includedPlayerID = deal.includedPlayerID,
           let ownIndex = clubs[userClubIndex].players.firstIndex(where: { $0.id == includedPlayerID }) {
            var makeweight = clubs[userClubIndex].players.remove(at: ownIndex)
            makeweight.morale = 65
            makeweight.isTransferListed = false
            clubs[deal.sellingClubIndex].players.append(makeweight)
            userStarterIDs.remove(makeweight.id)
            validateRoles()
            extras += " \(makeweight.name) moved the other way as part of the deal."
        }
        var signing = deal.player
        signing.wage = wage
        signing.contractYears = years
        signing.morale = 78
        signing.isTransferListed = false
        if deal.sellOnPercentage > 0 {
            signing.sellOnClause = SellOnClause(club: deal.sellingClubName, percentage: deal.sellOnPercentage)
            extras += " \(deal.sellingClubName) retain a \(deal.sellOnPercentage)% sell-on clause."
        }
        if deal.buyBackFee > 0 {
            signing.buyBackClause = BuyBackClause(club: deal.sellingClubName, fee: deal.buyBackFee)
            extras += " \(deal.sellingClubName) hold a \(formatMoney(deal.buyBackFee)) buy-back option."
        }
        clubs[userClubIndex].players.append(signing)
        clubs[userClubIndex].transferBudget -= (deal.agreedFee + signingOnFee)
        if signingOnFee > 0 {
            extras += " Signing-on fee: \(formatMoney(signingOnFee))."
        }
        pendingTransferDeals.remove(at: dealIndex)
        let message = "Signed \(deal.player.name) from \(deal.sellingClubName) for \(formatMoney(deal.agreedFee))." + extras
        addNews(.transfer, "Signing complete", message, player: signing, clubName: deal.sellingClubName)
        logLedger("Transfer in", amount: -deal.agreedFee, "Signed \(deal.player.name)")
        logTransferHistory(deal.player.name, action: "Signed", otherClub: deal.sellingClubName, fee: deal.agreedFee)
        persist()
        return .accepted(message)
    }

    /// Walks away from a pending deal before personal terms are settled —
    /// the player simply returns to the selling club, since nothing about
    /// the move was ever finalised.
    @discardableResult
    func withdrawPendingDeal(_ deal: PendingTransferDeal) -> String {
        guard let dealIndex = pendingTransferDeals.firstIndex(where: { $0.id == deal.id }) else {
            return "That deal is no longer on the table."
        }
        let removed = pendingTransferDeals.remove(at: dealIndex)
        if clubs.indices.contains(removed.sellingClubIndex) {
            clubs[removed.sellingClubIndex].players.append(removed.player)
        }
        persist()
        return "Talks with \(removed.player.name) broken off."
    }

    /// The result of putting a cash bid to a selling club: either they
    /// accept outright, or knock it back — sometimes with a counter figure
    /// they'd actually listen to, sometimes dismissing it entirely.
    enum BidOutcome {
        case accepted(String)
        case rejected(reason: String, counterPrice: Int?)
    }

    /// Proposes a transfer fee below (or at) the asking price. A genuine
    /// multi-round negotiation, not a single accept/reject roll: the gap
    /// narrows with each round rather than the club repeating the same
    /// counter forever, a club under real financial pressure will settle
    /// for less than a wealthy one, and dragging it out too long — or
    /// lowballing too hard — makes them walk away from the table entirely
    /// for the rest of this window.
    @discardableResult
    func proposeBid(_ target: TransferTarget, amount: Int, sellOnPercentage: Int = 0, buyBackFee: Int = 0, includedPlayer: Player? = nil) -> BidOutcome {
        guard transferWindowOpen else { return .rejected(reason: "The transfer window is closed.", counterPrice: nil) }
        guard transferMarket.contains(where: { $0.id == target.id }) else {
            return .rejected(reason: "That deal has fallen through — they're no longer willing to talk.", counterPrice: nil)
        }
        guard userClub.players.count < 30 else { return .rejected(reason: "Your squad is full (30 players).", counterPrice: nil) }
        guard userClub.transferBudget >= amount else {
            return .rejected(reason: "Not enough transfer budget to make that offer.", counterPrice: nil)
        }
        if let includedPlayer {
            guard userClub.players.contains(where: { $0.id == includedPlayer.id }) else {
                return .rejected(reason: "\(includedPlayer.name) is no longer available to include in the deal.", counterPrice: nil)
            }
        }

        // Free agents don't cost a fee at all — they're signed on personal
        // terms via `signFreeAgent` instead, so this path is club-to-club only.
        guard let sellerIndex = target.sellingClubIndex else {
            return .rejected(reason: "\(target.player.name) is a free agent — sort a contract with him instead of a fee.", counterPrice: nil)
        }

        let seller = clubs[sellerIndex]
        // A club whose transfer budget is thin next to its wage bill has
        // real financial pressure and less leverage to hold out for full price.
        let underPressure = seller.transferBudget < seller.wageBill * 8
        let acceptThreshold = underPressure ? 0.90 : 1.0
        let walkAwayThreshold = underPressure ? 0.55 : 0.68

        // A makeweight player adds real value to the deal from the seller's
        // side; a sell-on cut or a stingy buy-back fee sweetens it further —
        // each nudges their willingness to say yes without changing the cash
        // gap that drives the counter-offer figure shown back to the user.
        let effectiveOffer = amount + (includedPlayer?.value ?? 0)
        var ratio = Double(effectiveOffer) / Double(max(target.askingPrice, 1))
        ratio += Double(sellOnPercentage) / 100.0 * 0.15
        if buyBackFee > 0 {
            let discount = max(0, 1 - Double(buyBackFee) / Double(max(target.player.value, 1)))
            ratio += discount * 0.12
        }

        let attempt = (negotiationRounds[target.id] ?? 0) + 1
        negotiationRounds[target.id] = attempt

        if ratio >= acceptThreshold {
            negotiationRounds[target.id] = nil
            return .accepted(beginPersonalTermsWait(target, price: amount, sellOnPercentage: sellOnPercentage, buyBackFee: buyBackFee, includedPlayer: includedPlayer))
        }

        if attempt >= 4 || ratio < walkAwayThreshold {
            negotiationRounds[target.id] = nil
            transferMarket.removeAll { $0.id == target.id }
            return .rejected(reason: "\(seller.name) have walked away from the table — that's the end of this deal, for now.", counterPrice: nil)
        }

        let gap = Double(target.askingPrice) - Double(amount)
        let concession = min(0.55, 0.22 + Double(attempt) * 0.08)
        let counter = min(target.askingPrice, amount + Int(gap * concession))
        let roundLabel = attempt >= 3 ? "final offer" : "counter"
        return .rejected(reason: "\(seller.name) turned that down — their \(roundLabel) is \(formatMoney(counter)).", counterPrice: counter)
    }

    /// Sells one of the user's players. Returns a message for the UI.
    @discardableResult
    func sellPlayer(_ player: Player) -> String {
        guard transferWindowOpen else { return "The transfer window is closed." }
        guard userClub.players.count > 15 else { return "You must keep at least 16 players." }
        let cover = userClub.players.filter { $0.position == player.position }.count
        let minimumCover = player.position == .goalkeeper ? 2 : 3
        guard cover > minimumCover else { return "Not enough cover at \(player.position.rawValue) to sell." }
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return "That player is not in your squad."
        }
        let marketFee = Int(Double(player.value) * 0.9)
        var fee = marketFee
        var extras = ""
        if let clause = player.buyBackClause, clause.fee < marketFee {
            fee = clause.fee
            extras += " \(clause.club) triggered their \(formatMoney(clause.fee)) buy-back clause."
        }
        if let clause = player.sellOnClause {
            let cut = Int(Double(fee) * Double(clause.percentage) / 100.0)
            if cut > 0, let clubIndex = clubs.firstIndex(where: { $0.name == clause.club }) {
                clubs[clubIndex].transferBudget += cut
                fee -= cut
                extras += " \(clause.club) took a \(clause.percentage)% sell-on cut of \(formatMoney(cut))."
            }
        }
        clubs[userClubIndex].players.remove(at: index)
        clubs[userClubIndex].transferBudget += fee
        userStarterIDs.remove(player.id)
        validateRoles()
        let message = "Sold \(player.name) for \(formatMoney(fee))." + extras
        addNews(.transfer, "Player sold", message, player: player)
        logLedger("Transfer out", amount: fee, "Sold \(player.name)")
        logTransferHistory(player.name, action: "Sold", otherClub: nil, fee: fee)
        persist()
        return message
    }

    /// Toggles whether one of the user's players is listed for sale.
    func toggleTransferList(_ player: Player) {
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else { return }
        clubs[userClubIndex].players[index].isTransferListed.toggle()
    }

    /// Returns the current, possibly-updated version of a squad player.
    func currentPlayer(_ id: UUID) -> Player? {
        clubs[userClubIndex].players.first { $0.id == id }
    }

    // MARK: - AI transfers & offers

    /// One rival-to-rival transfer, keeping the world's squads moving.
    /// Picks an index with probability proportional to `weight`, so richer
    /// or more prestigious clubs act more often without ever excluding the
    /// smaller ones. Falls back to a plain random pick if all weights are 0.
    private func weightedRandomIndex(from indices: [Int], weight: (Int) -> Double) -> Int? {
        let weights = indices.map { max(0.1, weight($0)) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return indices.randomElement() }
        var roll = Double.random(in: 0..<total)
        for (index, w) in zip(indices, weights) {
            if roll < w { return index }
            roll -= w
        }
        return indices.last
    }

    /// A rich, in-form club buys more often and can reach further up a
    /// seller's squad list — a squad genuinely gets stronger after a big
    /// ownership-driven budget boost, rather than sitting static forever.
    /// Names that follow a scripted real-world path (`MarqueePlayers`) and
    /// so must never get swept up in ordinary random AI transfer activity
    /// — otherwise Ronaldo Basso could end up wherever the random churn sends
    /// him instead of Old Trafford Reds, Bernabéu Whites, and so on.
    private static let marqueeProtectedNames: Set<String> = {
        Set(MarqueePlayers.arrivals.map { $0.name } + MarqueePlayers.transfers.map { $0.name })
    }()

    private func processAITransfer() {
        let aiClubs = clubs.indices.filter { $0 != userClubIndex && clubs[$0].divisionTier < 4 }
        guard let buyer = weightedRandomIndex(from: aiClubs, weight: { sqrt(Double(clubs[$0].transferBudget)) }) else { return }
        guard let seller = aiClubs.filter({ $0 != buyer }).randomElement() else { return }
        let ranked = clubs[seller].players.sorted { $0.rating > $1.rating }
        guard ranked.count > 15 else { return }
        // A well-funded buyer can shop closer to the seller's best XI; a
        // modest one is limited to squad depth, same as before.
        let skip = clubs[buyer].transferBudget > 20_000 ? 3 : 9
        let pool = Array(ranked.dropFirst(skip)).filter { !Self.marqueeProtectedNames.contains($0.name) }
        guard let target = weightedRandomIndex(from: pool.indices.map { $0 }, weight: { Double(pool[$0].rating) * Double(pool[$0].rating) })
            .map({ pool[$0] }) else { return }
        let price = Int(Double(target.value) * Double.random(in: 1.0...1.4))
        guard clubs[buyer].transferBudget >= price else { return }

        if let index = clubs[seller].players.firstIndex(where: { $0.id == target.id }) {
            clubs[seller].players.remove(at: index)
        }
        clubs[seller].transferBudget += price
        clubs[buyer].players.append(target)
        clubs[buyer].transferBudget -= price
        transferMarket.removeAll { $0.player.id == target.id }
        addNews(.transfer, "Transfer completed",
                "\(clubs[buyer].name) sign \(target.name) from \(clubs[seller].name) for \(formatMoney(price)).")
    }

    /// A rival club bids for one of the user's players.
    private func generateOfferForUser() {
        let listed = userClub.players.filter { $0.isTransferListed }
        let pool = listed.isEmpty ? userClub.players.filter { $0.rating >= 72 } : listed
        guard let target = pool.randomElement() else { return }
        // A release clause is a contractual floor — any bid meets it or beats it.
        let price = max(target.releaseClause ?? 0, Int(Double(target.value) * Double.random(in: 1.0...1.5)))
        let buyers = clubs.indices.filter { $0 != userClubIndex && clubs[$0].divisionTier < 4 && clubs[$0].transferBudget >= price }
        guard let buyer = buyers.randomElement() else { return }
        let expiry = Self.calendar.date(byAdding: .day, value: 6, to: currentDate) ?? currentDate
        pendingOffers.append(TransferOffer(playerID: target.id, playerName: target.name,
                                           fromClubIndex: buyer, amount: price, expiryDate: expiry))
        let clauseNote = target.releaseClause != nil ? " — his release clause has been triggered" : ""
        addNews(.offer, "Bid received",
                "\(clubs[buyer].name) have bid \(formatMoney(price)) for \(target.name)\(clauseNote). Respond in Transfers.")
    }

    /// Drops offers that have passed their deadline.
    private func expireOffers() {
        let live = pendingOffers.filter { $0.expiryDate >= currentDate }
        if live.count != pendingOffers.count { pendingOffers = live }
    }

    /// Accepts a rival's bid: sells the player and banks the fee.
    @discardableResult
    func acceptOffer(_ offer: TransferOffer) -> String {
        guard let offerIndex = pendingOffers.firstIndex(where: { $0.id == offer.id }) else { return "Offer withdrawn." }
        guard let playerIndex = clubs[userClubIndex].players.firstIndex(where: { $0.id == offer.playerID }) else {
            pendingOffers.remove(at: offerIndex)
            return "That player has already left."
        }
        let player = clubs[userClubIndex].players[playerIndex]
        let cover = userClub.players.filter { $0.position == player.position }.count
        let minimumCover = player.position == .goalkeeper ? 2 : 3
        guard userClub.players.count > 15, cover > minimumCover else {
            return "Can't sell \(player.name) — not enough squad cover."
        }
        clubs[userClubIndex].players.remove(at: playerIndex)
        clubs[userClubIndex].transferBudget += offer.amount
        clubs[offer.fromClubIndex].players.append(player)
        clubs[offer.fromClubIndex].transferBudget = max(0, clubs[offer.fromClubIndex].transferBudget - offer.amount)
        userStarterIDs.remove(player.id)
        validateRoles()
        pendingOffers.remove(at: offerIndex)
        addNews(.transfer, "Player sold",
                "You accepted \(clubs[offer.fromClubIndex].name)'s \(formatMoney(offer.amount)) bid for \(player.name).",
                player: player, clubName: clubs[offer.fromClubIndex].name)
        logLedger("Transfer out", amount: offer.amount, "Sold \(player.name) to \(clubs[offer.fromClubIndex].name)")
        logTransferHistory(player.name, action: "Sold", otherClub: clubs[offer.fromClubIndex].name, fee: offer.amount)
        persist()
        return "Sold \(player.name) for \(formatMoney(offer.amount))."
    }

    /// Rejects a rival's bid.
    func rejectOffer(_ offer: TransferOffer) {
        pendingOffers.removeAll { $0.id == offer.id }
        addNews(.info, "Bid rejected", "You turned down the bid for \(offer.playerName).")
    }

    // MARK: - Shortlist

    func isShortlisted(_ playerID: UUID) -> Bool {
        shortlistedPlayerIDs.contains(playerID)
    }

    /// Adds or removes a player from the watchlist.
    func toggleShortlist(_ playerID: UUID) {
        if shortlistedPlayerIDs.contains(playerID) {
            shortlistedPlayerIDs.remove(playerID)
        } else {
            shortlistedPlayerIDs.insert(playerID)
        }
        persist()
    }

    /// Every shortlisted player still found in the world, with their current club.
    var shortlistedResults: [(player: Player, clubIndex: Int)] {
        guard !shortlistedPlayerIDs.isEmpty else { return [] }
        var results: [(player: Player, clubIndex: Int)] = []
        for (index, club) in clubs.enumerated() {
            for player in club.players where shortlistedPlayerIDs.contains(player.id) {
                results.append((player, index))
            }
        }
        return results.sorted { $0.player.rating > $1.player.rating }
    }

    // MARK: - Scouting

    /// The scouting state of a transfer target.
    enum ScoutState { case unscouted, inProgress, scouted(ScoutReport) }

    func scoutState(for target: TransferTarget) -> ScoutState {
        if let report = scoutedReports[target.id] { return .scouted(report) }
        if scoutingDue[target.id] != nil { return .inProgress }
        return .unscouted
    }

    /// Sends a scout to assess a target; the report takes three days.
    func scout(_ target: TransferTarget) {
        guard scoutedReports[target.id] == nil, scoutingDue[target.id] == nil else { return }
        let days = max(1, 3 - staffLevel(.chiefScout))
        scoutingDue[target.id] = Self.calendar.date(byAdding: .day, value: days, to: currentDate) ?? currentDate
        addNews(.info, "Scout assigned", "A scout is watching \(target.player.name). Report in ~\(days) day\(days == 1 ? "" : "s").")
    }

    /// Finalises any scouting assignments whose deadline has passed.
    private func completeScouting() {
        let ready = scoutingDue.filter { $0.value <= currentDate }
        guard !ready.isEmpty else { return }
        for (id, _) in ready {
            scoutingDue.removeValue(forKey: id)
            guard let target = transferMarket.first(where: { $0.id == id }) else { continue }
            let report = makeScoutReport(for: target.player)
            scoutedReports[id] = report
            addNews(.info, "Scout report: \(target.player.name)", report.verdict)
        }
    }

    private func makeScoutReport(for player: Player) -> ScoutReport {
        let growth: Int
        switch player.age {
        case ..<21:   growth = Int.random(in: 4...12)
        case 21...24: growth = Int.random(in: 1...7)
        case 25...28: growth = Int.random(in: 0...3)
        default:      growth = -Int.random(in: 0...3)
        }
        let potential = min(95, max(player.rating, player.rating + growth))

        let squadAverage = averageRating(atPosition: player.position, forClubIndex: userClubIndex)
        let verdict: String
        if player.rating >= squadAverage + 3 {
            verdict = "Clear upgrade on your current \(player.position.rawValue) options."
        } else if player.rating >= squadAverage - 2 {
            verdict = "A useful squad player at \(player.position.rawValue)."
        } else if potential >= squadAverage + 2 {
            verdict = "Raw, but strong potential — one for the future."
        } else {
            verdict = "Below the level of your current squad."
        }
        let note = "Age \(player.age) · current \(player.rating) · potential ~\(potential)."
        return ScoutReport(playerID: player.id, playerName: player.name, potential: potential, verdict: verdict, note: note)
    }

    /// Sends the scouting network out into the wider world (or specifically
    /// after youth talent) rather than waiting on a single named target —
    /// surfaces a handful of players from other clubs who weren't already
    /// on the market, adds them as biddable targets at a premium (their
    /// club isn't actively trying to sell), and has a full report ready
    /// immediately, since this is the payoff of an active scouting mission
    /// rather than a report on someone already spotted.
    @discardableResult
    func scoutTheWorld(youthOnly: Bool) -> String {
        guard transferWindowOpen else { return "The transfer window is closed." }
        let alreadyListedIDs = Set(transferMarket.map { $0.player.id })
        var candidates: [(clubIndex: Int, player: Player)] = []
        for (index, club) in clubs.enumerated() where index != userClubIndex {
            for player in club.players where !alreadyListedIDs.contains(player.id) {
                if youthOnly && player.age > 20 { continue }
                candidates.append((index, player))
            }
        }
        guard !candidates.isEmpty else {
            return youthOnly ? "No fresh young talent turned up this time — try again soon."
                              : "Nothing new turned up this time — try again soon."
        }
        // Bias toward the more promising finds without it always being
        // the single best player in the pyramid.
        let sorted = candidates.sorted { $0.player.rating > $1.player.rating }
        let pool = Array(sorted.prefix(min(sorted.count, 14))).shuffled()
        let picks = Array(pool.prefix(Int.random(in: 1...3)))

        var names: [String] = []
        for pick in picks {
            let target = TransferTarget(player: pick.player, sellingClubIndex: pick.clubIndex,
                                        askingPrice: Int(Double(pick.player.value) * Double.random(in: 1.4...1.9)))
            transferMarket.append(target)
            scoutedReports[target.id] = makeScoutReport(for: pick.player)
            names.append(pick.player.name)
        }
        let headline = youthOnly ? "Youth scouting mission" : "World scouting mission"
        let body = "Your scouts turned up \(names.count) player\(names.count == 1 ? "" : "s"): \(names.joined(separator: ", "))."
        addNews(.info, headline, body)
        return "Found \(names.count) new target\(names.count == 1 ? "" : "s") — check your scout reports."
    }

    private func averageRating(atPosition position: Position, forClubIndex index: Int) -> Int {
        let group = clubs[index].players.filter { $0.position == position }
        guard !group.isEmpty else { return 60 }
        return group.reduce(0) { $0 + $1.rating } / group.count
    }

    // MARK: - Loans

    /// Loans a player in from a rival for the season (wages only, no fee).
    @discardableResult
    func loanIn(_ target: TransferTarget) -> String {
        guard transferWindowOpen else { return "The transfer window is closed." }
        guard let sellerIndex = target.sellingClubIndex else { return "Free agents can't be loaned." }
        guard userClub.players.count < 30 else { return "Your squad is full (30 players)." }
        guard let marketIndex = transferMarket.firstIndex(where: { $0.id == target.id }) else {
            return "That player is no longer available."
        }
        guard let playerIndex = clubs[sellerIndex].players.firstIndex(where: { $0.id == target.player.id }) else {
            return "That player is no longer available."
        }
        var player = clubs[sellerIndex].players.remove(at: playerIndex)
        player.onLoanFromClubIndex = sellerIndex
        player.isTransferListed = false
        player.wantsToLeave = false
        clubs[userClubIndex].players.append(player)
        transferMarket.remove(at: marketIndex)
        addNews(.transfer, "Loan agreed", "You loaned \(player.name) from \(clubs[sellerIndex].name) for the season.")
        persist()
        return "Loaned \(player.name) for the season."
    }

    /// The result of approaching a club about taking a loanee: either they
    /// agree, or they pass with a reason.
    enum LoanOutcome {
        case accepted(String)
        case rejected(reason: String)
    }

    /// Rival clubs plausibly willing to take a loanee — weighted toward
    /// clubs genuinely short at his position rather than just anyone with
    /// a spare squad slot, so the shortlist reads like real interest
    /// instead of a random pick. Falls back to any club with room if
    /// nobody's especially short there.
    func loanCandidates(for player: Player) -> [Int] {
        let needy = clubs.indices.filter { index in
            guard index != userClubIndex, clubs[index].players.count < 30 else { return false }
            return clubs[index].players.filter { $0.position == player.position }.count <= 5
        }
        let pool = needy.isEmpty
            ? clubs.indices.filter { $0 != userClubIndex && clubs[$0].players.count < 30 }
            : needy
        return Array(pool.shuffled().prefix(4))
    }

    /// Proposes loaning a squad player out to a specific club. Real loan
    /// logic: they need genuine space at his position and the wage budget
    /// to carry him for the loan, and a requested fee makes them think
    /// twice. Loans move fast in real football, so this is a single
    /// yes/no per approach rather than a haggling negotiation — a rejected
    /// fee can simply be tried again lower.
    @discardableResult
    func proposeLoanOut(_ player: Player, toClubIndex: Int, fee: Int = 0) -> LoanOutcome {
        guard transferWindowOpen else { return .rejected(reason: "The transfer window is closed.") }
        guard !player.isOnLoan else { return .rejected(reason: "You can't loan out a loanee.") }
        guard userClub.players.count > 15 else { return .rejected(reason: "You must keep at least 16 players.") }
        guard let playerIndex = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return .rejected(reason: "That player is not in your squad.")
        }
        guard clubs.indices.contains(toClubIndex), toClubIndex != userClubIndex else {
            return .rejected(reason: "That club isn't a valid destination.")
        }
        let destination = clubs[toClubIndex]
        guard destination.players.count < 30 else {
            return .rejected(reason: "\(destination.name)'s squad is already full.")
        }
        guard destination.wageBill + player.wage <= destination.wageBudget else {
            return .rejected(reason: "\(destination.name) can't fit \(formatMoney(player.wage))/wk into their wage budget.")
        }
        guard destination.transferBudget >= fee else {
            return .rejected(reason: "\(destination.name) won't stretch to a \(formatMoney(fee)) loan fee.")
        }

        let positionCount = destination.players.filter { $0.position == player.position }.count
        let needFactor = max(0, 6 - positionCount)
        var chance = 0.35 + Double(needFactor) * 0.1
        chance -= Double(fee) / Double(max(player.value, 1)) * 0.6
        chance += (Double(destination.prestige) - Double(userClub.prestige)) / 300
        chance = min(0.92, max(0.05, chance))

        guard Double.random(in: 0..<1) < chance else {
            let reason = positionCount > 5
                ? "\(destination.name) already have enough cover at \(player.position.rawValue) and passed."
                : (fee > 0 ? "\(destination.name) weren't willing to pay a fee for the loan." : "\(destination.name) weren't convinced and passed on the move.")
            return .rejected(reason: reason)
        }

        var loanee = clubs[userClubIndex].players.remove(at: playerIndex)
        loanee.onLoanFromClubIndex = userClubIndex
        clubs[toClubIndex].players.append(loanee)
        if fee > 0 {
            clubs[toClubIndex].transferBudget -= fee
            clubs[userClubIndex].transferBudget += fee
        }
        userStarterIDs.remove(player.id)
        validateRoles()
        var message = "\(player.name) joined \(destination.name) on loan for the season."
        if fee > 0 { message += " Loan fee: \(formatMoney(fee))." }
        addNews(.transfer, "Loan out agreed", message, player: loanee, clubName: destination.name)
        logTransferHistory(player.name, action: "Loaned out", otherClub: destination.name, fee: fee > 0 ? fee : nil)
        persist()
        return .accepted(message)
    }

    /// Everyone the user's club currently has out on loan, and where.
    func playersOnLoanFromUser() -> [(player: Player, clubIndex: Int)] {
        clubs.indices.flatMap { clubIndex in
            clubs[clubIndex].players
                .filter { $0.onLoanFromClubIndex == userClubIndex }
                .map { (player: $0, clubIndex: clubIndex) }
        }
    }

    /// Recalls a loanee back to the parent club early, ending the loan.
    @discardableResult
    func recallFromLoan(_ player: Player) -> String {
        guard let hostIndex = clubs.firstIndex(where: { club in
            club.players.contains { $0.id == player.id && $0.onLoanFromClubIndex == userClubIndex }
        }) else {
            return "\(player.name) isn't out on loan from your club."
        }
        guard let playerIndex = clubs[hostIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return "\(player.name) isn't out on loan from your club."
        }
        var recalled = clubs[hostIndex].players.remove(at: playerIndex)
        let formerClub = clubs[hostIndex].name
        recalled.onLoanFromClubIndex = nil
        clubs[userClubIndex].players.append(recalled)
        addNews(.transfer, "Loan recalled", "\(recalled.name) has been recalled from \(formerClub) back to \(userClub.name).")
        persist()
        return "\(recalled.name) recalled from \(formerClub)."
    }

    /// Whether this player can be released by mutual consent — real clubs
    /// don't just give away a happy, effective squad member for nothing,
    /// so this only applies to the unsettled or the ageing.
    func canTerminateContract(_ player: Player) -> Bool {
        player.wantsToLeave || player.age >= 33
    }

    /// Responds to a player's transfer request: either agree to list him
    /// for sale, or try to talk him round. Talking round isn't guaranteed —
    /// it depends on his personality — and failing leaves him just as
    /// unhappy as before, so ignoring a request isn't a free option.
    @discardableResult
    func respondToTransferRequest(_ player: Player, agreeToList: Bool) -> String {
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }),
              clubs[userClubIndex].players[index].wantsToLeave else {
            return "\(player.name) hasn't asked to leave."
        }
        if agreeToList {
            clubs[userClubIndex].players[index].isTransferListed = true
            clubs[userClubIndex].players[index].morale = min(100, clubs[userClubIndex].players[index].morale + 8)
            addNews(.board, "Transfer request granted",
                    "\(player.name) has been listed for sale after asking to leave.")
            persist()
            return "\(player.name) has been listed for sale."
        }
        let chance = 0.4 + clubs[userClubIndex].players[index].personality.renewalChanceAdjustment
        if Double.random(in: 0..<1) < chance {
            clubs[userClubIndex].players[index].wantsToLeave = false
            clubs[userClubIndex].players[index].isTransferListed = false
            clubs[userClubIndex].players[index].morale = min(100, clubs[userClubIndex].players[index].morale + 15)
            addNews(.board, "Player talked round",
                    "\(player.name) has agreed to stay and fight for his place.")
            persist()
            return "\(player.name) has agreed to stay, for now."
        } else {
            clubs[userClubIndex].players[index].morale = max(0, clubs[userClubIndex].players[index].morale - 10)
            addNews(.board, "Still unhappy",
                    "\(player.name) wasn't convinced by the talk — he still wants to leave.")
            persist()
            return "\(player.name) wasn't convinced. He still wants out."
        }
    }

    /// Releases a player early, outside the transfer market entirely — no
    /// fee comes in, and the club pays a severance package, but it frees
    /// the wage budget immediately rather than waiting out the contract.
    @discardableResult
    func terminateContract(_ player: Player) -> String {
        guard userClub.players.count > 15 else { return "You must keep at least 16 players." }
        guard canTerminateContract(player) else {
            return "\(player.name) has no interest in leaving — this only works for unsettled or veteran players."
        }
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return "That player is not in your squad."
        }
        let severance = max(50, player.wage * 4)
        guard userClub.transferBudget >= severance else {
            return "The club can't afford the severance package (\(formatMoney(severance)))."
        }
        clubs[userClubIndex].players.remove(at: index)
        clubs[userClubIndex].transferBudget -= severance
        userStarterIDs.remove(player.id)
        validateRoles()
        logLedger("Contract termination", amount: -severance, "\(player.name) released by mutual consent")
        logTransferHistory(player.name, action: "Released", otherClub: nil, fee: nil)
        addNews(.transfer, "Contract terminated",
                "\(player.name) has left \(userClub.name) by mutual consent, with a severance payment of \(formatMoney(severance)).")
        persist()
        return "\(player.name) released by mutual consent."
    }

    /// Returns every loanee to their parent club at season's end.
    private func returnLoans() {
        var returning: [Player] = []
        for clubIndex in clubs.indices {
            let (loanees, kept) = clubs[clubIndex].players.reduce(into: ([Player](), [Player]())) { result, player in
                if player.isOnLoan { result.0.append(player) } else { result.1.append(player) }
            }
            clubs[clubIndex].players = kept
            returning.append(contentsOf: loanees)
        }
        for var player in returning {
            let parent = player.onLoanFromClubIndex ?? userClubIndex
            player.onLoanFromClubIndex = nil
            if clubs.indices.contains(parent) { clubs[parent].players.append(player) }
        }
    }

    // MARK: - Contracts & morale

    /// The user's own players with a year or less left on their deal —
    /// worth renewing proactively on your own terms, even though a
    /// contract can no longer just run out and cost you the player.
    var expiringContracts: [Player] {
        userClub.players
            .filter { $0.contractYears <= 1 }
            .sorted { $0.contractYears != $1.contractYears ? $0.contractYears < $1.contractYears : $0.rating > $1.rating }
    }

    /// A player's standing in the pecking order right now — ability-based,
    /// with a boost for anyone nailed on in the user's own starting XI and
    /// an override for clear academy prospects. Computed rather than
    /// stored so it always reflects the squad's current shape.
    func squadRole(for player: Player) -> SquadRole {
        if player.age <= 20 && player.rating < 78 { return .youthProspect }
        let isOwnStarter = userStarterIDs.contains(player.id)
        switch player.rating {
        case 85...:
            return .starPlayer
        case 75..<85:
            return isOwnStarter ? .starPlayer : .firstTeamRegular
        case 65..<75:
            return isOwnStarter ? .firstTeamRegular : .rotation
        default:
            return isOwnStarter ? .rotation : .backup
        }
    }

    /// The wage a player would demand to renew, for the negotiation UI —
    /// scaled by their squad role rather than a flat markup, so a star's
    /// demands and a fringe player's are genuinely different conversations.
    func renewalDemand(_ player: Player) -> Int {
        Int(Double(player.wage) * squadRole(for: player).wageDemandMultiplier) + 1
    }

    /// The result of putting a contract offer to a player. A rejection
    /// carries the specific reason, and — when wage was the sticking
    /// point — a counter-offer figure the player would likely accept.
    enum ContractOutcome {
        case accepted(String)
        case rejected(reason: String, counterWage: Int?)
    }

    /// Puts a wage-and-length offer to a squad player. Whether they accept
    /// depends on how the wage compares to their demand, their current
    /// morale, and — for longer or very short deals — their age.
    @discardableResult
    func proposeRenewal(_ player: Player, wage: Int, years: Int, releaseClause: Int? = nil, signingOnFee: Int = 0) -> ContractOutcome {
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return .rejected(reason: "That player is not in your squad.", counterWage: nil)
        }
        let projectedBill = userClub.wageBill - player.wage + wage
        guard projectedBill <= userClub.wageBudget else {
            return .rejected(reason: "The board won't sanction that wage — it would break the club's wage budget.", counterWage: nil)
        }
        guard signingOnFee <= userClub.transferBudget else {
            return .rejected(reason: "The board won't sanction a signing-on fee of that size — it would exceed the transfer budget.", counterWage: nil)
        }
        let demand = renewalDemand(player)
        let wageRatio = Double(wage) / Double(max(demand, 1))
        var chance = 0.5 + (wageRatio - 1.0) * 1.2
        chance += (Double(player.morale) - 50) / 250
        if years <= 1 && player.age < 30 { chance -= 0.12 }
        if years >= 4 && player.age >= 32 { chance -= 0.15 }
        chance += player.personality.renewalChanceAdjustment
        chance += min(0.08, Double(signingOnFee) / Double(max(demand, 1)) * 0.02)
        chance = min(0.97, max(0.03, chance))

        if Double.random(in: 0..<1) < chance {
            clubs[userClubIndex].players[index].contractYears = years
            clubs[userClubIndex].players[index].wage = wage
            clubs[userClubIndex].players[index].morale = min(100, clubs[userClubIndex].players[index].morale + 12)
            clubs[userClubIndex].players[index].wantsToLeave = false
            clubs[userClubIndex].players[index].releaseClause = releaseClause
            if signingOnFee > 0 {
                clubs[userClubIndex].transferBudget -= signingOnFee
            }
            var message = "\(player.name) signed a new \(years)-year deal at \(formatMoney(wage))/wk."
            if signingOnFee > 0 {
                message += " Signing-on fee: \(formatMoney(signingOnFee))."
            }
            if let releaseClause {
                message += " Release clause: \(formatMoney(releaseClause))."
            }
            addNews(.board, "Contract renewed", message, player: clubs[userClubIndex].players[index], clubName: userClub.name)
            persist()
            return .accepted(message)
        } else {
            clubs[userClubIndex].players[index].morale = max(0, clubs[userClubIndex].players[index].morale - 4)
            persist()

            // The single biggest reason, so the decline actually explains
            // itself instead of always blaming the wage.
            let reason: String
            if wageRatio < 0.9 {
                reason = "\(player.name) felt \(formatMoney(wage))/wk fell well short of his valuation."
            } else if years <= 1 && player.age < 30 {
                reason = "\(player.name) wants a longer commitment than \(years) year\(years == 1 ? "" : "s") at his age."
            } else if years >= 4 && player.age >= 32 {
                reason = "\(player.name) felt \(years) years was too long a deal at his age."
            } else if player.morale < 45 {
                reason = "\(player.name) is unhappy at the club right now and isn't ready to commit."
            } else {
                reason = "\(player.name) turned down the offer — wanted a little more."
            }

            // A counter only makes sense if wage was actually the sticking
            // point, and the club could plausibly afford to go higher.
            let counterWage: Int?
            if wageRatio < 1.05 {
                let proposed = Int(Double(demand) * 1.08)
                counterWage = (userClub.wageBill - player.wage + proposed <= userClub.wageBudget) ? proposed : nil
            } else {
                counterWage = nil
            }
            return .rejected(reason: reason, counterWage: counterWage)
        }
    }

    /// A negotiated transfer fee for signing any player directly (e.g. from
    /// search) — their base value (already driven by ability and age) with
    /// a premium or discount for how much contract time their club has left
    /// to hold them to. A long deal costs more to prise them out of; an
    /// expiring one costs much less, since the club's leverage is gone.
    func negotiatedFee(for player: Player) -> Int {
        let contractFactor: Double
        switch player.contractYears {
        case ...0: contractFactor = 0.45
        case 1:    contractFactor = 0.7
        case 2:    contractFactor = 1.0
        case 3:    contractFactor = 1.2
        default:   contractFactor = 1.45
        }
        return max(50, Int(Double(player.value) * contractFactor))
    }

    /// Signs a player found via search straight from their club, at a
    /// negotiated fee. Unlike the transfer market, this isn't limited to
    /// pre-generated targets — any player at any club is fair game.
    @discardableResult
    func signFromSearch(clubIndex: Int, playerID: UUID) -> String {
        guard transferWindowOpen else { return "The transfer window is closed." }
        guard clubIndex != userClubIndex else { return "\(userClub.name) can't buy from itself." }
        guard clubs.indices.contains(clubIndex),
              let playerIndex = clubs[clubIndex].players.firstIndex(where: { $0.id == playerID }) else {
            return "That player is no longer available."
        }
        let player = clubs[clubIndex].players[playerIndex]
        let fee = negotiatedFee(for: player)
        guard userClub.transferBudget >= fee else {
            return "Not enough transfer budget (need \(formatMoney(fee)))."
        }
        guard userClub.wageBill + player.wage <= userClub.wageBudget else {
            return "Wage budget won't stretch that far (\(formatMoney(player.wage))/wk needed, \(formatMoney(max(0, userClub.wageBudget - userClub.wageBill)))/wk free)."
        }
        guard userClub.players.count < 30 else { return "Your squad is full (30 players)." }

        clubs[clubIndex].players.remove(at: playerIndex)
        clubs[clubIndex].transferBudget += fee
        var signing = player
        signing.morale = 75
        signing.isTransferListed = false
        clubs[userClubIndex].players.append(signing)
        clubs[userClubIndex].transferBudget -= fee
        addNews(.transfer, "Signing complete", "You signed \(player.name) from \(clubs[clubIndex].name) for \(formatMoney(fee)).",
               player: signing, clubName: clubs[clubIndex].name)
        logLedger("Transfer in", amount: -fee, "Signed \(player.name) from \(clubs[clubIndex].name)")
        logTransferHistory(player.name, action: "Signed", otherClub: clubs[clubIndex].name, fee: fee)
        persist()
        return "Signed \(player.name) from \(clubs[clubIndex].name) for \(formatMoney(fee))."
    }

    /// The wage a free agent (or a player whose contract has already run
    /// out) would want to sign — there's no club to negotiate a fee with,
    /// so the whole negotiation is just personal terms.
    func freeAgentWageDemand(_ player: Player) -> Int {
        Int(Double(player.wage) * 1.1) + 1
    }

    /// Signs a player who costs no transfer fee at all — a genuine free
    /// agent from the market, or someone found via search whose contract
    /// has already expired — on agreed personal terms. Mirrors
    /// `proposeRenewal`'s negotiation math since it's fundamentally the
    /// same kind of conversation, just landing the player at a new club.
    @discardableResult
    func signFreeAgent(_ player: Player, fromClubIndex: Int?, wage: Int, years: Int, signingOnFee: Int = 0) -> ContractOutcome {
        guard transferWindowOpen else { return .rejected(reason: "The transfer window is closed.", counterWage: nil) }
        guard userClub.players.count < 30 else { return .rejected(reason: "Your squad is full (30 players).", counterWage: nil) }
        let projectedBill = userClub.wageBill + wage
        guard projectedBill <= userClub.wageBudget else {
            return .rejected(reason: "The board won't sanction that wage — it would break the club's wage budget.", counterWage: nil)
        }
        guard signingOnFee <= userClub.transferBudget else {
            return .rejected(reason: "The board won't sanction a signing-on fee of that size — it would exceed the transfer budget.", counterWage: nil)
        }

        let demand = freeAgentWageDemand(player)
        let wageRatio = Double(wage) / Double(max(demand, 1))
        var chance = 0.55 + (wageRatio - 1.0) * 1.2
        chance += (Double(player.morale) - 50) / 300
        chance += player.personality.renewalChanceAdjustment
        chance += min(0.08, Double(signingOnFee) / Double(max(demand, 1)) * 0.02)
        chance = min(0.97, max(0.05, chance))

        guard Double.random(in: 0..<1) < chance else {
            let reason = wageRatio < 0.9
                ? "\(player.name) felt \(formatMoney(wage))/wk fell well short of what he could get elsewhere."
                : "\(player.name) wasn't quite convinced by those terms."
            let counterWage = wageRatio < 1.05 ? Int(Double(demand) * 1.08) : nil
            return .rejected(reason: reason, counterWage: counterWage)
        }

        if let fromClubIndex, clubs.indices.contains(fromClubIndex),
           let playerIndex = clubs[fromClubIndex].players.firstIndex(where: { $0.id == player.id }) {
            clubs[fromClubIndex].players.remove(at: playerIndex)
        }
        var signing = player
        signing.wage = wage
        signing.contractYears = years
        signing.morale = 78
        signing.isTransferListed = false
        clubs[userClubIndex].players.append(signing)
        if signingOnFee > 0 {
            clubs[userClubIndex].transferBudget -= signingOnFee
        }
        transferMarket.removeAll { $0.player.id == player.id }
        let otherClub = fromClubIndex.flatMap { clubs.indices.contains($0) ? clubs[$0].name : nil }
        var message = "\(player.name) signed on a free transfer — a \(years)-year deal at \(formatMoney(wage))/wk."
        if signingOnFee > 0 {
            message += " Signing-on fee: \(formatMoney(signingOnFee))."
        }
        addNews(.transfer, "Free transfer complete", message, player: signing, clubName: otherClub)
        logTransferHistory(player.name, action: "Signed (free)", otherClub: otherClub, fee: nil)
        persist()
        return .accepted(message)
    }

    /// After a match, players who didn't feature lose a little morale; the
    /// unhappy and repeatedly-benched may ask to leave.
    private func updateSquadMorale(appearedIDs: Set<UUID>) {
        for index in clubs[userClubIndex].players.indices {
            let player = clubs[userClubIndex].players[index]
            guard !appearedIDs.contains(player.id), !player.isInjured, !player.isSuspended else { continue }
            let drop = player.rating >= 74 ? Int.random(in: 2...5) : 1
            clubs[userClubIndex].players[index].morale = max(0, player.morale - drop)
            if clubs[userClubIndex].players[index].morale <= 25,
               player.rating >= 72,
               !clubs[userClubIndex].players[index].wantsToLeave {
                clubs[userClubIndex].players[index].wantsToLeave = true
                addNews(.board, "Transfer request",
                        "\(player.name) is frustrated by a lack of game time and has asked to leave. Respond from his profile — talk him round, or list him for sale.")
            }
        }
    }

    /// At season's end, decrements contracts; user players who run down their
    /// deal leave on a free, while rivals quietly re-sign their own.
    /// At season's end, decrements every contract. A club never loses a
    /// player just because a deal quietly ran down in the background — an
    /// expiring contract auto-renews for another 2-4 years, the same as
    /// any AI club re-signing its own. For the user's club this is worth
    /// a heads-up, since they may still want to sell or renegotiate; it's
    /// never an automatic, unwanted departure.
    private func processContracts() {
        for clubIndex in clubs.indices {
            for index in clubs[clubIndex].players.indices {
                clubs[clubIndex].players[index].contractYears -= 1
                if clubs[clubIndex].players[index].contractYears <= 0 {
                    let newYears = Int.random(in: 2...4)
                    clubs[clubIndex].players[index].contractYears = newYears
                    if clubIndex == userClubIndex {
                        addNews(.board, "Contract auto-renewed",
                                "\(clubs[clubIndex].players[index].name)'s deal ran down and the club quietly tied him to a new \(newYears)-year contract. Sell or renegotiate any time from the squad screen.")
                    }
                }
            }
        }
    }

    // MARK: - News feed

    /// IDs of news items the manager hasn't opened yet.
    private(set) var unreadNewsIDs: Set<UUID> = []

    func addNews(_ category: NewsCategory, _ title: String, _ body: String, player: Player? = nil, clubName: String? = nil) {
        let item = NewsItem(date: currentDate, category: category, title: title, body: body,
                            playerName: player?.name, playerRating: player?.rating,
                            playerPosition: player?.position, playerAge: player?.age,
                            clubName: clubName)
        news.insert(item, at: 0)
        unreadNewsIDs.insert(item.id)
        if news.count > 60 {
            for dropped in news.suffix(news.count - 60) { unreadNewsIDs.remove(dropped.id) }
            news.removeLast(news.count - 60)
        }
    }

    func markNewsRead(_ item: NewsItem) {
        unreadNewsIDs.remove(item.id)
    }

    func markAllNewsRead() {
        unreadNewsIDs.removeAll()
    }

    // MARK: - Board

    /// A rough preview of what a club's board would expect, for comparing
    /// job offers — the same ladder logic as `setBoardObjective`, without
    /// the reputation-driven ambition creep (that's specific to a job
    /// already held, not a hypothetical new one).
    func previewObjective(forClubIndex index: Int) -> String {
        let tier = clubs[index].divisionTier
        let division = clubs.filter { $0.divisionTier == tier }.sorted { $0.prestige > $1.prestige }
        let rank = (division.firstIndex { $0.id == clubs[index].id } ?? 0) + 1
        let ladder: [String]
        let baseIndex: Int
        if tier == 0 {
            ladder = ["Avoid relegation", "Finish in the top half", "Qualify for Europe (top 4)", "Win the league"]
            baseIndex = rank <= 1 ? 3 : (rank <= 4 ? 2 : (rank <= Self.divisionSize / 2 ? 1 : 0))
        } else {
            let bottomLabel = tier == Self.divisionNames.count - 1 ? "Finish mid-table" : "Avoid relegation"
            ladder = [bottomLabel, "Finish in the top half", "Reach the play-offs (top 6)", "Win automatic promotion (top 2)"]
            baseIndex = rank <= 2 ? 3 : (rank <= 6 ? 2 : (rank <= Self.divisionSize / 2 ? 1 : 0))
        }
        return ladder[baseIndex]
    }

    private func setBoardObjective() {
        // Rank the user's prestige within their own division.
        let division = clubs.filter { $0.divisionTier == userDivisionTier }.sorted { $0.prestige > $1.prestige }
        let rank = (division.firstIndex { $0.id == userClub.id } ?? 0) + 1
        let tier = userDivisionTier

        let ladder: [String]
        let baseIndex: Int
        if tier == 0 {
            ladder = ["Avoid relegation", "Finish in the top half", "Qualify for Europe (top 4)", "Win the league"]
            baseIndex = rank <= 1 ? 3 : (rank <= 4 ? 2 : (rank <= Self.divisionSize / 2 ? 1 : 0))
        } else {
            let bottomLabel = tier == Self.divisionNames.count - 1 ? "Finish mid-table" : "Avoid relegation"
            ladder = [bottomLabel, "Finish in the top half", "Reach the play-offs (top 6)", "Win automatic promotion (top 2)"]
            baseIndex = rank <= 2 ? 3 : (rank <= 6 ? 2 : (rank <= Self.divisionSize / 2 ? 1 : 0))
        }
        // Ambition creep: sustained success raises reputation, and a board
        // that's grown used to winning starts expecting more than the raw
        // squad strength alone would suggest.
        let escalation = managerReputation >= 90 ? 2 : (managerReputation >= 75 ? 1 : 0)
        let index = min(ladder.count - 1, baseIndex + escalation)
        boardObjective = ladder[index]
        boardConfidence = 60
    }

    private func updateBoard(userWon: Bool, draw: Bool, isHome: Bool) {
        // A good assistant manager softens how badly a defeat lands with
        // both the board and the fans, without blunting the credit for a win.
        let assistantCushion = 1.0 - Double(staffLevel(.assistantManager)) * 0.12
        let delta = userWon ? 6 : (draw ? 1 : -Int((5.0 * difficulty.boardLossHarshness * assistantCushion).rounded()))
        let beforeConfidence = boardConfidence
        boardConfidence = min(100, max(0, boardConfidence + delta))
        boardConfidenceTrend = boardConfidence - beforeConfidence
        let fanDelta = userWon ? 5 : (draw ? -1 : -Int((6.0 * assistantCushion).rounded()))
        fanConfidence = min(100, max(0, fanConfidence + fanDelta))

        var record = careerRecordByClub[userClub.name] ?? ClubCareerRecord()
        if userWon { record.wins += 1 } else if draw { record.draws += 1 } else { record.losses += 1 }
        if isHome {
            if userWon { record.homeWins += 1 } else if draw { record.homeDraws += 1 } else { record.homeLosses += 1 }
        } else {
            if userWon { record.awayWins += 1 } else if draw { record.awayDraws += 1 } else { record.awayLosses += 1 }
        }
        careerRecordByClub[userClub.name] = record
    }

    /// A board verdict on the window's business, once it closes — net
    /// spend against what was available, coloured by whether the squad
    /// clearly needed reinforcement.
    private func reviewTransferWindowClose() {
        let net = transferBudgetAtWindowOpen - userClub.transferBudget
        let ratio = transferBudgetAtWindowOpen > 0 ? Double(net) / Double(transferBudgetAtWindowOpen) : 0
        let pressingNeed = !squadNeeds().isEmpty
        let verdict: String
        if net < 0 {
            verdict = "The board are pleased with the business — you banked \(formatMoney(-net)) more than you spent this window."
        } else if ratio >= 0.7 {
            verdict = "The board are pleased to see the club back you in the market, with \(formatMoney(net)) spent this window."
        } else if ratio <= 0.15 && pressingNeed {
            verdict = "The board privately question why so little was done given the squad's needs — only \(formatMoney(net)) spent this window."
        } else if ratio <= 0.15 {
            verdict = "The board are content with a quiet window — \(formatMoney(net)) spent, with the squad already in good shape."
        } else {
            verdict = "The board see this as sensible business — \(formatMoney(net)) spent this window."
        }
        addNews(.board, "Transfer window review", verdict)
    }

    /// A short read on the fanbase's current mood.
    var fanMoodLabel: String {
        switch fanConfidence {
        case 75...:   return "Buzzing"
        case 50..<75: return "Content"
        case 25..<50: return "Restless"
        default:      return "Furious"
        }
    }

    /// A short read on the manager's job security.
    var jobSecurity: String {
        switch boardConfidence {
        case 70...:   return "Secure"
        case 45..<70: return "Stable"
        case 25..<45: return "Under pressure"
        default:      return "At risk"
        }
    }

    /// The calendar year a player's contract runs out, e.g. 2003 for a deal
    /// that lapses at the end of the 2002/03 season.
    func contractExpiryYear(_ player: Player) -> Int {
        (startYear - 1) + season + player.contractYears
    }

    // MARK: - Squad status & scouting a team

    /// A player's standing in the user's squad at their position.
    func squadStatus(for player: Player) -> String {
        let group = userClub.players
            .filter { $0.position == player.position }
            .sorted { $0.rating > $1.rating }
        guard let rank = group.firstIndex(where: { $0.id == player.id }) else { return "Squad player" }
        let starters = slots(for: player.position)
        if rank == 0 { return "Key player" }
        if rank < starters { return "First team" }
        if rank < starters + 1 { return "Rotation" }
        return "Backup"
    }

    /// The averaged outfield attributes of a club's best XI, high to low.
    private func rankedTeamAttributes(forClubIndex index: Int) -> [(name: String, value: Double)] {
        let xi = bestXI(for: clubs[index], formation: aiFormation(for: clubs[index]))
            .filter { $0.position != .goalkeeper }
        guard !xi.isEmpty else { return [] }
        return Player.outfieldAttributes.map { name in
            let total = xi.reduce(0.0) { $0 + Double($1.attributes[name] ?? 0) }
            return (name, total / Double(xi.count))
        }
        .sorted { $0.value > $1.value }
    }

    func teamStrengths(forClubIndex index: Int) -> [String] {
        rankedTeamAttributes(forClubIndex: index).prefix(3).map { $0.name }
    }

    func teamWeaknesses(forClubIndex index: Int) -> [String] {
        rankedTeamAttributes(forClubIndex: index).suffix(2).map { $0.name }.reversed()
    }

    /// A club's average squad morale, 0...100.
    func teamMorale(forClubIndex index: Int) -> Int {
        let squad = clubs[index].players
        guard !squad.isEmpty else { return 70 }
        return squad.reduce(0) { $0 + $1.morale } / squad.count
    }

    /// A short read on squad mood, for the UI.
    func teamMoraleLabel(forClubIndex index: Int) -> String {
        switch teamMorale(forClubIndex: index) {
        case 80...:   return "Buoyant"
        case 60..<80: return "Settled"
        case 40..<60: return "Uneasy"
        case 20..<40: return "Unhappy"
        default:      return "Mutinous"
        }
    }

    /// The best-rated player in a club's starting XI.
    func keyPlayer(forClubIndex index: Int) -> Player? {
        bestXI(for: clubs[index], formation: aiFormation(for: clubs[index])).max { $0.rating < $1.rating }
    }

    /// The natural formation name a club lines up in.
    func formationName(forClubIndex index: Int) -> String {
        aiFormation(for: clubs[index]).name
    }

    /// A one-word playing style based on a club's shape.
    func playStyle(forClubIndex index: Int) -> String {
        let formation = aiFormation(for: clubs[index])
        if formation.forwards >= 3 { return "Attacking" }
        if formation.forwards <= 1 { return "Defensive" }
        return "Balanced"
    }

    /// A pre-match prediction for the user's next fixture.
    func matchPrediction() -> String {
        guard let fixture = nextUserFixture else { return "" }
        let probs = outcomeProbabilities(homeIndex: fixture.homeIndex, awayIndex: fixture.awayIndex)
        let isHome = fixture.homeIndex == userClubIndex
        let userWin = isHome ? probs.home : probs.away
        let oppWin = isHome ? probs.away : probs.home
        let opponent = clubs[isHome ? fixture.awayIndex : fixture.homeIndex]
        if userWin > oppWin + 0.2 {
            return "\(userClub.name) should have too much quality for \(opponent.name) in this one."
        } else if oppWin > userWin + 0.2 {
            return "\(opponent.name) are favourites — this will be a real test for \(userClub.name)."
        }
        return "A finely balanced contest between \(userClub.name) and \(opponent.name)."
    }

    // MARK: - Squad generation

    /// First names common among English pros born in the late 1970s/early
    /// 1980s — the generation filling the pyramid's lower divisions in 2000/01.
    private static let firstNames = [
        "Jack", "Harry", "Tom", "Danny", "Wayne", "Frank", "Lee", "Craig",
        "Steven", "Michael", "Alan", "Paul", "Gary", "Nigel", "Ashley",
        "Kevin", "Darren", "Jamie", "Marcus", "Simon", "Phil", "Neil",
        "Matthew", "Mark", "Jordan", "Kyle", "Luke", "Carl", "Callum",
        "Ian", "Scott", "Chris", "David", "Richard", "Adam",
    ]

    private static let lastNames = [
        "Smith", "Jones", "Taylor", "Brown", "Wilson", "Evans", "Roberts",
        "Walker", "Wright", "Hughes", "Green", "Clarke", "Hall", "Wood",
        "Turner", "Hill", "Ward", "Hargate", "Fenshaw", "Millbrook", "Corrigan",
        "Ratcliffe", "Sowerby", "Pentland", "Ashdown", "Crowther", "Selwood",
        "Kearns", "Whitfield", "Osborne", "Dysart", "Marshall", "Bishop", "Grant",
    ]

    /// A loose (not researched) pool of continental European first/last
    /// names, used only to flavour the occasional overseas wonderkid in the
    /// youth intake — a nationality hook, not a researched name.
    private static let foreignFirstNames = [
        "Mateo", "Diego", "Luca", "Marco", "Nils", "Lars", "Pierre",
        "Antoine", "Rafael", "Bruno", "Emil", "Anders", "Théo", "Hugo",
        "Adrien", "Jonas", "Fabio", "Sven", "Mikkel", "Rico",
    ]
    private static let foreignLastNames = [
        "Fernández", "Novak", "Bergqvist", "Rinaldi", "Dubois", "Weber",
        "Larsen", "Moreau", "Andersen", "Salvi", "Van Houten", "Meyer",
        "Beaumont", "Nilsson", "Berg", "Chastain", "Krause", "Silva",
    ]

    private static func randomForeignName() -> String {
        "\(foreignFirstNames.randomElement()!) \(foreignLastNames.randomElement()!)"
    }

    /// Every hand-authored career start year, each mapped to its own
    /// club-name-keyed squad book. Adding a further start year later is
    /// just adding another entry here (plus a matching
    /// `HistoricalSquadsYYYY`/`EuropeanSquadsYYYY` data file) — nothing
    /// else in the engine needs to change.
    private static let historicalEras: [Int: [String: [HistoricalPlayer]]] = [
        2000: HistoricalSquads2000.squads.merging(EuropeanSquads2000.squads) { existing, _ in existing },
        2010: HistoricalSquads2010.squads.merging(EuropeanSquads2010.squads) { existing, _ in existing },
    ]

    /// Every start year offered on the New Game screen, oldest first.
    static let availableStartYears: [Int] = historicalEras.keys.sorted()

    /// Creates a full squad for a club, using its hand-authored roster for
    /// the chosen start year when one is known, and otherwise generating
    /// one from the club's prestige (as every non-top-flight club always
    /// has, regardless of era).
    private static func makeSquad(name: String, prestige: Int, startYear: Int) -> [Player] {
        if let historical = historicalEras[startYear]?[name] {
            return historical.map { entry in
                var player = makePlayer(name: entry.name, position: entry.detailedPosition.broad,
                                        detailedPosition: entry.detailedPosition,
                                        secondaryPositions: entry.secondaryPositions,
                                        age: entry.age, rating: entry.rating, startYear: startYear)
                player.contractYears = Int.random(in: 1...4)
                return player
            }
        }
        return makeSquad(prestige: prestige, startYear: startYear)
    }

    /// Creates a full generated squad for a club of the given prestige.
    private static func makeSquad(prestige: Int, startYear: Int = 2000) -> [Player] {
        var players: [Player] = []
        // Roughly a realistic distribution across the pitch.
        let plan: [(Position, Int)] = [
            (.goalkeeper, 2),
            (.defender, 6),
            (.midfielder, 6),
            (.forward, 4),
        ]
        for (position, count) in plan {
            for _ in 0..<count {
                let rating = clampRating(prestige + Int.random(in: -14...8))
                let age = Int.random(in: 18...34)
                var player = makePlayer(position: position, age: age, rating: rating, startYear: startYear)
                player.contractYears = Int.random(in: 1...4)
                players.append(player)
            }
        }
        return players
    }

    /// Drops in any real players known for this club (see `ForeignStars`),
    /// each replacing the weakest generated player in the matching broad
    /// position so squad size and shape stay untouched.
    private static func applyForeignStars(to club: inout Club, startYear: Int = 2000) {
        for star in ForeignStars.all where star.club == club.name {
            let broad = star.detailedPosition.broad
            guard let weakestIndex = club.players.indices
                .filter({ club.players[$0].position == broad })
                .min(by: { club.players[$0].rating < club.players[$1].rating })
            else { continue }
            var player = makePlayer(name: star.name, position: broad, detailedPosition: star.detailedPosition,
                                    age: star.age, rating: star.rating, startYear: startYear)
            player.contractYears = Int.random(in: 1...4)
            club.players[weakestIndex] = player
        }
    }

    /// Builds a player with value, wage, attributes and a preferred foot.
    /// When no detailed position is supplied, one is picked at random from
    /// those plausible for the broad `position`, with a modest chance of a
    /// secondary role — most players have a single specialism.
    static func makePlayer(name: String? = nil, position: Position, detailedPosition: DetailedPosition? = nil,
                           secondaryPositions: [DetailedPosition]? = nil, age: Int, rating: Int, startYear: Int = 2000) -> Player {
        let role = detailedPosition ?? DetailedPosition.plausibleRoles(for: position).randomElement()!
        var player = Player(name: name ?? randomName(),
                            position: position,
                            detailedPosition: role,
                            age: age,
                            rating: rating,
                            value: playerValue(rating: rating, age: age, startYear: startYear),
                            wage: playerWage(rating: rating, age: age, startYear: startYear))
        player.secondaryPositions = secondaryPositions ?? randomSecondaryPositions(for: role)
        player.attributes = makeAttributes(position: position, rating: rating)
        let footRoll = Int.random(in: 0..<100)
        player.foot = footRoll < 68 ? "Right" : (footRoll < 92 ? "Left" : "Both")
        let durabilityRoll = Int.random(in: 0..<100)
        player.durability = durabilityRoll < 18 ? .robust : (durabilityRoll < 82 ? .normal : .fragile)
        let personalityRoll = Int.random(in: 0..<100)
        player.personality = personalityRoll < 40 ? .professional
            : (personalityRoll < 65 ? .loyal : (personalityRoll < 85 ? .ambitious : .volatile))
        return player
    }

    /// A plausible secondary role for a generated player — not every
    /// specialist can deputise elsewhere, so this is often empty.
    private static func randomSecondaryPositions(for role: DetailedPosition) -> [DetailedPosition] {
        let candidates: [(DetailedPosition, Double)]
        switch role {
        case .goalkeeper:   candidates = []
        case .centreBack:   candidates = [(.leftBack, 0.08), (.rightBack, 0.08)]
        case .leftBack:     candidates = [(.leftWing, 0.30), (.centreBack, 0.20)]
        case .rightBack:    candidates = [(.rightWing, 0.30), (.centreBack, 0.20)]
        case .holding:      candidates = [(.centreBack, 0.15), (.centralMid, 0.30)]
        case .centralMid:   candidates = [(.holding, 0.25), (.attackingMid, 0.20)]
        case .attackingMid: candidates = [(.leftWing, 0.15), (.rightWing, 0.15), (.centralMid, 0.20)]
        case .leftWing:     candidates = [(.leftBack, 0.20), (.attackingMid, 0.25), (.striker, 0.15)]
        case .rightWing:    candidates = [(.rightBack, 0.20), (.attackingMid, 0.25), (.striker, 0.15)]
        case .leftMid:      candidates = [(.leftBack, 0.25), (.centralMid, 0.25), (.leftWing, 0.20)]
        case .rightMid:     candidates = [(.rightBack, 0.25), (.centralMid, 0.25), (.rightWing, 0.20)]
        case .striker:      candidates = [(.leftWing, 0.10), (.rightWing, 0.10)]
        }
        for (candidate, chance) in candidates where Double.random(in: 0..<1) < chance {
            return [candidate]
        }
        return []
    }

    /// A free agent available on the transfer market.
    static func makeFreeAgent(startYear: Int = 2000) -> Player {
        let position = Position.allCases.randomElement()!
        var player = makePlayer(position: position,
                                age: Int.random(in: 24...34),
                                rating: Int.random(in: 55...78),
                                startYear: startYear)
        player.contractYears = Int.random(in: 1...2)
        return player
    }

    private static func randomName() -> String {
        "\(firstNames.randomElement()!) \(lastNames.randomElement()!)"
    }

    private static func randomManagerName() -> String {
        // Initial + surname, in the classic manager style.
        "\(firstNames.randomElement()!.prefix(1)). \(lastNames.randomElement()!)"
    }

    /// The manager of the club at the given index.
    func manager(forClubIndex index: Int) -> String {
        managers.indices.contains(index) ? managers[index] : "—"
    }

    private static func clampRating(_ value: Int) -> Int {
        min(94, max(45, value))
    }

    // MARK: - Fixtures (double round-robin)

    /// Generates a home-and-away schedule using the circle method.
    /// Builds a double round-robin for every division, all sharing matchdays.
    private func makeAllFixtures() -> [Fixture] {
        var all: [Fixture] = []
        for tier in 0..<Self.divisionNames.count {
            all += Self.roundRobin(indices: clubIndices(inTier: tier))
        }
        return all
    }

    /// A home-and-away schedule for the given club indices (circle method).
    private static func roundRobin(indices global: [Int]) -> [Fixture] {
        var indices = global
        let count = indices.count
        guard count >= 2 else { return [] }
        var rounds: [[(Int, Int)]] = []
        let firstHalf = count - 1

        for _ in 0..<firstHalf {
            var pairs: [(Int, Int)] = []
            for i in 0..<(count / 2) {
                pairs.append((indices[i], indices[count - 1 - i]))
            }
            rounds.append(pairs)
            let last = indices.removeLast()
            indices.insert(last, at: 1)
        }

        var fixtures: [Fixture] = []
        for (round, pairs) in rounds.enumerated() {
            for (home, away) in pairs {
                fixtures.append(Fixture(matchday: round + 1, homeIndex: home, awayIndex: away))
            }
        }
        for (round, pairs) in rounds.enumerated() {
            for (home, away) in pairs {
                fixtures.append(Fixture(matchday: round + 1 + firstHalf, homeIndex: away, awayIndex: home))
            }
        }
        return fixtures
    }

    // MARK: - Strength & selection

    /// Returns the best starting XI for a club under a formation. Each slot
    /// prefers a player whose natural or secondary role fits it — a natural
    /// full-back beats a higher-rated centre-back for a wing-back slot —
    /// with the wide/specific slots resolved before the central ones.
    /// The strongest available XI in a formation. `restBias` (0 by default)
    /// lets the auto-pick assist nudge tired players out in favour of
    /// fresher squad depth ahead of a bigger match soon — 0 reproduces the
    /// plain "best available" pick used everywhere else.
    func bestXI(for club: Club, formation: Formation, restBias: Double = 0) -> [Player] {
        func top(_ position: Position, _ count: Int) -> [Player] {
            guard count > 0 else { return [] }
            var pool = club.players.filter { $0.position == position && $0.isAvailable }
            var chosen: [Player?] = Array(repeating: nil, count: count)
            let order = Array(0..<count).sorted { a, b in
                let aEdge = a == 0 || a == count - 1
                let bEdge = b == 0 || b == count - 1
                if aEdge != bEdge { return aEdge }
                return a < b
            }
            for index in order {
                let role = DetailedPosition.expected(for: position, indexInRow: index, rowCount: count, wideIsWinger: formation.wideMidfieldersAreWingers)
                func score(_ p: Player) -> Double {
                    let fitnessFactor = 0.9 + 0.1 * Double(p.fitness) / 100
                    let moraleFactor = 0.96 + 0.04 * Double(p.morale) / 100
                    let restPenalty = restBias * Double(100 - p.fitness)
                    return Double(p.effectiveRating(for: role)) * fitnessFactor * moraleFactor - restPenalty
                }
                guard let best = pool.max(by: { score($0) < score($1) }) else { continue }
                chosen[index] = best
                pool.removeAll { $0.id == best.id }
            }
            return chosen.compactMap { $0 }
        }
        var xi: [Player] = []
        xi += top(.goalkeeper, 1)
        xi += top(.defender, formation.defenders)
        xi += top(.midfielder, formation.midfielders)
        xi += top(.forward, formation.forwards)
        return xi
    }

    /// The number of starting slots a formation gives to a position.
    func slots(for position: Position) -> Int {
        switch position {
        case .goalkeeper: return 1
        case .defender:   return formation.defenders
        case .midfielder: return formation.midfielders
        case .forward:    return formation.forwards
        }
    }

    /// The user's current starting XI, in back-to-front order.
    /// Falls back to the best XI if the hand-picked side is incomplete.
    func userStartingXI() -> [Player] {
        // Injured or suspended players can't take the field even if still selected.
        let chosen = userClub.players.filter { userStarterIDs.contains($0.id) && $0.isAvailable }
        let xi = isValidLineup(chosen)
            ? chosen.sorted { $0.position.order < $1.position.order }
            : bestXI(for: userClub, formation: formation)
        let familiarity = formationFamiliarity
        guard familiarity < 1.0 else { return xi }
        return xi.map { player in
            var adjusted = player
            adjusted.rating = max(1, Int((Double(player.rating) * familiarity).rounded()))
            return adjusted
        }
    }

    /// True when the given players exactly fill every slot in the formation.
    func isValidLineup(_ players: [Player]) -> Bool {
        guard players.count == 11 else { return false }
        for position in Position.allCases {
            if players.filter({ $0.position == position }).count != slots(for: position) {
                return false
            }
        }
        return true
    }

    /// Empties the user's starting XI so it can be rebuilt by hand.
    func clearLineup() {
        userStarterIDs = []
    }

    /// Replaces the user's starting XI with the best available side.
    func autoPickLineup() {
        guard userClubIndex < clubs.count else { return }
        userStarterIDs = Set(bestXI(for: userClub, formation: formation).map { $0.id })
        validateRoles()
    }

    /// Whether the "assist" team-selection setting is on — when enabled,
    /// the starting XI is picked automatically before every one of the
    /// user's matches, factoring fitness, morale, today's opponent, and
    /// what's coming up next.
    var autoPickAssist = false {
        didSet { persist() }
    }

    /// Whether a sufficiently capable assistant manager (staff level 3+)
    /// auto-handles press conferences and team talks, so they don't need
    /// a tap through every single match.
    var delegateToAssistant = false {
        didSet { persist() }
    }

    /// The manager's default tactical mentality — seeds each live match's
    /// starting mentality, and shifts the balance of an abstractly-resolved
    /// (force-simmed) match too, so the setting matters either way.
    var preferredMentality: Mentality = .balanced {
        didSet { persist() }
    }

    /// Backroom appointments, keyed by role — at most one per role.
    private(set) var backroomStaff: [StaffMember] = []

    /// The cost to hire a staff member at a given level (1...3), in £000s.
    func staffHireCost(level: Int) -> Int { 300 * level * level }

    /// Hires (or replaces) a backroom appointment, paid as a one-off fee
    /// from the transfer budget, the same as a stadium or academy upgrade.
    @discardableResult
    func hireStaff(role: StaffRole, level: Int) -> String {
        let cost = staffHireCost(level: level)
        guard userClub.transferBudget >= cost else {
            return "Not enough in the transfer budget to hire (\(formatMoney(cost)))."
        }
        clubs[userClubIndex].transferBudget -= cost
        let name = Self.randomManagerName()
        backroomStaff.removeAll { $0.role == role }
        backroomStaff.append(StaffMember(role: role, name: name, level: level))
        logLedger("Staff", amount: -cost, "Hired \(name) as \(role.rawValue)")
        addNews(.board, "New backroom appointment", "\(userClub.name) appoint \(name) as \(role.rawValue).")
        persist()
        return "\(name) appointed as \(role.rawValue)."
    }

    /// The staff level for a role, or 0 if nobody's been hired.
    func staffLevel(_ role: StaffRole) -> Int {
        backroomStaff.first { $0.role == role }?.level ?? 0
    }

    /// A rough "how much does this match matter" score: competition weight
    /// plus a nudge for a tougher opponent — used only to compare today's
    /// game against what's coming up next, not as a literal probability.
    private func matchImportance(_ info: UserMatchInfo) -> Double {
        let opponentIndex = info.homeIndex == userClubIndex ? info.awayIndex : info.homeIndex
        let opponentPrestige = clubs.indices.contains(opponentIndex) ? Double(clubs[opponentIndex].prestige) : 60
        let competitionWeight: Double
        if !info.isCup {
            competitionWeight = 10
        } else if info.label.hasPrefix(Self.euroName) || info.label.hasPrefix(Self.uefaCupName) {
            competitionWeight = 9
        } else if info.label.hasPrefix(Self.communityShieldName) || info.label.hasPrefix(Self.uefaSuperCupName) {
            competitionWeight = 7
        } else if info.label.hasPrefix(Self.cupName) {
            competitionWeight = 6
        } else {
            competitionWeight = 4   // League Trophy
        }
        return competitionWeight + opponentPrestige / 10
    }

    /// Auto-picks today's starting XI the way a competent assistant coach
    /// would: the strongest available side by default, but easing off
    /// players who are short of full fitness when a clearly bigger match
    /// is coming up within the next few days — a cup replay midweek before
    /// a title-race league game at the weekend, say.
    func smartAutoPick() {
        guard userClubIndex < clubs.count else { return }
        let upcoming = upcomingUserMatches
        guard let today = upcoming.first else { autoPickLineup(); return }
        var restBias = 0.0
        if let next = upcoming.dropFirst().first {
            let daysUntilNext = Self.calendar.dateComponents([.day], from: today.date, to: next.date).day ?? 99
            let importanceGap = matchImportance(next.info) - matchImportance(today.info)
            if daysUntilNext <= 4 && importanceGap > 1.5 {
                restBias = min(0.12, importanceGap * 0.02)
            }
        }
        userStarterIDs = Set(bestXI(for: userClub, formation: formation, restBias: restBias).map { $0.id })
        validateRoles()
    }

    // MARK: - Squad roles

    /// Assigns any missing roles automatically and drops roles for players who
    /// have left the club.
    func validateRoles() {
        let squad = userClub.players
        func exists(_ id: UUID?) -> Bool { id != nil && squad.contains { $0.id == id } }

        if !exists(captainID) {
            captainID = squad.filter { $0.position != .goalkeeper }.max { $0.rating < $1.rating }?.id
        }
        if !exists(penaltyTakerID) {
            penaltyTakerID = squad.max { ($0.attributes["Shooting"] ?? 0) < ($1.attributes["Shooting"] ?? 0) }?.id
        }
        if !exists(freeKickTakerID) {
            freeKickTakerID = squad.max {
                (($0.attributes["Shooting"] ?? 0) + ($0.attributes["Passing"] ?? 0))
                    < (($1.attributes["Shooting"] ?? 0) + ($1.attributes["Passing"] ?? 0))
            }?.id
        }
        if !exists(cornerTakerID) {
            cornerTakerID = squad.max { ($0.attributes["Passing"] ?? 0) < ($1.attributes["Passing"] ?? 0) }?.id
        }
    }

    // MARK: - Youth academy

    /// Generates this season's crop of youth prospects for the user's club.
    private func generateYouthIntake() {
        let base = userClub.prestige
        let level = userClub.youthFacilityLevel
        var sawForeignTalent = false
        let count = Int.random(in: 3...5) + (level >= 3 ? 1 : 0) + (level >= 5 ? 1 : 0)
        // Better facilities narrow the usual below-first-team gap and
        // improve the odds of a scout unearthing talent from overseas.
        let penaltyRange = (-28 + level * 3)...(-8 + level * 2)
        let foreignChance = 0.15 + Double(level) * 0.05
        let freshIntake: [Player] = (0..<count).map { _ in
            let position = Position.allCases.randomElement()!
            let rating = Self.clampRating(base + Int.random(in: penaltyRange))
            // A big academy's scouting network occasionally turns up a
            // prospect from overseas rather than the usual local intake.
            let isForeign = Double.random(in: 0..<1) < foreignChance
            let name = isForeign ? Self.randomForeignName() : Self.randomName()
            var player = Self.makePlayer(name: name, position: position, age: Int.random(in: 15...18), rating: rating, startYear: startYear)
            player.contractYears = Int.random(in: 2...3)
            if isForeign { sawForeignTalent = true }
            return player
        }

        // Prospects the manager hasn't promoted (or lost interest in)
        // don't just vanish at the next intake — a year of academy
        // coaching genuinely develops them, so they stick around, age up
        // and improve, until either promoted or they age out of the
        // academy entirely at 21.
        let developedHoldovers: [Player] = youthProspects.compactMap { prospect in
            var developed = prospect
            developed.age += 1
            guard developed.age <= 20 else { return nil }
            let growth = Int.random(in: 1...4) + (level >= 4 ? 1 : 0)
            developed.rating = Self.clampRating(developed.rating + growth)
            return developed
        }

        // Cap the pool so it can't grow without bound — keep the best
        // prospects if the combined list runs over a sensible academy size.
        let combined = (developedHoldovers + freshIntake).sorted { $0.rating > $1.rating }
        youthProspects = Array(combined.prefix(12))

        if sawForeignTalent {
            addNews(.info, "Academy news", "This year's youth intake includes a prospect spotted by the club's scouts overseas.")
        }
    }

    /// Promotes a youth prospect to the senior squad.
    @discardableResult
    func promoteYouth(_ player: Player) -> String {
        guard userClub.players.count < 30 else { return "Squad is full (30 players)." }
        guard let index = youthProspects.firstIndex(where: { $0.id == player.id }) else { return "No longer available." }
        let prospect = youthProspects.remove(at: index)
        clubs[userClubIndex].players.append(prospect)
        addNews(.transfer, "Youth promoted", "\(prospect.name) (\(prospect.age)) has been promoted to the first team.",
               player: prospect, clubName: userClub.name)
        persist()
        return "\(prospect.name) promoted to the senior squad."
    }

    /// Releases a youth prospect.
    @discardableResult
    func releaseYouth(_ player: Player) -> String {
        youthProspects.removeAll { $0.id == player.id }
        persist()
        return "\(player.name) released."
    }

    // MARK: - Squad roles

    func setCaptain(_ player: Player) { captainID = player.id }
    func setPenaltyTaker(_ player: Player) { penaltyTakerID = player.id }
    func setFreeKickTaker(_ player: Player) { freeKickTakerID = player.id }
    func setCornerTaker(_ player: Player) { cornerTakerID = player.id }

    /// Short role markers for a player (C / P / FK / CK).
    func roleMarkers(for id: UUID) -> [String] {
        var markers: [String] = []
        if id == captainID { markers.append("C") }
        if id == penaltyTakerID { markers.append("P") }
        if id == freeKickTakerID { markers.append("FK") }
        if id == cornerTakerID { markers.append("CK") }
        return markers
    }

    /// Result of trying to change a player's selection.
    enum SelectionChange {
        case added
        case removed
        case blocked(String)
    }

    /// Toggles a player in or out of the user's starting XI, respecting the
    /// formation's positional limits. Returns what happened so the UI can
    /// give feedback.
    @discardableResult
    func toggleStarter(_ player: Player) -> SelectionChange {
        if userStarterIDs.contains(player.id) {
            userStarterIDs.remove(player.id)
            return .removed
        }
        guard !player.isInjured else {
            return .blocked("\(player.name) is injured and unavailable.")
        }
        guard !player.isSuspended else {
            return .blocked("\(player.name) is suspended for \(player.suspensionMatches) match\(player.suspensionMatches == 1 ? "" : "es").")
        }
        let inPosition = userClub.players.filter {
            userStarterIDs.contains($0.id) && $0.position == player.position
        }.count
        guard inPosition < slots(for: player.position) else {
            let label = player.position == .goalkeeper ? "goalkeeper" : "\(player.position.rawValue) slots"
            return .blocked("No free \(label) — remove one first.")
        }
        userStarterIDs.insert(player.id)
        return .added
    }

    /// Puts a specific player into the starting XI for a given detailed
    /// role — the "quick select" action from the pitch screen. If that
    /// broad position's slots are already full, the weakest fit for the
    /// role is dropped to make room.
    @discardableResult
    func assignStarter(_ player: Player, forRole role: DetailedPosition) -> SelectionChange {
        guard !player.isInjured else {
            return .blocked("\(player.name) is injured and unavailable.")
        }
        guard !player.isSuspended else {
            return .blocked("\(player.name) is suspended for \(player.suspensionMatches) match\(player.suspensionMatches == 1 ? "" : "es").")
        }
        if userStarterIDs.contains(player.id) { return .added }
        let group = userClub.players.filter { userStarterIDs.contains($0.id) && $0.position == role.broad }
        if group.count >= slots(for: role.broad), let weakest = group.min(by: {
            $0.effectiveRating(for: role) < $1.effectiveRating(for: role)
        }) {
            userStarterIDs.remove(weakest.id)
        }
        userStarterIDs.insert(player.id)
        return .added
    }

    /// The strength of a set of players, used by the match engine. Happy,
    /// fresh players play closer to their rating; unhappy or tired ones
    /// undershoot it.
    private func strengthValue(_ players: [Player]) -> Double {
        players.reduce(0.0) {
            let moraleFactor = 0.85 + 0.15 * Double($1.morale) / 100
            let fitnessFactor = 0.9 + 0.1 * Double($1.fitness) / 100
            return $0 + Double($1.rating) * moraleFactor * fitnessFactor
        }
    }

    /// The XI a club fields in a match: the user's hand-picked side for the
    /// managed club, or the best XI in its strongest formation for the AI.
    private func matchXI(forClubIndex index: Int) -> [Player] {
        if index == userClubIndex {
            return userStartingXI()
        }
        let club = clubs[index]
        return bestXI(for: club, formation: aiFormation(for: club))
    }

    /// The formation the AI uses for a non-user club (its natural best).
    private func aiFormation(for club: Club) -> Formation {
        Formation.all.max {
            strengthValue(bestXI(for: club, formation: $0)) < strengthValue(bestXI(for: club, formation: $1))
        } ?? Formation.all[0]
    }

    /// The shape that gets the strongest XI out of the user's current
    /// squad — the same "best fit" logic the AI uses for itself, surfaced
    /// as a one-tap suggestion on the Tactics screen rather than something
    /// only rival managers benefit from.
    var recommendedFormation: Formation {
        aiFormation(for: userClub)
    }

    // MARK: - Match simulation

    /// Samples a Poisson-distributed goal count for the given mean.
    private func poisson(_ lambda: Double) -> Int {
        let l = exp(-lambda)
        var k = 0
        var p = 1.0
        repeat {
            k += 1
            p *= Double.random(in: 0...1)
        } while p > l
        return k - 1
    }

    /// Simulates one fixture, updating the fixture, both clubs' records,
    /// and returning a report with the scorers.
    private func simulate(fixtureIndex: Int) -> MatchReport {
        let fixture = fixtures[fixtureIndex]
        let home = clubs[fixture.homeIndex]
        let away = clubs[fixture.awayIndex]

        // A bigger, fuller ground is a genuinely louder, more intimidating
        // place to visit — each stadium expansion level adds a little more
        // home advantage on top of the base atmosphere.
        let homeAdvantage = 40.0 + Double(home.stadiumExpansionLevel) * 3.0
        let homeXI = matchXI(forClubIndex: fixture.homeIndex)
        let awayXI = matchXI(forClubIndex: fixture.awayIndex)
        var homeStrength = strengthValue(homeXI) + homeAdvantage
        var awayStrength = strengthValue(awayXI)
        // The user's chosen mentality shifts an abstractly-resolved match
        // too, the same trade-off `LiveMatch` applies minute by minute:
        // more attack for less solidity, or vice versa.
        if fixture.homeIndex == userClubIndex {
            homeStrength *= preferredMentality.attack
            awayStrength /= preferredMentality.solidity
        } else if fixture.awayIndex == userClubIndex {
            awayStrength *= preferredMentality.attack
            homeStrength /= preferredMentality.solidity
        }
        let ratio = homeStrength / (homeStrength + awayStrength)
        applyMatchFitness(clubIndex: fixture.homeIndex, xi: homeXI)
        applyMatchFitness(clubIndex: fixture.awayIndex, xi: awayXI)

        // Around 2.7 goals per game on average, split by relative strength.
        let homeGoals = poisson(2.7 * ratio)
        let awayGoals = poisson(2.7 * (1.0 - ratio))

        // Record the result.
        fixtures[fixtureIndex].played = true
        fixtures[fixtureIndex].homeGoals = homeGoals
        fixtures[fixtureIndex].awayGoals = awayGoals

        applyResult(clubIndex: fixture.homeIndex, scored: homeGoals, conceded: awayGoals, isHome: true, opponentIndex: fixture.awayIndex)
        applyResult(clubIndex: fixture.awayIndex, scored: awayGoals, conceded: homeGoals, isHome: false, opponentIndex: fixture.homeIndex)

        let homeScorers = attributeGoals(homeGoals, toClubAt: fixture.homeIndex)
        let awayScorers = attributeGoals(awayGoals, toClubAt: fixture.awayIndex)

        let involvesUser = fixture.homeIndex == userClubIndex || fixture.awayIndex == userClubIndex
        return MatchReport(matchday: fixture.matchday,
                           homeName: home.name,
                           awayName: away.name,
                           homeGoals: homeGoals,
                           awayGoals: awayGoals,
                           scorers: homeScorers + awayScorers,
                           involvesUser: involvesUser)
    }

    /// Updates a club's win/draw/loss record after a result.
    private func applyResult(clubIndex: Int, scored: Int, conceded: Int, isHome: Bool, opponentIndex: Int) {
        clubs[clubIndex].played += 1
        clubs[clubIndex].goalsFor += scored
        clubs[clubIndex].goalsAgainst += conceded
        if scored > conceded {
            clubs[clubIndex].won += 1
        } else if scored == conceded {
            clubs[clubIndex].drawn += 1
        } else {
            clubs[clubIndex].lost += 1
        }

        // Celebrate a new biggest-ever win, for the user's club only —
        // an all-time club record, not reset each season.
        let margin = scored - conceded
        if clubIndex == userClubIndex, margin > clubs[clubIndex].recordWinMargin {
            clubs[clubIndex].recordWinMargin = margin
            clubs[clubIndex].recordWinDescription = "\(scored)-\(conceded) (\(currentDate.formatted(.dateTime.day().month(.wide).year())))"
            addNews(.board, "Club record!", "That's the biggest win in \(userClub.name)'s history — \(scored)-\(conceded).")
        }

        // Gate revenue for the user's own home matches — a stadium
        // investment's actual payoff, on top of the season's budget reset.
        if isHome, clubIndex == userClubIndex {
            let attendance = expectedAttendance(homeIndex: clubIndex, awayIndex: opponentIndex, isCup: false)
            let revenue = attendance * pricePerHead(forClubIndex: clubIndex) / 1000   // in £000s
            clubs[clubIndex].transferBudget += revenue
            logLedger("Gate receipts", amount: revenue, "\(attendance.formatted()) attendance vs \(clubs[opponentIndex].shortName)")
        }
    }

    /// Randomly assigns goals to attacking players, weighted by position
    /// and rating, and increments their season tally.
    private func attributeGoals(_ count: Int, toClubAt clubIndex: Int) -> [String] {
        guard count > 0 else { return [] }
        // Weight forwards most, then midfielders, then defenders.
        let weights: [Position: Double] = [.forward: 4, .midfielder: 2, .defender: 0.6, .goalkeeper: 0.02]
        let squad = clubs[clubIndex].players
        var scorers: [String] = []

        func weight(_ player: Player) -> Double {
            (weights[player.position] ?? 1) * Double(player.rating)
        }
        let total = squad.reduce(0.0) { $0 + weight($1) }

        for _ in 0..<count {
            // Pick a scorer by weighted random choice.
            var roll = Double.random(in: 0..<total)
            var chosen = 0
            for (index, player) in squad.enumerated() {
                let w = weight(player)
                if roll < w { chosen = index; break }
                roll -= w
            }
            clubs[clubIndex].players[chosen].goals += 1
            scorers.append("\(clubs[clubIndex].players[chosen].name) (\(clubs[clubIndex].shortName))")
        }
        return scorers
    }

    // MARK: - Advancing the season

    /// Instantly simulates the whole current matchday (used as a fallback
    /// when there is no user match to play out live).
    func playNextMatchday() {
        guard !isSeasonOver else { return }
        let day = currentMatchday
        var reports: [MatchReport] = []
        for index in fixtures.indices where fixtures[index].matchday == day && !fixtures[index].played {
            reports.append(simulate(fixtureIndex: index))
        }
        // Show the user's match first.
        lastReports = reports.sorted { $0.involvesUser && !$1.involvesUser }
        currentMatchday += 1
        advanceWeek()
    }

    // MARK: - Live match orchestration

    /// The user's fiercest rival — a genuine real-world rival if one
    /// exists in this save (even in another division), else a stand-in:
    /// the strongest other club in their own division.
    var rivalClubIndex: Int? {
        if let realRival = clubs.indices.first(where: {
            $0 != userClubIndex && RivalClubs.areRivals(userClub.name, clubs[$0].name)
        }) {
            return realRival
        }
        return clubIndices(inTier: userDivisionTier)
            .filter { $0 != userClubIndex }
            .max { clubs[$0].prestige < clubs[$1].prestige }
    }

    /// Whether the next match is a derby against the user's rival.
    var nextMatchIsDerby: Bool {
        guard let info = nextUserMatchInfo, let rival = rivalClubIndex, info.isCup == false else { return false }
        let opponent = info.homeIndex == userClubIndex ? info.awayIndex : info.homeIndex
        return opponent == rival
    }

    /// Opens the pre-match hub before the user's next match.
    func enterPreMatch() {
        guard isUserMatchToday else { return }
        atPreMatch = true
        if pendingPressQuestion == nil {
            if nextMatchIsDerby, let rival = rivalClubIndex {
                pendingPressQuestion = makeMindGames(clubs[rival].name)
            } else if Double.random(in: 0..<1) < 0.5 {
                pendingPressQuestion = makePressQuestion()
            }
        }
        if pendingTeamTalk == nil {
            pendingTeamTalk = makeTeamTalk()
        }
        // A capable enough assistant can be trusted to handle the routine
        // stuff — picks whichever option reads best for morale and the
        // board, same as a manager on autopilot would.
        if delegateToAssistant, staffLevel(.assistantManager) >= 3 {
            if let question = pendingPressQuestion,
               let best = question.options.max(by: { ($0.moraleDelta + $0.confidenceDelta) < ($1.moraleDelta + $1.confidenceDelta) }) {
                answerPress(best, headline: "Press conference (assistant)")
            }
            if let talk = pendingTeamTalk,
               let best = talk.options.max(by: { ($0.moraleDelta + $0.confidenceDelta) < ($1.moraleDelta + $1.confidenceDelta) }) {
                answerTeamTalk(best)
            }
        }
    }

    /// A pre-match team talk — reuses the press-conference question shape,
    /// but the morale swing applies only to today's starting XI, before
    /// kickoff, so it genuinely feeds into today's match strength (morale
    /// is one of the factors `strengthValue` weighs) rather than just
    /// banking goodwill for another day.
    private func makeTeamTalk() -> PressQuestion {
        let opponent = nextUserMatchInfo.map { info in
            clubs[info.homeIndex == userClubIndex ? info.awayIndex : info.homeIndex].name
        } ?? "the opposition"
        return PressQuestion(prompt: "Team talk before facing \(opponent) — what's the message in the dressing room?", options: [
            PressOption(label: "Keep it calm",
                        response: "A measured, low-key talk — the players stay focused and level-headed.",
                        moraleDelta: 3, confidenceDelta: 0),
            PressOption(label: "Rev them up",
                        response: "A rousing, high-energy team talk sends the players out fired up.",
                        moraleDelta: 7, confidenceDelta: 0),
            PressOption(label: "Demand a big performance",
                        response: "The manager set the bar high and demanded a big performance from every player.",
                        moraleDelta: 2, confidenceDelta: 2),
        ])
    }

    /// Applies a team talk's effect to today's starting XI, then clears it.
    func answerTeamTalk(_ option: PressOption) {
        for id in userStarterIDs {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                clubs[userClubIndex].players[index].morale =
                    min(100, max(0, clubs[userClubIndex].players[index].morale + option.moraleDelta))
            }
        }
        boardConfidence = min(100, max(0, boardConfidence + option.confidenceDelta))
        addNews(.board, "Team talk", option.response)
        pendingTeamTalk = nil
    }

    private func makeMindGames(_ rival: String) -> PressQuestion {
        PressQuestion(prompt: "\(rival)'s manager says you're “feeling the pressure” before the derby. Your response?", options: [
            PressOption(label: "Fire back", response: "The boss returned fire — the squad is fired up for the derby!", moraleDelta: 6, confidenceDelta: 0),
            PressOption(label: "Stay classy", response: "The manager rose above the mind games, impressing the board.", moraleDelta: 2, confidenceDelta: 2),
            PressOption(label: "Ignore it", response: "The manager refused to engage with the taunts.", moraleDelta: 0, confidenceDelta: 0),
        ])
    }

    private func makePressQuestion() -> PressQuestion {
        let opponent = nextUserMatchInfo.map { info in
            clubs[info.homeIndex == userClubIndex ? info.awayIndex : info.homeIndex].name
        } ?? "the opposition"
        let prompts = [
            "How do you approach the game against \(opponent)?",
            "The fans want a statement — what's your message before \(opponent)?",
            "There's pressure on the team. What do you tell the press ahead of \(opponent)?",
        ]
        return PressQuestion(prompt: prompts.randomElement()!, options: [
            PressOption(label: "We're going for the win",
                        response: "The manager promised an all-out attacking display. The dressing room is fired up.",
                        moraleDelta: 5, confidenceDelta: 2),
            PressOption(label: "We respect them, but back ourselves",
                        response: "A measured, professional message from the boss.",
                        moraleDelta: 2, confidenceDelta: 1),
            PressOption(label: "The players must prove themselves",
                        response: "The manager publicly questioned his squad — not everyone was happy.",
                        moraleDelta: -3, confidenceDelta: -1),
        ])
    }

    /// Applies a press-conference / interview answer's effects.
    func answerPress(_ option: PressOption, headline: String = "Press conference") {
        for index in clubs[userClubIndex].players.indices {
            clubs[userClubIndex].players[index].morale =
                min(100, max(0, clubs[userClubIndex].players[index].morale + option.moraleDelta))
        }
        boardConfidence = min(100, max(0, boardConfidence + option.confidenceDelta))
        // Fans read the same interview — a bold promise or a dig at the
        // squad lands with them too, not just the boardroom.
        fanConfidence = min(100, max(0, fanConfidence + option.moraleDelta / 2))
        addNews(.board, headline, option.response)
        pendingPressQuestion = nil
    }

    /// Builds a post-match interview shaped by the result.
    func makePostMatchInterview(won: Bool, draw: Bool) -> PressQuestion {
        if won {
            return PressQuestion(prompt: "Delighted with that win, boss?", options: [
                PressOption(label: "Praise the players", response: "The manager heaped praise on his squad.", moraleDelta: 5, confidenceDelta: 2),
                PressOption(label: "Stay grounded", response: "“We move on to the next one.”", moraleDelta: 2, confidenceDelta: 1),
            ])
        } else if draw {
            return PressQuestion(prompt: "A point gained — satisfied?", options: [
                PressOption(label: "A fair result", response: "“A point on the board, we go again.”", moraleDelta: 1, confidenceDelta: 0),
                PressOption(label: "Two points dropped", response: "The boss demanded more from his team.", moraleDelta: -2, confidenceDelta: 1),
            ])
        } else {
            return PressQuestion(prompt: "A tough defeat — your reaction?", options: [
                PressOption(label: "Take responsibility", response: "“That’s on me, not the players.” The squad appreciated it.", moraleDelta: 2, confidenceDelta: 1),
                PressOption(label: "Criticise the players", response: "The manager laid into his team in public.", moraleDelta: -4, confidenceDelta: -1),
            ])
        }
    }

    /// Starts a live match for the user's next match (knockouts take priority).
    func beginUserMatch() {
        if autoPickAssist { smartAutoPick() }
        atPreMatch = false
        if isUserCommunityShieldToday, let tie = nextUserCommunityShieldTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: communityShieldDate(),
                             competitionName: Self.communityShieldName, roundName: "Final")
        } else if isUserUefaSuperCupToday, let tie = nextUserUefaSuperCupTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: uefaSuperCupDate(),
                             competitionName: Self.uefaSuperCupName, roundName: "Final")
        } else if isUserEuroToday, let tie = nextUserEuroTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: euroRoundDate(tie.round),
                             competitionName: Self.euroName,
                             roundName: euroRoundName(tieCount: euroTies.count))
        } else if isUserCupToday, let tie = nextUserCupTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: cupRoundDate(tie.round),
                             competitionName: Self.cupName,
                             roundName: cupRoundName(tieCount: cupTies.filter { !$0.isBye }.count))
        } else if isUserLeagueCupToday, let tie = nextUserLeagueCupTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: leagueCupRoundDate(tie.round),
                             competitionName: Self.leagueCupName,
                             roundName: leagueCupRoundName(tieCount: leagueCupTies.filter { !$0.isBye }.count))
        } else if isUserUefaCupToday, let tie = nextUserUefaCupTie {
            live = LiveMatch(store: self, knockoutTie: tie, date: uefaCupRoundDate(tie.round),
                             competitionName: Self.uefaCupName,
                             roundName: uefaCupRoundName(tieCount: uefaCupTies.filter { !$0.isBye }.count))
        } else if let fixture = nextUserFixture, isUserLeagueToday {
            live = LiveMatch(store: self, fixture: fixture)
        }
        live?.userMentality = preferredMentality
    }

    /// Commits a finished live match, simulates the rest of the round,
    /// and advances the calendar.
    func finishLiveMatch() {
        guard let match = live, match.isFinished else { return }
        if match.isCup {
            if match.tieID == communityShieldTie?.id { finishLiveCommunityShield(match) }
            else if match.tieID == uefaSuperCupTie?.id { finishLiveUefaSuperCup(match) }
            else if euroTies.contains(where: { $0.id == match.tieID }) { finishLiveEuroTie(match) }
            else if uefaCupTies.contains(where: { $0.id == match.tieID }) { finishLiveUefaCupTie(match) }
            else if leagueCupTies.contains(where: { $0.id == match.tieID }) { finishLiveLeagueCupTie(match) }
            else { finishLiveCupTie(match) }
            return
        }
        let day = currentMatchday

        // Record the user's result.
        if let fxIndex = fixtures.firstIndex(where: { $0.id == match.fixtureID }) {
            fixtures[fxIndex].played = true
            fixtures[fxIndex].homeGoals = match.homeGoals
            fixtures[fxIndex].awayGoals = match.awayGoals
            applyResult(clubIndex: match.homeIndex, scored: match.homeGoals, conceded: match.awayGoals, isHome: true, opponentIndex: match.awayIndex)
            applyResult(clubIndex: match.awayIndex, scored: match.awayGoals, conceded: match.homeGoals, isHome: false, opponentIndex: match.homeIndex)
            for id in match.homeScorerIDs { incrementGoal(clubIndex: match.homeIndex, playerID: id) }
            for id in match.awayScorerIDs { incrementGoal(clubIndex: match.awayIndex, playerID: id) }
        }

        var reports = [MatchReport(matchday: day,
                                   homeName: match.homeName, awayName: match.awayName,
                                   homeGoals: match.homeGoals, awayGoals: match.awayGoals,
                                   scorers: liveScorerNames(match), involvesUser: true)]

        // Simulate every other fixture in the round.
        for index in fixtures.indices where fixtures[index].matchday == day && !fixtures[index].played {
            reports.append(simulate(fixtureIndex: index))
        }
        lastReports = reports
        currentMatchday += 1

        // Heal existing knocks/bans, then apply this match's fresh ones so
        // they carry into the next round.
        advanceWeek()
        for out in match.injuredOut {
            setInjury(clubIndex: out.side == .home ? match.homeIndex : match.awayIndex,
                      playerID: out.id, weeks: Int.random(in: 2...5))
        }
        for red in match.sentOff {
            setSuspension(clubIndex: red.side == .home ? match.homeIndex : match.awayIndex,
                          playerID: red.id, matches: 1)
        }

        // Post-match: record player ratings, morale and board confidence.
        for (id, rating) in match.userPlayerRatingsByID {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                clubs[userClubIndex].players[index].ratingPoints += rating
                clubs[userClubIndex].players[index].apps += 1
                clubs[userClubIndex].players[index].recentRatings.append(rating)
                if clubs[userClubIndex].players[index].recentRatings.count > 5 {
                    clubs[userClubIndex].players[index].recentRatings.removeFirst()
                }
            }
        }
        let userScored = match.userSide == .home ? match.homeGoals : match.awayGoals
        let userConceded = match.userSide == .home ? match.awayGoals : match.homeGoals
        let won = userScored > userConceded
        let draw = userScored == userConceded
        let isDerby = RivalClubs.areRivals(match.homeName, match.awayName)
        let derbyBonus = isDerby ? (won ? 6 : (draw ? 0 : -6)) : 0
        for id in match.userAppearedIDs {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                let delta = won ? Int.random(in: 3...8) : (draw ? Int.random(in: -1...2) : -Int.random(in: 3...8))
                let scaledDelta = Int(Double(delta) * clubs[userClubIndex].players[index].personality.moraleSwingMultiplier)
                clubs[userClubIndex].players[index].morale = min(100, max(0, clubs[userClubIndex].players[index].morale + scaledDelta + derbyBonus))
            }
        }
        updateSquadMorale(appearedIDs: Set(match.userAppearedIDs))
        updateBoard(userWon: won, draw: draw, isHome: match.userSide == .home)
        checkWinMilestones()
        if won { checkGiantKilling(opponentIndex: match.userSide == .home ? match.awayIndex : match.homeIndex) }

        let outcome = won ? "Win" : (draw ? "Draw" : "Defeat")
        var body = "Full-time: \(match.homeName) \(match.homeGoals)-\(match.awayGoals) \(match.awayName)."
        if !match.motmName.isEmpty {
            body += " MOTM: \(match.motmName)."
            motmTally[match.motmName, default: 0] += 1
        }
        addNews(.result, isDerby ? "Derby \(outcome.lowercased())! (matchday \(day))" : "\(outcome) on matchday \(day)", body)

        if isSeasonOver { recordSeasonHonours() }
        live = nil
        persist()
    }

    /// Commits a finished live cup tie: records the result (penalties if
    /// drawn), applies player effects, and resolves the rest of the round.
    private func finishLiveCupTie(_ match: LiveMatch) {
        if let index = cupTies.firstIndex(where: { $0.id == match.tieID }) {
            var winner = match.homeGoals > match.awayGoals ? match.homeIndex
                : (match.awayGoals > match.homeGoals ? match.awayIndex : -1)
            var pens = false
            if winner == -1 {
                let hs = strengthValue(bestXI(for: clubs[match.homeIndex], formation: aiFormation(for: clubs[match.homeIndex]))) + 30
                let aws = strengthValue(bestXI(for: clubs[match.awayIndex], formation: aiFormation(for: clubs[match.awayIndex])))
                winner = Double.random(in: 0..<1) < hs / (hs + aws) ? match.homeIndex : match.awayIndex
                pens = true
            }
            cupTies[index].homeGoals = match.homeGoals
            cupTies[index].awayGoals = match.awayGoals
            cupTies[index].winnerIndex = winner
            cupTies[index].onPenalties = pens
            cupTies[index].played = true
        }
        applyLivePlayerEffects(match)
        concludeCupRound()
        live = nil
        persist()
    }

    /// Applies injuries, suspensions, ratings and morale from a live match
    /// (shared by league and cup, without touching the table or the board).
    private func applyLivePlayerEffects(_ match: LiveMatch) {
        for out in match.injuredOut {
            setInjury(clubIndex: out.side == .home ? match.homeIndex : match.awayIndex,
                      playerID: out.id, weeks: Int.random(in: 2...5))
        }
        for red in match.sentOff {
            setSuspension(clubIndex: red.side == .home ? match.homeIndex : match.awayIndex,
                          playerID: red.id, matches: 1)
        }
        for (id, rating) in match.userPlayerRatingsByID {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                clubs[userClubIndex].players[index].ratingPoints += rating
                clubs[userClubIndex].players[index].apps += 1
                clubs[userClubIndex].players[index].recentRatings.append(rating)
                if clubs[userClubIndex].players[index].recentRatings.count > 5 {
                    clubs[userClubIndex].players[index].recentRatings.removeFirst()
                }
            }
        }
        let userScored = match.userSide == .home ? match.homeGoals : match.awayGoals
        let userConceded = match.userSide == .home ? match.awayGoals : match.homeGoals
        let won = userScored > userConceded
        let draw = userScored == userConceded
        for id in match.userAppearedIDs {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                let delta = won ? Int.random(in: 3...8) : (draw ? Int.random(in: -1...2) : -Int.random(in: 3...8))
                clubs[userClubIndex].players[index].morale = min(100, max(0, clubs[userClubIndex].players[index].morale + delta))
            }
        }
        let appeared = clubs[userClubIndex].players.filter { match.userAppearedIDs.contains($0.id) }
        // A continental away trip costs extra condition on top of the
        // match itself — real travel fatigue, not just the 90 minutes.
        let isEuropeanAway = !match.isUserHome
            && (match.competition.contains(Self.euroName) || match.competition.contains(Self.uefaCupName))
        applyMatchFitness(clubIndex: userClubIndex, xi: appeared, extraFatigue: isEuropeanAway)
        if isEuropeanAway {
            addNews(.info, "Travel toll", "The away trip to Europe leaves the squad a little more fatigued than usual.")
        }
    }

    /// Drops match fitness for the players who featured in a fixture.
    /// `extraFatigue` adds an extra hit on top — used for a European away
    /// trip, where travel itself takes something out of the squad.
    private func applyMatchFitness(clubIndex: Int, xi: [Player], extraFatigue: Bool = false) {
        let ids = Set(xi.map { $0.id })
        let extra = extraFatigue ? Int.random(in: 6...12) : 0
        for index in clubs[clubIndex].players.indices where ids.contains(clubs[clubIndex].players[index].id) {
            clubs[clubIndex].players[index].fitness = max(30, clubs[clubIndex].players[index].fitness - Int.random(in: 10...20) - extra)
        }
    }

    private func incrementGoal(clubIndex: Int, playerID: UUID) {
        if let index = clubs[clubIndex].players.firstIndex(where: { $0.id == playerID }) {
            clubs[clubIndex].players[index].goals += 1
        }
    }

    private func setInjury(clubIndex: Int, playerID: UUID, weeks: Int) {
        if let index = clubs[clubIndex].players.firstIndex(where: { $0.id == playerID }) {
            let physioFactor = clubIndex == userClubIndex ? (1.0 - Double(staffLevel(.physio)) * 0.1) : 1.0
            let scaled = max(1, Int(Double(weeks) * clubs[clubIndex].players[index].durability.injuryDurationMultiplier * physioFactor))
            clubs[clubIndex].players[index].injuryWeeks = max(clubs[clubIndex].players[index].injuryWeeks, scaled)
            clubs[clubIndex].players[index].injuriesThisSeason += 1
        }
    }

    private func setSuspension(clubIndex: Int, playerID: UUID, matches: Int) {
        if let index = clubs[clubIndex].players.firstIndex(where: { $0.id == playerID }) {
            clubs[clubIndex].players[index].suspensionMatches = max(clubs[clubIndex].players[index].suspensionMatches, matches)
        }
    }

    private func liveScorerNames(_ match: LiveMatch) -> [String] {
        func names(_ ids: [UUID], clubIndex: Int) -> [String] {
            ids.compactMap { id in
                clubs[clubIndex].players.first { $0.id == id }
                    .map { "\($0.name) (\(clubs[clubIndex].shortName))" }
            }
        }
        return names(match.homeScorerIDs, clubIndex: match.homeIndex)
            + names(match.awayScorerIDs, clubIndex: match.awayIndex)
    }

    /// The starting XI and the available bench for a club going into a match.
    func matchLineupAndBench(forClubIndex index: Int) -> (xi: [Player], bench: [Player]) {
        let club = clubs[index]
        let xi = index == userClubIndex
            ? userStartingXI()
            : bestXI(for: club, formation: aiFormation(for: club))
        let xiIDs = Set(xi.map { $0.id })
        let bench = club.players.filter { $0.isAvailable && !xiIDs.contains($0.id) }
        return (xi, bench)
    }

    struct SquadNeed {
        let role: DetailedPosition
        let count: Int
    }

    /// Detailed positions where the user's squad is dangerously thin —
    /// fewer than two available players who can competently fill that
    /// role (a natural, secondary or related fit), sorted worst first.
    func squadNeeds() -> [SquadNeed] {
        DetailedPosition.allCases.compactMap { role in
            let count = userClub.players.filter { $0.isAvailable && $0.fit(for: role) >= 1 }.count
            return count < 2 ? SquadNeed(role: role, count: count) : nil
        }.sorted { $0.count < $1.count }
    }

    /// A handful of transfer-market targets that would plug the squad's
    /// thinnest positions and actually fit the budget — a lightweight
    /// "director of football" nudge, not a full scouting network.
    func suggestedTransferTargets(limit: Int = 5) -> [TransferTarget] {
        let thinRoles = Set(squadNeeds().map { $0.role })
        guard !thinRoles.isEmpty else { return [] }
        return Array(transferMarket
            .filter { target in
                thinRoles.contains { target.player.fit(for: $0) >= 1 }
                    && target.askingPrice <= userClub.transferBudget
                    && userClub.wageBill + target.player.wage <= userClub.wageBudget
            }
            .sorted { $0.player.rating > $1.player.rating }
            .prefix(limit))
    }

    /// The home ground name and capacity for a club, scaled by its stature.
    /// Ground capacity, scaled by division and prestige to roughly match
    /// real English (and European) crowd sizes — not exact, just the right
    /// order of magnitude at each level.
    func stadiumInfo(forClubIndex index: Int) -> (name: String, capacity: Int) {
        let club = clubs[index]
        let range: (min: Int, max: Int)
        switch club.divisionTier {
        case 0:  range = (20_000, 76_000)   // First Division
        case 1:  range = (10_000, 32_000)   // Second Division
        case 2:  range = (5_000, 20_000)    // Third Division
        case 3:  range = (3_000, 12_000)    // Fourth Division
        case Self.foreignTier: range = (40_000, 90_000)   // European giants
        default:
            // Spain/Italy/Germany/France: top-flight vs second-tier grounds.
            let topFlightTiers = [ForeignLeagues.spainTier1, ForeignLeagues.italyTier1,
                                  ForeignLeagues.germanyTier1, ForeignLeagues.franceTier1]
            range = topFlightTiers.contains(club.divisionTier) ? (14_000, 50_000) : (4_000, 22_000)
        }
        let normalized = min(1, max(0, Double(club.prestige - 45) / Double(94 - 45)))
        let base = range.min + Int(Double(range.max - range.min) * normalized)
        let expanded = Int(Double(base) * (1.0 + 0.08 * Double(club.stadiumExpansionLevel)))
        return ("\(club.name) Stadium", expanded)
    }

    /// The cost to expand a club's stadium by one level (0...5), in £000s —
    /// steeper each time, like a real construction project.
    func stadiumUpgradeCost(forClubIndex index: Int) -> Int? {
        let level = clubs[index].stadiumExpansionLevel
        guard level < 5 else { return nil }
        return 1_200 * (level + 1) * (level + 1)
    }

    /// Spends transfer budget to expand the user's stadium by one level.
    @discardableResult
    func investInStadium() -> String {
        guard let cost = stadiumUpgradeCost(forClubIndex: userClubIndex) else {
            return "The stadium is already at its maximum size."
        }
        guard userClub.transferBudget >= cost else {
            return "Not enough in the transfer budget for this expansion (\(formatMoney(cost)))."
        }
        clubs[userClubIndex].transferBudget -= cost
        clubs[userClubIndex].stadiumExpansionLevel += 1
        let newCapacity = stadiumInfo(forClubIndex: userClubIndex).capacity
        addNews(.board, "Stadium expansion approved",
                "Work begins to grow \(userClub.name)'s ground — new capacity around \(newCapacity.formatted()).")
        logLedger("Investment", amount: -cost, "Stadium expansion")
        persist()
        return "Stadium expansion approved — new capacity around \(newCapacity.formatted())."
    }

    /// The cost to upgrade a club's youth academy by one level (0...5).
    func youthUpgradeCost(forClubIndex index: Int) -> Int? {
        let level = clubs[index].youthFacilityLevel
        guard level < 5 else { return nil }
        return 900 * (level + 1) * (level + 1)
    }

    /// Spends transfer budget to improve the user's youth academy —
    /// stronger, more frequent, and more likely to unearth a foreign
    /// wonderkid in future intakes.
    @discardableResult
    func investInYouthAcademy() -> String {
        guard let cost = youthUpgradeCost(forClubIndex: userClubIndex) else {
            return "The academy is already at its best facilities."
        }
        guard userClub.transferBudget >= cost else {
            return "Not enough in the transfer budget for this upgrade (\(formatMoney(cost)))."
        }
        clubs[userClubIndex].transferBudget -= cost
        clubs[userClubIndex].youthFacilityLevel += 1
        addNews(.board, "Academy investment approved",
                "\(userClub.name) invest in better training facilities for the youth academy.")
        logLedger("Investment", amount: -cost, "Youth academy upgrade")
        persist()
        return "Academy upgraded to level \(clubs[userClubIndex].youthFacilityLevel)."
    }

    /// A matchday attendance for a fixture — a fraction of capacity that
    /// leans on the home club's own pull, nudged up for a big away side,
    /// a local derby, or a cup tie, and down for a struggling smaller club.
    func expectedAttendance(homeIndex: Int, awayIndex: Int, isCup: Bool) -> Int {
        let capacity = stadiumInfo(forClubIndex: homeIndex).capacity
        let homePrestige = clubs[homeIndex].prestige
        let awayPrestige = clubs[awayIndex].prestige
        let base = 0.5 + 0.42 * min(1, max(0, Double(homePrestige - 45) / Double(94 - 45)))
        let bigAwayDraw = awayPrestige > homePrestige + 8 ? 0.06 : 0.0
        let derbyBonus = RivalClubs.areRivals(clubs[homeIndex].name, clubs[awayIndex].name) ? 0.10 : 0.0
        let cupBonus = isCup ? 0.04 : 0.0
        let formBonus = (Double(clubs[homeIndex].won) - Double(clubs[homeIndex].lost)) * 0.004
        // Only tracked for the user's own club — an angry fanbase stays
        // away, a buzzing one packs the ground beyond what form alone explains.
        let fanFactor = homeIndex == userClubIndex ? (Double(fanConfidence) - 50) * 0.0025 : 0.0
        // Premium pricing keeps some seats empty; cheap tickets fill them.
        let priceFactor = -Double(clubs[homeIndex].ticketPriceLevel - 3) * 0.03
        let occupancy = min(1.0, max(0.30, base + bigAwayDraw + derbyBonus + cupBonus + formBonus + fanFactor + priceFactor
                                      + Double.random(in: -0.05...0.05)))
        return Int(Double(capacity) * occupancy)
    }

    /// The per-head matchday revenue at a club's current ticket price
    /// level, in whole pounds.
    private func pricePerHead(forClubIndex index: Int) -> Int {
        10 + clubs[index].ticketPriceLevel * 8
    }

    /// Sets the user's ticket price level (1 cheap ... 5 premium). Raising
    /// prices earns more per head but costs some attendance and fan
    /// goodwill; cutting them does the reverse.
    @discardableResult
    func setTicketPriceLevel(_ level: Int) -> String {
        let clamped = min(5, max(1, level))
        let previous = clubs[userClubIndex].ticketPriceLevel
        guard clamped != previous else { return "Ticket prices unchanged." }
        clubs[userClubIndex].ticketPriceLevel = clamped
        persist()
        if clamped > previous {
            fanConfidence = max(0, fanConfidence - (clamped - previous) * 4)
            addNews(.board, "Ticket prices raised", "The club raises ticket prices — some supporters grumble about the cost of watching their team.")
            return "Ticket prices raised. Fans aren't thrilled."
        } else {
            fanConfidence = min(100, fanConfidence + (previous - clamped) * 3)
            addNews(.board, "Ticket prices cut", "The club lowers ticket prices, welcomed by supporters.")
            return "Ticket prices lowered. Fans approve."
        }
    }

    // MARK: - Injuries & suspensions

    /// Seeds a couple of injuries so the Medical Centre isn't empty at kick-off.
    private func seedInjuries() {
        for clubIndex in clubs.indices {
            let count = Int.random(in: 0...2)
            for _ in 0..<count { injureRandomPlayer(clubIndex: clubIndex) }
        }
    }

    /// Heals injuries and suspensions by one round and rolls for a fresh
    /// knock at each club.
    private func advanceWeek() {
        for clubIndex in clubs.indices {
            for playerIndex in clubs[clubIndex].players.indices {
                if clubs[clubIndex].players[playerIndex].injuryWeeks > 0 {
                    clubs[clubIndex].players[playerIndex].injuryWeeks -= 1
                }
                if clubs[clubIndex].players[playerIndex].suspensionMatches > 0 {
                    clubs[clubIndex].players[playerIndex].suspensionMatches -= 1
                }
            }
            // Roughly a one-in-three chance of a fresh training-ground
            // injury — a physio on the staff cuts that down.
            let physioReduction = clubIndex == userClubIndex ? Double(staffLevel(.physio)) * 0.06 : 0
            if Double.random(in: 0..<1) < 0.30 - physioReduction {
                injureRandomPlayer(clubIndex: clubIndex)
            }
        }
        trainUserSquad()
    }

    /// Develops the user's players' attributes each week, per training focus.
    private func trainUserSquad() {
        for index in clubs[userClubIndex].players.indices {
            var player = clubs[userClubIndex].players[index]
            let devChance: Double
            switch player.age {
            case ..<22:   devChance = 0.30
            case 22...25: devChance = 0.15
            case 26...29: devChance = 0.06
            default:      devChance = 0.0
            }
            guard Double.random(in: 0..<1) < devChance else { continue }

            let focused = player.attributeOrder.filter { trainingFocus.preferred.isEmpty || trainingFocus.preferred.contains($0) }
            let pool = focused.isEmpty ? player.attributeOrder : focused
            if let name = pool.randomElement(), (player.attributes[name] ?? 0) < 20 {
                player.attributes[name]! += 1
            }
            // Young players can raise their overall rating (and value).
            if player.age <= 24, player.rating < 90, Double.random(in: 0..<1) < 0.5 {
                player.rating += 1
                player.value = playerValue(rating: player.rating, age: player.age, startYear: startYear)
            }
            clubs[userClubIndex].players[index] = player
        }
        trainYouthProspects()
    }

    /// A gentler version of first-team training for the academy's current
    /// crop, so a prospect sat in the pool for a few months is a little
    /// sharper by the time they're promoted, not still exactly as raw as
    /// the day they arrived.
    private func trainYouthProspects() {
        for index in youthProspects.indices where youthProspects[index].rating < 85 {
            guard Double.random(in: 0..<1) < 0.12 else { continue }
            youthProspects[index].rating += 1
            youthProspects[index].value = playerValue(rating: youthProspects[index].rating, age: youthProspects[index].age, startYear: startYear)
        }
    }

    /// Injures one fit player at the club for one to four weeks — a
    /// fragile player is more likely to be picked, and picks up a longer
    /// lay-off; a robust one, the opposite.
    private func injureRandomPlayer(clubIndex: Int) {
        let fit = clubs[clubIndex].players.indices.filter { clubs[clubIndex].players[$0].injuryWeeks == 0 }
        // A run of knocks this season makes a player temporarily more
        // likely to be the next one to break down, on top of their fixed
        // durability trait — a squad with an injury crisis feels like one.
        guard let target = weightedRandomIndex(from: Array(fit), weight: {
            clubs[clubIndex].players[$0].durability.injuryChanceMultiplier
                * (1.0 + Double(min(4, clubs[clubIndex].players[$0].injuriesThisSeason)) * 0.15)
        }) else { return }
        let base = Int.random(in: 1...4)
        let physioFactor = clubIndex == userClubIndex ? (1.0 - Double(staffLevel(.physio)) * 0.1) : 1.0
        clubs[clubIndex].players[target].injuryWeeks = max(1, Int(Double(base) * clubs[clubIndex].players[target].durability.injuryDurationMultiplier * physioFactor))
        clubs[clubIndex].players[target].injuriesThisSeason += 1
    }

    /// The injured players in a club's squad, worst injuries first.
    func injuredPlayers(forClubIndex index: Int) -> [Player] {
        guard clubs.indices.contains(index) else { return [] }
        return clubs[index].players
            .filter { $0.isInjured }
            .sorted { $0.injuryWeeks > $1.injuryWeeks }
    }

    /// The suspended players in a club's squad, longest ban first.
    func suspendedPlayers(forClubIndex index: Int) -> [Player] {
        guard clubs.indices.contains(index) else { return [] }
        return clubs[index].players
            .filter { $0.isSuspended }
            .sorted { $0.suspensionMatches > $1.suspensionMatches }
    }

    /// A rough calendar date for when an injured player should be back —
    /// injuries heal at one week off per `advanceWeek()` call, so this is
    /// today plus seven days per week still remaining.
    func expectedReturnDate(for player: Player) -> Date? {
        guard player.injuryWeeks > 0 else { return nil }
        return Self.calendar.date(byAdding: .day, value: player.injuryWeeks * 7, to: currentDate)
    }

    // MARK: - Calendar

    private static let calendar = Calendar(identifier: .gregorian)
    /// Days from the season's start (1 July) until the opening fixture.
    private static let firstMatchOffsetDays = 35   // early August
    /// Days between successive matchdays — roughly weekly, so a 38-round
    /// season runs from August to May.
    private static let matchGapDays = 7

    /// The first calendar day of the current season (a July pre-season).
    /// Season 1 begins in the year 2000.
    private var seasonStartDate: Date {
        Self.calendar.date(from: DateComponents(year: (startYear - 1) + season, month: 7, day: 1)) ?? Date()
    }

    /// The date a given matchday is played.
    func date(forMatchday matchday: Int) -> Date {
        let days = Self.firstMatchOffsetDays + (matchday - 1) * Self.matchGapDays
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    /// The date of the given pre-season friendly (0 or 1), both well before
    /// the opening league fixture.
    private func friendlyDate(_ index: Int) -> Date {
        let days = 14 + index * 7
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    /// The pre-season friendlies scheduled for a given day.
    func friendlyFixtures(onDate day: Date) -> [Fixture] {
        friendlyFixtures.filter { Self.calendar.isDate(friendlyDate($0.matchday), inSameDayAs: day) }
    }

    /// The current in-game day, exposed to the UI as "today".
    var todayDate: Date { currentDate }

    // MARK: - Calendar

    /// The user division's league fixtures scheduled for a given day.
    func fixtures(onDate day: Date) -> [Fixture] {
        fixtures.filter {
            clubs[$0.homeIndex].divisionTier == userDivisionTier
                && Self.calendar.isDate(date(forMatchday: $0.matchday), inSameDayAs: day)
        }
    }

    /// The current-round domestic cup ties on a given day (past rounds are
    /// no longer retained once resolved — check the news feed for those).
    func cupTies(onDate day: Date) -> [CupTie] {
        guard cupRound > 0, Self.calendar.isDate(cupRoundDate(cupRound), inSameDayAs: day) else { return [] }
        return cupTies
    }

    /// The current-round Continental Cup ties on a given day.
    func euroTies(onDate day: Date) -> [CupTie] {
        guard euroRound > 0, Self.calendar.isDate(euroRoundDate(euroRound), inSameDayAs: day) else { return [] }
        return euroTies
    }

    /// The Community Trophy tie, if it's played on the given day.
    func communityShieldTie(onDate day: Date) -> CupTie? {
        guard let tie = communityShieldTie, Self.calendar.isDate(communityShieldDate(), inSameDayAs: day) else { return nil }
        return tie
    }

    /// News items posted on a given day.
    func news(onDate day: Date) -> [NewsItem] {
        news.filter { Self.calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Whether anything at all — a match, a cup tie, or news — happened or
    /// is scheduled on a given day. Used to draw the calendar's day dots.
    func hasCalendarEvent(onDate day: Date) -> Bool {
        !fixtures(onDate: day).isEmpty || !cupTies(onDate: day).isEmpty || !leagueCupTies(onDate: day).isEmpty
            || !euroTies(onDate: day).isEmpty || !uefaCupTies(onDate: day).isEmpty
            || communityShieldTie(onDate: day) != nil || uefaSuperCupTie(onDate: day) != nil
            || !news(onDate: day).isEmpty
    }

    /// The date of the user's next unplayed league fixture, if any.
    var nextUserFixtureDate: Date? {
        nextUserFixture.map { date(forMatchday: $0.matchday) }
    }

    /// The user's live cup tie in the current round (excludes byes), if any.
    var nextUserCupTie: CupTie? {
        guard cupWinnerName == nil else { return nil }
        return cupTies.first { !$0.played && !$0.isBye && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex) }
    }

    /// The date of the user's next cup tie, if they're still in the cup.
    var nextUserCupDate: Date? {
        nextUserCupTie.map { cupRoundDate($0.round) }
    }

    /// The user's live Continental Cup tie in the current round, if any.
    var nextUserEuroTie: CupTie? {
        guard euroWinnerName == nil else { return nil }
        return euroTies.first { !$0.played && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex) }
    }

    var nextUserEuroDate: Date? {
        nextUserEuroTie.map { euroRoundDate($0.round) }
    }

    private var isUserLeagueToday: Bool {
        guard let date = nextUserFixtureDate else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: date)
    }

    private var isUserCupToday: Bool {
        guard let date = nextUserCupDate else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: date)
    }

    private var isUserEuroToday: Bool {
        guard let date = nextUserEuroDate else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: date)
    }

    /// Whether the user has any match (league, cup, Europe or a one-off shield/super cup) today.
    var isUserMatchToday: Bool {
        isUserLeagueToday || isUserCupToday || isUserLeagueCupToday || isUserEuroToday
            || isUserUefaCupToday || isUserCommunityShieldToday || isUserUefaSuperCupToday
    }

    /// The date of the user's next commitment, across all competitions.
    var nextUserMatchDate: Date? {
        [nextUserFixtureDate, nextUserCupDate, nextUserLeagueCupDate, nextUserEuroDate, nextUserUefaCupDate,
         nextUserCommunityShieldTie != nil ? communityShieldDate() : nil,
         nextUserUefaSuperCupTie != nil ? uefaSuperCupDate() : nil].compactMap { $0 }.min()
    }

    /// Whole days until the user's next match (nil if none).
    var daysUntilNextMatch: Int? {
        guard let date = nextUserMatchDate else { return nil }
        let from = Self.calendar.startOfDay(for: currentDate)
        let to = Self.calendar.startOfDay(for: date)
        return Self.calendar.dateComponents([.day], from: from, to: to).day
    }

    /// Whether today's match (if any) is a knockout tie or one-off cup final.
    var isCupMatchDay: Bool {
        isUserCupToday || isUserLeagueCupToday || isUserEuroToday || isUserUefaCupToday
            || isUserCommunityShieldToday || isUserUefaSuperCupToday
    }

    // MARK: - Advancing the calendar

    /// Advances the game by a single day, up to the next match day.
    func advanceDay() {
        guard !isSeasonOver, !isUserMatchToday else { return }
        currentDate = Self.calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        dailyTick()
        persist()
    }

    /// Advances day by day until the next match, the season's end, or a
    /// freshly-arrived transfer offer that needs the manager's attention.
    /// Offers already pending when this is called (e.g. left over from an
    /// earlier skip) don't block progress — only a new one does.
    func advanceToNextMatch() async {
        let startingOfferCount = pendingOffers.count
        var safety = 0
        while !isSeasonOver && !isUserMatchToday && pendingOffers.count <= startingOfferCount && safety < 120 {
            advanceDay()
            safety += 1
            if safety.isMultiple(of: 4) { await Task.yield() }
        }
    }

    /// The CONTINUE button's fast-forward: advances day by day through the
    /// quiet stretches instead of making the manager tap through every
    /// blank day by hand, pulling up as soon as something worth their
    /// attention happens — new news in the inbox, a match day, or the
    /// season ending — whichever comes first.
    func advanceUntilNews() async {
        let startingUnreadCount = unreadNewsIDs.count
        var safety = 0
        while !isSeasonOver && !isUserMatchToday && unreadNewsIDs.count <= startingUnreadCount && safety < 120 {
            advanceDay()
            safety += 1
            if safety.isMultiple(of: 4) { await Task.yield() }
        }
    }

    /// Advances day by day up to a chosen calendar date, using the same
    /// stopping rules as `advanceToNextMatch` (season end, a match day, or
    /// a fresh transfer offer) — so simming to a distant date still pulls
    /// up short for anything that needs the manager's attention.
    ///
    /// `await Task.yield()` every few iterations hands control back to the
    /// run loop so the loading spinner actually animates instead of the
    /// whole UI freezing solid for however long this takes — without it,
    /// this whole while loop runs synchronously on the main actor in one
    /// shot and nothing else, including the spinner, gets to draw.
    func simTo(date target: Date) async {
        let startingOfferCount = pendingOffers.count
        var safety = 0
        while !isSeasonOver && !isUserMatchToday && pendingOffers.count <= startingOfferCount
                && currentDate < target && safety < 750 {
            advanceDay()
            safety += 1
            if safety.isMultiple(of: 4) { await Task.yield() }
        }
    }

    /// A harder fast-forward to a chosen date: any match due along the way
    /// — including the user's own, in any competition — is auto-resolved
    /// instead of pausing for live play. Still stops at season end.
    func forceSimTo(date target: Date) async {
        var safety = 0
        while !isSeasonOver && currentDate < target && safety < 750 {
            if isUserMatchToday {
                resolveTodaysUserMatchAbstractly()
            } else {
                advanceDay()
            }
            safety += 1
            if safety.isMultiple(of: 4) { await Task.yield() }
        }
        persist()
    }

    /// Resolves whichever competition has the user's match today without
    /// live play, then advances the calendar exactly as `advanceDay()` would.
    private func resolveTodaysUserMatchAbstractly() {
        if autoPickAssist { smartAutoPick() }
        if isUserCommunityShieldToday {
            resolveCommunityShield(homeGoals: nil, awayGoals: nil)
        } else if isUserUefaSuperCupToday {
            resolveUefaSuperCup(homeGoals: nil, awayGoals: nil)
        } else if isUserEuroToday {
            concludeEuroRound()
        } else if isUserUefaCupToday {
            concludeUefaCupRound()
        } else if isUserCupToday {
            concludeCupRound()
        } else if isUserLeagueCupToday {
            concludeLeagueCupRound()
        } else if isUserLeagueToday {
            forceResolveLeagueDay()
        }
        currentDate = Self.calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        dailyTick()
    }

    /// Simulates every fixture in the current matchday (including the
    /// user's) and advances the matchday counter, mirroring what
    /// `finishLiveMatch()` does for the rest of the round after a live game.
    private func forceResolveLeagueDay() {
        let day = currentMatchday
        for index in fixtures.indices where fixtures[index].matchday == day && !fixtures[index].played {
            let fixture = fixtures[index]
            let involvesUser = fixture.homeIndex == userClubIndex || fixture.awayIndex == userClubIndex
            _ = simulate(fixtureIndex: index)
            if involvesUser {
                let updated = fixtures[index]
                applyUserAbstractMatchOutcome(homeIndex: updated.homeIndex, awayIndex: updated.awayIndex,
                                              homeGoals: updated.homeGoals, awayGoals: updated.awayGoals)
            }
        }
        currentMatchday += 1
    }

    /// Applies the same squad-morale and board-confidence swing a live
    /// match would, for a league day resolved abstractly during force-sim
    /// — otherwise board confidence (and the sacking-risk meter) never
    /// moves at all for a manager who always force-sims through matches.
    private func applyUserAbstractMatchOutcome(homeIndex: Int, awayIndex: Int, homeGoals: Int, awayGoals: Int) {
        let userIsHome = homeIndex == userClubIndex
        let userScored = userIsHome ? homeGoals : awayGoals
        let userConceded = userIsHome ? awayGoals : homeGoals
        let won = userScored > userConceded
        let draw = userScored == userConceded
        let isDerby = RivalClubs.areRivals(clubs[homeIndex].name, clubs[awayIndex].name)
        let derbyBonus = isDerby ? (won ? 6 : (draw ? 0 : -6)) : 0
        for id in userStarterIDs {
            if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == id }) {
                let delta = won ? Int.random(in: 3...8) : (draw ? Int.random(in: -1...2) : -Int.random(in: 3...8))
                let scaledDelta = Int(Double(delta) * clubs[userClubIndex].players[index].personality.moraleSwingMultiplier)
                clubs[userClubIndex].players[index].morale = min(100, max(0, clubs[userClubIndex].players[index].morale + scaledDelta + derbyBonus))
            }
        }
        updateSquadMorale(appearedIDs: userStarterIDs)
        updateBoard(userWon: won, draw: draw, isHome: userIsHome)
        if won { checkGiantKilling(opponentIndex: userIsHome ? awayIndex : homeIndex) }
    }

    /// A one-off extra reputation and confidence bump for beating a club
    /// far above you in prestige — recognition beyond what a normal win
    /// already earns, on top of `updateBoard`.
    private func checkGiantKilling(opponentIndex: Int) {
        let gap = clubs[opponentIndex].prestige - userClub.prestige
        guard gap >= 15 else { return }
        boardConfidence = min(100, boardConfidence + 5)
        fanConfidence = min(100, fanConfidence + 8)
        managerReputation = min(100, managerReputation + 3)
        addNews(.board, "Giant-killing!",
                "\(userClub.name)'s win over the much-fancied \(clubs[opponentIndex].name) turns heads — a real statement result.")
    }

    /// Simulates the goings-on of a single day: transfer activity and news.
    private func dailyTick() {
        expireOffers()
        checkPendingTransferDeals()
        completeScouting()
        recoverFitness()
        progressRetraining()
        checkRealTransferHeadlines()
        checkOwnershipChanges()
        checkMarqueePlayerArrivals()
        checkMarqueePlayerTransfers()
        checkMonthlyAwards()
        checkInternationalCallUps()
        checkRivalManagerSackings()
        checkShortlistAvailability()
        checkObjectiveRisk()
        maybeProcessFriendlies()
        maybeProcessCommunityShield()
        maybeProcessUefaSuperCup()
        maybeProcessCupRound()
        maybeProcessLeagueCupRound()
        maybeProcessEuroRound()
        maybeProcessUefaCupRound()
        let open = transferWindowOpen
        if open && !windowWasOpen {
            generateTransferMarket()
            addNews(.info, "Transfer window open", "Clubs can now buy and sell players.")
            transferBudgetAtWindowOpen = userClub.transferBudget
        } else if !open && windowWasOpen {
            addNews(.info, "Transfer window closed", "No more transfers until the next window.")
            reviewTransferWindowClose()
        }
        windowWasOpen = open

        if open {
            if let days = daysUntilTransferDeadline, days == 2 {
                addNews(.info, "Deadline day looms", "The transfer window shuts in 48 hours — expect late business.")
            } else if let days = daysUntilTransferDeadline, days == 0, !deadlineDayAnnounced {
                deadlineDayAnnounced = true
                addNews(.info, "Deadline day", "Transfer deadline day is here — clubs will be busy right up to the wire.")
            }
            // A last-minute scramble: AI clubs chase far more business in
            // the final 48 hours than on an ordinary day.
            let aiTransferAttempts = isDeadlineDayRush ? Int.random(in: 2...4) : (Double.random(in: 0..<1) < 0.5 ? 1 : 0)
            for _ in 0..<aiTransferAttempts { processAITransfer() }
            let offerChance = isDeadlineDayRush ? 0.20 : 0.08
            if pendingOffers.count < 2 && Double.random(in: 0..<1) < offerChance { generateOfferForUser() }
            maybeGenerateTransferRumour()
        }
    }

    /// Pure gossip: an unverified "linked with a move" story about an
    /// in-game player, using the same clubs and squads as everything else
    /// but never actually moving anyone — flavour for the inbox between
    /// real signings.
    private func maybeGenerateTransferRumour() {
        guard Double.random(in: 0..<1) < 0.06 else { return }
        let candidates = clubs.indices.filter { clubs[$0].divisionTier < 4 }
        guard let subjectClubIndex = candidates.randomElement(),
              let subject = clubs[subjectClubIndex].players.filter({ $0.rating >= 65 }).randomElement() else { return }
        let suitors = candidates.filter { $0 != subjectClubIndex && clubs[$0].prestige >= clubs[subjectClubIndex].prestige - 5 }
        guard let suitorIndex = suitors.randomElement() else { return }
        let subjectName = clubs[subjectClubIndex].name
        let suitorName = clubs[suitorIndex].name
        let templates = [
            "\(suitorName) are understood to be monitoring \(subject.name)'s situation at \(subjectName).",
            "Reports link \(subject.name) with a possible move to \(suitorName), though \(subjectName) are yet to comment.",
            "\(suitorName) have been credited with interest in \(subjectName)'s \(subject.name).",
            "Speculation continues to link \(subject.name) with a switch to \(suitorName) — nothing concrete yet.",
        ]
        addNews(.world, "Transfer gossip", templates.randomElement() ?? templates[0])
    }

    /// Everyone recovers a little match fitness on a rest day.
    private func recoverFitness() {
        for clubIndex in clubs.indices {
            for index in clubs[clubIndex].players.indices {
                let current = clubs[clubIndex].players[index].fitness
                if current < 100 {
                    clubs[clubIndex].players[index].fitness = min(100, current + Int.random(in: 3...6))
                }
            }
        }
    }

    /// Advances any in-progress position retraining by a day; when it
    /// completes, the trained role becomes an official secondary position.
    private func progressRetraining() {
        for index in clubs[userClubIndex].players.indices {
            guard let role = clubs[userClubIndex].players[index].retrainingRole else { continue }
            clubs[userClubIndex].players[index].retrainingDaysRemaining -= 1
            if clubs[userClubIndex].players[index].retrainingDaysRemaining <= 0 {
                let name = clubs[userClubIndex].players[index].name
                if !clubs[userClubIndex].players[index].secondaryPositions.contains(role) {
                    clubs[userClubIndex].players[index].secondaryPositions.append(role)
                }
                clubs[userClubIndex].players[index].retrainingRole = nil
                clubs[userClubIndex].players[index].retrainingDaysRemaining = 0
                addNews(.board, "Retraining complete", "\(name) has completed retraining and can now play \(role.fullName).")
            }
        }
    }

    enum RetrainingOutcome {
        case started(String)
        case blocked(String)
    }

    /// Begins retraining a squad player toward a new detailed role within
    /// their own broad position — you can't retrain a striker into a
    /// goalkeeper, but a centre-back can learn to play left-back, or a
    /// central midfielder can learn to play out wide.
    @discardableResult
    func beginRetraining(_ player: Player, toward role: DetailedPosition) -> RetrainingOutcome {
        guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else {
            return .blocked("That player is not in your squad.")
        }
        guard role.broad == player.position else {
            return .blocked("\(player.name) can't retrain outside \(player.position.rawValue).")
        }
        guard role != player.detailedPosition, !player.secondaryPositions.contains(role) else {
            return .blocked("\(player.name) can already play \(role.fullName).")
        }
        let familiar = player.fit(for: role) >= 1
        let baseDays = (familiar ? 5 : 9) * 7
        let ageAdjust = player.age <= 23 ? -14 : (player.age >= 30 ? 14 : 0)
        let days = max(21, baseDays + ageAdjust)
        clubs[userClubIndex].players[index].retrainingRole = role
        clubs[userClubIndex].players[index].retrainingDaysRemaining = days
        addNews(.board, "Retraining started", "\(player.name) begins training to play \(role.fullName), expected to take about \(days / 7) weeks.")
        persist()
        return .started("\(player.name) is now training for \(role.fullName) (~\(days / 7) weeks).")
    }

    /// Hands out a Manager of the Month award for the user's own division
    /// when the calendar rolls into a new month, based on points earned
    /// since the last check (not the raw season total, so it rewards
    /// recent form rather than always crowning the runaway leader).
    private func checkMonthlyAwards() {
        guard let year = Self.calendar.dateComponents([.year], from: currentDate).year else { return }
        let month = Self.calendar.component(.month, from: currentDate)
        let key = year * 12 + month
        guard key != lastMonthlyAwardKey else { return }
        let previousKey = lastMonthlyAwardKey
        lastMonthlyAwardKey = key
        let table = leagueTable(tier: userDivisionTier)
        defer { monthlyAwardBaseline = Dictionary(uniqueKeysWithValues: table.map { ($0.id, $0.points) }) }
        guard previousKey != 0 else { return }   // first check this game — just seed the baseline

        let improvements = table.compactMap { club -> (Club, Int)? in
            guard let before = monthlyAwardBaseline[club.id] else { return nil }
            return (club, club.points - before)
        }
        if let best = improvements.max(by: { $0.1 < $1.1 }), best.1 > 0,
           let index = clubs.firstIndex(where: { $0.id == best.0.id }) {
            addNews(.board, "Manager of the Month",
                    "\(managers[index]) (\(best.0.name)) takes the award after \(best.1) point\(best.1 == 1 ? "" : "s") from their last few fixtures.")
        }
        awardClubPlayerOfTheMonth()
        punditPowerRankings()
    }

    /// A monthly pundit-style top-5 roundup for the user's division — a
    /// different flavour of "how are things going" than the plain
    /// standings table, with a nod to where the user's club sits if
    /// they're outside it.
    private func punditPowerRankings() {
        let table = leagueTable(tier: userDivisionTier)
        let top5 = Array(table.prefix(5))
        guard !top5.isEmpty else { return }
        let lines = top5.enumerated().map { "\($0.offset + 1). \($0.element.name)" }.joined(separator: ", ")
        var body = "This month's power rankings: \(lines)."
        if let userRank = table.firstIndex(where: { $0.id == userClub.id }), userRank >= 5 {
            body += " \(userClub.name) sit \(userRank + 1)\(ordinalSuffix(userRank + 1)) — plenty to play for."
        }
        addNews(.info, "Power rankings", body)
    }

    private func ordinalSuffix(_ n: Int) -> String {
        let mod100 = n % 100
        if (11...13).contains(mod100) { return "th" }
        switch n % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    /// The user's own standout performer over recent matches — a smaller,
    /// squad-morale-boosting sibling to the league-wide Manager of the Month.
    private func awardClubPlayerOfTheMonth() {
        func recentAverage(_ p: Player) -> Double {
            p.recentRatings.isEmpty ? 0 : p.recentRatings.reduce(0, +) / Double(p.recentRatings.count)
        }
        guard let best = userClub.players.filter({ $0.recentRatings.count >= 2 }).max(by: { recentAverage($0) < recentAverage($1) })
        else { return }
        addNews(.board, "Player of the Month",
                "\(best.name) is named \(userClub.name)'s Player of the Month after a string of strong performances.")
        if let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == best.id }) {
            clubs[userClubIndex].players[index].morale = min(100, clubs[userClubIndex].players[index].morale + 5)
        }
    }

    /// Real-world international-break windows during an English season, as
    /// day offsets from the season's start. No nationality data exists in
    /// this game, so "called up" is a flavour/fitness-cost mechanic — your
    /// best players occasionally get pulled away — not a specific country's
    /// actual squad.
    private static let internationalBreakOffsets = [33, 63, 96, 145, 240]

    private func checkInternationalCallUps() {
        guard let daysSinceStart = Self.calendar.dateComponents([.day], from: seasonStartDate, to: currentDate).day,
              Self.internationalBreakOffsets.contains(daysSinceStart) else { return }
        let candidates = userClub.players.filter { $0.rating >= 78 && $0.isAvailable }
        guard !candidates.isEmpty else { return }
        let called = Array(candidates.sorted { $0.rating > $1.rating }.prefix(Int.random(in: 1...3)))
        guard !called.isEmpty else { return }
        for player in called {
            guard let index = clubs[userClubIndex].players.firstIndex(where: { $0.id == player.id }) else { continue }
            clubs[userClubIndex].players[index].fitness = max(30, clubs[userClubIndex].players[index].fitness - Int.random(in: 15...25))
            clubs[userClubIndex].players[index].morale = min(100, clubs[userClubIndex].players[index].morale + 3)
        }
        let names = called.map { $0.name }.joined(separator: ", ")
        addNews(.info, "International call-ups",
                "\(names) \(called.count == 1 ? "has" : "have") been called up for international duty during the break — expect \(called.count == 1 ? "him" : "them") back a little jaded.")
    }

    /// A small daily chance that a struggling AI club sacks its manager —
    /// the wider world keeps turning even when it isn't your own job on
    /// the line.
    private func checkRivalManagerSackings() {
        guard hasStarted, !isSeasonOver, Double.random(in: 0..<1) < 0.006 else { return }
        var strugglers: [Club] = []
        for tier in 0..<Self.divisionNames.count {
            let table = leagueTable(tier: tier)
            guard table.count > 6 else { continue }
            strugglers.append(contentsOf: table.suffix(4).filter { $0.id != userClub.id && $0.played >= 8 })
        }
        guard let victim = strugglers.randomElement(),
              let index = clubs.firstIndex(where: { $0.id == victim.id }) else { return }
        let oldManager = managers[index]
        managers[index] = Self.randomManagerName()
        addNews(.world, "Manager sacked",
                "\(clubs[index].name) have sacked \(oldManager) after a difficult run of results. \(managers[index]) takes charge.")
    }

    /// A one-off ping (per season) when a shortlisted player enters the
    /// final year of his deal — worth a move now, or a free next summer.
    private func checkShortlistAvailability() {
        for (player, clubIndex) in shortlistedResults where clubIndex != userClubIndex {
            guard player.contractYears <= 1, !shortlistAlertedIDs.contains(player.id) else { continue }
            shortlistAlertedIDs.insert(player.id)
            addNews(.info, "Shortlist alert",
                    "\(player.name) (\(clubs[clubIndex].name)) is entering the final year of his contract — a move could be within reach.")
        }
    }

    /// A one-off warning, the first time the season is far enough along
    /// that current form is genuinely on track to miss the board's
    /// objective — rather than only finding out at the season review.
    private func checkObjectiveRisk() {
        guard !objectiveRiskWarned, isObjectiveAtRisk else { return }
        objectiveRiskWarned = true
        addNews(.board, "Under pressure",
                "With \(userClub.played) games gone, \(userClub.name) are off the pace for \"\(boardObjective)\" — the board will be watching closely.")
    }

    /// Fires any real-world "big transfer" headlines whose real announcement
    /// date the in-game calendar has just reached. Flavour only — none of
    /// these players or clubs exist in this game's world, so nothing here
    /// touches squads, budgets or results.
    private func checkRealTransferHeadlines() {
        for entry in RealTransfers.all where entry.year >= startYear {
            let eventID = "realTransfer-\(entry.year)-\(entry.month)-\(entry.day)-\(entry.headline)"
            guard !firedDatedEventIDs.contains(eventID),
                  let date = Self.calendar.date(from: DateComponents(year: entry.year, month: entry.month, day: entry.day)),
                  currentDate >= date else { continue }
            firedDatedEventIDs.insert(eventID)
            addNews(.world, entry.headline, entry.body)
        }
    }

    /// Fires a genuine transfer-budget boost when a real-world ownership
    /// change's announcement date is reached, for any of these clubs that
    /// exist in the English pyramid. Unlike `checkRealTransferHeadlines`,
    /// this one actually mutates the club's finances.
    private func checkOwnershipChanges() {
        for entry in OwnershipChanges.all where entry.year >= startYear {
            let eventID = "ownership-\(entry.club)"
            guard !firedDatedEventIDs.contains(eventID),
                  let date = Self.calendar.date(from: DateComponents(year: entry.year, month: entry.month, day: entry.day)),
                  currentDate >= date,
                  let index = clubs.firstIndex(where: { $0.name == entry.club }) else { continue }
            firedDatedEventIDs.insert(eventID)
            clubs[index].transferBudget = max(0, clubs[index].transferBudget + entry.budgetInjection)
            clubs[index].wageBudget = max(0, clubs[index].wageBudget + entry.budgetInjection / 6)
            if entry.prestigeBoost != 0 {
                clubs[index].prestige = min(95, clubs[index].prestige + entry.prestigeBoost)
            }
            addNews(.board, entry.headline, entry.body)
            if index == userClubIndex {
                logLedger("Ownership change", amount: entry.budgetInjection, entry.headline)
            }
        }
    }

    /// Adds a handful of real, recognisable players to the game world on
    /// their real breakthrough dates, in place of the weakest same-position
    /// player already at that club — the same "make room" pattern used for
    /// the researched foreign stars, just triggered by the calendar instead
    /// of at game creation.
    private func checkMarqueePlayerArrivals() {
        for entry in MarqueePlayers.arrivals where entry.year >= startYear {
            let eventID = "marqueeArrival-\(entry.name)"
            guard !firedDatedEventIDs.contains(eventID),
                  let date = Self.calendar.date(from: DateComponents(year: entry.year, month: entry.month, day: entry.day)),
                  currentDate >= date,
                  let clubIndex = clubs.firstIndex(where: { $0.name == entry.club }) else { continue }
            firedDatedEventIDs.insert(eventID)
            var player = Self.makePlayer(name: entry.name, position: entry.detailedPosition.broad,
                                         detailedPosition: entry.detailedPosition,
                                         secondaryPositions: entry.secondaryPositions,
                                         age: entry.age, rating: entry.rating, startYear: startYear)
            player.contractYears = Int.random(in: 3...5)
            if let weakestIndex = clubs[clubIndex].players.indices
                .filter({ clubs[clubIndex].players[$0].position == entry.detailedPosition.broad })
                .min(by: { clubs[clubIndex].players[$0].rating < clubs[clubIndex].players[$1].rating }) {
                clubs[clubIndex].players.remove(at: weakestIndex)
            }
            clubs[clubIndex].players.append(player)
            addNews(.transfer, entry.headline, entry.body, player: player, clubName: entry.club)
        }
    }

    /// Moves a real, already-in-the-world player to their real next club on
    /// their real transfer date. Silently skips if that player can't be
    /// found — sold, released or renamed some other way in this save —
    /// rather than risk a duplicate or a crash.
    private func checkMarqueePlayerTransfers() {
        for entry in MarqueePlayers.transfers where entry.year >= startYear {
            let eventID = "marqueeTransfer-\(entry.name)-\(entry.toClub)"
            guard !firedDatedEventIDs.contains(eventID),
                  let date = Self.calendar.date(from: DateComponents(year: entry.year, month: entry.month, day: entry.day)),
                  currentDate >= date,
                  let toIndex = clubs.firstIndex(where: { $0.name == entry.toClub }),
                  let fromIndex = clubs.firstIndex(where: { club in club.players.contains { $0.name == entry.name } }),
                  fromIndex != toIndex,
                  let playerIndex = clubs[fromIndex].players.firstIndex(where: { $0.name == entry.name }) else { continue }
            firedDatedEventIDs.insert(eventID)
            var player = clubs[fromIndex].players.remove(at: playerIndex)
            player.rating = entry.newRating
            player.value = playerValue(rating: entry.newRating, age: player.age, startYear: startYear)
            player.wage = playerWage(rating: entry.newRating, age: player.age, startYear: startYear)
            player.morale = 78
            player.contractYears = Int.random(in: 3...5)
            if let weakestIndex = clubs[toIndex].players.indices
                .filter({ clubs[toIndex].players[$0].position == player.position })
                .min(by: { clubs[toIndex].players[$0].rating < clubs[toIndex].players[$1].rating }) {
                clubs[toIndex].players.remove(at: weakestIndex)
            }
            clubs[toIndex].players.append(player)
            addNews(.transfer, entry.headline, entry.body, player: player, clubName: entry.toClub)
        }
    }

    // MARK: - Domestic cup

    /// The date a given cup round is played (spread across the season).
    /// Every competition's round gap is a multiple of 7 days and its base
    /// offset lands on a different weekday than the league's, so no cup
    /// round can ever fall on the same date as a league fixture, at any
    /// round number — no rescheduling is needed.
    func cupRoundDate(_ round: Int) -> Date {
        let days = Self.firstMatchOffsetDays + 26 + (round - 1) * 28
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    /// A friendly name for a round given how many ties it contains.
    func cupRoundName(tieCount: Int) -> String {
        switch tieCount {
        case 1:     return "Final"
        case 2:     return "Semi-finals"
        case 3...4: return "Quarter-finals"
        default:    return "Round \(cupRound)"
        }
    }

    var cupRoundLabel: String {
        cupWinnerName != nil ? "Completed" : cupRoundName(tieCount: cupTies.filter { !$0.isBye }.count)
    }

    /// Draws the first cup round from all clubs in the pyramid.
    private func startCup() {
        cupWinnerName = nil
        cupRound = 1
        cupTies = makeCupTies(from: Array(clubs.indices), round: 1)
    }

    /// Seeded draw: the stronger half is drawn against the weaker half so the
    /// big clubs are spread out (and lower sides get their shot at a giant).
    private func makeCupTies(from indices: [Int], round: Int) -> [CupTie] {
        let ranked = indices.sorted { clubs[$0].prestige > clubs[$1].prestige }
        let half = ranked.count / 2
        var seeds = Array(ranked[0..<half]).shuffled()
        var unseeded = Array(ranked[half...]).shuffled()
        var ties: [CupTie] = []
        while !seeds.isEmpty && !unseeded.isEmpty {
            ties.append(CupTie(round: round, homeIndex: seeds.removeFirst(), awayIndex: unseeded.removeFirst()))
        }
        var rest = (seeds + unseeded).shuffled()
        while rest.count >= 2 {
            ties.append(CupTie(round: round, homeIndex: rest.removeFirst(), awayIndex: rest.removeFirst()))
        }
        if let bye = rest.first {
            ties.append(CupTie(round: round, homeIndex: bye, awayIndex: bye))
        }
        return ties
    }

    /// Simulates a knockout tie, deciding drawn ties on penalties. `magic`
    /// flattens the strength gap toward a coin-flip, so higher values produce
    /// more cup upsets.
    private func simCupTie(_ homeIndex: Int, _ awayIndex: Int, magic: Double = 0) -> (hg: Int, ag: Int, winner: Int, pens: Bool) {
        if homeIndex == awayIndex { return (0, 0, homeIndex, false) }   // bye
        let homeStrength = strengthValue(bestXI(for: clubs[homeIndex], formation: aiFormation(for: clubs[homeIndex]))) + 30
        let awayStrength = strengthValue(bestXI(for: clubs[awayIndex], formation: aiFormation(for: clubs[awayIndex])))
        var ratio = homeStrength / (homeStrength + awayStrength)
        ratio = ratio * (1 - magic) + 0.5 * magic
        let hg = poisson(2.6 * ratio)
        let ag = poisson(2.6 * (1 - ratio))
        if hg != ag { return (hg, ag, hg > ag ? homeIndex : awayIndex, false) }
        let winner = Double.random(in: 0..<1) < ratio ? homeIndex : awayIndex
        return (hg, ag, winner, true)
    }

    /// Auto-plays a due cup round — but only when the user isn't in it (they
    /// play their own tie live).
    private func maybeProcessCupRound() {
        guard cupRound > 0, cupWinnerName == nil, !cupTies.isEmpty else { return }
        guard currentDate >= cupRoundDate(cupRound) else { return }
        guard cupTies.contains(where: { !$0.played }) else { return }
        guard nextUserCupTie == nil else { return }   // the user must play theirs live
        concludeCupRound()
    }

    /// Simulates any remaining ties in the current round, reports the user's
    /// outcome, and draws the next round (or crowns a winner).
    private func concludeCupRound() {
        for index in cupTies.indices where !cupTies[index].played {
            let result = simCupTie(cupTies[index].homeIndex, cupTies[index].awayIndex, magic: 0.28)
            cupTies[index].homeGoals = result.hg
            cupTies[index].awayGoals = result.ag
            cupTies[index].winnerIndex = result.winner
            cupTies[index].onPenalties = result.pens
            cupTies[index].played = true
        }

        // Headline the biggest giant-killing of the round.
        var upset: (gap: Int, text: String)?
        for tie in cupTies where !tie.isBye && tie.winnerIndex >= 0 {
            let loser = tie.winnerIndex == tie.homeIndex ? tie.awayIndex : tie.homeIndex
            let gap = clubs[tie.winnerIndex].divisionTier - clubs[loser].divisionTier
            if gap >= 2, upset == nil || gap > upset!.gap {
                upset = (gap, "\(clubs[tie.winnerIndex].name) (\(divisionName(clubs[tie.winnerIndex].divisionTier))) knock out \(clubs[loser].name)!")
            }
        }
        if let upset { addNews(.result, "\(Self.cupName) SHOCK", upset.text) }

        if let tie = cupTies.first(where: { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }) {
            let roundName = cupRoundName(tieCount: cupTies.filter { !$0.isBye }.count)
            if tie.isBye {
                addNews(.result, "\(Self.cupName): \(roundName)", "\(userClub.name) receive a bye to the next round.")
            } else {
                let opponent = clubs[tie.homeIndex == userClubIndex ? tie.awayIndex : tie.homeIndex]
                let advanced = tie.winnerIndex == userClubIndex
                let pens = tie.onPenalties ? " (on penalties)" : ""
                addNews(.result, "\(Self.cupName): \(roundName)",
                        "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(pens). "
                        + "\(userClub.name) \(advanced ? "advance vs \(opponent.shortName)." : "are knocked out by \(opponent.shortName).")")
            }
        }

        let winners = cupTies.map { $0.winnerIndex }
        if winners.count == 1 {
            let winnerIndex = winners[0]
            cupWinnerName = clubs[winnerIndex].name
            cupWinnerID = clubs[winnerIndex].id
            clubs[winnerIndex].transferBudget += 1_300
            addNews(.board, "\(Self.cupName) winners", "\(cupWinnerName!) lift the \(Self.cupName)!")
        } else {
            cupRound += 1
            cupTies = makeCupTies(from: winners, round: cupRound)
        }
    }

    // MARK: - League Trophy

    /// The date a given League Trophy round is played — offset from the FA
    /// Cup's own rounds so the two competitions don't collide.
    func leagueCupRoundDate(_ round: Int) -> Date {
        let days = Self.firstMatchOffsetDays + 9 + (round - 1) * 28
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    func leagueCupRoundName(tieCount: Int) -> String {
        switch tieCount {
        case 1:     return "Final"
        case 2:     return "Semi-finals"
        case 3...4: return "Quarter-finals"
        default:    return "Round \(leagueCupRound)"
        }
    }

    var leagueCupRoundLabel: String {
        leagueCupWinnerName != nil ? "Completed" : leagueCupRoundName(tieCount: leagueCupTies.filter { !$0.isBye }.count)
    }

    /// Draws the first League Trophy round from all clubs in the pyramid.
    private func startLeagueCup() {
        leagueCupWinnerName = nil
        leagueCupWinnerID = nil
        leagueCupRound = 1
        leagueCupTies = makeCupTies(from: Array(clubs.indices), round: 1)
    }

    /// The user's live League Trophy tie in the current round (excludes byes), if any.
    var nextUserLeagueCupTie: CupTie? {
        guard leagueCupWinnerName == nil else { return nil }
        return leagueCupTies.first { !$0.played && !$0.isBye && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex) }
    }

    var nextUserLeagueCupDate: Date? {
        nextUserLeagueCupTie.map { leagueCupRoundDate($0.round) }
    }

    private var isUserLeagueCupToday: Bool {
        guard let date = nextUserLeagueCupDate else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: date)
    }

    /// The League Trophy ties scheduled on a given day, for the calendar.
    func leagueCupTies(onDate day: Date) -> [CupTie] {
        guard leagueCupRound > 0, Self.calendar.isDate(leagueCupRoundDate(leagueCupRound), inSameDayAs: day) else { return [] }
        return leagueCupTies
    }

    /// Auto-plays a due League Trophy round when the user isn't in it.
    private func maybeProcessLeagueCupRound() {
        guard leagueCupRound > 0, leagueCupWinnerName == nil, !leagueCupTies.isEmpty else { return }
        guard currentDate >= leagueCupRoundDate(leagueCupRound) else { return }
        guard leagueCupTies.contains(where: { !$0.played }) else { return }
        guard nextUserLeagueCupTie == nil else { return }
        concludeLeagueCupRound()
    }

    private func concludeLeagueCupRound() {
        for index in leagueCupTies.indices where !leagueCupTies[index].played {
            let result = simCupTie(leagueCupTies[index].homeIndex, leagueCupTies[index].awayIndex, magic: 0.32)
            leagueCupTies[index].homeGoals = result.hg
            leagueCupTies[index].awayGoals = result.ag
            leagueCupTies[index].winnerIndex = result.winner
            leagueCupTies[index].onPenalties = result.pens
            leagueCupTies[index].played = true
        }

        if let tie = leagueCupTies.first(where: { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }) {
            let roundName = leagueCupRoundName(tieCount: leagueCupTies.filter { !$0.isBye }.count)
            if tie.isBye {
                addNews(.result, "\(Self.leagueCupName): \(roundName)", "\(userClub.name) receive a bye to the next round.")
            } else {
                let opponent = clubs[tie.homeIndex == userClubIndex ? tie.awayIndex : tie.homeIndex]
                let advanced = tie.winnerIndex == userClubIndex
                let pens = tie.onPenalties ? " (on penalties)" : ""
                addNews(.result, "\(Self.leagueCupName): \(roundName)",
                        "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(pens). "
                        + "\(userClub.name) \(advanced ? "advance vs \(opponent.shortName)." : "are knocked out by \(opponent.shortName).")")
            }
        }

        let winners = leagueCupTies.map { $0.winnerIndex }
        if winners.count == 1 {
            let winnerIndex = winners[0]
            leagueCupWinnerName = clubs[winnerIndex].name
            leagueCupWinnerID = clubs[winnerIndex].id
            clubs[winnerIndex].transferBudget += 700
            addNews(.board, "\(Self.leagueCupName) winners", "\(leagueCupWinnerName!) lift the \(Self.leagueCupName)!")
        } else {
            leagueCupRound += 1
            leagueCupTies = makeCupTies(from: winners, round: leagueCupRound)
        }
    }

    private func finishLiveLeagueCupTie(_ match: LiveMatch) {
        if let index = leagueCupTies.firstIndex(where: { $0.id == match.tieID }) {
            var winner = match.homeGoals > match.awayGoals ? match.homeIndex
                : (match.awayGoals > match.homeGoals ? match.awayIndex : -1)
            var pens = false
            if winner == -1 {
                let hs = strengthValue(bestXI(for: clubs[match.homeIndex], formation: aiFormation(for: clubs[match.homeIndex]))) + 30
                let aws = strengthValue(bestXI(for: clubs[match.awayIndex], formation: aiFormation(for: clubs[match.awayIndex])))
                winner = Double.random(in: 0..<1) < hs / (hs + aws) ? match.homeIndex : match.awayIndex
                pens = true
            }
            leagueCupTies[index].homeGoals = match.homeGoals
            leagueCupTies[index].awayGoals = match.awayGoals
            leagueCupTies[index].winnerIndex = winner
            leagueCupTies[index].onPenalties = pens
            leagueCupTies[index].played = true
        }
        applyLivePlayerEffects(match)
        concludeLeagueCupRound()
        live = nil
        persist()
    }

    // MARK: - Community Trophy

    /// The Community Trophy is played early in the pre-season.
    func communityShieldDate() -> Date {
        Self.calendar.date(byAdding: .day, value: 24, to: seasonStartDate) ?? seasonStartDate
    }

    /// Sets up the Community Trophy between last season's champion and cup winner.
    private func startCommunityShield() {
        communityShieldTie = nil
        communityShieldWinnerName = nil
        cupWinnerID = nil
        guard let championID = lastSeasonChampionID,
              let champion = clubs.firstIndex(where: { $0.id == championID }) else { return }
        var opponent = lastSeasonCupWinnerID.flatMap { id in clubs.firstIndex { $0.id == id } }
        // If the champion also won the cup (or the winner is gone), use the runner-up.
        if opponent == nil || opponent == champion {
            opponent = lastSeasonRunnerUpID.flatMap { id in clubs.firstIndex { $0.id == id } }
        }
        guard let away = opponent, away != champion else { return }
        communityShieldTie = CupTie(round: 0, homeIndex: champion, awayIndex: away)
    }

    var nextUserCommunityShieldTie: CupTie? {
        guard let tie = communityShieldTie, !tie.played,
              tie.homeIndex == userClubIndex || tie.awayIndex == userClubIndex else { return nil }
        return tie
    }

    private var isUserCommunityShieldToday: Bool {
        guard nextUserCommunityShieldTie != nil else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: communityShieldDate())
    }

    /// Resolves any pre-season friendly whose date has arrived. Always
    /// auto-resolved (never live) — the point is low-stakes fitness work,
    /// not a match to sit through. Result is flavour only: no league
    /// record, goalscorer tally or fitness drain, just a light sharpening
    /// for anyone who was short of full fitness.
    private func maybeProcessFriendlies() {
        for index in friendlyFixtures.indices where !friendlyFixtures[index].played
                && currentDate >= friendlyDate(friendlyFixtures[index].matchday) {
            let fixture = friendlyFixtures[index]
            let homeXI = matchXI(forClubIndex: fixture.homeIndex)
            let awayXI = matchXI(forClubIndex: fixture.awayIndex)
            let homeStrength = strengthValue(homeXI) + 15.0
            let awayStrength = strengthValue(awayXI)
            let ratio = homeStrength / (homeStrength + awayStrength)
            let homeGoals = poisson(2.4 * ratio)
            let awayGoals = poisson(2.4 * (1.0 - ratio))
            friendlyFixtures[index].played = true
            friendlyFixtures[index].homeGoals = homeGoals
            friendlyFixtures[index].awayGoals = awayGoals
            for player in homeXI + awayXI {
                sharpenFitness(playerID: player.id)
            }
            let home = clubs[fixture.homeIndex].name
            let away = clubs[fixture.awayIndex].name
            addNews(.result, "Pre-season friendly", "\(home) \(homeGoals) - \(awayGoals) \(away).")
        }
    }

    /// A friendly builds fitness rather than draining it, the opposite of a
    /// competitive match — that's the whole point of playing one.
    private func sharpenFitness(playerID: UUID) {
        for clubIndex in clubs.indices {
            guard let index = clubs[clubIndex].players.firstIndex(where: { $0.id == playerID }) else { continue }
            clubs[clubIndex].players[index].fitness = min(100, clubs[clubIndex].players[index].fitness + 10)
            return
        }
    }

    private func maybeProcessCommunityShield() {
        guard let tie = communityShieldTie, !tie.played else { return }
        guard currentDate >= communityShieldDate() else { return }
        guard nextUserCommunityShieldTie == nil else { return }   // user plays it live
        resolveCommunityShield(homeGoals: nil, awayGoals: nil)
    }

    /// Resolves the Community Trophy — from a live result if given, else simulated.
    private func resolveCommunityShield(homeGoals: Int?, awayGoals: Int?) {
        guard var tie = communityShieldTie else { return }
        if let hg = homeGoals, let ag = awayGoals {
            tie.homeGoals = hg; tie.awayGoals = ag
            if hg != ag { tie.winnerIndex = hg > ag ? tie.homeIndex : tie.awayIndex }
            else {
                let hs = strengthValue(bestXI(for: clubs[tie.homeIndex], formation: aiFormation(for: clubs[tie.homeIndex])))
                let aws = strengthValue(bestXI(for: clubs[tie.awayIndex], formation: aiFormation(for: clubs[tie.awayIndex])))
                tie.winnerIndex = Double.random(in: 0..<1) < hs / (hs + aws) ? tie.homeIndex : tie.awayIndex
                tie.onPenalties = true
            }
        } else {
            let result = simCupTie(tie.homeIndex, tie.awayIndex)
            tie.homeGoals = result.hg; tie.awayGoals = result.ag
            tie.winnerIndex = result.winner; tie.onPenalties = result.pens
        }
        tie.played = true
        communityShieldTie = tie
        communityShieldWinnerName = clubs[tie.winnerIndex].name
        clubs[tie.winnerIndex].transferBudget += 300
        addNews(.result, "\(Self.communityShieldName)",
                "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(tie.onPenalties ? " (pens)" : "") — \(communityShieldWinnerName!) win the \(Self.communityShieldName).")
    }

    private func finishLiveCommunityShield(_ match: LiveMatch) {
        applyLivePlayerEffects(match)
        resolveCommunityShield(homeGoals: match.homeGoals, awayGoals: match.awayGoals)
        live = nil
        persist()
    }

    // MARK: - Continental Cup

    /// The date a Continental Cup round is played.
    func euroRoundDate(_ round: Int) -> Date {
        let days = Self.firstMatchOffsetDays + 55 + (round - 1) * 42
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    func euroRoundName(tieCount: Int) -> String {
        switch tieCount {
        case 1:  return "Final"
        case 2:  return "Semi-finals"
        default: return "Quarter-finals"
        }
    }

    /// The global indices of the foreign clubs.
    var foreignClubIndices: [Int] {
        clubs.indices.filter { clubs[$0].divisionTier == Self.foreignTier }
    }

    /// A readable division label for a club (handles foreign clubs).
    func clubDivisionLabel(forClubIndex index: Int) -> String {
        guard clubs.indices.contains(index) else { return "" }
        let tier = clubs[index].divisionTier
        if tier == Self.foreignTier { return "European club" }
        if let division = ForeignLeagues.all.first(where: { $0.divisionTier == tier }) { return division.label }
        return divisionName(tier)
    }

    var euroRoundLabel: String {
        euroWinnerName != nil ? "Completed" : euroRoundName(tieCount: euroTies.count)
    }

    /// Whether the user's club is in this season's Continental Cup.
    var userInEurope: Bool {
        euroTies.contains { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }
            || euroWinnerName != nil && europeanQualifierIDs.contains(userClub.id)
    }

    /// Seeds the Continental Cup with the four qualifiers (last season's PL top 4,
    /// or the strongest PL clubs in season one).
    private func startEuropeanCup() {
        euroWinnerName = nil
        euroWinnerID = nil
        euroRound = 0
        euroTies = []
        var english = europeanQualifierIDs.compactMap { id in clubs.firstIndex { $0.id == id } }
        if english.count < 4 {
            // Season one: seed by prestige (no prior table yet).
            english = Array(clubIndices(inTier: 0).sorted { clubs[$0].prestige > clubs[$1].prestige }.prefix(4))
        }
        english = Array(english.prefix(4))
        // Eight-team field: four English qualifiers + four of this season's foreign giants.
        let field = (english + seasonForeignAllocation.europe).shuffled()
        guard field.count >= 2 else { return }
        euroRound = 1
        euroTies = makeEuroTies(from: field, round: 1)
    }

    /// This season's random split of the foreign pool between the European
    /// Cup and the Midweek Cup.
    /// The elite eight plus each of Spain/Italy/Germany/France's strongest
    /// club this season — the pool Continental Cup and Midweek Cup qualification
    /// draws from, so the continental field has some real variety.
    private var europeanCandidateIndices: [Int] {
        var candidates = foreignClubIndices
        let topFlightTiers = [ForeignLeagues.spainTier1, ForeignLeagues.italyTier1,
                              ForeignLeagues.germanyTier1, ForeignLeagues.franceTier1]
        for tier in topFlightTiers {
            if let best = clubs.indices.filter({ clubs[$0].divisionTier == tier })
                .max(by: { clubs[$0].prestige < clubs[$1].prestige }) {
                candidates.append(best)
            }
        }
        // Winning the domestic cup earns a European route too, even for a
        // club that isn't the country's biggest name — the same real-world
        // rule that lets a cup upset punch above its prestige.
        for winner in foreignCupWinnerIndices where !candidates.contains(winner) {
            candidates.append(winner)
        }
        return candidates
    }

    private func allocateForeignClubsForSeason() {
        let shuffled = europeanCandidateIndices.shuffled()
        seasonForeignAllocation = (Array(shuffled.prefix(4)), Array(shuffled.dropFirst(4).prefix(4)))
    }

    /// This season's foreign domestic cup winners (Spain/Italy/Germany/
    /// France), one club index each — recomputed at every season rollover.
    private var foreignCupWinnerIndices: [Int] = []

    /// The non-playable countries' own domestic cups, resolved abstractly
    /// at season's end — not a full bracket, just a plausible winner
    /// weighted by prestige (upsets can and do happen), whose reward is a
    /// genuine route into next season's European qualification pool.
    private func resolveForeignDomesticCups() {
        let cups: [(country: String, name: String, tiers: [Int])] = [
            ("Spain", "Copa del Rey", [ForeignLeagues.spainTier1, ForeignLeagues.spainTier2]),
            ("Italy", "Coppa Italia", [ForeignLeagues.italyTier1, ForeignLeagues.italyTier2]),
            ("Germany", "DFB-Pokal", [ForeignLeagues.germanyTier1, ForeignLeagues.germanyTier2]),
            ("France", "Coupe de France", [ForeignLeagues.franceTier1, ForeignLeagues.franceTier2]),
        ]
        var winners: [Int] = []
        for cup in cups {
            let candidates = clubs.indices.filter { cup.tiers.contains(clubs[$0].divisionTier) }
            guard let winnerIndex = weightedRandomIndex(from: candidates, weight: { Double(clubs[$0].prestige * clubs[$0].prestige) })
            else { continue }
            winners.append(winnerIndex)
            addNews(.world, "\(cup.name) winners",
                    "\(clubs[winnerIndex].name) win the \(cup.name), securing a route into next season's European draw.")
            bumpForeignPrestige(clubIndex: winnerIndex, by: 1)
        }
        foreignCupWinnerIndices = winners
    }

    /// A small, capped prestige nudge for a foreign (non-playable) club's
    /// silverware — so a country's footballing landscape drifts over a
    /// long career instead of staying frozen at its 2000/01 snapshot.
    /// Playable English-pyramid clubs are untouched; their prestige only
    /// moves via the deliberate, one-off ownership-change events.
    private func bumpForeignPrestige(clubIndex: Int, by amount: Int) {
        guard clubs[clubIndex].divisionTier >= 4 else { return }
        clubs[clubIndex].prestige = min(95, clubs[clubIndex].prestige + amount)
    }

    private func makeEuroTies(from indices: [Int], round: Int) -> [CupTie] {
        var ties: [CupTie] = []
        var i = 0
        while i + 1 < indices.count {
            ties.append(CupTie(round: round, homeIndex: indices[i], awayIndex: indices[i + 1]))
            i += 2
        }
        return ties
    }

    /// Auto-plays a due European round unless the user is in it (they play live).
    private func maybeProcessEuroRound() {
        guard euroRound > 0, euroWinnerName == nil, !euroTies.isEmpty else { return }
        guard currentDate >= euroRoundDate(euroRound) else { return }
        guard euroTies.contains(where: { !$0.played }) else { return }
        guard nextUserEuroTie == nil else { return }   // user plays their tie live
        concludeEuroRound()
    }

    private func concludeEuroRound() {
        for index in euroTies.indices where !euroTies[index].played {
            let result = simCupTie(euroTies[index].homeIndex, euroTies[index].awayIndex)
            euroTies[index].homeGoals = result.hg
            euroTies[index].awayGoals = result.ag
            euroTies[index].winnerIndex = result.winner
            euroTies[index].onPenalties = result.pens
            euroTies[index].played = true
        }

        if let tie = euroTies.first(where: { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }) {
            let opponent = clubs[tie.homeIndex == userClubIndex ? tie.awayIndex : tie.homeIndex]
            let advanced = tie.winnerIndex == userClubIndex
            addNews(.result, "\(Self.euroName): \(euroRoundName(tieCount: euroTies.count))",
                    "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(tie.onPenalties ? " (pens)" : ""). "
                    + "\(userClub.name) \(advanced ? "go through vs \(opponent.shortName)." : "are out, beaten by \(opponent.shortName).")")
        }

        let winners = euroTies.map { $0.winnerIndex }
        if winners.count == 1 {
            euroWinnerName = clubs[winners[0]].name
            euroWinnerID = clubs[winners[0]].id
            clubs[winners[0]].transferBudget += 6_500
            bumpForeignPrestige(clubIndex: winners[0], by: 3)
            addNews(.board, "\(Self.euroName) winners", "\(euroWinnerName!) are champions of Europe!")
        } else {
            euroRound += 1
            euroTies = makeEuroTies(from: winners, round: euroRound)
        }
    }

    /// Commits the user's finished live European tie, then resolves the round.
    private func finishLiveEuroTie(_ match: LiveMatch) {
        if let index = euroTies.firstIndex(where: { $0.id == match.tieID }) {
            var winner = match.homeGoals > match.awayGoals ? match.homeIndex
                : (match.awayGoals > match.homeGoals ? match.awayIndex : -1)
            var pens = false
            if winner == -1 {
                let hs = strengthValue(bestXI(for: clubs[match.homeIndex], formation: aiFormation(for: clubs[match.homeIndex]))) + 30
                let aws = strengthValue(bestXI(for: clubs[match.awayIndex], formation: aiFormation(for: clubs[match.awayIndex])))
                winner = Double.random(in: 0..<1) < hs / (hs + aws) ? match.homeIndex : match.awayIndex
                pens = true
            }
            euroTies[index].homeGoals = match.homeGoals
            euroTies[index].awayGoals = match.awayGoals
            euroTies[index].winnerIndex = winner
            euroTies[index].onPenalties = pens
            euroTies[index].played = true
        }
        applyLivePlayerEffects(match)
        concludeEuroRound()
        live = nil
        persist()
    }

    // MARK: - Midweek Cup

    /// The date a Midweek Cup round is played — offset from the European
    /// Cup's own rounds so the two competitions don't collide.
    func uefaCupRoundDate(_ round: Int) -> Date {
        let days = Self.firstMatchOffsetDays + 45 + (round - 1) * 42
        return Self.calendar.date(byAdding: .day, value: days, to: seasonStartDate) ?? seasonStartDate
    }

    func uefaCupRoundName(tieCount: Int) -> String {
        switch tieCount {
        case 1:     return "Final"
        case 2:     return "Semi-finals"
        case 3...4: return "Quarter-finals"
        default:    return "Round \(uefaCupRound)"
        }
    }

    var uefaCupRoundLabel: String {
        uefaCupWinnerName != nil ? "Completed" : uefaCupRoundName(tieCount: uefaCupTies.filter { !$0.isBye }.count)
    }

    /// Whether the user's club is in this season's Midweek Cup.
    var userInUefaCup: Bool {
        uefaCupTies.contains { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }
            || uefaCupWinnerName != nil && uefaCupQualifierIDs.contains(userClub.id)
    }

    /// Seeds the Midweek Cup with the next-best English clubs (those who just
    /// missed out on the Continental Cup) plus this season's other four
    /// foreign giants.
    private func startUefaCup() {
        uefaCupWinnerName = nil
        uefaCupWinnerID = nil
        uefaCupRound = 0
        uefaCupTies = []
        var english = uefaCupQualifierIDs.compactMap { id in clubs.firstIndex { $0.id == id } }
        if english.count < 4 {
            // Season one: seed by prestige, just below the Continental Cup qualifiers.
            english = Array(clubIndices(inTier: 0).sorted { clubs[$0].prestige > clubs[$1].prestige }
                .dropFirst(4).prefix(4))
        }
        english = Array(english.prefix(4))
        let field = english + seasonForeignAllocation.uefa
        guard field.count >= 2 else { return }
        uefaCupRound = 1
        uefaCupTies = makeCupTies(from: field, round: 1)
    }

    /// The user's live Midweek Cup tie in the current round (excludes byes), if any.
    var nextUserUefaCupTie: CupTie? {
        guard uefaCupWinnerName == nil else { return nil }
        return uefaCupTies.first { !$0.played && !$0.isBye && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex) }
    }

    var nextUserUefaCupDate: Date? {
        nextUserUefaCupTie.map { uefaCupRoundDate($0.round) }
    }

    private var isUserUefaCupToday: Bool {
        guard let date = nextUserUefaCupDate else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: date)
    }

    /// The Midweek Cup ties scheduled on a given day, for the calendar.
    func uefaCupTies(onDate day: Date) -> [CupTie] {
        guard uefaCupRound > 0, Self.calendar.isDate(uefaCupRoundDate(uefaCupRound), inSameDayAs: day) else { return [] }
        return uefaCupTies
    }

    /// Auto-plays a due Midweek Cup round unless the user is in it.
    private func maybeProcessUefaCupRound() {
        guard uefaCupRound > 0, uefaCupWinnerName == nil, !uefaCupTies.isEmpty else { return }
        guard currentDate >= uefaCupRoundDate(uefaCupRound) else { return }
        guard uefaCupTies.contains(where: { !$0.played }) else { return }
        guard nextUserUefaCupTie == nil else { return }
        concludeUefaCupRound()
    }

    private func concludeUefaCupRound() {
        for index in uefaCupTies.indices where !uefaCupTies[index].played {
            let result = simCupTie(uefaCupTies[index].homeIndex, uefaCupTies[index].awayIndex)
            uefaCupTies[index].homeGoals = result.hg
            uefaCupTies[index].awayGoals = result.ag
            uefaCupTies[index].winnerIndex = result.winner
            uefaCupTies[index].onPenalties = result.pens
            uefaCupTies[index].played = true
        }

        if let tie = uefaCupTies.first(where: { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }) {
            let roundName = uefaCupRoundName(tieCount: uefaCupTies.filter { !$0.isBye }.count)
            if tie.isBye {
                addNews(.result, "\(Self.uefaCupName): \(roundName)", "\(userClub.name) receive a bye to the next round.")
            } else {
                let opponent = clubs[tie.homeIndex == userClubIndex ? tie.awayIndex : tie.homeIndex]
                let advanced = tie.winnerIndex == userClubIndex
                let pens = tie.onPenalties ? " (on penalties)" : ""
                addNews(.result, "\(Self.uefaCupName): \(roundName)",
                        "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(pens). "
                        + "\(userClub.name) \(advanced ? "advance vs \(opponent.shortName)." : "are knocked out by \(opponent.shortName).")")
            }
        }

        let winners = uefaCupTies.map { $0.winnerIndex }
        if winners.count == 1 {
            let winnerIndex = winners[0]
            uefaCupWinnerName = clubs[winnerIndex].name
            uefaCupWinnerID = clubs[winnerIndex].id
            clubs[winnerIndex].transferBudget += 3_500
            bumpForeignPrestige(clubIndex: winnerIndex, by: 2)
            addNews(.board, "\(Self.uefaCupName) winners", "\(uefaCupWinnerName!) win the \(Self.uefaCupName)!")
        } else {
            uefaCupRound += 1
            uefaCupTies = makeCupTies(from: winners, round: uefaCupRound)
        }
    }

    private func finishLiveUefaCupTie(_ match: LiveMatch) {
        if let index = uefaCupTies.firstIndex(where: { $0.id == match.tieID }) {
            var winner = match.homeGoals > match.awayGoals ? match.homeIndex
                : (match.awayGoals > match.homeGoals ? match.awayIndex : -1)
            var pens = false
            if winner == -1 {
                let hs = strengthValue(bestXI(for: clubs[match.homeIndex], formation: aiFormation(for: clubs[match.homeIndex]))) + 30
                let aws = strengthValue(bestXI(for: clubs[match.awayIndex], formation: aiFormation(for: clubs[match.awayIndex])))
                winner = Double.random(in: 0..<1) < hs / (hs + aws) ? match.homeIndex : match.awayIndex
                pens = true
            }
            uefaCupTies[index].homeGoals = match.homeGoals
            uefaCupTies[index].awayGoals = match.awayGoals
            uefaCupTies[index].winnerIndex = winner
            uefaCupTies[index].onPenalties = pens
            uefaCupTies[index].played = true
        }
        applyLivePlayerEffects(match)
        concludeUefaCupRound()
        live = nil
        persist()
    }

    // MARK: - Continental Super Cup

    /// The Continental Super Cup is played early in the pre-season, after the FA
    /// Community Shield.
    func uefaSuperCupDate() -> Date {
        Self.calendar.date(byAdding: .day, value: 31, to: seasonStartDate) ?? seasonStartDate
    }

    /// Sets up the Continental Super Cup between last season's Continental Cup and
    /// Midweek Cup winners, if both are known.
    private func startUefaSuperCup() {
        uefaSuperCupTie = nil
        uefaSuperCupWinnerName = nil
        guard let euroWinnerID = lastSeasonEuroWinnerID, let uefaWinnerID = lastSeasonUefaCupWinnerID,
              let homeIndex = clubs.firstIndex(where: { $0.id == euroWinnerID }),
              let awayIndex = clubs.firstIndex(where: { $0.id == uefaWinnerID }), homeIndex != awayIndex
        else { return }
        uefaSuperCupTie = CupTie(round: 1, homeIndex: homeIndex, awayIndex: awayIndex)
    }

    var nextUserUefaSuperCupTie: CupTie? {
        guard let tie = uefaSuperCupTie, !tie.played,
              tie.homeIndex == userClubIndex || tie.awayIndex == userClubIndex else { return nil }
        return tie
    }

    private var isUserUefaSuperCupToday: Bool {
        guard nextUserUefaSuperCupTie != nil else { return false }
        return Self.calendar.isDate(currentDate, inSameDayAs: uefaSuperCupDate())
    }

    /// The Continental Super Cup tie, if it's played on the given day.
    func uefaSuperCupTie(onDate day: Date) -> CupTie? {
        guard let tie = uefaSuperCupTie, Self.calendar.isDate(uefaSuperCupDate(), inSameDayAs: day) else { return nil }
        return tie
    }

    /// Auto-plays the Continental Super Cup once its date arrives, unless the user is in it.
    private func maybeProcessUefaSuperCup() {
        guard let tie = uefaSuperCupTie, !tie.played else { return }
        guard currentDate >= uefaSuperCupDate() else { return }
        guard nextUserUefaSuperCupTie == nil else { return }
        resolveUefaSuperCup(homeGoals: nil, awayGoals: nil)
    }

    private func resolveUefaSuperCup(homeGoals: Int?, awayGoals: Int?) {
        guard var tie = uefaSuperCupTie else { return }
        let result: (hg: Int, ag: Int, winner: Int, pens: Bool)
        if let homeGoals, let awayGoals {
            if homeGoals != awayGoals {
                result = (homeGoals, awayGoals, homeGoals > awayGoals ? tie.homeIndex : tie.awayIndex, false)
            } else {
                let hs = strengthValue(bestXI(for: clubs[tie.homeIndex], formation: aiFormation(for: clubs[tie.homeIndex]))) + 20
                let aws = strengthValue(bestXI(for: clubs[tie.awayIndex], formation: aiFormation(for: clubs[tie.awayIndex])))
                let winner = Double.random(in: 0..<1) < hs / (hs + aws) ? tie.homeIndex : tie.awayIndex
                result = (homeGoals, awayGoals, winner, true)
            }
        } else {
            result = simCupTie(tie.homeIndex, tie.awayIndex)
        }
        tie.homeGoals = result.hg
        tie.awayGoals = result.ag
        tie.winnerIndex = result.winner
        tie.onPenalties = result.pens
        tie.played = true
        uefaSuperCupTie = tie
        uefaSuperCupWinnerName = clubs[result.winner].name
        addNews(.result, "\(Self.uefaSuperCupName)",
                "\(clubs[tie.homeIndex].shortName) \(tie.homeGoals)-\(tie.awayGoals) \(clubs[tie.awayIndex].shortName)\(tie.onPenalties ? " (pens)" : "") — \(uefaSuperCupWinnerName!) win the \(Self.uefaSuperCupName).")
    }

    private func finishLiveUefaSuperCup(_ match: LiveMatch) {
        resolveUefaSuperCup(homeGoals: match.homeGoals, awayGoals: match.awayGoals)
        live = nil
        persist()
    }

    // MARK: - Match preview data

    /// A 1...5 star rating for a club, scaled across the league by strength.
    func starRating(forClubIndex index: Int) -> Int {
        starRatings(forClubIndices: [index])[index] ?? 1
    }

    /// A 1...5 fixture-difficulty rating for an upcoming opponent — just
    /// their own league-wide star rating, so a top club always reads as a
    /// tough game regardless of who's asking.
    func fixtureDifficulty(opponentIndex: Int) -> Int {
        starRating(forClubIndex: opponentIndex)
    }

    /// Star ratings for several clubs at once, sharing a single pass over
    /// every club's best XI instead of recomputing it per club requested.
    /// The full league-wide pass is genuinely expensive (every club's best
    /// XI across every formation), so it's cached for the current day
    /// rather than redone on every SwiftUI body evaluation — callers like
    /// the Home dashboard's fixture list can otherwise trigger it dozens
    /// of times a second during a single screen.
    func starRatings(forClubIndices indices: [Int]) -> [Int: Int] {
        if starRatingsCacheDate != currentDate {
            let strengths = clubs.indices.map { strengthValue(bestXI(for: clubs[$0], formation: aiFormation(for: clubs[$0]))) }
            let sorted = strengths.enumerated().sorted { $0.element > $1.element }
            let denominator = max(clubs.count - 1, 1)
            var cache: [Int: Int] = [:]
            for index in clubs.indices {
                let rank = sorted.firstIndex { $0.offset == index } ?? 0
                let stars = Int(round(5.0 - 4.0 * Double(rank) / Double(denominator)))
                cache[index] = min(5, max(1, stars))
            }
            starRatingsCache = cache
            starRatingsCacheDate = currentDate
        }
        var result: [Int: Int] = [:]
        for index in indices where clubs.indices.contains(index) {
            result[index] = starRatingsCache[index] ?? 1
        }
        return result
    }

    /// A club's recent results, oldest to newest, from its point of view.
    func recentForm(forClubIndex index: Int, count: Int = 5) -> [MatchOutcome] {
        let played = fixtures
            .filter { $0.played && ($0.homeIndex == index || $0.awayIndex == index) }
            .sorted { $0.matchday < $1.matchday }
            .suffix(count)
        return played.map { fixture in
            let isHome = fixture.homeIndex == index
            let scored = isHome ? fixture.homeGoals : fixture.awayGoals
            let conceded = isHome ? fixture.awayGoals : fixture.homeGoals
            if scored > conceded { return .win }
            if scored == conceded { return .draw }
            return .loss
        }
    }

    /// Win / draw / loss probabilities for a match between two clubs,
    /// derived from the same strength model the engine uses.
    func outcomeProbabilities(homeIndex: Int, awayIndex: Int) -> (home: Double, draw: Double, away: Double) {
        let homeStrength = strengthValue(matchXIForPreview(homeIndex)) + 40.0
        let awayStrength = strengthValue(matchXIForPreview(awayIndex))
        let ratio = homeStrength / (homeStrength + awayStrength)
        let homeExp = 2.7 * ratio
        let awayExp = 2.7 * (1.0 - ratio)

        func pmf(_ k: Int, _ lambda: Double) -> Double {
            var fact = 1.0
            for i in 1...max(k, 1) where k > 0 { fact *= Double(i) }
            return exp(-lambda) * pow(lambda, Double(k)) / (k == 0 ? 1.0 : fact)
        }

        var home = 0.0, draw = 0.0, away = 0.0
        for h in 0...8 {
            for a in 0...8 {
                let p = pmf(h, homeExp) * pmf(a, awayExp)
                if h > a { home += p } else if h == a { draw += p } else { away += p }
            }
        }
        let total = home + draw + away
        guard total > 0 else { return (0.34, 0.33, 0.33) }
        return (home / total, draw / total, away / total)
    }

    /// The XI used for previews (mirrors the engine's match selection).
    private func matchXIForPreview(_ index: Int) -> [Player] {
        if index == userClubIndex { return userStartingXI() }
        return bestXI(for: clubs[index], formation: aiFormation(for: clubs[index]))
    }

    // MARK: - Derived views

    /// Clubs in a division, sorted into league-table order.
    func leagueTable(tier: Int) -> [Club] {
        clubs.filter { $0.divisionTier == tier }.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.goalDifference != $1.goalDifference { return $0.goalDifference > $1.goalDifference }
            if $0.goalsFor != $1.goalsFor { return $0.goalsFor > $1.goalsFor }
            return $0.name < $1.name
        }
    }

    /// The user's own division table.
    func userTable() -> [Club] { leagueTable(tier: userDivisionTier) }

    /// The user club's current position in its division (1-based).
    var userPosition: Int {
        (userTable().firstIndex { $0.id == userClub.id } ?? 0) + 1
    }

    /// The 1-based position of any club within its own division.
    func position(ofClubIndex index: Int) -> Int {
        guard clubs.indices.contains(index) else { return 0 }
        let club = clubs[index]
        return (leagueTable(tier: club.divisionTier).firstIndex { $0.id == club.id } ?? 0) + 1
    }

    /// A short window of the user's fixtures: the most recent result plus
    /// the next few matches, for the home-screen summary.
    func userFixtureWindow(count: Int = 5) -> [Fixture] {
        let mine = fixtures
            .filter { $0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex }
            .sorted { $0.matchday < $1.matchday }
        let nextIndex = mine.firstIndex { !$0.played } ?? mine.count
        let start = max(0, nextIndex - 1)
        return Array(mine[start..<min(start + count, mine.count)])
    }

    /// The user club's next unplayed fixture, if any.
    var nextUserFixture: Fixture? {
        fixtures.first { !$0.played && ($0.homeIndex == userClubIndex || $0.awayIndex == userClubIndex) }
    }

    /// Every scheduled match the user is still involved in, across every
    /// competition, soonest first — the shared basis for "what's my next
    /// match" and "what's coming up after that".
    private var upcomingUserMatches: [(date: Date, info: UserMatchInfo)] {
        let candidates: [(date: Date, info: UserMatchInfo)] = [
            nextUserCommunityShieldTie.map { tie in
                (communityShieldDate(), UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                               label: "\(Self.communityShieldName) · Final")) },
            nextUserUefaSuperCupTie.map { tie in
                (uefaSuperCupDate(), UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                               label: "\(Self.uefaSuperCupName) · Final")) },
            nextUserEuroDate.flatMap { date in nextUserEuroTie.map { tie in
                (date, UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                     label: "\(Self.euroName) · \(euroRoundName(tieCount: euroTies.count))")) } },
            nextUserUefaCupDate.flatMap { date in nextUserUefaCupTie.map { tie in
                (date, UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                     label: "\(Self.uefaCupName) · \(uefaCupRoundName(tieCount: uefaCupTies.filter { !$0.isBye }.count))")) } },
            nextUserCupDate.flatMap { date in nextUserCupTie.map { tie in
                (date, UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                     label: "\(Self.cupName) · \(cupRoundName(tieCount: cupTies.filter { !$0.isBye }.count))")) } },
            nextUserLeagueCupDate.flatMap { date in nextUserLeagueCupTie.map { tie in
                (date, UserMatchInfo(homeIndex: tie.homeIndex, awayIndex: tie.awayIndex, isCup: true,
                                     label: "\(Self.leagueCupName) · \(leagueCupRoundName(tieCount: leagueCupTies.filter { !$0.isBye }.count))")) } },
            nextUserFixtureDate.flatMap { date in nextUserFixture.map { fixture in
                (date, UserMatchInfo(homeIndex: fixture.homeIndex, awayIndex: fixture.awayIndex, isCup: false,
                                     label: divisionName(userDivisionTier))) } },
        ].compactMap { $0 }
        return candidates.sorted { $0.date < $1.date }
    }

    /// A unified description of the user's next match — league or cup,
    /// whichever comes first.
    var nextUserMatchInfo: UserMatchInfo? { upcomingUserMatches.first?.info }

    /// The top scorers in a division (defaults to the user's).
    func topScorers(limit: Int = 10, tier: Int? = nil) -> [(player: Player, club: Club)] {
        let divisionTier = tier ?? userDivisionTier
        var rows: [(Player, Club)] = []
        for club in clubs where club.divisionTier == divisionTier {
            for player in club.players where player.goals > 0 {
                rows.append((player, club))
            }
        }
        return rows
            .sorted { $0.0.goals > $1.0.goals }
            .prefix(limit)
            .map { (player: $0.0, club: $0.1) }
    }

    /// The champion of the user's division once the season is complete.
    var champion: Club? { isSeasonOver ? userTable().first : nil }

    // MARK: - Season review

    /// True once the season is far enough along (past halfway) that the
    /// current league position genuinely predicts missing the board's
    /// objective, rather than just an early-season blip.
    var isObjectiveAtRisk: Bool {
        userClub.played >= Self.divisionSize / 2 && !objectiveMet()
    }

    /// Whether the board's objective was achieved this season.
    func objectiveMet() -> Bool {
        let position = userPosition
        if boardObjective.contains("Win the league") { return position == 1 }
        if boardObjective.contains("automatic promotion") { return position <= 2 }
        if boardObjective.contains("play-offs") { return position <= 6 }
        if boardObjective.contains("top 4") { return position <= 4 }
        if boardObjective.contains("top half") { return position <= Self.divisionSize / 2 }
        if boardObjective.contains("mid-table") { return position <= Self.divisionSize - 3 }
        if boardObjective.contains("relegation") { return position <= Self.divisionSize - 3 }
        return true
    }

    /// The board's end-of-season verdict.
    func seasonVerdict() -> String {
        objectiveMet()
            ? "The board are delighted — objective achieved."
            : "The board are disappointed — the objective was missed."
    }

    /// The user's standout performer, by average match rating.
    func playerOfSeason() -> Player? {
        userClub.players
            .filter { $0.apps > 0 }
            .max { ($0.averageRating ?? 0) < ($1.averageRating ?? 0) }
    }

    /// The user's leading scorer this season.
    func userTopScorer() -> Player? {
        userClub.players.filter { $0.goals > 0 }.max { $0.goals < $1.goals }
    }

    /// The league's overall top scorer (the Golden Boot).
    func goldenBoot() -> (player: Player, club: Club)? {
        topScorers(limit: 1).first
    }

    /// Unlocks a career achievement the first time its condition is met —
    /// a no-op on repeat calls, so callers can just re-check the condition
    /// every time without needing to track what's already unlocked.
    private func unlock(_ kind: AchievementKind) {
        guard unlockedAchievements.insert(kind).inserted else { return }
        addNews(.board, "Achievement unlocked", "🏅 \(kind.rawValue) — \(kind.subtitle)")
    }

    /// Career win totals cross round-number milestones mid-season, not
    /// just at the end of one — checked after every result.
    private func checkWinMilestones() {
        let totalWins = careerRecordByClub.values.reduce(0) { $0 + $1.wins }
        if totalWins >= 50 { unlock(.wins50) }
        if totalWins >= 100 { unlock(.wins100) }
        if totalWins >= 200 { unlock(.wins200) }
    }

    /// Records any honours the user won this season (called once at season end).
    func recordSeasonHonours() {
        guard lastHonourSeason != season else { return }
        lastHonourSeason = season
        if userPosition == 1 {
            careerHonours.append("🏆 \(divisionName(userDivisionTier)) title (\(seasonLabel))")
        }
        if cupWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.cupName) (\(seasonLabel))")
        }
        if leagueCupWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.leagueCupName) (\(seasonLabel))")
        }
        if userDivisionTier > 0 && userPosition <= 2 {
            careerHonours.append("⬆︎ Promoted from \(divisionName(userDivisionTier)) (\(seasonLabel))")
        }
        if euroWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.euroName) (\(seasonLabel))")
        }
        if uefaCupWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.uefaCupName) (\(seasonLabel))")
        }
        if uefaSuperCupWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.uefaSuperCupName) (\(seasonLabel))")
        }
        // Capture this season's First Division top 4 as next season's Europe
        // entrants, and the next four (5th-8th) as next season's Midweek Cup entrants.
        let plQualifiers = leagueTable(tier: 0)
        europeanQualifierIDs = plQualifiers.prefix(4).map { $0.id }
        if europeanQualifierIDs.contains(userClub.id) {
            addNews(.board, "European qualification", "\(userClub.name) have qualified for next season's \(Self.euroName).")
        }
        uefaCupQualifierIDs = plQualifiers.dropFirst(4).prefix(4).map { $0.id }
        if uefaCupQualifierIDs.contains(userClub.id) {
            addNews(.board, "European qualification", "\(userClub.name) have qualified for next season's \(Self.uefaCupName).")
        }
        if communityShieldWinnerName == userClub.name {
            careerHonours.append("🏆 \(Self.communityShieldName) (\(seasonLabel))")
        }
        // Capture this season's champion, runner-up and cup winner for the Community Trophy.
        let plTable = leagueTable(tier: 0)
        lastSeasonChampionID = plTable.first?.id
        lastSeasonRunnerUpID = plTable.dropFirst().first?.id
        lastSeasonCupWinnerID = cupWinnerID
        // Capture this season's Continental Cup and Midweek Cup winners for next
        // season's Continental Super Cup.
        lastSeasonEuroWinnerID = euroWinnerID
        lastSeasonUefaCupWinnerID = uefaCupWinnerID

        history.append(SeasonRecord(
            season: season, label: seasonLabel,
            userClub: userClub.name, userDivision: divisionName(userDivisionTier), userPosition: userPosition,
            champion: plTable.first?.name ?? "—",
            cupWinner: cupWinnerName ?? "—",
            euroWinner: euroWinnerName ?? "—",
            communityShieldWinner: communityShieldWinnerName ?? "—"))

        // Career achievement milestones tied to this season's outcome.
        let wonLeague = userPosition == 1
        let wonDomesticCup = cupWinnerName == userClub.name || leagueCupWinnerName == userClub.name
        let wonEurope = euroWinnerName == userClub.name || uefaCupWinnerName == userClub.name
        if userDivisionTier > 0 && userPosition <= 2 { unlock(.promotion) }
        if wonLeague { unlock(.leagueTitle) }
        if wonDomesticCup { unlock(.cupWinner) }
        if wonEurope { unlock(.europeanGlory) }
        if wonLeague && wonDomesticCup && wonEurope { unlock(.treble) }
        if userClub.lost == 0 && userClub.played >= 20 { unlock(.invincible) }
        if history.filter({ $0.userClub == userClub.name }).count >= 10 { unlock(.dynasty) }

        // Accumulate all-time goal tallies across the game, celebrating a
        // round-number milestone crossed this season for the user's own
        // players — a small, recurring "that mattered" moment.
        let milestones = [10, 25, 50, 100, 150, 200, 250, 300]
        for club in clubs where club.divisionTier < 4 {
            for player in club.players where player.goals > 0 {
                let before = allTimeScorers[player.name, default: 0]
                let after = before + player.goals
                allTimeScorers[player.name] = after
                if club.id == userClub.id, let crossed = milestones.last(where: { before < $0 && after >= $0 }) {
                    addNews(.board, "Milestone reached",
                            "\(player.name) has now scored \(crossed)+ career goals for \(club.name).")
                }
            }
            for player in club.players where player.apps > 0 {
                allTimeAppearances[player.name, default: 0] += player.apps
            }
        }

        // Record peak ratings of the user's players for the Hall of Fame.
        for player in userClub.players {
            if let existing = hallOfFame[player.name], existing.peakRating >= player.rating { continue }
            hallOfFame[player.name] = HallEntry(name: player.name, position: player.position,
                                                peakRating: player.rating, peakSeason: seasonLabel)
        }

        updateReputation()
        checkForSacking()
        checkManagerContractRenewal()
        generateJobOffers()
    }

    /// Runs down the manager's own contract by a year at season's end. If
    /// it expires, the board either extends it (when confidence is decent)
    /// or lets it lapse — a distinct, calmer "time for a new challenge"
    /// moment from being sacked mid-tenure for poor results.
    private func checkManagerContractRenewal() {
        guard !wasSacked else { return }
        managerContractYears -= 1
        guard managerContractYears <= 0 else { return }
        if boardConfidence >= 40 {
            let years = Int.random(in: 2...4)
            managerContractYears = years
            addNews(.board, "Contract extended",
                    "The board have extended your contract at \(userClub.name) for another \(years) year\(years == 1 ? "" : "s") — pleased with how things are going.")
        } else {
            wasSacked = true
            addNews(.board, "Contract not renewed",
                    "Your contract at \(userClub.name) has run its course and the board have decided not to renew it. You'll need to find a new club.")
        }
    }

    /// Adjusts reputation from the season's achievements and board mood.
    private func updateReputation() {
        var delta = (boardConfidence - 50) / 10
        if userPosition == 1 { delta += 8 }
        if userDivisionTier > 0 && userPosition <= 2 { delta += 6 }
        if cupWinnerName == userClub.name { delta += 6 }
        if euroWinnerName == userClub.name { delta += 12 }
        if !objectiveMet() { delta -= 4 }
        let previous = managerReputation
        managerReputation = min(100, max(0, managerReputation + delta))
        checkReputationMilestones(previous: previous, current: managerReputation)
    }

    /// One-off news the first time reputation crosses a notable threshold —
    /// a sense of career progression beyond just the raw number going up.
    private func checkReputationMilestones(previous: Int, current: Int) {
        let milestones: [(threshold: Int, message: String)] = [
            (50, "Your reputation has grown enough that mid-table clubs are starting to take real notice."),
            (65, "Bigger clubs are now watching your work closely — a genuinely elite job could be within reach."),
            (80, "Your reputation is elite — Europe's biggest clubs are aware of what you're building."),
            (95, "Few managers reach this level of reputation — you're spoken of alongside the very best."),
        ]
        for milestone in milestones where previous < milestone.threshold && current >= milestone.threshold {
            addNews(.board, "Reputation milestone", milestone.message)
        }
    }

    /// Sacks the manager if the board has entirely lost faith.
    private func checkForSacking() {
        wasSacked = boardConfidence <= 12
        if wasSacked {
            managerReputation = max(0, managerReputation - 6)
            addNews(.board, "Sacked", "\(userClub.name) have relieved you of your duties. You must find a new club.")
        }
    }

    /// Offers the manager jobs from rival clubs, scaled to reputation.
    private func generateJobOffers() {
        pendingJobOffers = []
        let domestic = clubs.indices.filter { $0 != userClubIndex && clubs[$0].divisionTier < 4 }
        var candidates: [Int]
        if wasSacked {
            // Clubs within reach so the career can continue.
            candidates = domestic.filter { clubs[$0].prestige <= managerReputation + 4 }
                .sorted { clubs[$0].prestige > clubs[$1].prestige }
        } else {
            // Ambitious moves: bigger clubs the manager could realistically land.
            candidates = domestic.filter {
                clubs[$0].prestige >= userClub.prestige - 3 && clubs[$0].prestige <= managerReputation + 10
            }.sorted { clubs[$0].prestige > clubs[$1].prestige }
        }
        let count = wasSacked ? min(2, candidates.count) : (objectiveMet() ? Int.random(in: 0...2) : (Bool.random() ? 1 : 0))
        // A sacked manager must always have somewhere to go.
        if wasSacked && candidates.isEmpty, let fallback = domestic.min(by: { clubs[$0].prestige < clubs[$1].prestige }) {
            candidates = [fallback]
        }
        for index in candidates.prefix(max(count, wasSacked ? 1 : 0)) {
            pendingJobOffers.append(JobOffer(clubIndex: index, clubName: clubs[index].name,
                                             divisionName: divisionName(clubs[index].divisionTier),
                                             prestige: clubs[index].prestige,
                                             transferBudget: clubs[index].transferBudget,
                                             expectedObjective: previewObjective(forClubIndex: index)))
        }
    }

    /// Accepts a job offer; the move takes effect next season.
    func acceptJobOffer(_ offer: JobOffer) {
        pendingClubSwitch = offer.clubIndex
        addNews(.board, "New job agreed", "You will take over at \(offer.clubName) next season.")
    }

    /// Ends the 30-season career.
    func endCareer() {
        careerEnded = true
        persist()
    }

    /// Leaves a finished career, discarding the save.
    func returnToMenuAfterCareer() {
        careerEnded = false
        hasStarted = false
        if let id = currentSaveID { Self.deleteSave(id: id) }
        currentSaveID = nil
    }

    /// The best XI across every division, by overall ability (Team of the Season).
    func teamOfTheSeason() -> [Player] {
        let everyone = clubs.filter { $0.divisionTier < 4 }.flatMap { $0.players }
        func top(_ position: Position, _ count: Int) -> [Player] {
            everyone.filter { $0.position == position }.sorted { $0.rating > $1.rating }.prefix(count).map { $0 }
        }
        return top(.goalkeeper, 1) + top(.defender, 4) + top(.midfielder, 3) + top(.forward, 3)
    }

    /// The short code of the club a player belongs to.
    func clubShort(forPlayerID id: UUID) -> String {
        clubs.first { $0.players.contains { $0.id == id } }?.shortName ?? "?"
    }

    // MARK: - All-time records

    private func mostFrequent(_ names: [String]) -> (name: String, count: Int)? {
        var counts: [String: Int] = [:]
        for name in names where name != "—" { counts[name, default: 0] += 1 }
        return counts.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    /// The club with the most league titles across the career, and the count.
    func mostTitles() -> (name: String, count: Int)? { mostFrequent(history.map { $0.champion }) }
    func mostCups() -> (name: String, count: Int)? { mostFrequent(history.map { $0.cupWinner }) }
    func mostEuropeanCups() -> (name: String, count: Int)? { mostFrequent(history.map { $0.euroWinner }) }

    /// The all-time leading scorer in the game, and their goal total.
    func topCareerScorer() -> (name: String, goals: Int)? {
        allTimeScorers.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    /// The all-time leading appearance-maker in the game, and their total.
    func topCareerAppearances() -> (name: String, apps: Int)? {
        allTimeAppearances.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    /// One line of the manager's CV: a spell at one club (grouping
    /// consecutive seasons together, so two separate stints at the same
    /// club show as two lines), its length, match record, and the
    /// trophies won specifically during that spell.
    struct ManagerCVEntry: Identifiable {
        var id: String { "\(club)-\(startLabel)" }
        let club: String
        let startLabel: String
        let seasons: Int
        let record: ClubCareerRecord
        let trophies: [String]
    }

    /// The manager's full career history — every club managed, in order.
    func managerCV() -> [ManagerCVEntry] {
        guard !history.isEmpty else { return [] }
        var groups: [(club: String, startLabel: String, seasons: Int)] = []
        for record in history {
            if let last = groups.last, last.club == record.userClub {
                groups[groups.count - 1].seasons += 1
            } else {
                groups.append((club: record.userClub, startLabel: record.label, seasons: 1))
            }
        }
        let clubForLabel = Dictionary(uniqueKeysWithValues: history.map { ($0.label, $0.userClub) })
        return groups.map { group in
            let trophies = careerHonours.filter { honour in
                clubForLabel.contains { label, club in club == group.club && honour.contains("(\(label))") }
            }
            let record = careerRecordByClub[group.club] ?? ClubCareerRecord()
            return ManagerCVEntry(club: group.club, startLabel: group.startLabel, seasons: group.seasons,
                                   record: record, trophies: trophies)
        }
    }

    /// The best XI the user has ever managed, by peak rating per position.
    func bestEverXI() -> [HallEntry] {
        func top(_ position: Position, _ count: Int) -> [HallEntry] {
            hallOfFame.values.filter { $0.position == position }
                .sorted { $0.peakRating > $1.peakRating }
                .prefix(count).map { $0 }
        }
        return top(.goalkeeper, 1) + top(.defender, 4) + top(.midfielder, 3) + top(.forward, 3)
    }

    /// The user's honour count by type, for the records screen.
    func honourTally() -> (titles: Int, cups: Int, euros: Int, promotions: Int) {
        var t = 0, c = 0, e = 0, p = 0
        for h in careerHonours {
            if h.contains("title") { t += 1 }
            else if h.contains(Self.cupName) { c += 1 }
            else if h.contains(Self.euroName) { e += 1 }
            else if h.contains("Promoted") { p += 1 }
        }
        return (t, c, e, p)
    }

    /// A short description of the user's biggest win, if any.
    func biggestUserWin() -> String? {
        var best: (margin: Int, text: String)?
        for fixture in fixtures where fixture.played
            && (fixture.homeIndex == userClubIndex || fixture.awayIndex == userClubIndex) {
            let isHome = fixture.homeIndex == userClubIndex
            let us = isHome ? fixture.homeGoals : fixture.awayGoals
            let them = isHome ? fixture.awayGoals : fixture.homeGoals
            guard us > them else { continue }
            let margin = us - them
            if best == nil || margin > best!.margin {
                let opponent = clubs[isHome ? fixture.awayIndex : fixture.homeIndex]
                best = (margin, "\(us)-\(them) vs \(opponent.shortName)")
            }
        }
        return best?.text
    }
}
