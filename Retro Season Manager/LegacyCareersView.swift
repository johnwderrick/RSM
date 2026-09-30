//
//  LegacyCareersView.swift
//  Retro Season Manager
//
//  Browsing permanently archived careers (see `LegacyCareer.swift`) —
//  reachable from the main menu without any active save, since a finished
//  career's own save no longer exists once it's archived.
//
//  Presented in the accepted Career light-card design language (pale
//  canvas, white cards, ink headings, green accents, gold reserved for
//  genuine emphasis, monospaced figures). All six wings — Careers, Trophy
//  Cabinet, Managers, Players, Record Book and Newspapers — share ONE
//  vertical scroll container: switching wings swaps content views inside
//  the same ScrollView identity, so nothing rebuilds and the sheet never
//  jumps (the Hall of Fame's one-container rule). The overview strip and
//  the wing switcher stay pinned above it; the archive-wide empty state
//  is a single card in the same container. Wing controls are compact
//  always-3-across buttons rather than a horizontal ScrollView so every
//  wing is reachable on phone landscape without horizontal hunting.
//
//  Archive behaviour is untouched: `LegacyArchive.all()`/`load` still own
//  loading and scoring presentation, the delete confirmation still
//  routes through `LegacyArchive.remove(id:)` with an explicit
//  "This can't be undone." warning, and the single-career detail view
//  still replays the frozen snapshot. Stable `career.museum.*`
//  identifiers support the focused UI tests.
//

import SwiftUI

/// A stable colour per tier, tuned for the light-card canvas (deep,
/// readable inks rather than pastels) — kept here rather than on
/// `LegacyTier` itself since the model file stays SwiftUI-free like the
/// rest of `Models.swift`.
private func tierColor(_ tier: LegacyTier) -> Color {
    switch tier {
    case .legend:        return Color(red: 0.72, green: 0.55, blue: 0.08) // gold ink
    case .distinguished: return Color(red: 0.16, green: 0.34, blue: 0.62) // blue ink
    case .accomplished:  return Color(red: 0.12, green: 0.46, blue: 0.23) // green ink
    case .journeyman:    return CareerPalette.mutedInk
    case .modest:        return CareerPalette.mutedInk.opacity(0.75)
    }
}

private func tierBadge(_ tier: LegacyTier, score: Int) -> some View {
    Text("\(tier.rawValue.uppercased()) · \(score)")
        .font(.system(size: 8, weight: .bold, design: .monospaced))
        .foregroundStyle(tierColor(tier))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(tierColor(tier).opacity(0.14))
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

    var icon: String {
        switch self {
        case .careers:          return "folder.fill"
        case .trophyCabinet:    return "trophy.fill"
        case .greatestManagers: return "person.crop.square.fill"
        case .greatestPlayers:  return "person.fill"
        case .recordBook:       return "book.fill"
        case .newspapers:       return "newspaper.fill"
        }
    }
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
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if careers.isEmpty {
                    ScrollView {
                        archiveEmptyState
                            .padding(14)
                            .padding(.trailing, 6)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .accessibilityIdentifier(CareerIdentifiers.museumScroll)
                } else {
                    overviewStrip
                    wingPicker
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            wingContent
                            endAnchor
                        }
                        .padding(14)
                        .padding(.trailing, 6) // breathing room around the floating close
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .accessibilityIdentifier(CareerIdentifiers.museumScroll)
                }
            }

            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
                    .padding(12)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.museumClose)
            .accessibilityLabel("Close museum")
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(CareerPalette.ink)
        .onAppear {
            fullCareers = careers.compactMap { LegacyArchive.load(id: $0.id) }
        }
        .sheet(item: $selected) { career in
            LegacyCareerDetailView(career: career)
        }
        .alert("Delete this career?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
            .accessibilityIdentifier(CareerIdentifiers.museumDeleteCancel)

            Button("Delete", role: .destructive) {
                if let info = pendingDelete {
                    LegacyArchive.remove(id: info.id)
                    careers = LegacyArchive.all()
                    fullCareers = careers.compactMap { LegacyArchive.load(id: $0.id) }
                    wing = .careers
                }
                pendingDelete = nil
            }
            .accessibilityIdentifier(CareerIdentifiers.museumDeleteConfirm)
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: Header band

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("FOOTBALL MUSEUM")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text(careers.isEmpty
                     ? "No archived careers yet"
                     : "\(careers.count) archived career\(careers.count == 1 ? "" : "s") · \(fullCareers.reduce(0) { $0 + $1.careerHonours.count }) trophies")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.museumHeader)
        .accessibilityLabel("Football museum. \(careers.count) archived careers.")
    }

    // MARK: Overview strip

    /// The "save-to-save museum overview" — a summary strip visible above
    /// every wing, not just one screen.
    private var overviewStrip: some View {
        let totalTrophies = fullCareers.reduce(0) { $0 + $1.careerHonours.count }
        let totalLegends = fullCareers.reduce(0) { $0 + $1.clubLegends.count }
        let bestTier = fullCareers.map { $0.legacyScore }.max().map { LegacyTier.forScore($0) }
        return HStack(spacing: 8) {
            overviewStat("\(careers.count)", "career\(careers.count == 1 ? "" : "s")")
            overviewStat("\(totalTrophies)", "trophies")
            overviewStat("\(totalLegends)", "legends")
            if let bestTier {
                overviewStat(bestTier.rawValue, "best tier")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(CareerIdentifiers.museumOverview)
    }

    private func overviewStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(CareerPalette.line)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Wing switcher

    /// Always-3-across wing control — every wing reachable on phone
    /// landscape without horizontal hunting (the Hall of Fame's tab
    /// pattern, at two rows of three).
    private var wingPicker: some View {
        VStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(Array(MuseumWing.allCases.enumerated()), id: \.element.id) { index, candidate in
                        if index / 3 == row {
                            wingButton(candidate)
                        }
                    }
                }
            }
        }
        .padding(6)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func wingButton(_ candidate: MuseumWing) -> some View {
        let selected = wing == candidate
        return Button {
            Haptics.tap()
            wing = candidate
        } label: {
            HStack(spacing: 5) {
                Image(systemName: candidate.icon)
                    .font(.system(size: 10, weight: .black))
                Text(candidate.rawValue.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(selected ? CareerPalette.line : Color.clear)
            .foregroundStyle(selected ? Color.white : CareerPalette.mutedInk)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(CareerIdentifiers.museumWing(candidate.rawValue))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var endAnchor: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityIdentifier(CareerIdentifiers.museumEnd(wing.rawValue))
    }

    // MARK: Wing content

    @ViewBuilder
    private var wingContent: some View {
        switch wing {
        case .careers:
            if careers.isEmpty {
                wingEmptyState("No completed careers yet — finish one to see it here.")
            } else {
                VStack(spacing: 8) {
                    ForEach(careers) { info in
                        row(info)
                    }
                }
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

    /// Shared empty-state card for an archive-wide or per-wing void.
    private func wingEmptyState(_ text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "picture")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(CareerPalette.mutedInk.opacity(0.45))
                .frame(height: 36)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.museumEmpty)
    }

    /// The archive-wide empty state — the museum with nothing in it yet.
    private var archiveEmptyState: some View {
        wingEmptyState("No completed careers yet — finish one to see it here.")
    }

    // MARK: Careers wing row

    private func row(_ info: LegacyCareerInfo) -> some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                selected = LegacyArchive.load(id: info.id)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(info.managerName) — \(info.clubName)")
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(CareerPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(info.seasonsManaged) season\(info.seasonsManaged == 1 ? "" : "s") · \(info.startYear) – \(info.endYear) · \(info.trophyCount) trophy\(info.trophyCount == 1 ? "" : "ies") · \(info.finalDivisionName)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                            .lineLimit(2)
                        tierBadge(info.legacyTier, score: info.legacyScore)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(CareerPalette.mutedInk.opacity(0.5))
                }
                .padding(12)
                .background(CareerPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.18)))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.museumCareer(info.managerName))
            .accessibilityLabel("\(info.managerName) at \(info.clubName), \(info.seasonsManaged) seasons, \(info.startYear) to \(info.endYear), \(info.trophyCount) trophies, final position tier \(info.legacyTier.rawValue), legacy score \(info.legacyScore). Opens the career record.")

            Button {
                Haptics.tap()
                pendingDelete = info
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
                    .frame(width: 40, height: 40)
                    .background(CareerPalette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.18)))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.museumCareerDelete(info.managerName))
            .accessibilityLabel("Delete \(info.managerName) at \(info.clubName)")
        }
    }
}

/// A shared "LABEL … VALUE" row used by several museum wings below.
private func museumLine(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
        Text(label)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(CareerPalette.mutedInk)
        Spacer()
        Text(value)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(CareerPalette.ink)
            .multilineTextAlignment(.trailing)
    }
}

/// One white card in the light-card language — the museum's replacement
/// for the dark `Panel` so the hub matches the accepted Career sheets.
private struct MuseumCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.line)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: CareerPalette.ink.opacity(0.05), radius: 5, y: 2)
    }
}

/// Every honour won across every archived career, tagged by which career
/// won it — the museum-wide counterpart to Settings' current-save-only
/// Trophy Cabinet, reusing the same `TrophyKind.guess(from:)` visual language.
struct MuseumTrophyCabinetView: View {
    let careers: [LegacyCareer]

    private var tally: [(honour: String, career: String)] { LegacyArchive.trophyTally(from: careers) }

    var body: some View {
        MuseumCard(title: "TROPHY CABINET") {
            if tally.isEmpty {
                Text("Nothing in the cabinet yet — win something to start filling it.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(Array(tally.enumerated()), id: \.offset) { index, entry in
                        VStack(spacing: 6) {
                            if let guess = TrophyKind.guess(from: entry.honour) {
                                TrophyView(kind: guess.kind, tier: guess.tier, size: 44)
                            } else {
                                TrophyView(kind: .league, tier: .bronze, size: 44)
                            }
                            Text(entry.honour)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(CareerPalette.ink)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            Text(entry.career)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(CareerPalette.mutedInk)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier(CareerIdentifiers.museumTrophy(index))
                        .accessibilityLabel("\(entry.honour), won by \(entry.career).")
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
        VStack(alignment: .leading, spacing: 12) {
            MuseumCard(title: "BEST CAREERS") {
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
            MuseumCard(title: "LEADERBOARD") {
                VStack(spacing: 6) {
                    ForEach(Array(LegacyArchive.greatestManagers(from: careers, limit: 20).enumerated()), id: \.element.id) { index, career in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(CareerPalette.mutedInk.opacity(0.7))
                                .frame(width: 24, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(career.managerName) — \(career.clubName)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(CareerPalette.ink)
                                tierBadge(career.legacyTier, score: career.legacyScore)
                            }
                            Spacer()
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier(CareerIdentifiers.museumLeaderboardRow(index))
                        .accessibilityLabel("Number \(index + 1): \(career.managerName) at \(career.clubName), legacy score \(career.legacyScore), tier \(career.legacyTier.rawValue).")
                    }
                }
            }
            MuseumCard(title: "COMPARE TWO CAREERS") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        comparePicker("Career A", selection: $compareA)
                        comparePicker("Career B", selection: $compareB)
                    }
                    if let a = compareA, let b = compareB {
                        compareTable(a, b)
                    } else {
                        Text("Pick two careers to compare.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
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
            HStack(spacing: 5) {
                Text(selection.wrappedValue.map { "\($0.managerName)" } ?? label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(CareerPalette.line)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(CareerPalette.surface)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.35)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(CareerIdentifiers.museumCompareSlot(label))
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
        .accessibilityIdentifier(CareerIdentifiers.museumCompareTable)
    }

    private func compareRow(_ label: String, _ a: String, _ b: String) -> some View {
        HStack {
            Text(a).frame(maxWidth: .infinity, alignment: .leading)
            Text(label).foregroundStyle(CareerPalette.mutedInk).frame(maxWidth: .infinity, alignment: .center)
            Text(b).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(CareerPalette.ink)
    }
}

/// A wall of the greatest club legends across every archived career,
/// ranked by legend score — `ClubLegend` already carries full stats and a
/// generated biography (see item 6), so no new player data is needed.
struct MuseumGreatestPlayersView: View {
    let careers: [LegacyCareer]

    var body: some View {
        MuseumCard(title: "GREATEST PLAYERS") {
            let wall = LegacyArchive.greatestPlayers(from: careers, limit: 30)
            if wall.isEmpty {
                Text("No club legends produced yet.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(wall.enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 10) {
                            PlayerPortraitView(name: entry.legend.name, position: entry.legend.position,
                                               age: nil, size: 40)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(entry.legend.name) — \(entry.legend.clubName)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(CareerPalette.ink)
                                Text("\(entry.legend.appearances) apps · \(entry.legend.goals) goals · score \(entry.legend.legendScore) · \(entry.career)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(CareerPalette.mutedInk)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier(CareerIdentifiers.museumPlayer(index))
                        .accessibilityLabel("\(entry.legend.name) of \(entry.legend.clubName), \(entry.legend.appearances) appearances, \(entry.legend.goals) goals, legend score \(entry.legend.legendScore), managed by \(entry.career).")
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
        VStack(alignment: .leading, spacing: 12) {
            MuseumCard(title: "CAREER RECORD BOOK") {
                VStack(alignment: .leading, spacing: 8) {
                    holderLine("⚽ Top scorer", LegacyArchive.globalTopScorer(from: careers))
                    holderLine("👕 Most appearances", LegacyArchive.globalTopAppearances(from: careers))
                    holderLine("🌟 Most Man of the Match", LegacyArchive.globalTopMOTM(from: careers))
                    holderLine("🔥 Biggest win", LegacyArchive.globalRecordWin(from: careers), suffix: "margin")
                    holderLine("🏅 Best season", LegacyArchive.globalBestSeason(from: careers), positionStyle: true)
                }
            }
            MuseumCard(title: "BIGGEST TRANSFERS") {
                let transfers = LegacyArchive.globalTopTransfers(from: careers, limit: 10)
                if transfers.isEmpty {
                    Text("No preserved transfer records yet — only careers archived from here on capture this.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(transfers.enumerated()), id: \.offset) { index, entry in
                            museumLine("\(entry.entry.action == "Sold" ? "💰" : "🖋️") \(entry.entry.playerName)",
                                       "\(formatMoney(entry.entry.fee ?? 0)) — \(entry.career)")
                                .accessibilityElement(children: .ignore)
                                .accessibilityIdentifier(CareerIdentifiers.museumTransfer(index))
                                .accessibilityLabel("\(entry.entry.playerName), \(entry.entry.action) for \(formatMoney(entry.entry.fee ?? 0)), during \(entry.career).")
                        }
                    }
                }
            }
            MuseumCard(title: "EVERY CAREER'S HIGHLIGHTS") {
                let lines = careers.flatMap { career in
                    career.recordBook.map { (line: $0, career: "\(career.managerName) at \(career.clubName)") }
                }
                if lines.isEmpty {
                    Text("No individual records yet.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, entry in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(CareerPalette.ink)
                                Text(entry.career)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(CareerPalette.mutedInk)
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
/// reuses `NewspaperFrontPageCard` exactly as the current-save Newspaper
/// Archive does; the article sheet wraps the original
/// `NewspaperArticleView` in a museum-local close bar (the original view
/// has no close control of its own and is shared with the current-save
/// archive, so it is left untouched).
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
                MuseumCard(title: "NEWSPAPERS") {
                    Text("No preserved front pages yet — only careers archived from here on keep their biggest headlines.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(careersWithPages.enumerated()), id: \.offset) { groupIndex, entry in
                        MuseumCard(title: "\(entry.career.managerName.uppercased()) AT \(entry.career.clubName.uppercased())") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(Array(entry.pages.enumerated()), id: \.element.id) { pageIndex, newspaper in
                                    Button {
                                        Haptics.tap()
                                        selected = newspaper
                                    } label: {
                                        NewspaperFrontPageCard(newspaper: newspaper)
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                    .accessibilityIdentifier(CareerIdentifiers.museumNewspaper(groupIndex * 100 + pageIndex))
                                    .accessibilityLabel("Front page: \(newspaper.headline). Opens the article.")
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $selected) { newspaper in
            ZStack(alignment: .topTrailing) {
                NewspaperArticleView(newspaper: newspaper)
                Button {
                    Haptics.tap()
                    selected = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Retro.text.opacity(0.55))
                        .padding(12)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(CareerIdentifiers.museumPaperClose)
                .accessibilityLabel("Close article")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(CareerIdentifiers.museumPaper)
        }
    }
}

/// A single archived career's full story — the same layout `CareerEndView`
/// shows at the moment of completion, replayed from the frozen snapshot.
/// Now in the light-card language, still one vertical scroll container.
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
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    identifierAnchor
                    heroBlock

                    MuseumCard(title: "\(career.managerName.uppercased()) — THE FULL STORY") {
                        Text(career.autobiography)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink)
                            .lineSpacing(5)
                    }
                    .frame(maxWidth: 560)

                    if clubStints.count > 1 {
                        MuseumCard(title: "CAREER MAP") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    ForEach(Array(clubStints.enumerated()), id: \.offset) { index, stint in
                                        HStack(spacing: 0) {
                                            VStack(spacing: 2) {
                                                Text(stint.club)
                                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(CareerPalette.ink)
                                                Text("\(stint.startYear) · \(stint.seasons)s")
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .foregroundStyle(CareerPalette.mutedInk)
                                            }
                                            .padding(.horizontal, 10).padding(.vertical, 8)
                                            .background(CareerPalette.line.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(CareerPalette.line.opacity(0.18)))
                                            if index < clubStints.count - 1 {
                                                Image(systemName: "arrow.right")
                                                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.5))
                                                    .padding(.horizontal, 6)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 560)
                    }

                    MuseumCard(title: "CAREER HONOURS (\(career.careerHonours.count))") {
                        if career.careerHonours.isEmpty {
                            Text("No major honours — but a career to remember.")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(CareerPalette.mutedInk)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(career.careerHonours.enumerated()), id: \.offset) { index, honour in
                                    HonourRow(text: honour)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(CareerPalette.ink)
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityIdentifier(CareerIdentifiers.museumDetailHonour(index))
                                        .accessibilityLabel(honour)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 560)

                    if !career.recordBook.isEmpty {
                        MuseumCard(title: "RECORD BOOK") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(career.recordBook.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(CareerPalette.ink)
                                }
                            }
                        }
                        .frame(maxWidth: 560)
                    }

                    if !career.timeline.isEmpty {
                        MuseumCard(title: "TIMELINE") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(career.timeline) { moment in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(moment.icon)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(moment.headline)
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundStyle(CareerPalette.ink)
                                            Text("\(moment.year) · \(moment.detail)")
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundStyle(CareerPalette.mutedInk)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 560)
                    }

                    if !legendsByClub.isEmpty {
                        MuseumCard(title: "CLUB LEGENDS (\(career.clubLegends.count))") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(legendsByClub.enumerated()), id: \.offset) { groupIndex, group in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(group.club.uppercased())
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                            .foregroundStyle(CareerPalette.line)
                                        ForEach(Array(group.legends.enumerated()), id: \.element.id) { legendIndex, legend in
                                            Text("\(legend.name) (\(legend.joinedSeason)–\(legend.retiredSeason))")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(CareerPalette.ink)
                                                .accessibilityIdentifier(CareerIdentifiers.museumDetailLegend(groupIndex, legendIndex))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 560)
                    }
                }
                .padding(14)
                .padding(.trailing, 6) // breathing room around the floating close
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier(CareerIdentifiers.museumDetailScroll)

            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
                    .padding(12)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.museumDetailClose)
            .accessibilityLabel("Close career record")
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(CareerPalette.ink)
    }

    /// A stable, name-slugged root anchor for the detail sheet (kept
    /// separate from the hero content so concurrent managers with the
    /// same name never share an anchor).
    private var identifierAnchor: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityIdentifier(CareerIdentifiers.museumDetail(career.managerName))
    }

    private var heroBlock: some View {
        VStack(spacing: 6) {
            Text(career.managerName.uppercased())
                .font(.system(.title, design: .monospaced).bold())
                .foregroundStyle(CareerPalette.line)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(career.seasonsManaged) season\(career.seasonsManaged == 1 ? "" : "s") managed · \(career.startYear) – \(career.endYear)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Text("Finished with \(career.clubName) in the \(career.finalDivisionName)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPalette.line)
            tierBadge(career.legacyTier, score: career.legacyScore)
        }
        .frame(maxWidth: .infinity)
    }
}
