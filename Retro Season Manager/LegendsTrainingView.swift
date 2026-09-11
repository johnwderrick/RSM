import SwiftUI

/// The Legends development centre: a squad-level training summary, the
/// club's current training plan, and one scannable card per signed player.
/// Presentation only — every value comes from the existing career/training
/// models and all training actions stay in the player-detail flow.
struct LegendsTrainingView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    let onBack: () -> Void

    @State private var search = ""
    @State private var position = "ALL"
    @State private var stage = "ALL"
    @State private var focus = "ALL"
    @State private var sort: TrainingSort = .progress
    @State private var selectedCard: LegendsCard?

    private enum TrainingSort: String, CaseIterable, Identifiable {
        case progress = "PROGRESS"
        case age = "AGE"
        case overall = "OVR"
        case potential = "POTENTIAL"
        case availability = "SESSIONS"
        var id: String { rawValue }
    }

    private var cards: [LegendsCard] {
        let filtered = store.activeClubPlayers.filter { card in
            let plan = store.trainingPlan(for: card) ?? LegendsTrainingPlan()
            let matchesSearch = search.isEmpty || card.name.localizedCaseInsensitiveContains(search)
            let matchesPosition = position == "ALL" || card.position.broad.rawValue == position
            let matchesStage = stage == "ALL" || store.playerCareerStage(for: card) == stage
            let matchesFocus = focus == "ALL" || plan.focus.rawValue == focus
            return matchesSearch && matchesPosition && matchesStage && matchesFocus
        }
        return filtered.sorted { lhs, rhs in
            let left = store.careerState(for: lhs)
            let right = store.careerState(for: rhs)
            switch sort {
            case .progress: return (left?.trainingPlan.seasonProgress ?? 0) > (right?.trainingPlan.seasonProgress ?? 0)
            case .age: return store.effectiveAge(for: lhs) < store.effectiveAge(for: rhs)
            case .overall: return store.effectiveOverall(for: lhs) > store.effectiveOverall(for: rhs)
            case .potential: return (left?.potential ?? lhs.overall) > (right?.potential ?? rhs.overall)
            case .availability:
                return (left?.trainingSessionsThisSeason ?? 0) < (right?.trainingSessionsThisSeason ?? 0)
            }
        }
    }

    var body: some View {
        LegendsMenuShell(store: store, title: "TRAINING", subtitle: "DEVELOPMENT CENTRE",
                         icon: "figure.run.circle.fill", accent: LegendsPalette.green,
                         onBack: onBack, currentNav: .training, onNavigate: onNavigate,
                         scrollContent: false) {
            GeometryReader { geo in
                let wide = geo.size.width >= 860
                ScrollView(showsIndicators: false) {
                    Group {
                        if wide {
                            // Development centre: summary across the top, plan
                            // beside the squad of player cards.
                            VStack(spacing: 12) {
                                summaryBand
                                HStack(alignment: .top, spacing: 14) {
                                    trainingPlanPanel
                                        .frame(width: 300)
                                    VStack(spacing: 12) {
                                        controls
                                        playerList
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                summaryBand
                                trainingPlanPanel
                                controls
                                playerList
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .sheet(item: $selectedCard) { card in LegendsPlayerDetailView(store: store, card: card) }
        .accessibilityIdentifier("legends.training.screen")
    }

    // MARK: - Summary band

    /// Squad-level facts already tracked by the career model, so the state
    /// of the whole development group is readable at a glance.
    private var summaryBand: some View {
        let summary = store.trainingCentreSummary()
        return HStack(spacing: 8) {
            summaryStat(value: "\(summary.signedPlayers)",
                        label: "SIGNED",
                        color: LegendsPalette.green,
                        identifier: "legends.training.summary.signed")
            summaryStat(value: "\(summary.sessionsRemaining)",
                        label: "SESSIONS LEFT",
                        color: summary.sessionsRemaining > 0 ? LegendsPalette.blue : LegendsPalette.orange,
                        identifier: "legends.training.summary.sessions")
            summaryStat(value: "\(summary.playersAtSessionLimit)",
                        label: "AT LIMIT",
                        color: summary.playersAtSessionLimit > 0 ? LegendsPalette.orange : LegendsPalette.navy.opacity(0.4),
                        identifier: "legends.training.summary.atLimit")
            summaryStat(value: "\(summary.prospectsAndDeveloping)",
                        label: "DEVELOPING",
                        color: LegendsPalette.purple,
                        identifier: "legends.training.summary.prospects")
            if summary.finalSeasonPlayers > 0 {
                summaryStat(value: "\(summary.finalSeasonPlayers)",
                            label: "FINAL SEASON",
                            color: LegendsPalette.orange,
                            identifier: "legends.training.summary.finalSeason")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.green.opacity(0.22), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.training.summary")
    }

    private func summaryStat(value: String, label: String, color: Color, identifier: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.28), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label.lowercased())")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Training plan panel

    /// The club's current development emphasis, derived from what the
    /// squad's saved plans actually say — no new progression data.
    private var trainingPlanPanel: some View {
        let summary = store.trainingCentreSummary()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "clipboard.list").font(.system(size: 13, weight: .bold)).foregroundStyle(LegendsPalette.green)
                Text("TRAINING PLAN").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.navy)
            }
            planRow(title: "FOCUS MIX",
                    text: mixText(summary.focusCounts),
                    color: LegendsPalette.green,
                    identifier: "legends.training.plan.focus")
            planRow(title: "INTENSITY",
                    text: mixText(summary.intensityCounts),
                    color: LegendsPalette.blue,
                    identifier: "legends.training.plan.intensity")
            planRow(title: "SESSION ALLOWANCE",
                    text: summary.totalSessionAllowance == 0
                        ? "No signed players yet."
                        : "\(summary.sessionsRemaining) of \(summary.totalSessionAllowance) squad sessions remaining",
                    color: LegendsPalette.purple,
                    identifier: "legends.training.plan.allowance")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.green.opacity(0.22), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.training.plan")
    }

    /// "PASSING ×5 · BALANCED ×3" style summary of the saved plans.
    private func mixText<Key>(_ counts: [Key: Int]) -> String where Key: RawRepresentable, Key.RawValue == String {
        let parts = counts
            .sorted { $0.value > $1.value || ($0.value == $1.value && $0.key.rawValue < $1.key.rawValue) }
            .map { "\($0.key.rawValue) ×\($0.value)" }
        return parts.isEmpty ? "No plans yet." : parts.joined(separator: " · ")
    }

    private func planRow(title: String, text: String, color: Color, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(9)
        .background(LegendsPalette.contentBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.lowercased()): \(text)")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Players

    private var playerList: some View {
        // Plain VStack (not lazy): squads are small, and every row must be
        // present in the accessibility tree even when scrolled off-screen.
        VStack(spacing: 9) {
            if cards.isEmpty {
                Text("No signed active players match these filters.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.65))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .accessibilityIdentifier("legends.training.empty")
            } else {
                ForEach(cards) { card in trainingRow(card) }
            }
        }
    }
    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                TextField("SEARCH SIGNED PLAYERS", text: $search)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(LegendsPalette.navy.opacity(0.14), lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("legends.training.search")

            // Two fixed rows of filter pills: everything stays reachable on
            // compact landscape, and no lazy container hides the controls
            // from assistive tech.
            HStack(spacing: 8) {
                filterMenu("POSITION", selection: $position,
                           values: ["ALL"] + Position.allCases.map(\.rawValue), identifier: "position")
                filterMenu("STAGE", selection: $stage,
                           values: ["ALL", "PROSPECT", "DEVELOPING", "PRIME", "VETERAN", "DECLINING", "FINAL SEASON"], identifier: "stage")
            }
            HStack(spacing: 8) {
                filterMenu("FOCUS", selection: $focus,
                           values: ["ALL"] + LegendsDevelopmentFocus.allCases.map(\.rawValue), identifier: "focus")
                sortMenu
            }
        }
    }

    private func filterMenu(_ title: String, selection: Binding<String>, values: [String], identifier: String) -> some View {
        Menu {
            ForEach(values, id: \.self) { value in Button(value) { selection.wrappedValue = value } }
        } label: {
            filterLabel(title: title, value: selection.wrappedValue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) filter, currently \(selection.wrappedValue)")
        .accessibilityIdentifier("legends.training.filter.\(identifier)")
    }

    private var sortMenu: some View {
        Menu {
            ForEach(TrainingSort.allCases) { option in Button(option.rawValue) { sort = option } }
        } label: {
            filterLabel(title: "SORT", value: sort.rawValue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sort order, currently \(sort.rawValue)")
        .accessibilityIdentifier("legends.training.sort")
    }

    private func filterLabel(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
            Text(value)
                .foregroundStyle(LegendsPalette.navy)
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .black))
                .foregroundStyle(LegendsPalette.green)
        }
        .font(.system(size: 9, weight: .black, design: .monospaced))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(LegendsPalette.navy.opacity(0.14), lineWidth: 1))
    }

    private func trainingRow(_ card: LegendsCard) -> some View {
        let career = store.careerState(for: card)
        let plan = career?.trainingPlan ?? LegendsTrainingPlan()
        let remaining = max(0, LegendsStore.maxTrainingSessionsPerSeason - (career?.trainingSessionsThisSeason ?? 0))
        let stage = store.playerCareerStage(for: card)
        let atLimit = remaining == 0
        let finalSeason = store.isFinalSeason(card)
        return Button { selectedCard = card } label: {
            HStack(spacing: 12) {
                PlayerPortraitView(name: card.name, position: card.position.broad, nation: card.nation, size: 52)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(card.rarity.tint, lineWidth: 2))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(card.name)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        stageBadge(stage, finalSeason: finalSeason)
                        Spacer(minLength: 4)
                        Text("\(store.effectiveOverall(for: card)) OVR · AGE \(store.effectiveAge(for: card))")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(LegendsPalette.navy.opacity(0.78))
                    }
                    Text("\(card.position.rawValue) · \(plan.focus.rawValue) · \(plan.intensity.rawValue)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                    HStack(spacing: 8) {
                        Text(atLimit ? "SEASON LIMIT REACHED" : "\(remaining) SESSION\(remaining == 1 ? "" : "S") LEFT")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(atLimit ? LegendsPalette.orange : LegendsPalette.green)
                            .accessibilityIdentifier("legends.training.sessions.\(card.id)")
                        Text(store.potentialDescription(for: card))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                    }
                    ProgressView(value: Double(plan.seasonProgress % 100), total: 100)
                        .tint(atLimit ? LegendsPalette.orange : LegendsPalette.green)
                        .accessibilityIdentifier("legends.training.progress.\(card.id)")
                        .accessibilityLabel("Season progress \(plan.seasonProgress % 100) percent")
                    Text(plan.lastExplanation)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                        .lineLimit(2)
                }
            }
            .foregroundStyle(LegendsPalette.navy)
            .padding(12)
            .background(atLimit ? LegendsPalette.goldWash : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                atLimit ? LegendsPalette.orange.opacity(0.45) : LegendsPalette.navy.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("legends.training.player.\(card.id)")
        .accessibilityLabel(playerAccessibilityLabel(card: card, stage: stage, finalSeason: finalSeason,
                                                      plan: plan, remaining: remaining, atLimit: atLimit))
    }

    private func playerAccessibilityLabel(card: LegendsCard, stage: String, finalSeason: Bool,
                                          plan: LegendsTrainingPlan, remaining: Int, atLimit: Bool) -> String {
        let who = "\(card.name), \(card.position.rawValue), \(store.effectiveOverall(for: card)) overall, age \(store.effectiveAge(for: card))"
        let career = ", \(stage.lowercased())" + (finalSeason ? ", final season" : "")
        let sessionText = atLimit ? "season training limit reached" : "\(remaining) sessions left"
        return who + career + ", \(plan.focus.rawValue.lowercased()) focus, " + sessionText +
               ", season progress \(plan.seasonProgress % 100) percent"
    }

    /// Career stage as a small restrained badge. Colour is backed by the
    /// words in both the badge text and the row's accessibility label.
    private func stageBadge(_ stage: String, finalSeason: Bool) -> some View {
        let color: Color = {
            switch stage {
            case "PROSPECT", "DEVELOPING": return LegendsPalette.green
            case "PRIME", "VETERAN": return LegendsPalette.blue
            case "DECLINING", "FINAL SEASON": return LegendsPalette.orange
            default: return LegendsPalette.navy.opacity(0.5)
            }
        }()
        return Text(finalSeason ? "FINAL SEASON" : stage)
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
            .lineLimit(1)
    }
}
