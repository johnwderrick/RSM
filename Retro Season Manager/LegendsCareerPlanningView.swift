import SwiftUI

/// Career Planning destination. Purely presentational: every figure is a
/// read-only projection of the authoritative `store.squadCareerPlan()` data
/// (ages, stages, retirement distances, replacement matches). Nothing here
/// recalculates lifecycle rules, mutates careers, or persists anything.
struct LegendsCareerPlanningView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    let onBack: () -> Void
    private var plan: LegendsSquadCareerPlan { store.squadCareerPlan() }

    /// Presentation-only risk label derived from the plan's next-season
    /// retirement count. The underlying distances are the store's.
    private var risk: (label: String, color: Color, detail: String) {
        let next = plan.retiringNextSeason.count
        if next >= 3 {
            return ("HIGH RISK", LegendsPalette.orange, "\(next) players retire next season")
        }
        if next >= 1 {
            return ("WATCH", LegendsPalette.goldDeep, "\(next) player\(next == 1 ? "" : "s") retire\(next == 1 ? "s" : "") next season")
        }
        return ("STABLE", LegendsPalette.green, "No projected next-season retirements")
    }

    var body: some View {
        LegendsMenuShell(store: store, title: "CAREER PLANNING", subtitle: "PLAN THE NEXT GENERATION", icon: "chart.bar.xaxis", accent: LegendsPalette.cyan, onBack: onBack, currentNav: .planning, onNavigate: onNavigate) {
            // The shared shell owns the single vertical scroll container.
            // Sections are plain (non-lazy) so every figure stays in the
            // accessibility tree, and all state here is derived, so nothing
            // can reset scroll position during interaction.
            VStack(alignment: .leading, spacing: 12) {
                if store.activeClubPlayers.isEmpty {
                    emptySquadState
                } else {
                    summaryBand
                    stagePanel
                    retirementPanel
                    replacementPanel
                    agePanel
                }
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("legends.planning.screen")
        }
    }

    // MARK: - Summary band

    private var summaryBand: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    summaryStat(value: plan.startingXIAverageAge.map(String.init) ?? "—",
                                label: "XI AVG AGE",
                                accessible: plan.startingXIAverageAge.map { "Starting eleven average age \($0)" } ?? "No starting eleven",
                                identifier: "legends.planning.summary.xiAge")
                    summaryStat(value: plan.signedAverageAge.map(String.init) ?? "—",
                                label: "SQUAD AGE",
                                accessible: plan.signedAverageAge.map { "Signed squad average age \($0)" } ?? "No signed players",
                                identifier: "legends.planning.summary.squadAge")
                    summaryStat(value: "\(plan.finalSeasonCount)",
                                label: "FINAL SEASON",
                                accessible: "\(plan.finalSeasonCount) players in their final season",
                                identifier: "legends.planning.summary.finalSeason")
                }
                HStack(spacing: 7) {
                    Circle().fill(risk.color).frame(width: 8, height: 8)
                    Text("RETIREMENT RISK: \(risk.label)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(risk.color)
                    Text("· \(risk.detail)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Retirement risk \(risk.label). \(risk.detail).")
                .accessibilityIdentifier("legends.planning.summary.risk")
            }
            Spacer(minLength: 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.cyan.opacity(0.28), lineWidth: 1.2))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.planning.summary")
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

    // MARK: - Career stages

    private var stagePanel: some View {
        planningPanel("CAREER STAGES", icon: "person.3.fill") {
            if plan.stageCounts.isEmpty {
                Text("No signed careers yet.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                    .accessibilityIdentifier("legends.planning.stages.empty")
            } else {
                let stages = plan.stageCounts.sorted { $0.key < $1.key }
                let total = plan.stageCounts.values.reduce(0, +)
                // Compact proportional bar: one segment per career stage.
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(stages, id: \.key) { stage, count in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(stageColor(stage))
                                .frame(width: max(6, geo.size.width * CGFloat(count) / CGFloat(max(1, total))))
                        }
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)
                VStack(spacing: 5) {
                    ForEach(stages, id: \.key) { stage, count in
                        HStack(spacing: 6) {
                            Circle().fill(stageColor(stage)).frame(width: 7, height: 7)
                            Text(stage)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(LegendsPalette.navy.opacity(0.72))
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(LegendsPalette.navy)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(count) players in the \(stage.lowercased()) stage")
                        .accessibilityIdentifier("legends.planning.stage.\(stage.lowercased().replacingOccurrences(of: " ", with: "-"))")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.planning.stages")
    }

    private func stageColor(_ stage: String) -> Color {
        switch stage {
        case "FINAL SEASON": return LegendsPalette.orange
        case "PROSPECT": return LegendsPalette.green
        case "DEVELOPING": return LegendsPalette.cyan
        case "PRIME": return LegendsPalette.blue
        case "DECLINING": return LegendsPalette.goldDeep
        case "VETERAN": return LegendsPalette.purple
        default: return LegendsPalette.navy.opacity(0.4)
        }
    }

    // MARK: - Retirement radar

    private var retirementPanel: some View {
        let withinOnly = plan.retiringWithinThreeSeasons.filter { !plan.retiringNextSeason.contains($0) }
        return planningPanel("RETIREMENT RADAR", icon: "hourglass") {
            VStack(alignment: .leading, spacing: 9) {
                retirementGroup(title: "NEXT SEASON",
                                names: plan.retiringNextSeason,
                                color: LegendsPalette.orange,
                                empty: "No players retire next season.",
                                identifier: "legends.planning.radar.next")
                retirementGroup(title: "WITHIN 3 SEASONS",
                                names: withinOnly,
                                color: LegendsPalette.goldDeep,
                                empty: "No players retire within three seasons.",
                                identifier: "legends.planning.radar.within")
                if let warning = plan.warning {
                    Text(warning)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("legends.planning.radar.warning")
                } else {
                    Text("No concentrated retirement warning.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                        .accessibilityIdentifier("legends.planning.radar.nowarning")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.planning.radar")
    }

    @ViewBuilder
    private func retirementGroup(title: String, names: [String], color: Color, empty: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
                Text("\(names.count)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            if names.isEmpty {
                Text(empty)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            } else {
                Text(names.joined(separator: ", "))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(LegendsPalette.navy)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(names.isEmpty ? "none" : names.joined(separator: ", "))")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Replacement watch

    private var replacementPanel: some View {
        planningPanel("REPLACEMENT WATCH", icon: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SLOTS TO COVER")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                    if plan.positionsNeedingReplacements.isEmpty {
                        Text("No starting slots tracked.")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                    } else {
                        Text(plan.positionsNeedingReplacements.sorted().joined(separator: " · "))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Starting slots to cover: \(plan.positionsNeedingReplacements.sorted().joined(separator: ", "))")
                .accessibilityIdentifier("legends.planning.replacement.positions")

                VStack(alignment: .leading, spacing: 4) {
                    Text("UNSIGNED CANDIDATES")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                    if plan.unsignedReplacements.isEmpty {
                        Text("No unsigned replacement currently matches the signed squad. Open packs to find cover.")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                            .accessibilityIdentifier("legends.planning.replacement.empty")
                    } else {
                        ForEach(Array(plan.unsignedReplacements.prefix(8)), id: \.self) { name in
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill.questionmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(LegendsPalette.cyan)
                                Text(name)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(LegendsPalette.navy)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Suggested unsigned replacement: \(name)")
                            .accessibilityIdentifier("legends.planning.replacement.suggestion")
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.planning.replacement")
    }

    // MARK: - Age distribution

    private var agePanel: some View {
        planningPanel("AGE DISTRIBUTION", icon: "chart.bar.fill") {
            if plan.ageDistribution.isEmpty {
                Text("Sign players to build your first generation.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                    .accessibilityIdentifier("legends.planning.ages.empty")
            } else {
                let ages = plan.ageDistribution.sorted { $0.key < $1.key }
                let maxCount = ages.map(\.value).max() ?? 1
                VStack(spacing: 4) {
                    ForEach(ages, id: \.key) { age, count in
                            let plural = count == 1 ? "" : "s"
                        HStack(spacing: 8) {
                            Text("\(age)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(LegendsPalette.navy.opacity(0.75))
                                .frame(width: 22, alignment: .trailing)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(LegendsPalette.navy.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(ageBarColor(age))
                                        .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                                }
                            }
                            .frame(height: 8)
                            .accessibilityHidden(true)
                            Text("\(count)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(LegendsPalette.navy)
                                .frame(width: 18, alignment: .leading)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Age \(age): \(count) player\(plural)")
                        .accessibilityIdentifier("legends.planning.age.\(age)")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("legends.planning.ages")
            }
        }
    }

    private func ageBarColor(_ age: Int) -> Color {
        switch age {
        case ..<21: return LegendsPalette.green
        case 21...26: return LegendsPalette.cyan
        case 27...30: return LegendsPalette.blue
        default: return LegendsPalette.orange
        }
    }

    // MARK: - Empty squad

    private var emptySquadState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LegendsPalette.cyan)
                Text("NO SIGNED SQUAD YET")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
            }
            Text("Sign players from your collection and plan their careers here: age profile, career stages, retirement radar and replacement cover all update from your squad.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.72))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.cyan.opacity(0.25), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.planning.empty")
    }

    private func planningPanel<Content: View>(_ title: String, icon: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        LegendsDashboardPanel(title: title, icon: icon, color: LegendsPalette.cyan, content: content)
    }
}
