//
//  SeasonFlow.swift
//  Retro Season Manager
//
//  End-of-season and end-of-career summary screens.
//

import SwiftUI

// MARK: - Season review

/// The season-end review, in the CareerPalette light-card style: pale
/// canvas, white cards, ink headings, green controls and restrained gold
/// for earned honours. One vertical scroll container; the season handoff
/// action sits in a pinned footer so it is always reachable.
struct SeasonReviewView: View {
    let store: GameStore

    /// The reserved outcome colour for missed objectives — a deep red with
    /// AA contrast on white cards (the old inline red sat below 2:1 on the
    /// old dark panels).
    static let verdictMiss = Color(red: 0.72, green: 0.16, blue: 0.12)

    /// A restrained, earned honour colour — deep enough for AA contrast on
    /// white cards, reserved for actual awards.
    static let honourGold = Color(red: 0.72, green: 0.55, blue: 0.10)

    var body: some View {
        ZStack {
            CareerPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Text("SEASON \(store.season) REVIEW")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(CareerPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if store.wasSacked { sackedBanner }

                    verdictPanel

                    HStack(alignment: .top, spacing: 14) {
                        standingsPanel
                        awardsPanel
                    }

                    teamOfTheSeasonPanel

                    if !store.pendingJobOffers.isEmpty { jobOffersPanel }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier(CareerIdentifiers.seasonReviewScroll)

            // Pinned footer — the season handoff stays reachable without
            // scrolling, whatever the content depth above it.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                continueFooter
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(CareerPalette.ink)
        .accessibilityIdentifier(CareerIdentifiers.seasonReviewScreen)
    }

    /// The always-visible season handoff footer.
    private var continueFooter: some View {
        VStack(spacing: 8) {
            if !store.wasSacked {
                Text(nextSeasonHint)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            continueButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background(CareerPalette.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CareerPalette.line.opacity(0.18))
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.seasonReviewFooter)
    }

    /// Where the handoff leads: the next season's label in the same
    /// division, or the final-season signpost to the career summary.
    private var nextSeasonHint: String {
        if store.isFinalSeason {
            return "\(store.seasonLabel) was the final season — the career summary awaits."
        }
        let start = (store.startYear - 1) + store.season + 1
        let label = "\(start)/\(String(format: "%02d", (start + 1) % 100))"
        return "NEXT UP · \(store.divisionName(store.userDivisionTier).uppercased()) · \(label)"
    }

    private var verdictPanel: some View {
        let met = store.objectiveMet()
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("🏆")
                    .font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHAMPIONS")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(CareerPalette.mutedInk)
                    Text(store.champion?.name ?? "—")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(CareerPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CareerPalette.line.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Champions: \(store.champion?.name ?? "none")")

            VStack(spacing: 6) {
                Text("\(store.userClub.name) finished \(ordinal(store.userPosition)) on \(store.userClub.points) pts")
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(store.seasonVerdict())
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(met ? CareerPalette.line : Self.verdictMiss)
                Text("Objective: \(store.boardObjective) — \(met ? "ACHIEVED ✓" : "MISSED ✗")")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(met ? CareerPalette.line : Self.verdictMiss)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.seasonReviewVerdict)
    }

    private var standingsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(store.divisionName(store.userDivisionTier).uppercased()) — FINAL")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(CareerPalette.ink)
            VStack(spacing: 0) {
                ForEach(Array(store.userTable().enumerated()), id: \.element.id) { index, club in
                    let isUser = club.id == store.userClub.id
                    HStack {
                        Text("\(index + 1)")
                            .frame(width: 22, alignment: .leading)
                            .foregroundStyle(CareerPalette.mutedInk)
                        Text(club.shortName)
                            .foregroundStyle(CareerPalette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(club.points)")
                            .foregroundStyle(isUser ? CareerPalette.line : CareerPalette.mutedInk)
                    }
                    .font(.system(.callout, design: .monospaced).weight(isUser ? .bold : .regular))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(isUser ? CareerPalette.line.opacity(0.10) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(ordinal(index + 1)): \(club.name), \(club.points) points")
                    .accessibilityIdentifier(CareerIdentifiers.seasonReviewStandingRow(index + 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.seasonReviewStandings)
    }

    private var awardsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AWARDS")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(CareerPalette.ink)
            VStack(alignment: .leading, spacing: 10) {
                if let boot = store.goldenBoot() {
                    award("🥇 Golden Boot", "\(boot.player.name) (\(boot.club.shortName))",
                          "\(boot.player.goals) goals", gold: true)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.seasonReviewAwards)
    }

    private func award(_ title: String, _ name: String, _ detail: String, gold: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(gold ? Self.honourGold : CareerPalette.mutedInk)
            Text(name)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(CareerPalette.ink)
                .lineLimit(1)
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sackedBanner: some View {
        Text("⚠️ SACKED — you must accept a new job to continue")
            .font(.system(.callout, design: .monospaced).bold())
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Self.verdictMiss)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var jobOffersPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.wasSacked ? "JOB OFFERS (choose one)" : "JOB OFFERS")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(CareerPalette.ink)
            VStack(spacing: 8) {
                ForEach(store.pendingJobOffers) { offer in
                    jobOfferRow(offer)
                }
            }
            if !store.wasSacked {
                Text("Ignore these to stay at \(store.userClub.name).")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.seasonReviewJobOffers)
    }

    private func jobOfferRow(_ offer: JobOffer) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.clubName)
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(1)
                Text("\(offer.divisionName) · prestige \(offer.prestige)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
                Text("Budget \(formatMoney(offer.transferBudget)) · \(offer.expectedObjective)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Button {
                Haptics.tap()
                store.acceptJobOffer(offer)
            } label: {
                Text(store.pendingClubSwitch == offer.clubIndex ? "ACCEPTED ✓" : "ACCEPT")
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 32)
                    .foregroundStyle(Color.white)
                    .background(store.pendingClubSwitch == offer.clubIndex ? Self.honourGold : CareerPalette.line)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Accept job offer from \(offer.clubName)")
        }
        .padding(8)
        .background(CareerPalette.line.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                .font(.system(.callout, design: .monospaced).bold())
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(Color.white)
                .background(mustChooseJob ? CareerPalette.mutedInk.opacity(0.35) : CareerPalette.line)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(mustChooseJob)
        .accessibilityIdentifier(CareerIdentifiers.seasonReviewContinue)
    }

    private var teamOfTheSeasonPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TEAM OF THE SEASON")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(CareerPalette.ink)
            let xi = store.teamOfTheSeason()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(xi) { player in
                    HStack(spacing: 6) {
                        Text(player.careerPositionLabel)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Self.honourGold)
                            .frame(width: 30, alignment: .leading)
                        Text(surname(player.name))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text("\(player.rating)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(CareerPalette.line)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(CareerPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Career end

struct CareerEndView: View {
    let store: GameStore
    @State private var showingOffice = false
    @State private var isLeavingCareer = false

    private var achievementKinds: [AchievementKind] {
        AchievementKind.allCases.filter { store.unlockedAchievements.contains($0) }
    }

    var body: some View {
        ZStack {
            CareerPalette.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        summaryCard
                        storyCard
                        honoursCard
                        achievementsCard
                        Color.clear.frame(height: 1)
                            .accessibilityIdentifier(CareerIdentifiers.careerEndEnd)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier(CareerIdentifiers.careerEndScroll)
                actionFooter
            }
        }
        .sheet(isPresented: $showingOffice) {
            ManagerOfficeView(store: store)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.square.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text("CAREER COMPLETE")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text(store.managerName)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text("\(store.history.count) season\(store.history.count == 1 ? "" : "s") · \(store.startYear)–\(store.startYear + store.history.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text("FINAL CLUB")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Text(store.userClub.name)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2).minimumScaleFactor(0.75)
                Text(store.divisionName(store.userDivisionTier))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.06), radius: 6, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.careerEndSummary)
        .accessibilityLabel("Career complete. \(store.managerName). \(store.history.count) seasons, \(store.startYear) to \(store.startYear + store.history.count). Final club \(store.userClub.name), \(store.divisionName(store.userDivisionTier)).")
    }

    private var storyCard: some View {
        card(title: "THE FULL STORY", icon: "book.closed.fill") {
            Text(store.generateAutobiography())
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(CareerPalette.ink.opacity(0.88))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier(CareerIdentifiers.careerEndStory)
    }

    private var honoursCard: some View {
        card(title: "CAREER HONOURS", icon: "trophy.fill", accessory: "\(store.careerHonours.count)") {
            if store.careerHonours.isEmpty {
                Text("No major honours — but a career to remember.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(CareerIdentifiers.careerEndHonoursEmpty)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(store.careerHonours.enumerated()), id: \.offset) { index, honour in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Retro.gold)
                                .padding(.top, 1)
                            Text(honour)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(CareerPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Earned honour: \(honour)")
                        .accessibilityIdentifier("\(CareerIdentifiers.careerEndHonours).\(index)")
                    }
                }
            }
        }
        .accessibilityIdentifier(CareerIdentifiers.careerEndHonours)
        .accessibilityLabel("Career honours. \(store.careerHonours.count) earned. \(store.careerHonours.joined(separator: ". "))")
    }

    private var achievementsCard: some View {
        card(title: "ACHIEVEMENTS", icon: "rosette", accessory: "\(achievementKinds.count) earned") {
            if achievementKinds.isEmpty {
                Text("No achievements earned in this career.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(CareerIdentifiers.careerEndAchievements).empty")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(achievementKinds, id: \.self) { kind in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(CareerPalette.line)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.rawValue)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(CareerPalette.ink)
                                if let unlock = store.achievementUnlocks[kind] {
                                    Text("Season \(unlock.season) · \(unlock.context)")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundStyle(CareerPalette.mutedInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Earned achievement: \(kind.rawValue)\(store.achievementUnlocks[kind].map { ", season \($0.season), \($0.context)" } ?? "")")
                        .accessibilityIdentifier(CareerIdentifiers.careerEndAchievement(kind))
                    }
                }
            }
        }
        .accessibilityIdentifier(CareerIdentifiers.careerEndAchievements)
        .accessibilityLabel("Achievements. \(achievementKinds.count) earned.")
    }

    private func card<Content: View>(title: String, icon: String, accessory: String? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
                if let accessory {
                    Text(accessory.uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.line)
                }
            }
            content()
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.06), radius: 6, y: 2)
        .accessibilityElement(children: .contain)
    }

    private var actionFooter: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                showingOffice = true
            } label: {
                Label("OFFICE", systemImage: "building.2.fill")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(CareerPalette.surface)
                    .foregroundStyle(CareerPalette.line)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.24)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View Manager Office")
            .accessibilityIdentifier(CareerIdentifiers.careerEndOffice)

            Button {
                guard !isLeavingCareer else { return }
                isLeavingCareer = true
                Haptics.tap()
                store.returnToMenuAfterCareer()
            } label: {
                HStack(spacing: 7) {
                    Text(isLeavingCareer ? "RETURNING…" : "MAIN MENU")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(CareerPalette.line)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isLeavingCareer)
            .accessibilityLabel(isLeavingCareer ? "Returning to main menu" : "Back to main menu and archive this career")
            .accessibilityIdentifier(CareerIdentifiers.careerEndMenu)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(CareerPalette.canvas.opacity(0.98))
        .overlay(alignment: .top) {
            Rectangle().fill(CareerPalette.line.opacity(0.16)).frame(height: 1)
        }
    }
}
