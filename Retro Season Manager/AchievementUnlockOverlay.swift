//
//  AchievementUnlockOverlay.swift
//  Retro Season Manager
//
//  The full-screen celebration shown the moment an achievement unlocks —
//  reachable from anywhere in the app (not just live matches), reusing the
//  same CRT/confetti/shake broadcast language as the match-day flashes.
//

import SwiftUI

struct AchievementUnlockOverlay: View {
    let store: GameStore
    let kind: AchievementKind
    @State private var popped = false
    @State private var showConfetti = false
    @State private var shakeTrigger = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("ACHIEVEMENT UNLOCKED")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .tracking(3)
                TrophyView(kind: kind.trophy.kind, tier: kind.trophy.tier, size: 100)
                Text(kind.flavorTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.6), radius: 10, y: 4)
                    .padding(.horizontal, 24)
                Text(kind.subtitle)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                Text("+\(kind.points) CAREER POINTS")
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                    .padding(.top, 4)
                Button {
                    Haptics.tap()
                    store.pendingAchievementCelebration = nil
                } label: {
                    Text("CONTINUE")
                        .font(.system(.callout, design: .monospaced).bold())
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .background(Retro.accent.opacity(0.25))
                        .foregroundStyle(Retro.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .scaleEffect(popped ? 1.0 : 0.6)
            if showConfetti {
                PixelConfettiBurst(colors: [Retro.gold, Retro.accent, store.userColor])
            }
            CRTScanlineOverlay()
        }
        .matchShake(trigger: shakeTrigger)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { popped = true }
            showConfetti = true
            shakeTrigger += 1
            Haptics.success()
            // Never blocks play if the player doesn't tap Continue.
            Task {
                try? await Task.sleep(for: .seconds(6))
                if store.pendingAchievementCelebration == kind {
                    store.pendingAchievementCelebration = nil
                }
            }
        }
    }
}
