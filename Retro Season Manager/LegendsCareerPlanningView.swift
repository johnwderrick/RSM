import SwiftUI

struct LegendsCareerPlanningView: View {
    let store: LegendsStore
    let onBack: () -> Void
    private var plan: LegendsSquadCareerPlan { store.squadCareerPlan() }

    var body: some View {
        LegendsMenuShell(store: store, title: "CAREER PLANNING", subtitle: "PLAN THE NEXT GENERATION", icon: "chart.bar.xaxis", accent: LegendsPalette.cyan, onBack: onBack, currentNav: .planning) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    metrics
                    stagePanel
                    retirementPanel
                    replacementPanel
                    agePanel
                }
                .padding(16)
            }
        }
        .accessibilityIdentifier("legends.careerPlanning")
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            metric("XI AGE", plan.startingXIAverageAge.map(String.init) ?? "—")
            metric("SQUAD AGE", plan.signedAverageAge.map(String.init) ?? "—")
            metric("FINAL", "\(plan.finalSeasonCount)")
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(LegendsPalette.navy)
            Text(label).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.55))
        }.frame(maxWidth: .infinity).padding(12).background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var stagePanel: some View {
        planningPanel("CAREER STAGES", icon: "person.3.fill") {
            if plan.stageCounts.isEmpty { Text("No signed careers yet.").foregroundStyle(LegendsPalette.navy.opacity(0.6)) }
            else { ForEach(plan.stageCounts.keys.sorted(), id: \.self) { key in row(key, "\(plan.stageCounts[key] ?? 0)") } }
        }
    }

    private var retirementPanel: some View {
        planningPanel("RETIREMENT RADAR", icon: "hourglass") {
            row("NEXT SEASON", "\(plan.retiringNextSeason.count)")
            row("WITHIN 3 SEASONS", "\(plan.retiringWithinThreeSeasons.count)")
            if let warning = plan.warning { Text(warning).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.orange) }
            else { Text("No concentrated retirement warning.").font(.system(size: 10, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.6)) }
        }
    }

    private var replacementPanel: some View {
        planningPanel("REPLACEMENT WATCH", icon: "arrow.triangle.2.circlepath") {
            if plan.unsignedReplacements.isEmpty { Text("No unsigned replacement currently matches the signed squad.").font(.system(size: 10, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.6)) }
            else { ForEach(Array(plan.unsignedReplacements.prefix(8)), id: \.self) { Text($0).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(LegendsPalette.navy) } }
        }
    }

    private var agePanel: some View {
        planningPanel("AGE DISTRIBUTION", icon: "chart.bar.fill") {
            if plan.ageDistribution.isEmpty { Text("Sign players to build your first generation.").font(.system(size: 10, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.6)) }
            else { ForEach(plan.ageDistribution.keys.sorted(), id: \.self) { age in row("AGE \(age)", "\(plan.ageDistribution[age] ?? 0)") } }
        }
    }

    private func planningPanel<Content: View>(_ title: String, icon: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        LegendsDashboardPanel(title: title, icon: icon, color: LegendsPalette.cyan, content: content)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.65)); Spacer(); Text(value).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.navy) }
    }
}
