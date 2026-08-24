//
//  LegacyCareersView.swift
//  Retro Season Manager
//
//  Browsing permanently archived careers (see `LegacyCareer.swift`) —
//  reachable from the main menu without any active save, since a finished
//  career's own save no longer exists once it's archived.
//

import SwiftUI

/// A stable colour per tier, kept here rather than on `LegacyTier` itself
/// since the model file stays SwiftUI-free like the rest of `Models.swift`.
private func tierColor(_ tier: LegacyTier) -> Color {
    switch tier {
    case .legend:        return Color(red: 0.95, green: 0.75, blue: 0.25)
    case .distinguished: return Color(red: 0.62, green: 0.78, blue: 0.95)
    case .accomplished:  return Color(red: 0.55, green: 0.85, blue: 0.60)
    case .journeyman:    return Retro.text.opacity(0.75)
    case .modest:        return Retro.text.opacity(0.55)
    }
}

private func tierBadge(_ tier: LegacyTier, score: Int) -> some View {
    Text("\(tier.rawValue.uppercased()) · \(score)")
        .font(.system(.caption2, design: .monospaced).bold())
        .foregroundStyle(tierColor(tier))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(tierColor(tier).opacity(0.15))
        .clipShape(Capsule())
}

/// One wing of the Football Museum hub.
enum MuseumWing: String, CaseIterable, Identifiable {
    case careers = "Careers"
    case trophyCabinet = "Trophy Cabinet"
    case greatestManagers = "Managers"
    case greatestPlayers = "Players"
    case recordBook = "Record Book"
    case newspapers = "Newspapers"

    var id: String { rawValue }
}

/// The Football Museum hub, opened from the main menu — every permanently
/// archived career (see `LegacyCareer.swift`), browsable both individually
/// (the "Careers" wing, unchanged from the original "past careers" list)
/// and as cross-save aggregates (the other five wings). Nothing about the
/// original archive or the single-career detail view is removed; this
/// builds additional wings on top of it.
struct LegacyCareersListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var careers: [LegacyCareerInfo] = LegacyArchive.all()
    @State private var fullCareers: [LegacyCareer] = []
    @State private var selected: LegacyCareer?
    @State private var pendingDelete: LegacyCareerInfo?
    @State private var wing: MuseumWing = .careers

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("🏛 FOOTBALL MUSEUM")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                if careers.isEmpty {
                    Spacer()
                    Text("No completed careers yet — finish one to see it here.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    overviewStrip
                    wingPicker
                    ScrollView {
                        wingContent
                    }
                }
            }
            .padding(20)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .onAppear {
            fullCareers = careers.compactMap { LegacyArchive.load(id: $0.id) }
        }
        .sheet(item: $selected) { career in
            LegacyCareerDetailView(career: career)
        }
        .alert("Delete this career?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let info = pendingDelete {
                    LegacyArchive.remove(id: info.id)
                    careers = LegacyArchive.all()
                    fullCareers = careers.compactMap { LegacyArchive.load(id: $0.id) }
                }
                pendingDelete = nil
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    /// The "save-to-save museum overview" — a summary strip visible above
    /// every wing, not just one screen.
    private var overviewStrip: some View {
        let totalTrophies = fullCareers.reduce(0) { $0 + $1.careerHonours.count }
        let totalLegends = fullCareers.reduce(0) { $0 + $1.clubLegends.count }
        let bestTier = fullCareers.map { $0.legacyScore }.max().map { LegacyTier.forScore($0) }
        return HStack(spacing: 14) {
            overviewStat("\(careers.count)", "career\(careers.count == 1 ? "" : "s")")
            overviewStat("\(totalTrophies)", "trophies")
            overviewStat("\(totalLegends)", "legends")
            if let bestTier {
                overviewStat(bestTier.rawValue, "best tier")
            }
        }
        .padding(10)
        .background(Retro.panel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func overviewStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var wingPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MuseumWing.allCases) { candidate in
                    let isSelected = wing == candidate
                    Button {
                        Haptics.tap()
                        wing = candidate
                    } label: {
                        Text(candidate.rawValue.uppercased())
                            .font(.system(.caption, design: .monospaced).bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(isSelected ? Retro.highlight.opacity(0.3) : Retro.panel.opacity(0.6))
                            .foregroundStyle(isSelected ? Retro.highlight : Retro.text.opacity(0.7))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var wingContent: some View {
        switch wing {
        case .careers:
            VStack(spacing: 8) {
                ForEach(careers) { info in row(info) }
            }
        case .trophyCabinet:
            MuseumTrophyCabinetView(careers: fullCareers)
        case .greatestManagers:
            MuseumGreatestManagersView(careers: fullCareers)
        case .greatestPlayers:
            MuseumGreatestPlayersView(careers: fullCareers)
        case .recordBook:
            MuseumRecordBookView(careers: fullCareers)
        case .newspapers:
            MuseumNewspapersView(careers: fullCareers)
        }
    }

    private func row(_ info: LegacyCareerInfo) -> some View {
        Button {
            Haptics.tap()
            selected = LegacyArchive.load(id: info.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(info.managerName) — \(info.clubName)")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                    Text("\(info.seasonsManaged) season\(info.seasonsManaged == 1 ? "" : "s") · \(info.startYear) – \(info.endYear) · \(info.trophyCount) trophy\(info.trophyCount == 1 ? "" : "ies") · \(info.finalDivisionName)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.65))
                    tierBadge(info.legacyTier, score: info.legacyScore)
                }
                Spacer()
                Button {
                    pendingDelete = info
                } label: {
                    Image(systemName: "trash").foregroundStyle(Color(red: 0.9, green: 0.4, blue: 0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Retro.panel.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// A shared "LABEL … VALUE" row used by several museum wings below.
private func museumLine(_ label: String, _ value: String) -> some View {
    HStack {
        Text(label)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Retro.text.opacity(0.8))
        Spacer()
        Text(value)
            .font(.system(.footnote, design: .monospaced).bold())
            .foregroundStyle(Retro.text)
            .multilineTextAlignment(.trailing)
    }
}

/// Every honour won across every archived career, tagged by which career
/// won it — the museum-wide counterpart to Settings' current-save-only
/// Trophy Cabinet, reusing the same `TrophyKind.guess(from:)` visual language.
struct MuseumTrophyCabinetView: View {
    let careers: [LegacyCareer]

    private var tally: [(honour: String, career: String)] { LegacyArchive.trophyTally(from: careers) }

    var body: some View {
        Panel(title: "TROPHY CABINET") {
            if tally.isEmpty {
                Text("Nothing in the cabinet yet — win something to start filling it.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(Array(tally.enumerated()), id: \.offset) { _, entry in
                        VStack(spacing: 6) {
                            if let guess = TrophyKind.guess(from: entry.honour) {
                                TrophyView(kind: guess.kind, tier: guess.tier, size: 44)
                            } else {
                                TrophyView(kind: .league, tier: .bronze, size: 44)
                            }
                            Text(entry.honour)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            Text(entry.career)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.55))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }
}

/// Cross-career bests, plus a full leaderboard and a simple two-career
/// comparison — the directive's "Greatest managers" and "Career
/// comparison" items share one wing since a sortable leaderboard already
/// *is* a comparison.
struct MuseumGreatestManagersView: View {
    let careers: [LegacyCareer]
    @State private var compareA: LegacyCareer?
    @State private var compareB: LegacyCareer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel(title: "BEST CAREERS") {
                VStack(alignment: .leading, spacing: 8) {
                    if let best = careers.max(by: { $0.legacyScore < $1.legacyScore }) {
                        museumLine("👑 Highest Legacy Score", "\(best.managerName) at \(best.clubName) (\(best.legacyScore))")
                    }
                    if let mostTrophies = careers.max(by: { $0.careerHonours.count < $1.careerHonours.count }) {
                        museumLine("🏆 Most trophies in one career", "\(mostTrophies.managerName) — \(mostTrophies.careerHonours.count)")
                    }
                    if let longest = careers.max(by: { $0.seasonsManaged < $1.seasonsManaged }) {
                        museumLine("📅 Longest career", "\(longest.managerName) — \(longest.seasonsManaged) seasons")
                    }
                    if let mostLegends = careers.max(by: { $0.clubLegends.count < $1.clubLegends.count }) {
                        museumLine("⭐ Most club legends produced", "\(mostLegends.managerName) — \(mostLegends.clubLegends.count)")
                    }
                }
            }
            Panel(title: "LEADERBOARD") {
                VStack(spacing: 6) {
                    ForEach(Array(LegacyArchive.greatestManagers(from: careers, limit: 20).enumerated()), id: \.offset) { index, career in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(Retro.text.opacity(0.5))
                                .frame(width: 24, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(career.managerName) — \(career.clubName)")
                                    .font(.system(.footnote, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text)
                                tierBadge(career.legacyTier, score: career.legacyScore)
                            }
                            Spacer()
                        }
                        .font(.system(.footnote, design: .monospaced))
                    }
                }
            }
            Panel(title: "COMPARE TWO CAREERS") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        comparePicker("Career A", selection: $compareA)
                        comparePicker("Career B", selection: $compareB)
                    }
                    if let a = compareA, let b = compareB {
                        compareTable(a, b)
                    } else {
                        Text("Pick two careers to compare.")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.7))
                    }
                }
            }
        }
    }

    private func comparePicker(_ label: String, selection: Binding<LegacyCareer?>) -> some View {
        Menu {
            ForEach(careers) { career in
                Button("\(career.managerName) — \(career.clubName)") { selection.wrappedValue = career }
            }
        } label: {
            HStack {
                Text(selection.wrappedValue.map { "\($0.managerName)" } ?? label)
                    .font(.system(.caption, design: .monospaced).bold())
                    .lineLimit(1)
                Image(systemName: "chevron.down")
            }
            .foregroundStyle(Retro.accent)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Retro.panel.opacity(0.6))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    private func compareTable(_ a: LegacyCareer, _ b: LegacyCareer) -> some View {
        VStack(spacing: 4) {
            compareRow("Club", a.clubName, b.clubName)
            compareRow("Seasons", "\(a.seasonsManaged)", "\(b.seasonsManaged)")
            compareRow("Trophies", "\(a.careerHonours.count)", "\(b.careerHonours.count)")
            compareRow("Club legends", "\(a.clubLegends.count)", "\(b.clubLegends.count)")
            compareRow("Legacy score", "\(a.legacyScore)", "\(b.legacyScore)")
            compareRow("Tier", a.legacyTier.rawValue, b.legacyTier.rawValue)
        }
    }

    private func compareRow(_ label: String, _ a: String, _ b: String) -> some View {
        HStack {
            Text(a).frame(maxWidth: .infinity, alignment: .leading)
            Text(label).foregroundStyle(Retro.text.opacity(0.6)).frame(maxWidth: .infinity, alignment: .center)
            Text(b).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(.caption2, design: .monospaced).bold())
        .foregroundStyle(Retro.text)
    }
}

/// A wall of the greatest club legends across every archived career,
/// ranked by legend score — `ClubLegend` already carries full stats and a
/// generated biography (see item 6), so no new player data is needed.
struct MuseumGreatestPlayersView: View {
    let careers: [LegacyCareer]

    var body: some View {
        Panel(title: "GREATEST PLAYERS") {
            let wall = LegacyArchive.greatestPlayers(from: careers, limit: 30)
            if wall.isEmpty {
                Text("No club legends produced yet.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(wall.enumerated()), id: \.offset) { index, entry in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(Retro.text.opacity(0.5))
                                .frame(width: 24, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(entry.legend.name) — \(entry.legend.clubName)")
                                    .font(.system(.footnote, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text)
                                Text("\(entry.legend.appearances) apps · \(entry.legend.goals) goals · score \(entry.legend.legendScore) · \(entry.career)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.6))
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

/// Real cross-save superlatives — top scorer, most appearances, most
/// MOTM, biggest win, best season, biggest transfers — computed from the
/// structured `LegacyRecordHolder`/`topTransfers` fields, falling back to
/// each career's original flat `recordBook` strings underneath so careers
/// archived before those fields existed stay just as visible as before.
struct MuseumRecordBookView: View {
    let careers: [LegacyCareer]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel(title: "CAREER RECORD BOOK") {
                VStack(alignment: .leading, spacing: 8) {
                    holderLine("⚽ Top scorer", LegacyArchive.globalTopScorer(from: careers))
                    holderLine("👕 Most appearances", LegacyArchive.globalTopAppearances(from: careers))
                    holderLine("🌟 Most Man of the Match", LegacyArchive.globalTopMOTM(from: careers))
                    holderLine("🔥 Biggest win", LegacyArchive.globalRecordWin(from: careers), suffix: "margin")
                    holderLine("🏅 Best season", LegacyArchive.globalBestSeason(from: careers), positionStyle: true)
                }
            }
            Panel(title: "BIGGEST TRANSFERS") {
                let transfers = LegacyArchive.globalTopTransfers(from: careers, limit: 10)
                if transfers.isEmpty {
                    Text("No preserved transfer records yet — only careers archived from here on capture this.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(transfers.enumerated()), id: \.offset) { _, entry in
                            museumLine("\(entry.entry.action == "Sold" ? "💰" : "🖋️") \(entry.entry.playerName)",
                                       "\(formatMoney(entry.entry.fee ?? 0)) — \(entry.career)")
                        }
                    }
                }
            }
            Panel(title: "EVERY CAREER'S HIGHLIGHTS") {
                let lines = careers.flatMap { career in
                    career.recordBook.map { (line: $0, career: "\(career.managerName) at \(career.clubName)") }
                }
                if lines.isEmpty {
                    Text("No individual records yet.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, entry in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.line)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(Retro.text)
                                Text(entry.career)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.55))
                            }
                            .padding(.bottom, 4)
                        }
                    }
                }
            }
        }
    }

    private func holderLine(_ label: String, _ result: (holder: LegacyRecordHolder, career: String)?,
                             suffix: String? = nil, positionStyle: Bool = false) -> some View {
        Group {
            if let result {
                let valueText = positionStyle
                    ? "\(ordinal(result.holder.value)) — \(result.holder.detail)"
                    : "\(result.holder.name) (\(result.holder.value)\(suffix.map { " " + $0 } ?? "")) — \(result.career)"
                museumLine(label, valueText)
            }
        }
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }
}

/// Every preserved front page across every archived career, grouped by
/// career rather than by season since these span different careers —
/// reuses `NewspaperFrontPageCard`/`NewspaperArticleView` exactly as the
/// current-save Newspaper Archive already does.
struct MuseumNewspapersView: View {
    let careers: [LegacyCareer]
    @State private var selected: Newspaper?

    private var careersWithPages: [(career: LegacyCareer, pages: [Newspaper])] {
        careers.compactMap { career in
            guard let pages = career.frontPages, !pages.isEmpty else { return nil }
            return (career, pages)
        }
    }

    var body: some View {
        Group {
            if careersWithPages.isEmpty {
                Panel(title: "NEWSPAPERS") {
                    Text("No preserved front pages yet — only careers archived from here on keep their biggest headlines.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.8))
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(careersWithPages.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(entry.career.managerName.uppercased()) AT \(entry.career.clubName.uppercased())")
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundStyle(Retro.accent)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(entry.pages) { newspaper in
                                    Button {
                                        Haptics.tap()
                                        selected = newspaper
                                    } label: {
                                        NewspaperFrontPageCard(newspaper: newspaper)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $selected) { newspaper in
            NewspaperArticleView(newspaper: newspaper)
        }
    }
}

/// A single archived career's full story — the same layout `CareerEndView`
/// shows at the moment of completion, replayed from the frozen snapshot.
struct LegacyCareerDetailView: View {
    let career: LegacyCareer
    @Environment(\.dismiss) private var dismiss

    /// Consecutive same-club stints from `history`, oldest first — the
    /// "career map": which clubs, in what order, for how long.
    private var clubStints: [(club: String, startYear: Int, seasons: Int)] {
        var stints: [(club: String, startYear: Int, seasons: Int)] = []
        for record in career.history.sorted(by: { $0.season < $1.season }) {
            let year = career.startYear + record.season - 1
            if let last = stints.last, last.club == record.userClub {
                stints[stints.count - 1].seasons += 1
            } else {
                stints.append((club: record.userClub, startYear: year, seasons: 1))
            }
        }
        return stints
    }

    private var legendsByClub: [(club: String, legends: [ClubLegend])] {
        Dictionary(grouping: career.clubLegends, by: { $0.clubName })
            .sorted { $0.value.count > $1.value.count }
            .map { (club: $0.key, legends: $0.value) }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Retro.background, Retro.panel, Retro.background],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Button("Close") { dismiss() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Retro.text)
                    }
                    Text(career.managerName.uppercased())
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text("\(career.seasonsManaged) season\(career.seasonsManaged == 1 ? "" : "s") managed · \(career.startYear) – \(career.endYear)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                    Text("Finished with \(career.clubName) in the \(career.finalDivisionName)")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.highlight)
                    tierBadge(career.legacyTier, score: career.legacyScore)

                    Panel(title: "\(career.managerName.uppercased()) — THE FULL STORY") {
                        Text(career.autobiography)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Retro.text)
                            .lineSpacing(5)
                    }
                    .frame(maxWidth: 560)

                    if clubStints.count > 1 {
                        Panel(title: "CAREER MAP") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    ForEach(Array(clubStints.enumerated()), id: \.offset) { index, stint in
                                        HStack(spacing: 0) {
                                            VStack(spacing: 2) {
                                                Text(stint.club)
                                                    .font(.system(.caption2, design: .monospaced).bold())
                                                    .foregroundStyle(Retro.text)
                                                Text("\(stint.startYear) · \(stint.seasons)s")
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundStyle(Retro.text.opacity(0.6))
                                            }
                                            .padding(.horizontal, 10).padding(.vertical, 8)
                                            .background(Retro.panel.opacity(0.7))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            if index < clubStints.count - 1 {
                                                Image(systemName: "arrow.right")
                                                    .foregroundStyle(Retro.text.opacity(0.4))
                                                    .padding(.horizontal, 6)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 560)
                    }

                    Panel(title: "CAREER HONOURS (\(career.careerHonours.count))") {
                        if career.careerHonours.isEmpty {
                            Text("No major honours — but a career to remember.")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.8))
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(career.careerHonours.enumerated()), id: \.offset) { _, honour in
                                    HonourRow(text: honour)
                                        .font(.system(.callout, design: .monospaced))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 560)

                    if !career.recordBook.isEmpty {
                        Panel(title: "RECORD BOOK") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(career.recordBook.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundStyle(Retro.text)
                                }
                            }
                        }
                        .frame(maxWidth: 560)
                    }

                    if !career.timeline.isEmpty {
                        Panel(title: "TIMELINE") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(career.timeline) { moment in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(moment.icon)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(moment.headline)
                                                .font(.system(.footnote, design: .monospaced).bold())
                                                .foregroundStyle(Retro.text)
                                            Text("\(moment.year) · \(moment.detail)")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(Retro.text.opacity(0.65))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 560)
                    }

                    if !legendsByClub.isEmpty {
                        Panel(title: "CLUB LEGENDS (\(career.clubLegends.count))") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(legendsByClub.enumerated()), id: \.offset) { _, group in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(group.club.uppercased())
                                            .font(.system(.caption2, design: .monospaced).bold())
                                            .foregroundStyle(Retro.highlight)
                                        ForEach(group.legends) { legend in
                                            Text("\(legend.name) (\(legend.joinedSeason)–\(legend.retiredSeason))")
                                                .font(.system(.footnote, design: .monospaced))
                                                .foregroundStyle(Retro.text)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 560)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }
}
