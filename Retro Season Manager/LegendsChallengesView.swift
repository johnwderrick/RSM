//
//  LegendsChallengesView.swift
//  Retro Season Manager
//
//  Challenges (Phase 8) — Daily, Weekly and Permanent objectives.
//
//  Presentation only: completions, progress and rewards come from the
//  authoritative `LegendsStore` challenge system, and rewards stay
//  granted automatically by `recordMatchResult`. The cadence selector,
//  state filters and derived progress figures in this file are pure
//  view state and never mutate challenge rules or persistence.
//

import SwiftUI

struct LegendsChallengesView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var cadence: LegendsChallengeCadence = .daily
    @State private var stateFilter: ChallengeStateFilter = .all

    /// The selected cadence and filter survive leaving the screen (and even
    /// relaunches) through user defaults. This is presentation memory only —
    /// challenge rules, completions and rewards stay on `LegendsProfile`.
    @AppStorage("legends.challenges.cadence") private var cadenceRaw: String = LegendsChallengeCadence.daily.rawValue
    @AppStorage("legends.challenges.stateFilter") private var stateFilterRaw: String = ChallengeStateFilter.all.rawValue

    /// User-facing tabs for the cadence selector.
    enum ChallengeStateFilter: String, CaseIterable, Identifiable {
        case all = "ALL"
        case active = "ACTIVE"
        case completed = "COMPLETED"
        var id: String { rawValue }
    }

    private var allChallenges: [LegendsChallenge] { LegendsChallengeDatabase.all }
    private var completedCount: Int { allChallenges.filter { store.isCompleted($0) }.count }
    private var activeCount: Int { allChallenges.count - completedCount }
    private var completionPercent: Int {
        allChallenges.isEmpty ? 0 : Int((Double(completedCount) / Double(allChallenges.count) * 100).rounded())
    }

    private func challenges(in cadence: LegendsChallengeCadence) -> [LegendsChallenge] {
        allChallenges.filter { $0.cadence == cadence }
    }

    private func doneCount(in cadence: LegendsChallengeCadence) -> Int {
        challenges(in: cadence).filter { store.isCompleted($0) }.count
    }

    private var visibleChallenges: [LegendsChallenge] {
        challenges(in: cadence).filter { challenge in
            switch stateFilter {
            case .all: return true
            case .active: return !store.isCompleted(challenge)
            case .completed: return store.isCompleted(challenge)
            }
        }
    }

    var body: some View {
        LegendsMenuShell(store: store, title: "CHALLENGES", subtitle: "DAILY · WEEKLY · PERMANENT", icon: "flag.checkered", accent: LegendsPalette.cyan, onBack: onBack, currentNav: .challenges, onNavigate: onNavigate, scrollContent: false) {
            // One stable scroll container for the whole destination. Plain
            // (non-lazy) rows keep every challenge card in the accessibility
            // tree, and cadence/filter changes only mutate local state, so the
            // container never resets scroll position.
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    summaryBand
                    cadenceSelector
                    stateFilterRow
                    if visibleChallenges.isEmpty {
                        emptyState
                    } else {
                        countRow
                        VStack(spacing: 10) {
                            ForEach(visibleChallenges) { challenge in
                                challengeCard(challenge)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.challenges.screen")
        .onAppear {
            // Restore the remembered cadence/filter before the first render
            // of this visit, then refresh cadence counters as before.
            if let restored = LegendsChallengeCadence(rawValue: cadenceRaw) { cadence = restored }
            if let restoredFilter = ChallengeStateFilter(rawValue: stateFilterRaw) { stateFilter = restoredFilter }
            store.refreshChallengeCadences()
        }
        .onChange(of: cadence) { cadenceRaw = $0.rawValue }
        .onChange(of: stateFilter) { stateFilterRaw = $0.rawValue }
    }

    // MARK: - Summary band

    private var summaryBand: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(LegendsPalette.cyan.opacity(0.18), lineWidth: 6)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: Double(completionPercent) / 100)
                        .stroke(LegendsPalette.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    Text("\(completionPercent)%")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(LegendsPalette.navy)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(completionPercent) percent of all challenges complete")
                .accessibilityIdentifier("legends.challenges.summary.percent")

                VStack(alignment: .leading, spacing: 3) {
                    Text("OBJECTIVE TRACKER")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy)
                    HStack(spacing: 10) {
                        Text("\(completedCount) COMPLETED")
                            .foregroundStyle(LegendsPalette.green)
                            .accessibilityIdentifier("legends.challenges.summary.completed")
                        Text("\(activeCount) ACTIVE")
                            .foregroundStyle(LegendsPalette.cyan)
                            .accessibilityIdentifier("legends.challenges.summary.active")
                    }
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    Text("Rewards are granted automatically on completion.")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                }
                Spacer(minLength: 6)
            }

            HStack(spacing: 8) {
                cadenceSummaryStat("DAILY", done: doneCount(in: .daily), total: challenges(in: .daily).count,
                                   color: LegendsPalette.green, identifier: "legends.challenges.summary.daily")
                cadenceSummaryStat("WEEKLY", done: doneCount(in: .weekly), total: challenges(in: .weekly).count,
                                   color: LegendsPalette.blue, identifier: "legends.challenges.summary.weekly")
                cadenceSummaryStat("PERMANENT", done: doneCount(in: .permanent), total: challenges(in: .permanent).count,
                                   color: LegendsPalette.purple, identifier: "legends.challenges.summary.permanent")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.cyan.opacity(0.28), lineWidth: 1.2))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.challenges.summary")
    }

    private func cadenceSummaryStat(_ name: String, done: Int, total: Int, color: Color, identifier: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text("\(done)/\(total) \(name)")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) \(name.lowercased()) challenges complete")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Cadence selector

    private var cadenceSelector: some View {
        HStack(spacing: 8) {
            ForEach(LegendsChallengeCadence.allCases, id: \.self) { item in
                cadenceTab(item)
            }
        }
    }

    private func cadenceTab(_ item: LegendsChallengeCadence) -> some View {
        let selected = cadence == item
        let color = cadenceColor(item)
        let done = doneCount(in: item)
        let total = challenges(in: item).count
        return Button {
            Haptics.tap()
            cadence = item
        } label: {
            VStack(spacing: 2) {
                Text(item.rawValue.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(done)/\(total) DONE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .monospacedDigit()
            }
            .foregroundStyle(selected ? .white : LegendsPalette.navy.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? color : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                selected ? color : LegendsPalette.navy.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(item.rawValue) challenges, \(done) of \(total) done")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("legends.challenges.cadence.\(item.rawValue.lowercased())")
    }

    // MARK: - State filters

    private var stateFilterRow: some View {
        HStack(spacing: 8) {
            ForEach(ChallengeStateFilter.allCases) { filter in
                let selected = stateFilter == filter
                Button {
                    Haptics.tap()
                    stateFilter = filter
                } label: {
                    Text(filter.rawValue)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(selected ? .white : LegendsPalette.navy.opacity(0.72))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selected ? LegendsPalette.cyan : Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(
                            selected ? LegendsPalette.cyan : LegendsPalette.navy.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("legends.challenges.filter.\(filter.rawValue.lowercased())")
            }
            Spacer(minLength: 4)
        }
    }

    private var countRow: some View {
        Text("\(visibleChallenges.count) SHOWING")
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(LegendsPalette.navy.opacity(0.6))
            .accessibilityIdentifier("legends.challenges.count")
    }

    // MARK: - Challenge card

    private func challengeCard(_ challenge: LegendsChallenge) -> some View {
        let completed = store.isCompleted(challenge)
        let progress = store.progress(for: challenge)
        let accent = cadenceColor(challenge.cadence)

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(completed ? LegendsPalette.green : accent.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: completed ? "checkmark" : challenge.kind.glyph)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(completed ? .white : accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(challenge.title)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(LegendsPalette.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if completed {
                        Text("COMPLETED")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LegendsPalette.green)
                            .clipShape(Capsule())
                    }
                }
                Text(challenge.description)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.66))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(LegendsPalette.navy.opacity(0.10))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(completed ? LegendsPalette.green : accent)
                                .frame(width: geo.size.width * min(1, max(0, progress)))
                        }
                    }
                    .frame(height: 5)
                    .accessibilityHidden(true)

                    Text(progressText(challenge))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(completed ? LegendsPalette.green : LegendsPalette.navy.opacity(0.7))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(progressLabel(challenge))
                .accessibilityIdentifier("legends.challenges.progress.\(challenge.id)")

                rewardLine(challenge)
            }

            Spacer(minLength: 4)
        }
        .padding(12)
        .background(completed ? LegendsPalette.greenWash.opacity(0.72) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            completed ? LegendsPalette.green.opacity(0.4) : accent.opacity(0.24), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.07), radius: 6, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.challenges.card.\(challenge.id)")
        .accessibilityLabel("\(challenge.title), \(challenge.description). \(challenge.cadence.rawValue) challenge, \(completed ? "completed" : "active"). \(progressLabel(challenge)). \(rewardLabel(challenge)).")
    }

    /// "3 / 5" for count-based kinds, "DONE" / "IN PLAY" for one-shot kinds.
    /// A read-only projection of the same authoritative profile counters the
    /// store's `progress(for:)` already reads — no rules are duplicated.
    private func progressText(_ challenge: LegendsChallenge) -> String {
        if store.isCompleted(challenge) { return "DONE" }
        let profile = store.profile
        switch challenge.kind {
        case .winMatches(let n): return "\(min(profile.totalWins, n)) / \(n)"
        case .winStreak(let n): return "\(min(profile.currentWinStreak, n)) / \(n)"
        case .ownCards(let n): return "\(min(profile.ownedCardIDs.count, n)) / \(n)"
        case .playMatchesToday(let n): return "\(min(profile.matchesToday, n)) / \(n)"
        case .winMatchesToday(let n): return "\(min(profile.winsToday, n)) / \(n)"
        case .winMatchesThisWeek(let n): return "\(min(profile.winsThisWeek, n)) / \(n)"
        case .scoreGoalsThisWeek(let n): return "\(min(profile.goalsThisWeek, n)) / \(n)"
        case .scoreGoalsInOneMatch, .cleanSheet, .sameNationXIWin, .sameEraXIWin, .sameClubXIWin,
             .getPromoted, .beatStrongerOpponent, .winWithManager, .winWithStadium, .winInTopDivision:
            return "IN PLAY"
        }
    }

    private func progressLabel(_ challenge: LegendsChallenge) -> String {
        if store.isCompleted(challenge) { return "Complete" }
        switch challenge.kind {
        case .winMatches(let n): return "Progress \(min(store.profile.totalWins, n)) of \(n) career wins"
        case .winStreak(let n): return "Progress \(min(store.profile.currentWinStreak, n)) of \(n) wins in a row"
        case .ownCards(let n): return "Progress \(min(store.profile.ownedCardIDs.count, n)) of \(n) cards owned"
        case .playMatchesToday(let n): return "Progress \(min(store.profile.matchesToday, n)) of \(n) matches played today"
        case .winMatchesToday(let n): return "Progress \(min(store.profile.winsToday, n)) of \(n) wins today"
        case .winMatchesThisWeek(let n): return "Progress \(min(store.profile.winsThisWeek, n)) of \(n) wins this week"
        case .scoreGoalsThisWeek(let n): return "Progress \(min(store.profile.goalsThisWeek, n)) of \(n) goals this week"
        case .scoreGoalsInOneMatch, .cleanSheet, .sameNationXIWin, .sameEraXIWin, .sameClubXIWin,
             .getPromoted, .beatStrongerOpponent, .winWithManager, .winWithStadium, .winInTopDivision:
            return "Not yet completed — achieved in a match"
        }
    }

    private func rewardLabel(_ challenge: LegendsChallenge) -> String {
        var parts: [String] = []
        if challenge.coinReward > 0 { parts.append("+\(challenge.coinReward) Balance") }
        if challenge.tokenReward > 0 { parts.append("+\(challenge.tokenReward) pack token\(challenge.tokenReward == 1 ? "" : "s")") }
        return parts.isEmpty ? "No reward" : "Reward \(parts.joined(separator: ", "))"
    }

    private func rewardLine(_ challenge: LegendsChallenge) -> some View {
        HStack(spacing: 10) {
            if challenge.coinReward > 0 {
                HStack(spacing: 3) {
                    Text("+\(challenge.coinReward)")
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(LegendsPalette.gold)
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.goldDeep)
            }
            if challenge.tokenReward > 0 {
                HStack(spacing: 3) {
                    Text("+\(challenge.tokenReward)")
                    Image(systemName: "cube.fill")
                        .foregroundStyle(LegendsPalette.green)
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.green)
            }
            if challenge.coinReward == 0 && challenge.tokenReward == 0 {
                Text("NO REWARD")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rewardLabel(challenge))
        .accessibilityIdentifier("legends.challenges.reward.\(challenge.id)")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        let message: String
        switch stateFilter {
        case .all:
            message = "No \(cadence.rawValue.lowercased()) challenges exist yet."
        case .active:
            message = "Every \(cadence.rawValue.lowercased()) challenge is complete. New objectives arrive on the next cadence reset."
        case .completed:
            message = "No \(cadence.rawValue.lowercased()) challenge has been completed yet. Win matches to progress."
        }
        return HStack(spacing: 10) {
            Image(systemName: stateFilter == .active ? "checkmark.seal.fill" : "flag.checkered")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(cadenceColor(cadence))
            Text(message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.72))
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(cadenceColor(cadence).opacity(0.25), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.08), radius: 7, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.challenges.empty")
    }

    // MARK: - Cadence colours

    private func cadenceColor(_ cadence: LegendsChallengeCadence) -> Color {
        switch cadence {
        case .daily: return LegendsPalette.green
        case .weekly: return LegendsPalette.blue
        case .permanent: return LegendsPalette.purple
        }
    }
}
