//
//  Helpers.swift
//  Retro Season Manager
//
//  Small free-function helpers with no natural home elsewhere.
//

import SwiftUI

// MARK: - Helpers

/// The last word of a player's name, for compact pitch tokens.
func surname(_ name: String) -> String {
    name.split(separator: " ").last.map(String.init) ?? name
}

/// Formats an integer as an ordinal, e.g. 1 -> "1st".
func ordinal(_ n: Int) -> String {
    let suffix: String
    switch (n % 100, n % 10) {
    case (11, _), (12, _), (13, _): suffix = "th"
    case (_, 1): suffix = "st"
    case (_, 2): suffix = "nd"
    case (_, 3): suffix = "rd"
    default: suffix = "th"
    }
    return "\(n)\(suffix)"
}

