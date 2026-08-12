//
//  MarqueePlayers.swift
//  Retro Season Manager
//
//  A handful of the era's most recognisable footballers, entering the
//  game world on (approximately) their real breakthrough dates, and
//  moving clubs on their real big-money transfer dates — so a long career
//  save actually sees Renaldo turn up at Old Trafford in 2003, Mesi break
//  into the Camp Blaugrana first team, and so on. Ages/ratings/dates are a
//  best-effort approximation for a limited, high-confidence set of
//  players; this isn't meant to be exhaustive.
//

import Foundation

/// A real player entering the game world for the first time, replacing
/// the weakest same-position player at their real club so the world
/// doesn't just keep growing squads indefinitely.
struct MarqueeArrival {
    let name: String
    let club: String
    let year: Int
    let month: Int
    let day: Int
    let age: Int
    let rating: Int
    let detailedPosition: DetailedPosition
    let secondaryPositions: [DetailedPosition]
    let headline: String
    let body: String
}

/// A real, already-in-the-world player moving to a new club on their real
/// transfer date, with a rating step reflecting where their career was at.
struct MarqueeTransfer {
    let name: String
    let toClub: String
    let year: Int
    let month: Int
    let day: Int
    let newRating: Int
    let headline: String
    let body: String
}

enum MarqueePlayers {
    static let arrivals: [MarqueeArrival] = [
        MarqueeArrival(name: "Cristiano Renaldo", club: "Old Trafford Reds", year: 2003, month: 8, day: 1,
                        age: 18, rating: 72, detailedPosition: .rightWing, secondaryPositions: [.leftWing],
                        headline: "Old Trafford Reds sign Cristiano Renaldo",
                        body: "United beat off competition to sign the Alvalade Lions winger for around £12m — the club's manager calls him one of the most exciting talents he's seen."),
        MarqueeArrival(name: "Lionel Mesi", club: "Camp Blaugrana", year: 2005, month: 7, day: 1,
                        age: 18, rating: 75, detailedPosition: .rightWing, secondaryPositions: [.striker, .attackingMid],
                        headline: "Mesi breaks into the Camp Blaugrana first team",
                        body: "The Argentine forward, at the club since he was 13, is handed a regular first-team squad number after a string of impressive performances for the reserves."),
        MarqueeArrival(name: "Gareth Baile", club: "Solent", year: 2006, month: 4, day: 17,
                        age: 16, rating: 58, detailedPosition: .leftBack, secondaryPositions: [.leftWing],
                        headline: "Solent hand debut to 16-year-old Gareth Baile",
                        body: "The Welsh left-back becomes one of the youngest players in Solent's history, and looks a serious talent going forward."),
        MarqueeArrival(name: "Eden Hazzard", club: "Lile Rangers", year: 2007, month: 8, day: 1,
                        age: 16, rating: 58, detailedPosition: .leftWing, secondaryPositions: [.attackingMid],
                        headline: "Lile Rangers fast-track teenager Eden Hazzard",
                        body: "The Belgian winger, already turning heads in Lile Rangers's academy, is promoted to the first-team squad well ahead of schedule."),
        MarqueeArrival(name: "Neymar Souza", club: "Camp Blaugrana", year: 2013, month: 7, day: 3,
                        age: 21, rating: 82, detailedPosition: .leftWing, secondaryPositions: [.striker, .rightWing],
                        headline: "Camp Blaugrana complete Neymar Souza signing",
                        body: "The Brazilian forward joins from Vila Belmiro in a big-money move, forming a new-look front line alongside Mesi."),
        MarqueeArrival(name: "Kylian Mbape", club: "AS Wanderers", year: 2016, month: 8, day: 1,
                        age: 17, rating: 68, detailedPosition: .striker, secondaryPositions: [.rightWing],
                        headline: "Monaco fast-track 17-year-old Mbape",
                        body: "The teenage forward's electric pre-season form earns him an early promotion to Monaco's first-team squad."),
        MarqueeArrival(name: "Robert Lewandowsky", club: "Borssia Athletic", year: 2010, month: 7, day: 1,
                        age: 22, rating: 76, detailedPosition: .striker, secondaryPositions: [],
                        headline: "Dortmund sign Robert Lewandowsky",
                        body: "The Polish striker joins Borssia Athletic from Baltic Reserves, quickly becoming one of the Bundesliga's most feared forwards."),
    ]

    static let transfers: [MarqueeTransfer] = [
        MarqueeTransfer(name: "Gareth Baile", toClub: "White Hart Athletic", year: 2007, month: 5, day: 24,
                         newRating: 74,
                         headline: "Baile completes move to White Hart Athletic",
                         body: "Gareth Baile leaves Solent for White Hart Athletic Hotspur in a deal that could rise to £10m."),
        MarqueeTransfer(name: "Eden Hazzard", toClub: "Stamford Blues", year: 2012, month: 6, day: 14,
                         newRating: 86,
                         headline: "Hazzard signs for Stamford Blues",
                         body: "Eden Hazzard completes a big-money move from Lile Rangers to Stamford Blues, arriving as one of the most sought-after talents in Europe."),
        MarqueeTransfer(name: "Cristiano Renaldo", toClub: "Bernabéu Whites", year: 2009, month: 7, day: 1,
                         newRating: 92,
                         headline: "Renaldo completes world-record move to Bernabéu Whites",
                         body: "Old Trafford Reds sell Cristiano Renaldo to Bernabéu Whites for a reported world-record fee, ending six trophy-laden years at Old Trafford."),
        MarqueeTransfer(name: "Kylian Mbape", toClub: "Pars Athletic", year: 2017, month: 8, day: 31,
                         newRating: 85,
                         headline: "Mbape joins Pars Athletic",
                         body: "Kylian Mbape completes a big-money move from Monaco to PSG on transfer deadline day, reuniting him with Neymar Souza."),
        MarqueeTransfer(name: "Gareth Baile", toClub: "Bernabéu Whites", year: 2013, month: 9, day: 2,
                         newRating: 90,
                         headline: "Baile completes world-record move to Bernabéu Whites",
                         body: "Gareth Baile leaves White Hart Athletic for Bernabéu Whites in a deal reported to be a new world-record transfer fee."),
        // Free transfers — out-of-contract moves, no fee changes hands.
        MarqueeTransfer(name: "Solomon Camwell", toClub: "Highbury", year: 2001, month: 7, day: 3,
                         newRating: 87,
                         headline: "Solomon Camwell stuns White Hart Athletic with free transfer to Highbury",
                         body: "Solomon Camwell's contract runs out and he signs for bitter rivals Highbury on a free transfer — one of the most controversial moves in First Division history."),
        MarqueeTransfer(name: "Andrea Pirlio", toClub: "Turin Bianconeri", year: 2011, month: 7, day: 1,
                         newRating: 85,
                         headline: "Pirlio joins Turin Bianconeri on a free transfer",
                         body: "Andrea Pirlio signs for Turin Bianconeri after his contract expires — a decision that goes on to transform Turin Bianconeri into champions again."),
        MarqueeTransfer(name: "Robert Lewandowsky", toClub: "Bavarian Reds", year: 2014, month: 7, day: 1,
                         newRating: 89,
                         headline: "Lewandowsky joins Bavarian Reds on a free transfer",
                         body: "Robert Lewandowsky lets his Borssia Athletic contract run down and signs for Bundesliga rivals Bavarian Reds on a free transfer."),
    ]
}
