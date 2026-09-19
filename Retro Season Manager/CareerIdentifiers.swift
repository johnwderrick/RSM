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
