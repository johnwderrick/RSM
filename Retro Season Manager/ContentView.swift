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
    @State private var startsAtNewGame = false

    #if DEBUG
    // SwiftUI can reconstruct ContentView while retaining its @State.
    // Seed once per process so discarded initializers cannot create a
    // newer, unrelated save that the normal Resume tile would select.
    private static let transfersFixture: GameStore = {
        GameStore().prepareCareerTransfersFixtureForDebug()
    }()
    #endif

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
        // Isolated starting point for the New Game UI test: an in-memory,
        // empty store, no fixture save, and no implicit resume/load route.
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_NEW_GAME") {
            _store = State(initialValue: GameStore())
            _startsAtNewGame = State(initialValue: true)
        }

        // Deterministic Career navigation fixture: boots straight into an
        // active, saved career with stable injuries and inbox content
        // (see GameStore+UITestFixture.swift).
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_NAVIGATION") {
            let career = GameStore()
            career.prepareCareerNavigationFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        // Deterministic pre-match fixture: lands the career on the user's
        // next match day with the pre-match hub's prompts, lineup and
        // opponent pinned for the focused UI tests (see
        // GameStore+UITestFixture.swift). UITEST_CAREER_PREMATCH_NO_PROMPTS
        // opts out of the team-talk/press seeding.
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_PREMATCH") {
            let career = GameStore()
            career.prepareCareerPreMatchFixtureForDebug(
                skipPrompts: ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_PREMATCH_NO_PROMPTS"))
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
            _store = State(initialValue: Self.transfersFixture)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SETTINGS") {
            let career = GameStore()
            career.prepareCareerSettingsFixtureForDebug()
            if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SAVE_FAIL_FILE") {
                SaveSlots.debugFailNextWrite = .saveFile
            } else if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SAVE_FAIL_INDEX") {
                SaveSlots.debugFailNextWrite = .index
            }
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SHEETS") {
            let career = GameStore()
            career.prepareCareerSheetsFixtureForDebug(
                forceRenewalBudgetDecline: ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SHEETS_DECLINE"))
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        // Deterministic Squad Depth fixture: the navigation career with
        // exactly one red (no cover) and one amber (thin cover) role, plus
        // two affordable left-back targets (free agent + fee). The
        // fullCover variant shows the all-covered/no-suggestions state
        // instead (see GameStore+UITestFixture.swift).
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_DEPTH") {
            let career = GameStore()
            career.prepareCareerDepthFixtureForDebug(
                fullCover: ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_DEPTH_FULL_COVER"))
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SUPPORTER") {
            let career = GameStore()
            career.prepareCareerSupporterFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SAVE_SLOTS") {
            GameStore.seedCareerSaveSlotsFixtureForDebug(
                corruptNewest: ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SAVE_SLOTS_CORRUPT"))
            if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_SAVE_FAIL_INDEX") {
                SaveSlots.debugFailNextWrite = .index
            }
            _experience = State(initialValue: .career)
        }
        // Deterministic Football Museum fixture: seeds the LegacyArchive
        // store (Documents/legacy) with two hand-built careers and boots
        // into the career main menu with NO active save — the museum's
        // real entry route (the menu tile is enabled because archives
        // exist). Real player saves are never read or modified (see
        // GameStore+UITestFixture.swift).
        if ProcessInfo.processInfo.arguments.contains("UITEST_LEGACY_MUSEUM") {
            GameStore.seedLegacyMuseumFixtureForDebug()
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
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_HALL") {
            let career = GameStore()
            career.prepareCareerHallOfFameFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_CAREER_ACHIEVEMENTS") {
            let career = GameStore()
            career.prepareCareerAchievementsFixtureForDebug()
            _store = State(initialValue: career)
            _experience = State(initialValue: .career)
        }
        #endif
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            if startsAtNewGame && !store.hasStarted {
                ClubSelectView(store: store, onBack: {
                    startsAtNewGame = false
                    experience = nil
                })
            } else if let live = store.live {
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
