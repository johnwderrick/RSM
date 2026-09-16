//
//  LegendsPlayerDetailView.swift
//  Retro Season Manager
//
//  Player detail (redesigned): one stable scroll container in the accepted
//  Squad/Division/Training/Packs light-card language — white cards on the
//  light content background, navy headings, restrained green/orange/gold
//  accents, monospaced digits. Every fact shown is read from the
//  authoritative store/card data (identity profile, career state, condition,
//  duplicates, Hall entry); nothing here mutates progression except through
//  the pre-existing store calls (sign, favourite, compare, training focus/
//  intensity/session, squad assignment). The close control is pinned so it
//  stays reachable while the content scrolls.
//

import SwiftUI

struct LegendsPlayerDetailView: View {
    let store: LegendsStore
    let card: LegendsCard
    var moveToReservesAction: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingSign = false
    @State private var showingWelcome = false
    @State private var showingComparison = false

    // MARK: - Authoritative state (view-only reads)

    private var owned: Bool { store.profile.ownedCardIDs.contains(card.id) }
    private var lifecycleState: LegendsOwnedPlayerState { store.ownedPlayerState(for: card) }
    private var retired: Bool { owned && store.isRetired(card) }
    private var signed: Bool { owned && store.isSigned(card) }
    private var effectiveOverall: Int { store.effectiveOverall(for: card) }
    private var age: Int { store.effectiveAge(for: card) }
    private var career: LegendsPlayerCareer? { store.careerState(for: card) }
    private var status: LegendsStore.LegendsPlayerStatus? { signed ? store.playerStatus(for: card) : nil }
    private var event: LegendsStore.LegendsDevelopmentEvent? { signed ? store.developmentEvent(for: card) : nil }
    private var assignment: LegendsSquadAssignment { store.assignment(for: card) }
    private var favourite: Bool { store.isFavourite(card.id) }
    private var finalSeason: Bool { store.isFinalSeason(card) }
    private var identity: LegendsPlayerIdentity { store.identityProfile(for: card).identity }
    private var duplicateProgress: Int { store.profile.duplicateProgress[card.id] ?? 0 }
    private var upgrades: Int { store.profile.cardUpgrades[card.id] ?? 0 }
    private var isExactDuplicate: Bool { owned && store.isExactDuplicate(card) }
    private var hallEntry: LegendsHallEntry? {
        store.profile.legendsHall.last { $0.cardID == card.id }
    }
    private var records: [(LegendsClubRecordKind, LegendsClubRecordEntry)] {
        store.profile.clubRecords
            .filter { $0.value.playerName == card.name }
            .sorted { $0.key.rawValue < $1.key.rawValue }
    }

    /// Detailed-attribute groups this card presents. Outfielders have no
    /// meaningful goalkeeping ratings (all zeros), so the group is hidden
    /// for them; goalkeepers get their specialist group first.
    private var attributeGroups: [LegendsAttributeGroup] {
        card.position.broad == .goalkeeper
            ? [.goalkeeping, .technical, .mental, .physical]
            : [.technical, .mental, .physical]
    }

    var body: some View {
        ZStack(alignment: .top) {
            LegendsPalette.contentBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    heroHeader
                    actionBar
                    biographyCard
                    if retired {
                        careerCompleteSection
                    } else if signed {
                        if showingWelcome { welcomeCard }
                        statusCard
                        if finalSeason { finalSeasonBanner }
                        developmentCard
                        attributesSection
                        careerCard
                        achievementsCard
                    } else if owned {
                        unsignedCard
                        duplicateCard
                    } else {
                        notOwnedCard
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 52)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            pinnedClose
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.playerDetail")
        .alert("BEGIN CAREER?", isPresented: $confirmingSign) {
            Button("NOT YET", role: .cancel) { }
            Button("SIGN PLAYER") {
                guard store.signPlayer(cardID: card.id) else { return }
                Haptics.success()
                showingWelcome = true
            }
        } message: {
            Text("Once signed, \(card.name) will begin ageing, development and career statistics. This cannot normally be reversed.")
        }
    }

    // MARK: - Pinned close

    /// Stays pinned above the scroll container so the way out is always
    /// reachable, including on compact landscape screens mid-scroll.
    private var pinnedClose: some View {
        HStack {
            Spacer()
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(LegendsPalette.navy.opacity(0.92))
                    .clipShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Close player details")
            .accessibilityIdentifier("legends.playerDetail.close")
            .padding(.trailing, 14)
            .padding(.top, 10)
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                PlayerPortraitView(name: card.name, position: card.position.broad, nation: card.nation, size: 76)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(card.rarity.tint, lineWidth: 3))
                    .accessibilityIdentifier("legends.playerDetail.portrait")

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(owned ? "\(effectiveOverall)" : "??")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(owned ? LegendsPalette.navy : LegendsPalette.navy.opacity(0.4))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("OVR").font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                            Text(card.position.rawValue)
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(card.rarity.tint.opacity(owned ? 1 : 0.4))
                                .clipShape(Capsule())
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("OVR \(owned ? effectiveOverall : 0), position \(card.position.rawValue)")
                    .accessibilityIdentifier("legends.playerDetail.ovr")

                    Text(card.name)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text("\(card.rarity.rawValue.uppercased()) · \(card.era.rawValue.uppercased())")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(card.rarity.tint)
                    HStack(spacing: 5) {
                        FlagView(nationality: card.nation, width: 14)
                            .accessibilityIdentifier("legends.playerDetail.flag")
                        Text(card.nation)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.72))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Nationality \(card.nation)")
                    .accessibilityIdentifier("legends.playerDetail.nationality")
                }
                Spacer(minLength: 0)
            }

            statusCapsule

            Text(signed ? "AGE \(age) · CAREER AGE" : "AGE \(card.age) · AGE FROZEN UNTIL SIGNED")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(card.rarity.tint.opacity(0.30), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
    }

    private var statusCapsule: some View {
        HStack(spacing: 6) {
            Text(lifecycleHeadline)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(lifecycleTint)
                .clipShape(Capsule())
            if favourite {
                Label("FAVOURITED", systemImage: "star.fill")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.goldDeep)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(LegendsPalette.goldWash)
                    .clipShape(Capsule())
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status \(lifecycleHeadline)\(favourite ? ", favourited" : "")")
        .accessibilityIdentifier("legends.playerDetail.status")
    }

    private var lifecycleHeadline: String {
        if retired { return "RETIRED · CAREER COMPLETE" }
        if !owned { return "NOT OWNED" }
        if !signed { return "UNSIGNED" }
        return assignment.rawValue
    }

    private var lifecycleTint: Color {
        if retired { return LegendsPalette.goldDeep }
        if !owned || !signed { return LegendsPalette.blue }
        switch assignment {
        case .startingXI: return LegendsPalette.green
        case .bench: return LegendsPalette.purple
        case .reserves: return LegendsPalette.cyan
        }
    }

    // MARK: - Actions

    private var actionBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if owned && !retired {
                    actionButton(label: favourite ? "FAVOURITED" : "FAVOURITE",
                                 icon: favourite ? "star.fill" : "star",
                                 tint: LegendsPalette.goldDeep, filled: favourite) {
                        store.toggleFavourite(cardID: card.id)
                    }
                    .accessibilityIdentifier("legends.player.favourite")
                }
                actionButton(label: "COMPARE", icon: "rectangle.split.2x1", tint: LegendsPalette.blue, filled: false) {
                    showingComparison = true
                }
                .accessibilityIdentifier("legends.player.compare")
            }
            if let moveToReservesAction {
                actionButton(label: "MOVE TO RESERVES", icon: "person.2.fill",
                             tint: LegendsPalette.orange, filled: false) {
                    moveToReservesAction()
                    dismiss()
                }
                .accessibilityIdentifier("legends.playerDetail.moveToReserves")
            }
        }
        .sheet(isPresented: $showingComparison) {
            LegendsPlayerComparisonView(store: store, primary: card)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.playerDetail.actions")
    }

    private func actionButton(label: String, icon: String, tint: Color, filled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Label(label, systemImage: icon)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(filled ? .white : tint)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(filled ? tint : tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(tint.opacity(filled ? 0 : 0.35), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Biography

    private var biographyCard: some View {
        detailCard("BIOGRAPHY", identifier: "legends.playerDetail.biography") {
            bioRow("NAME", card.name)
            bioRow("NATIONALITY", card.nation, identifier: "legends.playerDetail.nationalityRow", leading: {
                FlagView(nationality: card.nation, width: 13)
            })
            bioRow("POSITION", "\(card.position.rawValue) · \(card.position.fullName)")
            bioRow("ERA / SEASON", "\(card.era.rawValue) · \(card.season)")
            bioRow("CLUB", card.club)
            bioRow("RARITY", card.rarity.rawValue.uppercased())
            bioRow("PREFERRED FOOT", identity.preferredFoot.rawValue)
            bioRow("ARCHETYPE", identity.archetype.rawValue)
            Divider()
            Text(identity.biography)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Career status

    private var statusCard: some View {
        detailCard("CAREER STATUS", identifier: "legends.playerDetail.statusCard") {
            if let status {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CAREER STAGE · \(status.rawValue)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(stageTint(status))
                    Text("SEASON \(store.profile.currentSeason) AT THE CLUB · SIGNED SEASON \(career?.signedSeason ?? store.profile.currentSeason)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(stageTint(status).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("legends.playerDetail.careerStage")
            }
            statRow("SQUAD STATUS", assignment.rawValue, valueID: "legends.playerDetail.squadStatus")
            statRow("AVAILABILITY", retired ? "UNAVAILABLE · RETIRED" : (signed ? "AVAILABLE FOR SELECTION" : "NOT SIGNED"))
            statRow("TRAINING SESSIONS", career.map { "\($0.trainingSessionsThisSeason)/\(LegendsStore.maxTrainingSessionsPerSeason) THIS SEASON" } ?? "—")
            statRow("TRAINING FOCUS", career?.trainingPlan.focus.rawValue ?? "—")
            statRow("INTENSITY", career?.trainingPlan.intensity.rawValue ?? "—")
            if signed, let condition = conditionValues {
                Divider()
                HStack(spacing: 8) {
                    conditionStat("FORM", condition.form)
                    conditionStat("MORALE", condition.morale)
                    conditionStat("TEAMWORK", condition.teamwork)
                    conditionStat("FAME", condition.fame)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Condition: form \(condition.form), morale \(condition.morale), teamwork \(condition.teamwork), fame \(condition.fame)")
                .accessibilityIdentifier("legends.playerDetail.condition")
                Text("Condition provides only a modest effective-attribute adjustment; base card ratings never change.")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            }
            Divider()
            seasonOutput
        }
    }

    /// Season and career output — only the numbers the authoritative
    /// career record actually tracks, with a clean dash treatment when a
    /// signed career has not recorded anything yet.
    private var seasonOutput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THIS SEASON")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            HStack(spacing: 8) {
                outputStat("APPS", career?.seasonAppearances)
                outputStat("GOALS", career?.seasonGoals)
                outputStat("ASSISTS", career?.seasonAssists)
                outputStat("CLEAN SHEETS", career?.seasonCleanSheets)
            }
            Text("CAREER TOTAL")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            HStack(spacing: 8) {
                outputStat("APPS", career?.appearances)
                outputStat("GOALS", career?.goals)
                outputStat("ASSISTS", career?.assists)
                outputStat("CLEAN SHEETS", career?.cleanSheets)
            }
            statRow("MINUTES", career.map { "\($0.minutesPlayed)" } ?? "—")
            statRow("HIGHEST OVR", career.map { "\($0.highestOverall)" } ?? "—")
        }
    }

    private var conditionValues: LegendsPlayerCondition? {
        signed ? store.condition(for: card) : nil
    }

    private func conditionStat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy)
            Text(label)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(LegendsPalette.contentBackground.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func outputStat(_ label: String, _ value: Int?) -> some View {
        VStack(spacing: 2) {
            Text(value.map(String.init) ?? "—")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(value == nil ? LegendsPalette.navy.opacity(0.35) : LegendsPalette.navy)
            Text(label)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(LegendsPalette.contentBackground.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func stageTint(_ status: LegendsStore.LegendsPlayerStatus) -> Color {
        let t = status.tint
        return Color(red: t.red, green: t.green, blue: t.blue)
    }

    private var finalSeasonBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .black))
            Text("FINAL SEASON — RETIRES AT THE END OF THIS SEASON")
                .font(.system(size: 9, weight: .black, design: .monospaced))
        }
        .foregroundStyle(LegendsPalette.orange)
        .frame(maxWidth: .infinity)
        .padding(9)
        .background(LegendsPalette.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(LegendsPalette.orange.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.playerDetail.finalSeason")
    }

    // MARK: - Development

    private var developmentCard: some View {
        detailCard("DEVELOPMENT", identifier: "legends.playerDetail.development") {
            if let career {
                if let event {
                    Text(event.rawValue)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(event.multiplier > 1 ? LegendsPalette.green
                                         : (event.multiplier < 1 ? LegendsPalette.orange : LegendsPalette.navy))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                statRow("DEVELOPMENT PROFILE", store.potentialLabel(for: card))
                statRow("SCOUTING", store.scoutingReport(for: card))
                statRow("OVR BREAKDOWN", ovrBreakdown)
                HStack(spacing: 8) {
                    Menu {
                        ForEach(store.availableDevelopmentFocuses(for: card)) { option in
                            Button(option.rawValue) { store.setDevelopmentFocus(option, for: card.id) }
                        }
                    } label: {
                        Label("FOCUS · \(career.trainingPlan.focus.rawValue)", systemImage: "target")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .accessibilityIdentifier("legends.training.focusPicker")
                    Menu {
                        ForEach(LegendsTrainingIntensity.allCases) { option in
                            Button(option.rawValue) { store.setTrainingIntensity(option, for: card.id) }
                        }
                    } label: {
                        Label("INTENSITY · \(career.trainingPlan.intensity.rawValue)", systemImage: "gauge")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .accessibilityIdentifier("legends.training.intensityPicker")
                }
                .foregroundStyle(LegendsPalette.navy)
                Button {
                    if store.trainPlayer(card.id) { Haptics.success() }
                    else { Haptics.error() }
                } label: {
                    Text(career.trainingSessionsThisSeason < LegendsStore.maxTrainingSessionsPerSeason
                         ? "START TRAINING SESSION" : "SEASONAL SESSIONS COMPLETE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PressableButtonStyle())
                .foregroundStyle(.white)
                .background(career.trainingSessionsThisSeason < LegendsStore.maxTrainingSessionsPerSeason
                            ? LegendsPalette.green : LegendsPalette.navy.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .disabled(career.trainingSessionsThisSeason >= LegendsStore.maxTrainingSessionsPerSeason)
                .accessibilityIdentifier("legends.training.start")
                VStack(alignment: .leading, spacing: 3) {
                    Text("SEASONAL PROGRESS")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                    LegendsProgressBar(value: Double(career.trainingPlan.seasonProgress % 100) / 100,
                                       tint: LegendsPalette.green, height: 7)
                        .accessibilityIdentifier("legends.training.playerProgress")
                }
                Text(career.trainingPlan.lastExplanation)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                if !career.trainingPlan.recentAttributeGains.isEmpty {
                    Text(career.trainingPlan.recentAttributeGains.keys.sorted().map {
                        "\($0) +\(career.trainingPlan.recentAttributeGains[$0] ?? 0)"
                    }.joined(separator: " · "))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.green)
                }
                Text("Young players develop through matches and training; minutes matter. Players past their peak decline instead.")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                if !career.trainingPlan.history.isEmpty {
                    Divider()
                    ForEach(career.trainingPlan.history.suffix(3).reversed()) { record in
                        Text("S\(record.season) · \(record.focus.rawValue) · +\(record.progress) progress")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.65))
                    }
                }
            } else {
                Text("Career record not started yet — development begins when the player is signed.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
            }
        }
    }

    private var ovrBreakdown: String {
        var parts: [String] = ["Base \(card.overall)"]
        let level = upgrades
        if level > 0 { parts.append("+ \(level) upgrade\(level == 1 ? "" : "s")") }
        let aging = store.agingPenalty(for: card)
        if aging > 0 { parts.append("− \(aging) aging") }
        let form = store.formBoost(for: card)
        if form > 0 { parts.append("+ \(form) form") }
        return parts.joined(separator: " ") + " = \(effectiveOverall)"
    }

    // MARK: - Attributes

    private var attributesSection: some View {
        VStack(spacing: 12) {
            detailCard("ATTRIBUTES", identifier: "legends.playerDetail.attributes") {
                Text(ovrBreakdown)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                ForEach([("PAC", card.pace), ("SHO", card.shooting), ("PAS", card.passing),
                         ("DRI", card.dribbling), ("DEF", card.defending), ("PHY", card.physical)],
                        id: \.0) { metric in
                    attributeBar(metric.0, metric.1, tint: card.rarity.tint)
                }
                Text("Headline ratings are the card's fixed base ratings; the OVR total above reflects upgrades, aging and form.")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.55))
            }
            detailCard("DETAILED ATTRIBUTES", identifier: "legends.playerDetail.detailedAttributes") {
                ForEach(attributeGroups, id: \.self) { group in
                    Text(group.rawValue)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(group == .goalkeeping ? LegendsPalette.blue : card.rarity.tint)
                        .padding(.top, 2)
                        .accessibilityIdentifier("legends.playerDetail.attributes.\(group.rawValue.lowercased())")
                    ForEach(store.effectiveDetailedAttributes(for: card).values(in: group), id: \.0) { item in
                        attributeBar(item.0, item.1, tint: group == .goalkeeping ? LegendsPalette.blue : card.rarity.tint, compact: true)
                    }
                }
            }
        }
    }

    // MARK: - Career history & achievements

    private var careerCard: some View {
        detailCard("CAREER HISTORY", identifier: "legends.playerDetail.careerHistory") {
            if let career {
                statRow("CLUB LEGEND", career.isClubLegend ? "YES" : "—")
                if !career.seasonRecords.isEmpty {
                    Divider()
                    Text("SEASON-BY-SEASON")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.blue)
                    ForEach(Array(career.seasonRecords.reversed()), id: \.season) { record in
                        HStack(spacing: 8) {
                            Text("S\(record.season)")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(LegendsPalette.navy.opacity(0.8))
                                .frame(width: 28, alignment: .leading)
                            Text("AGE \(record.age)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                            Text("\(record.appearances) APP")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                            Text("\(record.goals) G · \(record.assists) A")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                            Spacer()
                            Text("\(record.overallAtStart) → \(record.overallAtEnd)")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(record.overallAtEnd > record.overallAtStart ? LegendsPalette.green
                                                 : (record.overallAtEnd < record.overallAtStart ? LegendsPalette.orange : LegendsPalette.goldDeep))
                        }
                    }
                } else {
                    Text("No completed seasons yet — the first season-by-season entry appears after the season rolls over.")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                }
            } else {
                Text("No career history yet.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
            }
        }
    }

    private var achievementsCard: some View {
        detailCard("ACHIEVEMENTS", identifier: "legends.playerDetail.achievements") {
            if let career, !career.milestones.isEmpty {
                ForEach(Array(career.milestones), id: \.self) { milestone in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(milestone == .clubLegend ? LegendsPalette.goldDeep : LegendsPalette.green)
                        Text(milestone.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.9))
                    }
                }
            } else {
                Text("No milestones yet — milestones unlock for appearances, goals and trophies.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
            }
            if !records.isEmpty {
                Divider()
                Text("CLUB RECORDS")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.goldDeep)
                ForEach(records, id: \.0) { kind, record in
                    HStack {
                        Image(systemName: kind.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(LegendsPalette.goldDeep)
                        Text(kind.displayName)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.85))
                        Spacer()
                        Text("\(record.value)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(LegendsPalette.green)
                    }
                }
            }
        }
    }

    // MARK: - Unsigned / not-owned / retired states

    private var unsignedCard: some View {
        VStack(spacing: 8) {
            Text("SIGN THIS PLAYER TO BEGIN TRAINING AND CAREER DEVELOPMENT")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.green)
                .multilineTextAlignment(.center)
            Text("Age frozen at \(card.age). Signing starts this player's career clock and makes them eligible for the Active Club.")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.72))
                .multilineTextAlignment(.center)
            Button {
                confirmingSign = true
            } label: {
                Text("SIGN PLAYER")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(PressableButtonStyle())
            .background(LegendsPalette.green)
            .clipShape(Capsule())
            .accessibilityIdentifier("legends.playerDetail.sign")
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.green.opacity(0.35), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("legends.playerDetail.unsigned")
    }

    /// Duplicate upgrade progress — shown only when the player actually has
    /// duplicate activity or upgrades, using the authoritative counters.
    private var duplicateCard: some View {
        let active = isExactDuplicate || duplicateProgress > 0 || upgrades > 0
        return Group {
            if active {
                detailCard("DUPLICATE UPGRADES", identifier: "legends.playerDetail.duplicate") {
                    HStack {
                        Text("PROGRESS TO NEXT UPGRADE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                        Spacer()
                        Text("\(duplicateProgress)/\(LegendsStore.duplicatesPerUpgrade)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(LegendsPalette.orange)
                    }
                    LegendsProgressBar(value: Double(duplicateProgress) / Double(LegendsStore.duplicatesPerUpgrade),
                                       tint: LegendsPalette.orange, height: 7)
                        .accessibilityIdentifier("legends.playerDetail.duplicateBar")
                    statRow("UPGRADES APPLIED", "\(upgrades)/\(LegendsStore.maxCardUpgrade)")
                    Text(isExactDuplicate
                         ? "An exact duplicate of this card is owned — pulling another moves this bar."
                         : "Pull the same player from a pack to advance this bar; every full bar grants +1 OVR.")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                EmptyView()
            }
        }
    }

    private var welcomeCard: some View {
        detailCard("WELCOME TO THE CLUB", identifier: "legends.playerDetail.welcome") {
            Text("\(card.name) · CAREER BEGINS AT AGE \(store.effectiveAge(for: card))")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.green)
            Text("The player is now ACTIVE. Add them to matchday from Squad, or leave them in Reserves while their career continues.")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.72))
                .multilineTextAlignment(.center)
        }
    }

    private var notOwnedCard: some View {
        detailCard("NOT YET OWNED", identifier: "legends.playerDetail.notOwned") {
            Text("Open packs to add this card to your collection.")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var careerCompleteSection: some View {
        VStack(spacing: 12) {
            if let entry = hallEntry {
                detailCard("LEGENDS HALL — CAREER COMPLETE", identifier: "legends.playerDetail.hall") {
                    hallRow("Career", "S\(entry.signedSeason)–S\(entry.retiredSeason) · \(entry.seasonsAtClub) seasons")
                    hallRow("Appearances", "\(entry.appearances)")
                    hallRow("Goals / Assists", "\(entry.goals) / \(entry.assists)")
                    hallRow("Clean sheets", "\(entry.cleanSheets)")
                    hallRow("Peak OVR", "\(entry.highestOverall)")
                    hallRow("Trophies", "\(entry.trophies)")
                    hallRow("Legacy Score", "\(entry.legacyScore)")
                    if entry.isClubLegend {
                        Text("★ CLUB LEGEND ★")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.goldDeep)
                            .frame(maxWidth: .infinity)
                    }
                    if !entry.careerHistory.isEmpty { seasonHistory(entry.careerHistory) }
                    if !entry.milestones.isEmpty {
                        ForEach(Array(entry.milestones), id: \.self) { milestone in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(milestone == .clubLegend ? LegendsPalette.goldDeep : LegendsPalette.green)
                                Text(milestone.rawValue)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(LegendsPalette.navy.opacity(0.9))
                            }
                        }
                    }
                }
            } else {
                detailCard("CAREER COMPLETE", identifier: "legends.playerDetail.hall") {
                    Text("This player has retired and is remembered in the Legends Hall.")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(LegendsPalette.orange)
                }
            }
        }
    }

    private func seasonHistory(_ records: [LegendsSeasonRecord]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SEASON-BY-SEASON")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.blue)
            ForEach(Array(records.reversed()), id: \.season) { record in
                HStack(spacing: 8) {
                    Text("S\(record.season)")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.8))
                        .frame(width: 28, alignment: .leading)
                    Text("AGE \(record.age)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                    Text("\(record.appearances) APP")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                    Spacer()
                    Text("\(record.overallAtStart) → \(record.overallAtEnd)")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(record.overallAtEnd > record.overallAtStart ? LegendsPalette.green
                                         : (record.overallAtEnd < record.overallAtStart ? LegendsPalette.orange : LegendsPalette.goldDeep))
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Building blocks

    private func detailCard<Content: View>(_ title: String, identifier: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.62))
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LegendsPalette.navy.opacity(0.10), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func statRow(_ label: String, _ value: String, valueID: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(valueID ?? "")
        }
    }

    private func bioRow(_ label: String, _ value: String, identifier: String? = nil,
                        @ViewBuilder leading: () -> some View = { EmptyView() }) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                .frame(minWidth: 92, alignment: .leading)
            leading()
            Text(value)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? "")
    }

    private func hallRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.65))
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy)
        }
    }

    private func attributeBar(_ label: String, _ value: Int, tint: Color, compact: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: compact ? 7 : 8, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.72))
                .frame(width: compact ? 82 : 30, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LegendsPalette.navy.opacity(0.10))
                    Capsule().fill(tint.opacity(0.85))
                        .frame(width: geo.size.width * CGFloat(min(value, 99)) / 99)
                }
            }
            .frame(height: compact ? 6 : 8)
            Text("\(value)")
                .font(.system(size: compact ? 8 : 10, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LegendsPalette.navy)
                .frame(width: 24, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}
