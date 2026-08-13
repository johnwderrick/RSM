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
    var managerName: String?
    var firstEuropeQualificationSeason: Int?
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
    var achievementUnlocks: [AchievementKind: AchievementUnlock]?
    var careerAchievementPoints: Int?
    var giantKillingWins: Int?
    var profitableSalesCount: Int?
    /// The save format version this file was written under. Absent on
    /// every save written before versioning was introduced — those are
    /// treated as version 1. Bump `GameStore.currentSaveVersion` and add a
    /// migration step in `loadSavedGame(id:)` whenever a future change
    /// needs more than the existing "new field is Optional, default it on
    /// load" pattern already used throughout this struct.
    var version: Int?
    // Hall of Fame — all-time per-player accumulation (name-keyed, same
    // convention as allTimeScorers/allTimeAppearances above) plus
    // induction records.
    var allTimeAssists: [String: Int]?
    var allTimeCleanSheets: [String: Int]?
    var allTimeRatingPoints: [String: Double]?
    var captainSeasonTally: [UUID: Int]?
    var clubLegends: [ClubLegend]?
    var newspapers: [Newspaper]?
    var managerPersonalities: [ManagerPersonality]?
    var clubNegotiationStances: [ClubNegotiationStance]?
    var dynamicRivalries: [RivalryPair]?
    var fanConfidenceTrend: Int?
    var seasonTicketHolders: Int?
    var socialFeed: [SocialPost]?
}

@MainActor
@Observable
final class GameStore {

    /// The current save format version, written into every new save.
    /// Bump this and add a branch in `loadSavedGame(id:)` when a future
    /// change needs an actual data migration rather than just defaulting
    /// a new Optional field on load.
    static let currentSaveVersion = 1

    // MARK: - State

    var clubs: [Club] = []
    var fixtures: [Fixture] = []
    /// Two throwaway pre-season friendlies, auto-resolved as the calendar
    /// reaches them — sharpen fitness and let new signings get minutes
    /// without any risk to league form. `matchday` is repurposed as a 0/1
    /// index into `friendlyDate(_:)` rather than a real matchday.
    var friendlyFixtures: [Fixture] = []
    var userClubIndex: Int = 0
    var currentMatchday: Int = 1
    var season: Int = 1
    /// The real-world calendar year a career began in — season 1 is
    /// `startYear`/`startYear+1`. Lets a career start in 2000, 2010, or any
    /// future year `Self.availableStartYears` offers, while `season` itself
    /// stays a simple relative counter everywhere else in the engine.
    var startYear: Int = 2000
    var lastReports: [MatchReport] = []

    /// One manager name per club, index-aligned with `clubs`.
    var managers: [String] = []
    /// The user's own manager name — a full name, chosen at New Game (or
    /// randomly generated if left blank), unlike the initial-plus-surname
    /// style every AI manager gets. The protagonist of the generated
    /// autobiography — see `GameStore+CareerStory.swift`.
    var managerName: String = ""
    /// The first season this club reached continental competition — a
    /// standalone tracker since `addNews("European qualification")` is
    /// otherwise just a transient inbox item, and the career story needs
    /// a real "first reached Europe" beat to narrate.
    var firstEuropeQualificationSeason: Int?
    /// Hidden per-club manager behavioural trait, index-aligned with
    /// `managers`/`clubs` — see `ManagerPersonality`.
    var managerPersonalities: [ManagerPersonality] = []
    /// Hidden per-club transfer-negotiation hardness, index-aligned with
    /// `clubs` — see `ClubNegotiationStance`.
    var clubNegotiationStances: [ClubNegotiationStance] = []

    /// The live match currently in progress, if any.
    var live: LiveMatch?
    /// Whether the pre-match hub is currently showing.
    var atPreMatch = false
    /// Set around a heavy synchronous operation (new game, season rollover,
    /// a long calendar sim) so the UI can show a loading screen.
    var isBusy = false
    var busyMessage = "Loading…"
    /// A pending press-conference question, if any.
    var pendingPressQuestion: PressQuestion?
    var pendingTeamTalk: PressQuestion?

    /// Players currently available to sign.
    var transferMarket: [TransferTarget] = []
    /// The board's objective for the season.
    var boardObjective = ""
    /// Board confidence in the manager, 0...100.
    var boardConfidence = 60
    /// A separate pulse from the boardroom's — fans care about recent
    /// results and performances viscerally, not the season's objective,
    /// so this can sour (or recover) faster than board confidence does.
    var fanConfidence = 60
    /// The change in board confidence from the last result — positive
    /// means it's rising, negative falling, for a trend indicator.
    var boardConfidenceTrend = 0

    /// The current in-game date.
    var currentDate = Date()
    /// The dated news / inbox feed, newest first.
    var news: [NewsItem] = []
    /// Rival clubs' outstanding bids for the user's players.
    var pendingOffers: [TransferOffer] = []
    /// Tracks the transfer window state between day ticks.
    var windowWasOpen = false
    /// A same-day cache for `starRatings`, since the underlying league-wide
    /// strength pass is expensive and callers may ask for it many times
    /// while nothing about the squads has actually changed.
    var starRatingsCache: [Int: Int] = [:]
    var starRatingsCacheDate: Date?
    /// Whether this season's one-off "deadline day" news has already fired.
    var deadlineDayAnnounced = false
    /// The user's transfer budget at the moment the window last opened, so
    /// the board can react to net spend when it closes again.
    var transferBudgetAtWindowOpen = 0

    /// Completed scout reports, keyed by transfer-target id.
    var scoutedReports: [UUID: ScoutReport] = [:]
    /// Targets currently being scouted, with the date the report is due.
    var scoutingDue: [UUID: Date] = [:]

    /// How many rounds a bid negotiation for a given target has gone
    /// through this window — a selling club's patience for lowball offers
    /// isn't infinite, and repeated haggling narrows the gap rather than
    /// repeating the same counter forever. Cleared whenever the market
    /// regenerates, same lifetime as the targets it tracks.
    var negotiationRounds: [UUID: Int] = [:]
    /// Round counter for the seller's side of a negotiation — when a rival
    /// club bids for one of the user's players and the user counters,
    /// mirroring `negotiationRounds` from the buyer's perspective.
    var sellNegotiationRounds: [UUID: Int] = [:]

    /// Players the manager has bookmarked for later — a lightweight watchlist,
    /// independent of the full scouting flow.
    var shortlistedPlayerIDs: Set<UUID> = []
    /// Shortlisted players already alerted on this season, so the same
    /// "entering his final year" news doesn't repeat every day.
    var shortlistAlertedIDs: Set<UUID> = []
    /// Whether the objective-at-risk warning has already fired this season.
    var objectiveRiskWarned = false

    /// IDs of one-off, real-world-dated events (ownership changes, marquee
    /// player arrivals/transfers, real transfer headlines) already fired
    /// this career. These fire on "today's date has reached or passed the
    /// trigger date and it hasn't fired yet" rather than an exact-day
    /// match — an exact match would silently and permanently skip an
    /// event for any save whose calendar had already passed that date
    /// before the event existed in the game (e.g. a new dated event added
    /// mid-session, or force-simming straight past it).
    var firedDatedEventIDs: Set<String> = []

    /// Year*12+month of the last Manager of the Month check, and each
    /// club's points total as of that check — lets the award measure
    /// points earned *this month* without a full match-by-match log.
    var lastMonthlyAwardKey = 0
    var monthlyAwardBaseline: [UUID: Int] = [:]

    /// The domestic cup's current-round ties.
    var cupTies: [CupTie] = []
    /// The current cup round (1-based), or 0 if not running.
    var cupRound = 0
    /// The winner of this season's cup, once decided.
    var cupWinnerName: String?
    var cupWinnerID: UUID?
    static let cupName = "National Cup"

    /// The League Trophy — a second, smaller knockout run alongside the National Cup.
    var leagueCupTies: [CupTie] = []
    var leagueCupRound = 0
    var leagueCupWinnerName: String?
    var leagueCupWinnerID: UUID?
    static let leagueCupName = "League Trophy"

    /// The season-opening Community Trophy: last season's champion vs cup winner.
    var communityShieldTie: CupTie?
    var communityShieldWinnerName: String?
    var lastSeasonChampionID: UUID?
    var lastSeasonRunnerUpID: UUID?
    var lastSeasonCupWinnerID: UUID?
    static let communityShieldName = "Community Trophy"

    /// The Continental Cup contested by the top-4 First Division clubs.
    var euroTies: [CupTie] = []
    var euroRound = 0
    var euroWinnerName: String?
    var euroWinnerID: UUID?
    /// Club ids that qualified for Europe (captured at the previous season's end).
    var europeanQualifierIDs: [UUID] = []
    static let euroName = "Continental Cup"

    /// The Midweek Cup — Europe's second club competition, contested by clubs
    /// that miss out on the Continental Cup: the next-best English clubs plus
    /// the foreign giants not drawn into the Continental Cup that season.
    var uefaCupTies: [CupTie] = []
    var uefaCupRound = 0
    var uefaCupWinnerName: String?
    var uefaCupWinnerID: UUID?
    /// Club ids that qualified for the Midweek Cup (captured at the previous season's end).
    var uefaCupQualifierIDs: [UUID] = []
    static let uefaCupName = "Midweek Cup"

    /// The season-opening Continental Super Cup: last season's Continental Cup
    /// winner vs last season's Midweek Cup winner.
    var uefaSuperCupTie: CupTie?
    var uefaSuperCupWinnerName: String?
    var lastSeasonEuroWinnerID: UUID?
    var lastSeasonUefaCupWinnerID: UUID?
    static let uefaSuperCupName = "Continental Super Cup"

    /// This season's random split of the foreign pool between the European
    /// Cup and the Midweek Cup — recomputed once each season.
    var seasonForeignAllocation: (europe: [Int], uefa: [Int]) = ([], [])

    /// The manager's career honours, newest last.
    var careerHonours: [String] = []
    /// Career milestones unlocked so far — distinct from `careerHonours`,
    /// which just logs what was won; these are specific feats worth
    /// calling out and collecting on their own screen.
    var unlockedAchievements: Set<AchievementKind> = []
    /// Rich per-achievement history — when it happened and the story
    /// behind it — kept alongside the bare set above.
    var achievementUnlocks: [AchievementKind: AchievementUnlock] = [:]
    /// Total career points banked from every achievement unlocked so far.
    var careerAchievementPoints: Int = 0
    /// Career tallies feeding two achievements that can't be derived from
    /// existing state alone — see `checkGiantKilling`/`sellPlayer`.
    var giantKillingWins: Int = 0
    var profitableSalesCount: Int = 0
    /// The achievement (if any) whose unlock celebration is currently
    /// queued to show — transient UI state, never persisted.
    var pendingAchievementCelebration: AchievementKind?
    /// A record of every completed season, newest last.
    var history: [SeasonRecord] = []
    /// Career goal tallies across the whole game, keyed by player name.
    var allTimeScorers: [String: Int] = [:]
    var allTimeAppearances: [String: Int] = [:]
    var careerRecordByClub: [String: ClubCareerRecord] = [:]
    /// Man of the Match awards, by player name, across the whole career.
    var motmTally: [String: Int] = [:]
    /// The season a player was first seen at the user's club, keyed by id
    /// — tracks unbroken service toward a ten-year testimonial.
    var clubTenureStart: [UUID: Int] = [:]

    // MARK: - Hall of Fame

    /// Career assist/clean-sheet/rating-point tallies, same name-keyed
    /// accumulation convention as `allTimeScorers`/`allTimeAppearances`
    /// above — the real data a retiring player is judged on for Club
    /// Legend / Global Hall of Fame induction.
    var allTimeAssists: [String: Int] = [:]
    var allTimeCleanSheets: [String: Int] = [:]
    var allTimeRatingPoints: [String: Double] = [:]
    /// Seasons spent as club captain, keyed by player id (unlike the name-
    /// keyed dicts above, captaincy is tied to a specific player instance
    /// worth distinguishing precisely).
    var captainSeasonTally: [UUID: Int] = [:]
    /// Every player inducted as a Club Legend (or Global Hall of Fame
    /// legend) so far, newest last — permanent once earned.
    var clubLegends: [ClubLegend] = []

    // MARK: - Newspapers

    /// Generated front pages for newspaper-worthy stories, newest first —
    /// a permanent illustrated archive (unlike the ephemeral `news` inbox),
    /// doubling as part of season history. Capped generously so a very long
    /// career's save file doesn't grow unbounded.
    var newspapers: [Newspaper] = []
    static let newspaperArchiveCap = 600

    // MARK: - Living world

    /// Rivalries that formed organically over a career, on top of the
    /// scripted real-world derbies in `RivalClubs` — see `areRivals(_:_:)`.
    var dynamicRivalries: [RivalryPair] = []

    // MARK: - Supporters

    /// Change in `fanConfidence` since the last match result — mirrors
    /// `boardConfidenceTrend`, computed at the same point (`updateBoard`).
    var fanConfidenceTrend: Int = 0
    /// A loyal core of matchday-regardless attendance, distinct from the
    /// walk-up demand `expectedAttendance` already models — grows slowly
    /// with sustained fan happiness and success, shrinks in bad times.
    var seasonTicketHolders: Int = 0
    /// Generated fan reactions, newest first — the "social media" layer
    /// over big results, transfers and club moments.
    var socialFeed: [SocialPost] = []
    static let socialFeedCap = 150

    /// Whether two clubs are rivals — the scripted real-world derbies, plus
    /// anything that's organically formed during this career.
    func areRivals(_ nameA: String, _ nameB: String) -> Bool {
        RivalClubs.areRivals(nameA, nameB) || dynamicRivalries.contains { $0.involves(nameA, nameB) }
    }

    /// The career's leading Man of the Match winner, and their tally.
    func topCareerMOTM() -> (name: String, count: Int)? {
        motmTally.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }
    /// This season's finance ledger for the user's club — reset at each
    /// season rollover, not kept across the whole career.
    var seasonLedger: [LedgerEntry] = []
    /// Every signing, sale and loan move involving the user's club across
    /// the whole career — unlike `seasonLedger`, this never resets.
    var transferHistory: [TransferHistoryEntry] = []
    /// Deals where a fee has been agreed but personal terms haven't —
    /// see `PendingTransferDeal`.
    var pendingTransferDeals: [PendingTransferDeal] = []

    /// Records one line in the permanent transfer history.
    func logTransferHistory(_ playerName: String, action: String, otherClub: String?, fee: Int?) {
        transferHistory.insert(TransferHistoryEntry(date: currentDate, playerName: playerName, action: action,
                                                     otherClub: otherClub, fee: fee), at: 0)
    }
    /// The last time the manager formally asked the board for extra
    /// transfer funds — gated to once every couple of months.
    var lastBudgetRequestDate: Date?

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
    var lastClearAirDate: Date?

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
    var hallOfFame: [String: HallEntry] = [:]
    var lastHonourSeason = 0
    /// Set once the career has been ended by the manager (see `maxSeasons`).
    var careerEnded = false

    /// The manager's reputation, 0...100, driving job offers.
    var managerReputation = 45
    /// End-of-season job offers from rival clubs.
    var pendingJobOffers: [JobOffer] = []
    /// A club move accepted at season's end, applied next season.
    var pendingClubSwitch: Int?
    /// Whether the board sacked the manager this season.
    var wasSacked = false
    /// Years left on the manager's own contract at the current club — a
    /// separate, positive-or-negative moment from being sacked mid-tenure.
    var managerContractYears = 3

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

    /// Every career ends at the same fixed point regardless of start year —
    /// a 2000 start runs 30 seasons, a 2010 start runs 20, a 2020 start
    /// runs 10 — so `availableStartYears` can grow without this needing
    /// to change.
    static let careerEndYear = 2030

    /// How many seasons this particular career runs for, derived from
    /// `startYear` rather than a fixed constant — see `careerEndYear`.
    var maxSeasons: Int { Self.careerEndYear - startYear }

    /// The season as a "2000/01" style label.
    var seasonLabel: String {
        let start = (startYear - 1) + season
        return "\(start)/\(String(format: "%02d", (start + 1) % 100))"
    }

    /// Whether the final season has finished.
    var isFinalSeason: Bool { season >= maxSeasons }

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
    var slotPins: [String: UUID] = [:]

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
    var formationSwitchedDate: Date?

    /// Whether the current formation is still bedding in — surfaced to the
    /// UI so a dip in results after a tactical switch isn't a mystery.
    var isFormationBeddingIn: Bool { formationFamiliarity < 1.0 }

    /// A small, tapering rating penalty applied to the user's XI while the
    /// current formation is still bedding in.
    var formationFamiliarity: Double {
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
    var userStarterIDs: Set<UUID> = []

    /// Assigned squad roles for the user's club.
    var captainID: UUID?
    var penaltyTakerID: UUID?
    var freeKickTakerID: UUID?
    var cornerTakerID: UUID?

    /// This season's youth-academy prospects the manager can promote.
    var youthProspects: [Player] = []
    /// The squad's weekly training emphasis.
    var trainingFocus: TrainingFocus = .balanced
    /// The chosen game difficulty.
    var difficulty: Difficulty = .normal

    /// True once a club has been chosen and the season is under way.
    var hasStarted = false

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

    /// IDs of news items the manager hasn't opened yet.
    var unreadNewsIDs: Set<UUID> = []

    /// The save slot currently open. Nil until a game is started or loaded.
    var currentSaveID: UUID?
    /// The save format version this career was last loaded from (or
    /// `currentSaveVersion` for a freshly started one).
    var saveVersion: Int = GameStore.currentSaveVersion

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
    var backroomStaff: [StaffMember] = []

    /// This season's foreign domestic cup winners (Spain/Italy/Germany/
    /// France), one club index each — recomputed at every season rollover.
    var foreignCupWinnerIndices: [Int] = []

}
