//
//  OwnershipChanges.swift
//  Retro Season Manager
//
//  Real-world club takeovers that transformed a club's finances, fired as
//  a board news item plus a genuine transfer-budget change (and, where the
//  takeover meaningfully changed the club's on-pitch trajectory, a lasting
//  prestige shift) on the real announcement date — for any of these clubs
//  the user happens to be running (or plays against) in the English
//  pyramid.
//

import Foundation

struct OwnershipChange {
    let club: String
    let year: Int
    let month: Int
    let day: Int
    /// One-off change to the club's transfer budget, in £000s. Can be
    /// negative (e.g. a leveraged buyout loading the club with debt).
    let budgetInjection: Int
    /// One-off, permanent change to the club's prestige rating, reflecting
    /// a lasting shift in status/ambition. 0 for takeovers that changed
    /// ownership without meaningfully changing footballing trajectory.
    let prestigeBoost: Int
    let headline: String
    let body: String
}

enum OwnershipChanges {
    static let all: [OwnershipChange] = [
        OwnershipChange(club: "Stamford Blues", year: 2003, month: 7, day: 2,
                         budgetInjection: 150_000, prestigeBoost: 10,
                         headline: "Volkov completes Stamford Blues takeover",
                         body: "Russian billionaire Yevgeni Volkov buys Stamford Blues for around £140m and promises major investment. The board's ambitions are transformed overnight — the transfer budget swells accordingly."),
        OwnershipChange(club: "Etihad Blues", year: 2008, month: 9, day: 1,
                         budgetInjection: 100_000, prestigeBoost: 8,
                         headline: "Gulf Sporting Group completes Etihad Blues takeover",
                         body: "A Gulf investment group led by Sheikh Rashid buys Etihad Blues on transfer deadline day, instantly transforming the club's financial power."),
        OwnershipChange(club: "Aston Rovers", year: 2006, month: 8, day: 19,
                         budgetInjection: 40_000, prestigeBoost: 4,
                         headline: "Randall Kessler completes Aston Rovers takeover",
                         body: "American businessman Randall Kessler buys Aston Rovers from long-serving chairman Derek Fellowes, promising fresh investment after years of limited transfer activity."),
        OwnershipChange(club: "Tyneside", year: 2007, month: 7, day: 23,
                         budgetInjection: 25_000, prestigeBoost: 2,
                         headline: "Mike Ashworth completes Tyneside United takeover",
                         body: "SportsZone owner Mike Ashworth buys Tyneside United, ending the Fenwick family's long tenure. Fans hope for fresh ambition, though the scale of investment remains to be seen."),
        OwnershipChange(club: "Old Trafford Reds", year: 2005, month: 6, day: 22,
                         budgetInjection: -30_000, prestigeBoost: 0,
                         headline: "Harrow family completes Old Trafford Reds takeover",
                         body: "The Harrow family's controversial leveraged buyout loads the club with significant debt, sparking fan protests. Much of the takeover's financing must be serviced from the club's own revenues, squeezing transfer funds even as results stay strong."),
    ]
}
