//
//  ContentView.swift
//  Retro Season Manager
//
//  Old-school, text-driven football manager. Pick a club, set your
//  formation, play through the season and chase the title.
//

import SwiftUI

struct ContentView: View {
    @State private var store = GameStore()
    @State private var legendsStore = LegendsStore()
    @State private var experience: GameExperience? = nil

    init() {
        let legends = LegendsStore()
        #if DEBUG
        // Lets the manager-onboarding UI test re-run against an already
        // onboarded simulator install without needing a full app
        // uninstall/reinstall between runs. Must reset this specific
        // instance (not just the on-disk file) — `legends` has already
        // loaded whatever was on disk by the time this init body runs.
        if ProcessInfo.processInfo.arguments.contains("UITEST_RESET_LEGENDS_MANAGER") {
            legends.resetManagerOnboardingForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_TRAINING") {
            legends.prepareTrainingFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_MATCH_READY") {
            legends.prepareMatchReadyFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_DIVISION") {
            legends.prepareDivisionFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_PACKS") {
            legends.preparePacksFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_TRAINING_CENTRE") {
            legends.prepareTrainingCentreFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_CLUB_FACILITIES") {
            legends.prepareFacilitiesFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_CLUB_COLLECTION") {
            legends.prepareCollectionFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_PLAYERS") {
            legends.preparePlayersFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_PLAYER_DETAIL") {
            legends.preparePlayerDetailFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_SQUAD_RESERVES") {
            legends.prepareReservesFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_SQUAD_RESERVES_EMPTY") {
            legends.prepareReservesFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_HALL") {
            legends.prepareHallFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_CHALLENGES") {
            legends.prepareChallengesFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_PLANNING_REPORTS") {
            legends.preparePlanningReportsFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_MANAGER_EDIT") {
            legends.prepareManagerEditFixtureForDebug()
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGENDS_SETTINGS") {
            legends.prepareSettingsFixtureForDebug()
        }
        #endif
        _legendsStore = State(initialValue: legends)

        #if DEBUG
        // Deterministic Career navigation fixture: boots straight into an
        // active, saved career with stable injuries and inbox content
        // (see GameStore+UITestFixture.swift).
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_NAVIGATION") {
            let career = GameStore()
            career.prepareCareerNavigationFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SCOUT") {
            let career = GameStore()
            career.prepareCareerScoutFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_TRANSFERS") {
            let career = GameStore()
            career.prepareCareerTransfersFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SETTINGS") {
            let career = GameStore()
            career.prepareCareerSettingsFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SHEETS") {
            let career = GameStore()
            career.prepareCareerSheetsFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SUPPORTER") {
            let career = GameStore()
            career.prepareCareerSupporterFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_FACILITIES") {
            let career = GameStore()
            career.prepareCareerFacilitiesFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_OFFICE") {
            let career = GameStore()
            career.prepareCareerOfficeFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        // The transfers fixture re-asserts its shortlist against the
        // current market's target IDs on every launch — the persisted
        // entry can't survive a relaunch (see the fixture's doc comment).
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_TRANSFERS") {
            store.ensureTransfersFixtureStateForDebug()
        }
        #endif
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            if let live = store.live {
                MatchView(store: store, live: live)
            } else if store.atPreMatch {
                PreMatchHubView(store: store)
            } else if store.careerEnded {
                CareerEndView(store: store)
            } else if store.hasStarted && store.isSeasonOver {
                SeasonReviewView(store: store)
            } else if store.hasStarted {
                MainGameView(store: store)
            } else if experience == .legends {
                if legendsStore.profile.managerProfile == nil {
                    LegendsManagerOnboardingView(store: legendsStore) {
                        // The profile is persisted by the onboarding flow;
                        // the surrounding view re-evaluates into the dashboard.
                    }
                } else {
                    LegendsHomeView(store: legendsStore) { experience = nil }
                }
            } else if experience == .career {
                MainMenuView(store: store, onSwitchExperience: { experience = nil })
            } else {
                ExperienceSelectView(experience: $experience)
            }
            if store.isBusy {
                LoadingOverlay(message: store.busyMessage)
            }
            if let kind = store.pendingAchievementCelebration {
                AchievementUnlockOverlay(store: store, kind: kind)
                    .transition(.opacity)
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(store.hasStarted ? store.userColor : Retro.accent)
        .animation(.easeInOut(duration: 0.2), value: store.isBusy)
        .animation(.easeInOut(duration: 0.25), value: store.pendingAchievementCelebration)
    }
}
