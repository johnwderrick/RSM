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

/// The "past careers" list, opened from the main menu.
struct LegacyCareersListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var careers: [LegacyCareerInfo] = LegacyArchive.all()
    @State private var selected: LegacyCareer?
    @State private var pendingDelete: LegacyCareerInfo?
    @State private var showRecordBook = false

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("PAST CAREERS")
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
                    Button {
                        Haptics.tap()
                        showRecordBook = true
                    } label: {
                        HStack {
                            Image(systemName: "book.closed.fill")
                            Text("GLOBAL RECORD BOOK")
                                .font(.system(.footnote, design: .monospaced).bold())
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(Retro.highlight)
                        .padding(12)
                        .background(Retro.highlight.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PressableButtonStyle())

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(careers) { info in row(info) }
                        }
                    }
                }
            }
            .padding(20)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .sheet(item: $selected) { career in
            LegacyCareerDetailView(career: career)
        }
        .sheet(isPresented: $showRecordBook) {
            GlobalRecordBookView(careers: careers)
        }
        .alert("Delete this career?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let info = pendingDelete {
                    LegacyArchive.remove(id: info.id)
                    careers = LegacyArchive.all()
                }
                pendingDelete = nil
            }
        } message: {
            Text("This can't be undone.")
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

/// Cross-career bests — a multi-career comparison at a glance, computed
/// lazily (only when opened) since it's the one screen that has to decode
/// every archived career in full rather than just the lightweight index.
struct GlobalRecordBookView: View {
    let careers: [LegacyCareerInfo]
    @Environment(\.dismiss) private var dismiss
    @State private var fullCareers: [LegacyCareer] = []

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("GLOBAL RECORD BOOK")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Panel(title: "BEST CAREERS") {
                            VStack(alignment: .leading, spacing: 8) {
                                if let best = fullCareers.max(by: { $0.legacyScore < $1.legacyScore }) {
                                    line("👑 Highest Legacy Score", "\(best.managerName) at \(best.clubName) (\(best.legacyScore))")
                                }
                                if let mostTrophies = fullCareers.max(by: { $0.careerHonours.count < $1.careerHonours.count }) {
                                    line("🏆 Most trophies in one career", "\(mostTrophies.managerName) — \(mostTrophies.careerHonours.count)")
                                }
                                if let longest = fullCareers.max(by: { $0.seasonsManaged < $1.seasonsManaged }) {
                                    line("📅 Longest career", "\(longest.managerName) — \(longest.seasonsManaged) seasons")
                                }
                                if let mostLegends = fullCareers.max(by: { $0.clubLegends.count < $1.clubLegends.count }) {
                                    line("⭐ Most club legends produced", "\(mostLegends.managerName) — \(mostLegends.clubLegends.count)")
                                }
                            }
                        }
                        Panel(title: "INDIVIDUAL RECORDS") {
                            if allRecordLines.isEmpty {
                                Text("No individual records yet.")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(Retro.text.opacity(0.8))
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(allRecordLines.enumerated()), id: \.offset) { _, entry in
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
                    .frame(maxWidth: 560)
                }
            }
            .padding(20)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .onAppear {
            fullCareers = careers.compactMap { LegacyArchive.load(id: $0.id) }
        }
    }

    private var allRecordLines: [(line: String, career: String)] {
        fullCareers.flatMap { career in
            career.recordBook.map { (line: $0, career: "\(career.managerName) at \(career.clubName)") }
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
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
