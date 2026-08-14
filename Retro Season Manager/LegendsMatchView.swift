//
//  LegendsMatchView.swift
//  Retro Season Manager
//
//  Play Match (Phase 7) — a deliberately short presentation per the
//  doc ("Shorter presentation. Faster progression."): no live
//  minute-by-minute ticker, just a brief search beat and the result.
//

import SwiftUI

struct LegendsMatchView: View {
    let store: LegendsStore
    var onBack: () -> Void

    @State private var isSimulating = false
    @State private var summary: LegendsMatchOutcomeSummary? = nil

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 18) {
                header
                Spacer()
                if let summary {
                    resultPanel(summary)
                } else if isSimulating {
                    searchingPanel
                } else if store.currentTeamRating > 0 {
                    readyPanel
                } else {
                    notReadyPanel
                }
                Spacer()
            }
            .padding()
        }
    }

    private var header: some View {
        HStack {
            Button {
                Haptics.tap()
                onBack()
            } label: {
                Text("‹ Back")
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
            }
            .buttonStyle(PressableButtonStyle())
            Spacer()
            Text("PLAY MATCH")
                .font(.system(.headline, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            Spacer()
            Color.clear.frame(width: 60)
        }
        .padding(.top, 12)
    }

    private var notReadyPanel: some View {
        Panel(title: "SQUAD NOT READY") {
            Text("Fill every Starting XI slot in the Squad screen before you can play a match.")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 420)
    }

    private var readyPanel: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(store.profile.division.displayName.uppercased())
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .tracking(2)
                Text("\(store.profile.divisionWins)/\(LegendsStore.winsToPromote) WINS TO PROMOTION")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
            }

            Panel(title: "YOUR TEAM") {
                HStack {
                    Text(store.profile.clubName)
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                    Spacer()
                    Text("\(store.currentTeamRating) OVR")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                }
            }
            .frame(maxWidth: 380)

            Button {
                Haptics.tap()
                isSimulating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    summary = store.playMatch()
                    isSimulating = false
                }
            } label: {
                Text("KICK OFF")
                    .font(.system(.headline, design: .monospaced).bold())
                    .foregroundStyle(Retro.background)
                    .frame(maxWidth: 260)
                    .padding(.vertical, 14)
                    .background(Retro.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var searchingPanel: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Retro.accent)
            Text("Finding an opponent…")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
        }
    }

    private func resultPanel(_ summary: LegendsMatchOutcomeSummary) -> some View {
        VStack(spacing: 16) {
            Text(summary.result.outcome.label)
                .font(.system(.largeTitle, design: .monospaced).bold())
                .foregroundStyle(outcomeColor(summary.result.outcome))

            Text("\(store.profile.clubName)  \(summary.result.teamGoals) – \(summary.result.opponentGoals)  \(summary.opponent.name)")
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .multilineTextAlignment(.center)

            Text("Opponent rating \(summary.opponent.rating)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.6))

            Panel(title: "REWARDS") {
                VStack(alignment: .leading, spacing: 6) {
                    rewardRow("Coins", "+\(summary.coinsEarned)")
                    if summary.tokensEarned > 0 { rewardRow("Pack Tokens", "+\(summary.tokensEarned)") }
                    rewardRow("Manager XP", "+\(summary.xpEarned)")
                }
            }
            .frame(maxWidth: 380)

            if summary.leveledUp {
                Text("MANAGER LEVEL UP → \(store.profile.managerLevel)")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.gold)
            }
            if summary.promoted {
                Text("PROMOTED TO \(summary.newDivision.displayName.uppercased())")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.emerald)
            }

            HStack(spacing: 12) {
                Button {
                    Haptics.tap()
                    self.summary = nil
                } label: {
                    Text("Play Again")
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Retro.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    Haptics.tap()
                    onBack()
                } label: {
                    Text("Back to Home")
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Retro.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func rewardRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
        }
    }

    private func outcomeColor(_ outcome: LegendsMatchOutcome) -> Color {
        switch outcome {
        case .win: return Retro.emerald
        case .draw: return Retro.gold
        case .loss: return Retro.warning
        }
    }
}
