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
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    private var allChallenges: [LegendsChallenge] { LegendsChallengeDatabase.all }
    private var completedCount: Int { allChallenges.filter { store.isCompleted($0) }.count }
    private var activeCount: Int { allChallenges.count - completedCount }
    private var completionPercent: Double {
        allChallenges.isEmpty ? 0 : Double(completedCount) / Double(allChallenges.count)
    }

    var body: some View {
        LegendsMenuShell(store: store, title: "CHALLENGES", subtitle: "DAILY · WEEKLY · PERMANENT", icon: "flag.checkered", accent: LegendsPalette.cyan, onBack: onBack, currentNav: .challenges, onNavigate: onNavigate, scrollContent: false) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryHeader
                    ForEach(LegendsChallengeCadence.allCases, id: \.self) { cadence in
                        cadenceSection(cadence)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear { store.refreshChallengeCadences() }
    }

    // MARK: - Summary

    private var summaryHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(LegendsPalette.cyan.opacity(0.18), lineWidth: 6)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: completionPercent)
                    .stroke(LegendsPalette.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                Text("\(Int((completionPercent * 100).rounded()))%")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(LegendsPalette.navy)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("OBJECTIVE TRACKER")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)
                Text("\(completedCount) COMPLETED · \(activeCount) ACTIVE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(LegendsPalette.cyan)
                Text("Win matches, build your collection and earn coins and tokens.")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.cyan.opacity(0.25), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.08), radius: 7, y: 3)
    }

    // MARK: - Cadence sections

    private func cadenceSection(_ cadence: LegendsChallengeCadence) -> some View {
        let challenges = allChallenges.filter { $0.cadence == cadence }
        let sectionColor = cadenceColor(cadence)
        let done = challenges.filter { store.isCompleted($0) }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: cadenceIcon(cadence))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(sectionColor)
                    .frame(width: 30, height: 30)
                    .background(sectionColor.opacity(0.16))
                    .clipShape(Circle())
                Text(cadence.rawValue.uppercased())
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(done)/\(challenges.count) DONE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(LinearGradient(colors: [sectionColor, LegendsPalette.navy], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 8) {
                ForEach(challenges) { challenge in
                    challengeRow(challenge, accent: sectionColor)
                }
            }
        }
    }

    // MARK: - Row

    private func challengeRow(_ challenge: LegendsChallenge, accent: Color) -> some View {
        let completed = store.isCompleted(challenge)
        let progress = store.progress(for: challenge)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(completed ? LegendsPalette.green : accent.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: completed ? "checkmark" : challenge.kind.glyph)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(completed ? .white : accent)
            }
            .animation(.spring(duration: 0.4), value: completed)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(challenge.title)
                        .font(.system(.footnote, design: .rounded).weight(.black))
                        .foregroundStyle(LegendsPalette.navy)
                    if completed {
                        Text("COMPLETED")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LegendsPalette.green)
                            .clipShape(Capsule())
                    }
                }
                Text(challenge.description)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                    .lineLimit(2)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(LegendsPalette.navy.opacity(0.10))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(completed ? LegendsPalette.green : accent)
                            .frame(width: geo.size.width * min(1, max(0, progress)))
                    }
                }
                .frame(height: 5)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                if challenge.coinReward > 0 {
                    HStack(spacing: 3) {
                        Text("+\(challenge.coinReward)")
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(LegendsPalette.gold)
                    }
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(LegendsPalette.goldDeep)
                }
                if challenge.tokenReward > 0 {
                    HStack(spacing: 3) {
                        Text("+\(challenge.tokenReward)")
                        Image(systemName: "cube.fill")
                            .foregroundStyle(LegendsPalette.green)
                    }
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(LegendsPalette.green)
                }
            }
        }
        .padding(12)
        .background(completed ? LegendsPalette.greenWash.opacity(0.72) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(completed ? LegendsPalette.green.opacity(0.4) : accent.opacity(0.22), lineWidth: 1))
        .shadow(color: LegendsPalette.navy.opacity(0.07), radius: 6, y: 3)
    }

    private func cadenceIcon(_ cadence: LegendsChallengeCadence) -> String {
        switch cadence {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar"
        case .permanent: return "shield.fill"
        }
    }

    private func cadenceColor(_ cadence: LegendsChallengeCadence) -> Color {
        switch cadence {
        case .daily: return LegendsPalette.green
        case .weekly: return LegendsPalette.blue
        case .permanent: return LegendsPalette.purple
        }
    }
}
