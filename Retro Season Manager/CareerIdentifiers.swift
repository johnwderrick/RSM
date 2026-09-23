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
