//
//  LegendsChallengesView.swift
//  Retro Season Manager
//
//  Challenges (Phase 8) — Daily, Weekly and Permanent objectives,
//  grouped the same way the doc lists them.
//

import SwiftUI

struct LegendsChallengesView: View {
    let store: LegendsStore
    var onBack: () -> Void

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(LegendsChallengeCadence.allCases, id: \.self) { cadence in
                            cadenceSection(cadence)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear { store.refreshChallengeCadences() }
    }

    private var header: some View {
        VStack(spacing: 8) {
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
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Text("CHALLENGES")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
        }
    }

    private func cadenceSection(_ cadence: LegendsChallengeCadence) -> some View {
        let challenges = LegendsChallengeDatabase.all.filter { $0.cadence == cadence }
        return VStack(alignment: .leading, spacing: 8) {
            Text(cadence.rawValue.uppercased())
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            VStack(spacing: 8) {
                ForEach(challenges) { challenge in
                    challengeRow(challenge)
                }
            }
        }
    }

    private func challengeRow(_ challenge: LegendsChallenge) -> some View {
        let completed = store.isCompleted(challenge)
        let progress = store.progress(for: challenge)
        return HStack(spacing: 12) {
            Image(systemName: completed ? "checkmark.seal.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(completed ? Retro.emerald : Retro.text.opacity(0.3))
                .animation(.spring(duration: 0.4), value: completed)

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text(challenge.description)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
                if !completed && progress > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Retro.background.opacity(0.5))
                            RoundedRectangle(cornerRadius: 3).fill(Retro.accent)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 5)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if challenge.coinReward > 0 {
                    Text("+\(challenge.coinReward)")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                }
                if challenge.tokenReward > 0 {
                    Text("+\(challenge.tokenReward) tok")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(Retro.gold)
                }
            }
        }
        .padding(12)
        .background(Retro.panel.opacity(completed ? 0.4 : 0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(completed ? Retro.emerald.opacity(0.4) : Retro.accent.opacity(0.1), lineWidth: 1))
    }
}
