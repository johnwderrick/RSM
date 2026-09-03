import SwiftUI

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
        LegendsMenuShell(store: store, title: "TRAINING", subtitle: "INDIVIDUAL DEVELOPMENT",
                         icon: "figure.run.circle.fill", accent: LegendsPalette.green,
                         onBack: onBack, currentNav: .training, onNavigate: onNavigate,
                         scrollContent: false) {
            VStack(spacing: 10) {
                controls
                if cards.isEmpty {
                    Text("No signed active players match these filters.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.65))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 9) {
                            ForEach(cards) { card in trainingRow(card) }
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
            .padding(14)
        }
        .sheet(item: $selectedCard) { card in LegendsPlayerDetailView(store: store, card: card) }
        .accessibilityIdentifier("legends.training.screen")
    }

    private var controls: some View {
        VStack(spacing: 8) {
            TextField("SEARCH SIGNED PLAYERS", text: $search)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("legends.training.search")
            HStack(spacing: 8) {
                filterMenu("POSITION", selection: $position,
                           values: ["ALL"] + Position.allCases.map(\.rawValue), identifier: "position")
                filterMenu("STAGE", selection: $stage,
                           values: ["ALL", "PROSPECT", "DEVELOPING", "PRIME", "VETERAN", "DECLINING", "FINAL SEASON"], identifier: "stage")
                filterMenu("FOCUS", selection: $focus,
                           values: ["ALL"] + LegendsDevelopmentFocus.allCases.map(\.rawValue), identifier: "focus")
                Menu("SORT: \(sort.rawValue)") {
                    ForEach(TrainingSort.allCases) { option in Button(option.rawValue) { sort = option } }
                }
                .accessibilityIdentifier("legends.training.sort")
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
    }

    private func filterMenu(_ title: String, selection: Binding<String>, values: [String], identifier: String) -> some View {
        Menu("\(title): \(selection.wrappedValue)") {
            ForEach(values, id: \.self) { value in Button(value) { selection.wrappedValue = value } }
        }
        .accessibilityIdentifier("legends.training.filter.\(identifier)")
    }

    private func trainingRow(_ card: LegendsCard) -> some View {
        let career = store.careerState(for: card)
        let plan = career?.trainingPlan ?? LegendsTrainingPlan()
        let remaining = max(0, LegendsStore.maxTrainingSessionsPerSeason - (career?.trainingSessionsThisSeason ?? 0))
        return Button { selectedCard = card } label: {
            HStack(spacing: 12) {
                PlayerPortraitView(name: card.name, position: card.position.broad, nation: card.nation, size: 52)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(card.rarity.tint, lineWidth: 2))
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(card.name).font(.system(size: 13, weight: .black, design: .rounded))
                        Text("\(store.effectiveOverall(for: card)) OVR · AGE \(store.effectiveAge(for: card))")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    Text("\(plan.focus.rawValue) · \(plan.intensity.rawValue) · \(remaining) SESSIONS LEFT")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(remaining > 0 ? LegendsPalette.green : LegendsPalette.orange)
                        .accessibilityIdentifier("legends.training.sessions.\(card.id)")
                    ProgressView(value: Double(plan.seasonProgress % 100), total: 100)
                        .tint(LegendsPalette.green)
                        .accessibilityIdentifier("legends.training.progress.\(card.id)")
                    Text(plan.lastExplanation)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                if store.isFinalSeason(card) {
                    Text("FINAL\nSEASON").font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.orange).multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(LegendsPalette.navy)
            .padding(12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("legends.training.player.\(card.id)")
    }
}
