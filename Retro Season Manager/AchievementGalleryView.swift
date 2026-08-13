//
//  AchievementGalleryView.swift
//  Retro Season Manager
//
//  The achievement gallery: every achievement grouped by category, with a
//  career-points total up top and a full history page behind each unlocked
//  trophy — what it was, when it happened, and the story behind it.
//

import SwiftUI

struct AchievementGalleryView: View {
    let store: GameStore
    @State private var selected: AchievementKind?

    private var unlockedCount: Int { store.unlockedAchievements.count }
    private var totalCount: Int { AchievementKind.allCases.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    let kinds = AchievementKind.allCases.filter { $0.category == category }
                    Panel(title: category.rawValue.uppercased()) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(kinds) { kind in
                                Button {
                                    Haptics.tap()
                                    selected = kind
                                } label: {
                                    AchievementCard(kind: kind, unlocked: store.unlockedAchievements.contains(kind))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Retro.background.ignoresSafeArea())
        .sheet(item: $selected) { kind in
            AchievementHistorySheet(store: store, kind: kind)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🏅 ACHIEVEMENTS")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
            HStack {
                Text("\(unlockedCount)/\(totalCount) unlocked")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                Spacer()
                Text("\(store.careerAchievementPoints.formatted()) CAREER POINTS")
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
            }
        }
    }
}

private struct AchievementCard: View {
    let kind: AchievementKind
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                TrophyView(kind: kind.trophy.kind, tier: unlocked ? kind.trophy.tier : .bronze, size: 40)
                    .opacity(unlocked ? 1 : 0.25)
                    .grayscale(unlocked ? 0 : 1)
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Retro.text.opacity(0.4))
                        .offset(y: 14)
                }
            }
            Text(kind.rawValue)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(unlocked ? Retro.text : Retro.text.opacity(0.5))
                .multilineTextAlignment(.center)
            if unlocked {
                Text("+\(kind.points) pts")
                    .font(.system(size: 8, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
            } else {
                Text(kind.subtitle)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }
}

/// An unlocked achievement's history page — locked ones get a shorter,
/// spoiler-free version of the same sheet.
private struct AchievementHistorySheet: View {
    let store: GameStore
    let kind: AchievementKind
    @Environment(\.dismiss) private var dismiss

    private var unlock: AchievementUnlock? { store.achievementUnlocks[kind] }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Retro.text.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                TrophyView(kind: kind.trophy.kind, tier: unlock != nil ? kind.trophy.tier : .bronze, size: 110)
                    .opacity(unlock != nil ? 1 : 0.3)
                    .grayscale(unlock != nil ? 0 : 1)
                Text(unlock != nil ? kind.flavorTitle : kind.rawValue.uppercased())
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(unlock != nil ? Retro.highlight : Retro.text.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text(kind.subtitle)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                if let unlock {
                    Panel(title: "HOW IT HAPPENED") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(unlock.context)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(Retro.text)
                            Text("Season \(unlock.season) · \(unlock.date.formatted(.dateTime.day().month(.wide).year()))")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Retro.text.opacity(0.6))
                        }
                    }
                    Text("+\(kind.points) CAREER POINTS")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                } else {
                    Text("LOCKED — KEEP PLAYING")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.text.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }
}
