//
//  GameStore+PlayerStories.swift
//  Retro Season Manager
//
//  Season-end sweeps that turn existing per-player data into real
//  narrative moments — academy breakthroughs, fan favourites, and
//  homegrown wonderkid breakouts. All three route through the same
//  addNews(...) pipeline every other story in the game already uses, so
//  they get newspaper-archive coverage for free. Called once per season
//  from recordSeasonHonours(), alongside the existing achievement/legend
//  checks that already live there.
//

import Foundation

extension GameStore {

    /// Celebrates an academy graduate once their appearances for the club
    /// (already accumulated in `allTimeAppearances`, game-wide) cross a
    /// real first-team milestone — the one moment a graduate's provenance
    /// (`Player.isAcademyProduct`) actually pays off narratively.
    func checkAcademyGraduateBreakthroughs() {
        for player in userClub.players
        where player.isAcademyProduct && !academyGraduateMilestoneIDs.contains(player.id) {
            let appearances = allTimeAppearances[player.name] ?? player.apps
            guard appearances >= 50 else { continue }
            academyGraduateMilestoneIDs.insert(player.id)
            addNews(.board, "Academy graduate breakthrough",
                    "\(player.name) has made his \(appearances)th appearance for \(userClub.name) since coming through the academy — a genuine homegrown success story.",
                    player: player, clubName: userClub.name)
        }
    }

    /// Recognises a player becoming a fan favourite the first time
    /// `isFanFavourite(_:)` reads true for them — a positive counterpart
    /// to `reactToSellingFanFavourite`, which only ever fires negatively.
    func checkFanFavourites() {
        for player in userClub.players
        where isFanFavourite(player) && !recognizedFanFavouriteIDs.contains(player.id) {
            recognizedFanFavouriteIDs.insert(player.id)
            addNews(.board, "Fan favourite",
                    "\(player.name) has become adored by the \(userClub.name) faithful.",
                    player: player, clubName: userClub.name)
        }
    }

    /// A homegrown breakout season for one of the user's own young
    /// players — reuses `wonderkidWatchlist`/`WonderkidWatch` verbatim
    /// (built for the AI-club living-world system) rather than a parallel
    /// mechanism; the existing `checkWonderkidFollowUps()` (already
    /// called every season, and not scoped to any particular club) then
    /// resolves it a season later with zero further code.
    func checkUserWonderkidBreakthroughs() {
        for player in userClub.players
        where player.age <= 20 && player.apps >= 15 && player.rating >= 72 && wonderkidWatchlist[player.id] == nil {
            wonderkidWatchlist[player.id] = WonderkidWatch(season: season, ratingAtEmergence: player.rating)
            addNews(.board, "Breakout season",
                    "\(player.name) has enjoyed a real breakout season for \(userClub.name), and is being talked about as one for the future.",
                    player: player, clubName: userClub.name)
        }
    }
}
