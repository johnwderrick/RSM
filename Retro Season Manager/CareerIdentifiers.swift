//
//  CareerIdentifiers.swift
//  Retro Season Manager
//
//  Stable accessibility identifiers for the Career shell and its primary
//  destinations. These are semantic constants on purpose: a display-label
//  change (e.g. "Fixtures" → "Calendar") must never silently move a UI-test
//  selector. The sidebar applies them directly instead of deriving them
//  from the visible label.
//

import Foundation

/// Stable UI-test selectors for Career Mode's shell, sidebar and screens.
enum CareerIdentifiers {
    // MARK: Shell

    /// The in-career shell that hosts the sidebar and every destination.
    static let shell = "career.shell"

    /// The always-present CONTINUE / GO TO MATCH / NEW SEASON action.
    /// (Pre-existing identifier, kept stable.)
    static let continueButton = "career.continue"

    /// The post-match CONTINUE action. (Pre-existing identifier, kept stable.)
    static let postMatchContinue = "career.postMatch.continue"

    // MARK: Settings sub-destinations

    /// Selector for one Settings menu row, derived from the destination's
    /// stable enum raw value (not from any wording policy — the raw values
    /// are themselves the persisted, stable names).
    static func settingsRow(_ destination: SettingsDestination) -> String {
        "career.settings.row.\(slug(destination.rawValue))"
    }

    /// The back control on a Settings drill-down page.
    static let settingsBack = "career.settings.back"

    /// The SAVE & EXIT TO MENU action in Settings.
    static let settingsSaveExit = "career.settings.saveExit"

    // MARK: Settings screen (light-card control centre)

    /// The redesigned Settings screen's single scroll container.
    static let settingsScroll = "career.settings.scroll"

    /// The career summary card (club crest, manager, season, division,
    /// date, save-slot context).
    static let settingsSummary = "career.settings.summary"

    /// The save/career card explaining autosave and hosting SAVE & EXIT.
    static let settingsSaveCard = "career.settings.save"

    /// The 'saved <relative time>' status line when a save slot is active.
    static let settingsLastSaved = "career.settings.lastSaved"

    /// The preferences card (difficulty, auto-pick assist, delegation).
    static let settingsPreferences = "career.settings.preferences"

    /// Stable selector for one preference control.
    static func settingsPreference(_ name: String) -> String {
        "career.settings.pref.\(slug(name))"
    }

    /// The records & archives card (records, honours, achievements,
    /// newspaper archive, transfer history, season history).
    static let settingsRecords = "career.settings.records"

    /// The archive/record action rows inside the records card.
    static func settingsArchive(_ name: String) -> String {
        "career.settings.archive.\(slug(name))"
    }

    /// The career-management card (explanation of what Save & Exit does).
    static let settingsCareerManagement = "career.settings.careerManagement"

    /// The end-of-page scroll anchor.
    static let settingsEnd = "career.settings.end"

    /// The pinned close control on a restyled Settings sheet
    /// (currently the Newspaper Archive).
    static let settingsSheetClose = "career.settings.sheet.close"

    /// The newspaper archive's root when hosted as a sheet.
    static let settingsArchiveSheet = "career.settings.archive.sheet"

    // MARK: Action & confirmation sheets (contract, release, withdrawal)

    /// Root canvas of the contract renewal negotiation sheet.
    static let contractSheet = "career.contract.sheet"

    /// Root canvas of the free-agent personal-terms sheet.
    static let contractFreeAgentSheet = "career.contract.freeAgent.sheet"

    /// The contract sheet's pinned close control.
    static let contractSheetClose = "career.contract.close"

    /// The contract sheet's wage stepper figure.
    static let contractWageValue = "career.contract.wage"

    /// The MAKE OFFER / OFFER AGAIN primary action.
    static let contractMakeOffer = "career.contract.makeOffer"

    /// The contract sheet's Cancel/Walk away action.
    static let contractCancel = "career.contract.cancel"

    /// The result banner after an offer (accepted or declined + counter).
    static let contractResult = "career.contract.result"

    /// The counter-offer pill inside a declined result.
    static let contractCounterButton = "career.contract.counter"

    /// The post-acceptance DONE action.
    static let contractDone = "career.contract.done"

    /// Root canvas of a generic destructive confirmation sheet.
    static let confirmSheet = "career.sheet.confirm"

    /// The destructive confirmation sheet's title.
    static let confirmSheetTitle = "career.sheet.confirm.title"

    /// The destructive confirmation's Cancel action (prominent, safe).
    static let confirmSheetCancel = "career.sheet.confirm.cancel"

    /// The destructive confirmation action.
    static let confirmSheetConfirm = "career.sheet.confirm.confirm"

    /// Root canvas of the free-agent / search-found personal-terms sheet
    /// reached from the scout centre's profile flow.
    static let personalTermsSheet = "career.sheet.personalTerms"

    // MARK: Supporter Zone (light-card sheet)

    /// The Supporter Zone's single scroll container (it presents as a
    /// sheet from Settings, so it carries its own root anchors).
    static let supporterScroll = "career.supporter.scroll"

    /// The Supporter Zone's summary band (club, season, fan mood).
    static let supporterSummary = "career.supporter.summary"

    /// The pinned close control on the Supporter Zone sheet.
    static let supporterClose = "career.supporter.close"

    /// Stable selector for one Supporter Zone stat row (label slug).
    static func supporterStat(_ label: String) -> String {
        "career.supporter.stat.\(slug(label))"
    }

    /// The fan reactions feed's empty state.
    static let supporterFeedEmpty = "career.supporter.feed.empty"

    /// Stable selector for one social-feed post (by index, newest first).
    static func supporterPost(_ index: Int) -> String {
        "career.supporter.post.\(index)"
    }

    // MARK: Club Facilities (light-card sheet)

    /// The Club tab's single Facilities scroll container.
    static let facilitiesScroll = "career.facilities.scroll"

    /// The Club Facilities summary band (club, transfer budget, levels).
    static let facilitiesSummary = "career.facilities.summary"

    /// The transfer-budget figure inside the summary band.
    static let facilitiesBudget = "career.facilities.budget"

    /// Stable selector for one facility card, keyed by the `FacilityKind`
    /// raw value (e.g. `trainingGround`) — never by its display name.
    static func facilitiesCard(_ kind: FacilityKind) -> String {
        "career.facilities.card.\(kind.rawValue)"
    }

    /// The facility's current level text (e.g. `LVL 2/5`).
    static func facilitiesLevel(_ kind: FacilityKind) -> String {
        "career.facilities.level.\(kind.rawValue)"
    }

    /// The next-upgrade cost text on a facility card.
    static func facilitiesCost(_ kind: FacilityKind) -> String {
        "career.facilities.cost.\(kind.rawValue)"
    }

    /// The upgrade action on a facility card (absent at max level).
    static func facilitiesUpgrade(_ kind: FacilityKind) -> String {
        "career.facilities.upgrade.\(kind.rawValue)"
    }

    /// The MAX LEVEL badge on a fully upgraded facility card.
    static func facilitiesMax(_ kind: FacilityKind) -> String {
        "career.facilities.max.\(kind.rawValue)"
    }

    /// The Club Facilities end-of-page anchor.
    static let facilitiesEnd = "career.facilities.end"

    // MARK: Season Objectives (light-card sheet)

    /// The Season Objectives screen's single scroll container.
    static let objectivesScroll = "career.objectives.scroll"

    /// The Season Objectives summary band (season, completion count).
    static let objectivesSummary = "career.objectives.summary"

    /// The pinned close control on the Season Objectives sheet.
    static let objectivesClose = "career.objectives.close"

    /// Stable selector for one objective card, keyed by the objective's
    /// stable id (e.g. `beat-rival`) — never by its display title.
    static func objectivesCard(_ id: String) -> String {
        "career.objectives.card.\(slug(id))"
    }

    /// The objective detail sheet's scroll content root.
    static let objectivesDetail = "career.objectives.detail"

    /// The objective detail sheet's pinned close control.
    static let objectivesDetailClose = "career.objectives.detail.close"

    /// The objective detail's completion-reward band.
    static let objectivesDetailReward = "career.objectives.detail.reward"

    /// The objective detail's in-progress status line.
    static let objectivesDetailStatus = "career.objectives.detail.status"

    // MARK: Manager Office (light-card sheet with Overview/Timeline/Scrapbook)

    /// The Manager Office's own segmented-tab selector. The visible labels
    /// are stable enum raw values, but tests pick the tab through this
    /// constant so a future rename can't move the selector.
    static func officeTab(_ tab: String) -> String {
        "career.office.tab.\(slug(tab))"
    }

    /// The Manager Office's scroll container (shared by all three tabs —
    /// the same ScrollView identity across tab switches keeps scroll
    /// anchors and snapshots stable).
    static let officeScroll = "career.office.scroll"

    /// The Manager Office's pinned close control.
    static let officeClose = "career.office.close"

    /// The Manager Office's header band (manager + club identity).
    static let officeHeader = "career.office.header"

    /// Stable selector for one trophy-shelf item (by index in the honours log).
    static func officeTrophy(_ index: Int) -> String {
        "career.office.trophy.\(index)"
    }

    /// Per-tab end-of-content scroll anchors.
    static func officeEnd(_ tab: String) -> String {
        "career.office.\(tab).end"
    }

    /// The Overview tab's summary band (managed clubs, matches, win rate).
    static let officeSummary = "career.office.summary"

    /// The Overview tab's trophy shelf grid.
    static let officeTrophyShelf = "career.office.trophyShelf"

    /// The Overview tab's generated autobiography card.
    static let officeStory = "career.office.story"

    /// The Timeline tab's first moment row (`career.timeline.row.<year>`).
    static func timelineRow(_ year: Int) -> String {
        "career.timeline.row.\(year)"
    }

    /// The Timeline tab's empty state (no career moments yet).
    static let timelineEmpty = "career.timeline.empty"

    /// The Scrapbook tab's moments grid.
    static let scrapbookMoments = "career.scrapbook.moments"

    /// The Scrapbook tab's historic front pages grid.
    static let scrapbookFrontPages = "career.scrapbook.frontPages"

    /// Stable selector for one scrapbook moment card (by year).
    static func scrapbookMoment(_ year: Int) -> String {
        "career.scrapbook.moment.\(year)"
    }

    /// Stable selector for one scrapbook front-page card (by index).
    static func scrapbookFrontPage(_ index: Int) -> String {
        "career.scrapbook.frontPage.\(index)"
    }

    /// The Scrapbook tab's empty state (no moments, no front pages).
    static let scrapbookEmpty = "career.scrapbook.empty"

    /// Per-tab end-of-content scroll anchors (static forms kept for the
    /// tabs that own a single anchor).
    static let officeOverviewEnd = "career.office.overview.end"
    static let officeTimelineEnd = "career.office.timeline.end"
    static let officeScrapbookEnd = "career.scrapbook.end"

    // MARK: Hall of Fame (light-card sheet)

    /// The Hall of Fame's own segmented-tab selector — the visible labels
    /// are stable enum raw values, but tests pick the tab through this
    /// constant so a future rename can't move the selector.
    static func hallTab(_ tab: String) -> String {
        "career.hall.tab.\(slug(tab))"
    }

    /// The Hall of Fame's scroll container (shared by all three exhibits —
    /// the same ScrollView identity across exhibit switches keeps scroll
    /// anchors and snapshots stable, matching the Manager Office pattern).
    static let hallScroll = "career.hall.scroll"

    /// The Hall of Fame's pinned close control (sheet presentation only —
    /// absent when hosted by the Settings detail page).
    static let hallClose = "career.hall.close"

    /// The Hall of Fame's header band (name, induction count, club).
    static let hallHeader = "career.hall.header"

    /// Stable selector for one wall portrait card (by index within its
    /// exhibit — sorted by legend score, exactly as displayed).
    static func hallLegend(_ index: Int) -> String {
        "career.hall.legend.\(index)"
    }

    /// The wall grid container for an exhibit (Club Legends / Global).
    static let hallWall = "career.hall.wall"

    /// The manager exhibit's profile card.
    static let hallManagerCard = "career.hall.managerCard"

    /// The manager exhibit's trophy cabinet card.
    static let hallTrophyCabinet = "career.hall.trophyCabinet"

    /// Stable selector for one trophy-cabinet item (by index in the
    /// honours log — same ordering as the office trophy shelf).
    static func hallTrophy(_ index: Int) -> String {
        "career.hall.trophy.\(index)"
    }

    /// A shared empty state for an exhibit with no inductees yet.
    static let hallEmpty = "career.hall.empty"

    /// Per-exhibit end-of-content scroll anchors.
    static func hallEnd(_ tab: String) -> String {
        "career.hall.\(slug(tab)).end"
    }

    // MARK: Legend detail sheet

    /// The legend detail sheet's scroll content root (keyed by legend
    /// name slug so concurrent legends never share an anchor).
    static func hallDetail(_ legendName: String) -> String {
        "career.hall.detail.\(slug(legendName))"
    }

    /// The legend detail sheet's pinned close control.
    static let hallDetailClose = "career.hall.detail.close"

    /// The legend detail's CAREER STATISTICS card (label is the slug of
    /// the legend name — always paired with `hallDetail(_:)`).
    static let hallDetailStats = "career.hall.detail.stats"

    /// The legend detail's honours card (absent for a legend with no
    /// trophies won at the club).
    static let hallDetailHonours = "career.hall.detail.honours"

    /// Stable selector for one honours row (by index in `trophiesWon`).
    static func hallDetailHonour(_ index: Int) -> String {
        "career.hall.detail.honour.\(index)"
    }

    /// The legend detail's biography card.
    static let hallDetailBiography = "career.hall.detail.biography"

    // MARK: Achievements (light-card sheet)

    /// The Achievement Gallery's scroll container (shared by every
    /// category section — one ScrollView identity across the whole
    /// gallery, matching the Hall of Fame pattern).
    static let achievementsScroll = "career.achievements.scroll"

    /// The gallery's pinned close control (sheet presentation only —
    /// absent when hosted by the Settings detail page).
    static let achievementsClose = "career.achievements.close"

    /// The gallery's header band (unlocked count, career points).
    static let achievementsHeader = "career.achievements.header"

    /// Stable selector for one category section card, keyed by the
    /// `AchievementCategory` raw value (e.g. `trophies`) — never by
    /// display wording.
    static func achievementsCategory(_ category: String) -> String {
        "career.achievements.category.\(slug(category))"
    }

    /// Stable selector for one achievement card, keyed by the
    /// `AchievementKind` raw value (e.g. `League Winner`) — the
    /// persisted, stable name, never a display policy.
    static func achievementsCard(_ kind: String) -> String {
        "career.achievements.card.\(slug(kind))"
    }

    /// The gallery's end-of-content scroll anchor.
    static let achievementsEnd = "career.achievements.end"

    // MARK: Achievement detail sheet

    /// The achievement detail sheet's scroll content root, keyed by the
    /// achievement's stable raw value (e.g. `50 Wins` → `50-wins`).
    static func achievementsDetail(_ kind: String) -> String {
        "career.achievements.detail.\(slug(kind))"
    }

    /// The achievement detail sheet's pinned close control.
    static let achievementsDetailClose = "career.achievements.detail.close"

    /// The detail sheet's unlock-history card (absent while locked).
    static let achievementsDetailHistory = "career.achievements.detail.history"

    /// The detail sheet's locked status line (absent once unlocked).
    static let achievementsDetailLocked = "career.achievements.detail.locked"

    /// The detail sheet's career-points reward line (unlocked only).
    static let achievementsDetailPoints = "career.achievements.detail.points"

    // MARK: Helpers

    /// Lowercased, hyphenated slug for identifier components.
    static func slug(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "&", with: "and")
    }
}

extension GameSection {
    /// Stable slug for this destination — deliberately independent of the
    /// displayed `navLabel` so renames cannot move test selectors.
    var stableSlug: String {
        switch self {
        case .home:      return "home"
        case .squad:     return "squad"
        case .table:     return "table"
        case .fixtures:  return "calendar"
        case .club:      return "club"
        case .manager:   return "manager"
        case .search:    return "scout"
        case .transfers: return "transfers"
        case .inbox:     return "inbox"
        case .settings:  return "settings"
        }
    }

    /// Sidebar button selector, e.g. `career.nav.calendar`.
    var navIdentifier: String { "career.nav.\(stableSlug)" }

    /// Destination root selector, e.g. `career.calendar.screen`.
    var screenIdentifier: String { "career.\(stableSlug).screen" }
}
