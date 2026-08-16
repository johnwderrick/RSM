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
    /// Shown for a short fixed beat on cold launch — replaces what was
    /// otherwise a blank white frame between the system launch screen
    /// (LaunchScreen.storyboard) and this view's first real content, and
    /// covers the landscape rotation reflow `RetroSeasonManagerApp`'s
    /// `.onAppear` triggers.
    @State private var showSplash = true

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
                LegendsHomeView(store: legendsStore) { experience = nil }
            } else if experience == .career {
                MainMenuView(store: store, onSwitchExperience: { experience = nil })
            } else {
                ExperienceSelectView(store: store, experience: $experience)
            }
            if store.isBusy {
                LoadingOverlay(message: store.busyMessage)
            }
            if let kind = store.pendingAchievementCelebration {
                AchievementUnlockOverlay(store: store, kind: kind)
                    .transition(.opacity)
            }
            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(store.hasStarted ? store.userColor : Retro.accent)
        .animation(.easeInOut(duration: 0.2), value: store.isBusy)
        .animation(.easeInOut(duration: 0.25), value: store.pendingAchievementCelebration)
        .animation(.easeOut(duration: 0.35), value: showSplash)
        .task {
            try? await Task.sleep(for: .milliseconds(700))
            showSplash = false
        }
    }
}

/// The branded "loading" beat shown while `ContentView` settles — same
/// wordmark/palette recipe as `ExperienceSelectView`, no new assets.
private struct SplashView: View {
    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("⚽︎ RETRO SEASON MANAGER")
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                ProgressView()
                    .tint(Retro.highlight)
            }
        }
    }
}

