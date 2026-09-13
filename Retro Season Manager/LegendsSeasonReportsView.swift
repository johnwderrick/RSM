import SwiftUI

/// Season Reports destination. Presentation only: reports are read from
/// `store.profile.seasonReports` exactly as the season roll persisted them;
/// grouping and counts here are display projections, not recalculations.
struct LegendsSeasonReportsView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    let onBack: () -> Void
    @State private var selectedReport: LegendsSeasonDevelopmentReport?

    private var sortedReports: [LegendsSeasonDevelopmentReport] {
        store.profile.seasonReports.values.sorted { $0.season > $1.season }
    }

    var body: some View {
        LegendsMenuShell(store: store, title: "SEASON REPORTS", subtitle: "PLAYER DEVELOPMENT HISTORY", icon: "chart.line.uptrend.xyaxis", accent: LegendsPalette.blue, onBack: onBack, currentNav: .reports, onNavigate: onNavigate) {
            // The shared shell owns the single vertical scroll container;
            // season cards are plain (non-lazy) rows so the archive stays
            // fully materialised for accessibility.
            VStack(alignment: .leading, spacing: 12) {
                if sortedReports.isEmpty {
                    emptyState
                } else {
                    summaryBand
                    ForEach(sortedReports, id: \.season) { report in
                        seasonCard(report)
                    }
                }
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("legends.reports.screen")
        }
        .sheet(item: $selectedReport) { report in
            LegendsSeasonReportDetailView(store: store, report: report)
        }
    }

    // MARK: - Summary band

    private var summaryBand: some View {
        let latest = sortedReports.first
        let counts = ReportCategoryCounts(entries: latest?.entries ?? [])
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                summaryStat(value: "\(sortedReports.count)",
                            label: "REPORTS",
                            accessible: "\(sortedReports.count) season reports available",
                            identifier: "legends.reports.summary.count")
                summaryStat(value: latest.map { "S\($0.season)" } ?? "—",
                            label: "LATEST SEASON",
                            accessible: latest.map { "Latest reported season \($0.season)" } ?? "No reports",
                            identifier: "legends.reports.summary.latest")
                Spacer(minLength: 4)
            }
            Text("LATEST SEASON OUTCOMES")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            HStack(spacing: 6) {
                outcomeChip("IMPROVED", counts.improved, LegendsPalette.green, "legends.reports.summary.improved")
                outcomeChip("STABLE", counts.stable, LegendsPalette.blue, "legends.reports.summary.stable")
                outcomeChip("DECLINING", counts.declined, LegendsPalette.goldDeep, "legends.reports.summary.declining")
                outcomeChip("FINAL", counts.finalSeason, LegendsPalette.orange, "legends.reports.summary.final")
                outcomeChip("RETIRED", counts.retired, LegendsPalette.purple, "legends.reports.summary.retired")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.blue.opacity(0.28), lineWidth: 1.2))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.reports.summary")
    }

    private func summaryStat(value: String, label: String, accessible: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy)
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessible)
        .accessibilityIdentifier(identifier)
    }

    private func outcomeChip(_ name: String, _ count: Int, _ color: Color, _ identifier: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(count) \(name)")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy.opacity(0.78))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) players \(name.lowercased()) in the latest season")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Season cards

    private func seasonCard(_ report: LegendsSeasonDevelopmentReport) -> some View {
        let counts = ReportCategoryCounts(entries: report.entries)
        return Button {
            Haptics.tap()
            selectedReport = report
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("SEASON \(report.season)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(LegendsPalette.navy)
                    Spacer(minLength: 6)
                    Text("\(report.entries.count) PLAYERS")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.4))
                }
                HStack(spacing: 6) {
                    outcomeChip("IMPROVED", counts.improved, LegendsPalette.green, "legends.reports.card.\(report.season).improved")
                    outcomeChip("STABLE", counts.stable, LegendsPalette.blue, "legends.reports.card.\(report.season).stable")
                    outcomeChip("DECLINING", counts.declined, LegendsPalette.goldDeep, "legends.reports.card.\(report.season).declining")
                    if counts.finalSeason > 0 || counts.retired > 0 {
                        outcomeChip("FINAL", counts.finalSeason, LegendsPalette.orange, "legends.reports.card.\(report.season).final")
                        outcomeChip("RETIRED", counts.retired, LegendsPalette.purple, "legends.reports.card.\(report.season).retired")
                    }
                }
                if let warning = report.squadAgeWarning {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                        Text(warning)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Squad age warning: \(warning)")
                    .accessibilityIdentifier("legends.reports.card.\(report.season).warning")
                }
            }
            .padding(13)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.blue.opacity(0.25), lineWidth: 1))
            .shadow(color: LegendsPalette.navy.opacity(0.08), radius: 7, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.reports.card.\(report.season)")
        .accessibilityLabel("Season \(report.season) report, \(report.entries.count) players. \(counts.improved) improved, \(counts.stable) stable, \(counts.declined) declining, \(counts.finalSeason) entered final season, \(counts.retired) retired.\(report.squadAgeWarning.map { " Squad age warning: \($0)." } ?? "")")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LegendsPalette.blue)
                Text("NO SEASON REPORTS YET")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
            }
            Text("Complete a season and every signed player's development — improvements, declines, final-season entries and retirements — is reported here automatically.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.72))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.blue.opacity(0.25), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.reports.empty")
    }
}

/// Display-only grouping counts for one report's entries. A retired entry is
/// categorised as RETIRED even though it may also carry `improved`/`declined`
/// flags; the detail view groups entries the same way so the two always agree.
private struct ReportCategoryCounts {
    let improved: Int
    let stable: Int
    let declined: Int
    let finalSeason: Int
    let retired: Int

    init(entries: [LegendsSeasonReportEntry]) {
        improved = entries.filter { $0.improved && !$0.retired }.count
        stable = entries.filter { $0.stable && !$0.retired }.count
        declined = entries.filter { $0.declined && !$0.retired }.count
        finalSeason = entries.filter { $0.enteredFinalSeason && !$0.retired }.count
        retired = entries.filter { $0.retired }.count
    }
}

/// The light-card detail page for one season report, grouped by development
/// outcome. Reads the persisted entry fields verbatim — no recalculation.
private struct LegendsSeasonReportDetailView: View {
    let store: LegendsStore
    let report: LegendsSeasonDevelopmentReport
    @Environment(\.dismiss) private var dismiss

    private var groups: [(String, String, Color, String, [LegendsSeasonReportEntry])] {
        [
            ("IMPROVED", "arrow.up.circle.fill", LegendsPalette.green, "legends.reports.detail.improved",
             report.entries.filter { $0.improved && !$0.retired }),
            ("STABLE", "equal.circle.fill", LegendsPalette.blue, "legends.reports.detail.stable",
             report.entries.filter { $0.stable && !$0.retired && !$0.improved && !$0.declined }),
            ("DECLINING", "arrow.down.circle.fill", LegendsPalette.goldDeep, "legends.reports.detail.declining",
             report.entries.filter { $0.declined && !$0.retired && !$0.improved }),
            ("FINAL SEASON", "hourglass", LegendsPalette.orange, "legends.reports.detail.final",
             report.entries.filter { $0.enteredFinalSeason && !$0.retired && !$0.improved && !$0.declined }),
            ("RETIRED", "rosette", LegendsPalette.purple, "legends.reports.detail.retired",
             report.entries.filter { $0.retired }),
        ]
    }

    var body: some View {
        ZStack {
            LegendsPalette.contentBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Spacer()
                        Button {
                            Haptics.tap()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close season report")
                        .accessibilityIdentifier("legends.reports.detail.close")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("SEASON \(report.season)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(LegendsPalette.navy)
                        Text("\(report.entries.count) PLAYER DEVELOPMENT RECORDS")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                    }

                    if let warning = report.squadAgeWarning {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.orange)
                            Text(warning)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Squad age warning: \(warning)")
                        .accessibilityIdentifier("legends.reports.detail.warning")
                    }

                    if let after = report.signedAverageAgeAfter {
                        detailLine(label: "SIGNED SQUAD AVG AGE AFTER SEASON", value: "\(after)")
                    }

                    ForEach(groups, id: \.0) { title, icon, color, identifier, entries in
                        reportGroup(title: title, icon: icon, color: color, identifier: identifier, entries: entries)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func reportGroup(title: String, icon: String, color: Color, identifier: String, entries: [LegendsSeasonReportEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
                Spacer()
                Text("\(entries.count)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
            }
            if entries.isEmpty {
                Text("None")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            } else {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        playerEntry(entry, color: color)
                    }
                }
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func playerEntry(_ entry: LegendsSeasonReportEntry, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 9) {
                if let card = LegendsCardDatabase.all.first(where: { $0.id == entry.cardID }) {
                    PlayerPortraitView(name: entry.playerName, position: card.position.broad,
                                       nation: card.nation, size: 38)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(color.opacity(0.6), lineWidth: 1.5))
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(color.opacity(0.6))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.playerName)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(LegendsPalette.navy)
                        if entry.favourite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(LegendsPalette.goldDeep)
                        }
                    }
                    Text("\(entry.position.rawValue) · AGE \(entry.ageBefore) → \(entry.ageAfter) · OVR \(entry.overallBefore) → \(entry.overallAfter)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                }
                Spacer(minLength: 4)
                Text(entry.developmentProfile.rawValue)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                    .multilineTextAlignment(.trailing)
            }

            HStack(spacing: 6) {
                Text(entry.trainingFocus.rawValue)
                Text("·")
                Text(entry.trainingIntensity.rawValue)
                Text("·")
                Text("\(entry.trainingSessions) SESSIONS")
            }
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(LegendsPalette.navy.opacity(0.66))

            if !entry.trainingAttributeGains.isEmpty {
                Text(entry.trainingAttributeGains.keys.sorted()
                    .map { "\($0) +\(entry.trainingAttributeGains[$0] ?? 0)" }
                    .joined(separator: " · "))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(LegendsPalette.green)
            }

            Text(entry.trainingExplanation)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
        }
        .padding(10)
        .background(LegendsPalette.contentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.reports.detail.player.\(entry.cardID)")
        .accessibilityLabel("\(entry.playerName). Age \(entry.ageBefore) to \(entry.ageAfter), overall \(entry.overallBefore) to \(entry.overallAfter). Training focus \(entry.trainingFocus.rawValue), intensity \(entry.trainingIntensity.rawValue), \(entry.trainingSessions) sessions. Development profile \(entry.developmentProfile.rawValue).")
    }

    private func detailLine(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
