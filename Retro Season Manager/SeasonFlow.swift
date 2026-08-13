//
//  SeasonFlow.swift
//  Retro Season Manager
//
//  End-of-season and end-of-career summary screens.
//

import SwiftUI

// MARK: - Season review

struct SeasonReviewView: View {
    let store: GameStore

    var body: some View {
        ZStack {
            LinearGradient(colors: [Retro.background, Retro.panel, Retro.background],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Text("SEASON \(store.season) REVIEW")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)

                    if store.wasSacked { sackedBanner }

                    verdictPanel

                    HStack(alignment: .top, spacing: 14) {
                        standingsPanel
                        awardsPanel
                    }

                    teamOfTheSeasonPanel

                    if !store.pendingJobOffers.isEmpty { jobOffersPanel }

                    continueButton
                        .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private var verdictPanel: some View {
        let met = store.objectiveMet()
        return VStack(spacing: 8) {
            Text("🏆 CHAMPIONS: \(store.champion?.name ?? "—")")
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
            Text("\(store.userClub.name) finished \(ordinal(store.userPosition)) on \(store.userClub.points) pts")
                .font(.system(.callout, design: .monospaced).bold())
            Text(store.seasonVerdict())
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(met ? Retro.accent : Color(red: 0.95, green: 0.45, blue: 0.45))
            Text("Objective: \(store.boardObjective) — \(met ? "ACHIEVED ✓" : "MISSED ✗")")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(met ? Retro.accent : Color(red: 0.95, green: 0.45, blue: 0.45))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Retro.panel.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var standingsPanel: some View {
        Panel(title: "\(store.divisionName(store.userDivisionTier).uppercased()) — FINAL") {
            VStack(spacing: 3) {
                ForEach(Array(store.userTable().enumerated()), id: \.element.id) { index, club in
                    let isUser = club.id == store.userClub.id
                    HStack {
                        Text("\(index + 1)").frame(width: 22, alignment: .leading)
                        Text(club.shortName)
                        Spacer()
                        Text("\(club.points)")
                    }
                    .font(.system(.callout, design: .monospaced).weight(isUser ? .bold : .regular))
                    .foregroundStyle(isUser ? Retro.highlight : Retro.text)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var awardsPanel: some View {
        Panel(title: "AWARDS") {
            VStack(alignment: .leading, spacing: 10) {
                if let boot = store.goldenBoot() {
                    award("🥇 Golden Boot", "\(boot.player.name) (\(boot.club.shortName))", "\(boot.player.goals) goals")
                }
                if let pos = store.playerOfSeason() {
                    award("⭐ Your Player of the Season", pos.name,
                          pos.averageRating.map { String(format: "avg %.2f over %d apps", $0, pos.apps) } ?? "")
                }
                if let scorer = store.userTopScorer() {
                    award("🎯 Your Top Scorer", scorer.name, "\(scorer.goals) goals")
                }
                if let win = store.biggestUserWin() {
                    award("💥 Biggest Win", win, "")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func award(_ title: String, _ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            Text(name)
                .font(.system(.callout, design: .monospaced).bold())
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            }
        }
    }

    private var sackedBanner: some View {
        Text("⚠️ SACKED — you must accept a new job to continue")
            .font(.system(.callout, design: .monospaced).bold())
            .foregroundStyle(Retro.background)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(red: 0.9, green: 0.4, blue: 0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var jobOffersPanel: some View {
        Panel(title: store.wasSacked ? "JOB OFFERS (choose one)" : "JOB OFFERS") {
            VStack(spacing: 6) {
                ForEach(store.pendingJobOffers) { offer in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(offer.clubName)
                                .font(.system(.callout, design: .monospaced).bold())
                            Text("\(offer.divisionName) · prestige \(offer.prestige)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.8))
                            Text("Budget \(formatMoney(offer.transferBudget)) · \(offer.expectedObjective)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.highlight)
                        }
                        Spacer()
                        let accepted = store.pendingClubSwitch == offer.clubIndex
                        Button { store.acceptJobOffer(offer) } label: {
                            Text(accepted ? "ACCEPTED ✓" : "ACCEPT")
                                .font(.system(.caption, design: .monospaced).bold())
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(accepted ? Retro.highlight : Retro.accent)
                                .foregroundStyle(Retro.background)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !store.wasSacked {
                    Text("Ignore these to stay at \(store.userClub.name).")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var mustChooseJob: Bool { store.wasSacked && store.pendingClubSwitch == nil }

    @ViewBuilder
    private var continueButton: some View {
        Button {
            if store.isFinalSeason {
                store.endCareer()
            } else {
                store.runHeavy("Rolling into the new season…") {
                    store.startNextSeason()
                }
            }
        } label: {
            Text(store.isFinalSeason ? "VIEW CAREER SUMMARY ▸" : "CONTINUE TO SEASON \(store.season + 1) ▸")
                .font(.system(.body, design: .monospaced).bold())
                .padding(.horizontal, 26).padding(.vertical, 14)
                .background(mustChooseJob ? Retro.panel : Retro.accent)
                .foregroundStyle(mustChooseJob ? Retro.text.opacity(0.5) : Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(mustChooseJob)
    }

    private var teamOfTheSeasonPanel: some View {
        Panel(title: "TEAM OF THE SEASON") {
            let xi = store.teamOfTheSeason()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(xi) { player in
                    HStack(spacing: 6) {
                        Text(player.position.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Retro.highlight)
                            .frame(width: 30, alignment: .leading)
                        Text(surname(player.name))
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text("\(player.rating)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(Retro.accent)
                    }
                }
            }
        }
    }
}

// MARK: - Career end

struct CareerEndView: View {
    let store: GameStore
    @State private var showingOffice = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Retro.background, Retro.panel, Retro.background],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text("CAREER COMPLETE")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Text("\(store.history.count) season\(store.history.count == 1 ? "" : "s") managed · \(store.startYear) – \(store.startYear + store.history.count)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.85))
                    Text("Finished with \(store.userClub.name) in the \(store.divisionName(store.userDivisionTier))")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.highlight)

                    Panel(title: "\(store.managerName.uppercased()) — THE FULL STORY") {
                        Text(store.generateAutobiography())
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Retro.text)
                            .lineSpacing(5)
                    }
                    .frame(maxWidth: 560)

                    Panel(title: "CAREER HONOURS (\(store.careerHonours.count))") {
                        if store.careerHonours.isEmpty {
                            Text("No major honours — but a career to remember.")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.8))
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(store.careerHonours.enumerated()), id: \.offset) { _, honour in
                                    HonourRow(text: honour)
                                        .font(.system(.callout, design: .monospaced))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 560)

                    VStack(spacing: 10) {
                        Button {
                            Haptics.tap()
                            showingOffice = true
                        } label: {
                            Text("VIEW MANAGER OFFICE")
                                .font(.system(.body, design: .monospaced).bold())
                                .padding(.horizontal, 26).padding(.vertical, 14)
                                .background(Retro.highlight)
                                .foregroundStyle(Retro.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.returnToMenuAfterCareer()
                        } label: {
                            Text("BACK TO MAIN MENU")
                                .font(.system(.body, design: .monospaced).bold())
                                .padding(.horizontal, 26).padding(.vertical, 14)
                                .background(Retro.accent.opacity(0.2))
                                .foregroundStyle(Retro.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        Text("This career is archived permanently — find it under Legacy from the main menu.")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .sheet(isPresented: $showingOffice) {
            ManagerOfficeView(store: store)
        }
    }
}

