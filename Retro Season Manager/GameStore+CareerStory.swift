//
//  GameStore+CareerStory.swift
//  Retro Season Manager
//
//  Turns everything already tracked about a career — season history,
//  career honours, achievement unlocks, manager tenure — into a
//  chronological narrative: the timeline the Manager Office and Legacy
//  screens read from, and the generated prose autobiography.
//
//  This is deliberately a query/narration layer, not new raw tracking —
//  "track everything" was already true by the time this file exists;
//  the job here is telling the story with what's already there.
//

import Foundation

/// One beat in a manager's career story — enough to drive both a
/// timeline row (icon/headline/detail) and a biography sentence.
struct CareerMoment: Identifiable {
    let id = UUID()
    let season: Int
    let year: Int
    let icon: String
    let headline: String
    let detail: String
}

extension GameStore {

    fileprivate enum StoryBeatKind {
        case jobStart(first: Bool)
        case trophy(name: String)
        case promotion
        case europeQualification
        case achievement(AchievementKind)
        case retirement
    }

    fileprivate struct StoryBeat {
        let season: Int
        let club: String
        let kind: StoryBeatKind
    }

    /// Achievements storied enough to earn their own line in the prose
    /// autobiography — the rest (title/cup/Euro wins, win-count
    /// milestones) already show up via `careerHonours`/numeric beats and
    /// would just repeat themselves if narrated twice.
    private static let biographyWorthyAchievements: Set<AchievementKind> = [
        .invincible, .dynasty, .giantKiller, .youthRevolution,
        .transferGenius, .underdog, .greatEscape, .legendaryManager,
    ]

    fileprivate func storyBeats() -> [StoryBeat] {
        var beats: [StoryBeat] = []

        // Job changes: first appearance of each club across `history`.
        var seenClubs: Set<String> = []
        for record in history.sorted(by: { $0.season < $1.season }) {
            if !seenClubs.contains(record.userClub) {
                beats.append(StoryBeat(season: record.season, club: record.userClub,
                                       kind: .jobStart(first: seenClubs.isEmpty)))
                seenClubs.insert(record.userClub)
            }
        }

        // Trophies and promotions, parsed from the existing honours log —
        // every entry already ends "(season label)".
        for honour in careerHonours {
            guard let label = extractParenthesizedLabel(honour),
                  let record = history.first(where: { $0.label == label }) else { continue }
            if honour.hasPrefix("🏆") {
                let name = honour.replacingOccurrences(of: "🏆 ", with: "")
                    .components(separatedBy: " (").first ?? "trophy"
                beats.append(StoryBeat(season: record.season, club: record.userClub, kind: .trophy(name: name)))
            } else if honour.hasPrefix("⬆︎") {
                beats.append(StoryBeat(season: record.season, club: record.userClub, kind: .promotion))
            }
        }

        if let europeSeason = firstEuropeQualificationSeason {
            let club = history.first(where: { $0.season == europeSeason })?.userClub ?? userClub.name
            beats.append(StoryBeat(season: europeSeason, club: club, kind: .europeQualification))
        }

        for unlock in achievementUnlocks.values where Self.biographyWorthyAchievements.contains(unlock.kind) {
            let club = history.first(where: { $0.season == unlock.season })?.userClub ?? userClub.name
            beats.append(StoryBeat(season: unlock.season, club: club, kind: .achievement(unlock.kind)))
        }

        if careerEnded {
            beats.append(StoryBeat(season: season, club: userClub.name, kind: .retirement))
        }

        return beats.sorted { $0.season < $1.season }
    }

    private func extractParenthesizedLabel(_ text: String) -> String? {
        guard let openParen = text.lastIndex(of: "("), let closeParen = text.lastIndex(of: ")"),
              openParen < closeParen else { return nil }
        return String(text[text.index(after: openParen)..<closeParen])
    }

    private func year(forSeason season: Int) -> Int { startYear + season - 1 }

    /// The full career timeline — every job change, trophy, promotion,
    /// European qualification, storied achievement and retirement, in
    /// order. Drives the Career Timeline and Scrapbook screens.
    func careerTimeline() -> [CareerMoment] {
        storyBeats().map { beat in
            let year = year(forSeason: beat.season)
            switch beat.kind {
            case .jobStart(let first):
                return CareerMoment(season: beat.season, year: year, icon: "📋",
                                    headline: first ? "Took over \(beat.club)" : "Took charge of \(beat.club)",
                                    detail: "Season \(beat.season)")
            case .trophy(let name):
                return CareerMoment(season: beat.season, year: year, icon: "🏆",
                                    headline: "Won the \(name)", detail: beat.club)
            case .promotion:
                return CareerMoment(season: beat.season, year: year, icon: "⬆︎",
                                    headline: "Promoted with \(beat.club)", detail: "Season \(beat.season)")
            case .europeQualification:
                return CareerMoment(season: beat.season, year: year, icon: "🌍",
                                    headline: "Reached \(Self.euroName)", detail: beat.club)
            case .achievement(let kind):
                return CareerMoment(season: beat.season, year: year, icon: "🏅",
                                    headline: kind.flavorTitle, detail: kind.subtitle)
            case .retirement:
                return CareerMoment(season: beat.season, year: year, icon: "🎓",
                                    headline: "Retired", detail: "\(beat.club), after \(history.count) season\(history.count == 1 ? "" : "s")")
            }
        }
    }

    /// The generated prose autobiography — short declarative sentences,
    /// one per career beat, in publication order.
    func generateAutobiography() -> String {
        let beats = storyBeats()
        guard !beats.isEmpty else { return "\(managerName)'s story is just beginning." }
        let sentences: [String] = beats.map { beat in
            let year = year(forSeason: beat.season)
            switch beat.kind {
            case .jobStart(let first):
                return first ? "\(managerName) took over \(beat.club) in \(year)."
                             : "\(managerName) took charge of \(beat.club) in \(year)."
            case .trophy(let name):
                return "Won the \(name) in \(year)."
            case .promotion:
                return "Won promotion with \(beat.club) in \(year)."
            case .europeQualification:
                return "Reached \(Self.euroName) in \(year)."
            case .achievement(let kind):
                switch kind {
                case .greatEscape:      return "Saved \(beat.club) from relegation in \(year)."
                case .invincible:       return "Went the whole \(year) season unbeaten."
                case .dynasty:          return "A decade at \(beat.club) by \(year) — a dynasty."
                case .giantKiller:      return "Made a habit of giant-killing by \(year)."
                case .youthRevolution:  return "Built a youth revolution at \(beat.club) in \(year)."
                case .transferGenius:   return "Proved a transfer genius in the market by \(year)."
                case .underdog:         return "Shocked everyone as the underdog champions in \(year)."
                case .legendaryManager: return "Became a legendary manager by \(year)."
                default:                return "\(kind.rawValue) in \(year)."
                }
            case .retirement:
                return "Retired in \(year)."
            }
        }
        return sentences.joined(separator: " ")
    }
}
