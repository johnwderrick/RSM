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
        #endif
        _legendsStore = State(initialValue: legends)
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
