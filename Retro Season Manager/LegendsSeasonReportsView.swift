import SwiftUI

struct LegendsSeasonReportsView: View {
    let store: LegendsStore
    let onBack: () -> Void
    @State private var selectedReport: LegendsSeasonDevelopmentReport?

    var body: some View {
        LegendsMenuShell(store: store, title: "SEASON REPORTS", subtitle: "PLAYER DEVELOPMENT HISTORY", icon: "chart.line.uptrend.xyaxis", accent: LegendsPalette.blue, onBack: onBack, currentNav: .planning) {
            VStack(alignment: .leading, spacing: 12) {
                if store.profile.seasonReports.isEmpty {
                    Text("No completed season reports yet.").font(.system(size: 12, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.65)).frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    ForEach(store.profile.seasonReports.values.sorted { $0.season > $1.season }) { report in
                        Button { selectedReport = report } label: {
                            HStack { Text("SEASON \(report.season)").font(.system(size: 13, weight: .black, design: .monospaced)); Spacer(); Text("\(report.entries.count) PLAYERS").font(.system(size: 10, weight: .bold, design: .monospaced)) }
                                .foregroundStyle(LegendsPalette.navy).padding(14).background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(PressableButtonStyle())
                    }
                }
            }.padding(16)
        }
        .sheet(item: $selectedReport) { report in LegendsSeasonReportDetailView(report: report) }
        .accessibilityIdentifier("legends.seasonReports")
    }
}

private struct LegendsSeasonReportDetailView: View {
    let report: LegendsSeasonDevelopmentReport
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if let warning = report.squadAgeWarning { Section("SQUAD PLANNING") { Text(warning) } }
                reportSection("IMPROVED", entries: report.entries.filter { $0.improved })
                reportSection("STABLE", entries: report.entries.filter { $0.stable })
                reportSection("DECLINING", entries: report.entries.filter { $0.declined })
                reportSection("FINAL SEASON", entries: report.entries.filter { $0.enteredFinalSeason })
                reportSection("RETIRED", entries: report.entries.filter { $0.retired })
            }
            .navigationTitle("SEASON \(report.season)")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .accessibilityIdentifier("legends.seasonReportDetail")
    }
    @ViewBuilder private func reportSection(_ title: String, entries: [LegendsSeasonReportEntry]) -> some View {
        Section(title) {
            if entries.isEmpty { Text("None").foregroundStyle(.secondary) }
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading) { Text(entry.playerName).font(.headline); Text("AGE \(entry.ageBefore) → \(entry.ageAfter) · OVR \(entry.overallBefore) → \(entry.overallAfter)").font(.caption).foregroundStyle(.secondary) }
                    Spacer(); Text(entry.developmentProfile.rawValue).font(.caption2).multilineTextAlignment(.trailing)
                }
                .accessibilityIdentifier("legends.report.\(entry.cardID)")
            }
        }
    }
}
