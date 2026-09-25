//
//  AchievementGalleryView.swift
//  Retro Season Manager
//
//  The achievement gallery: every achievement grouped by category, with a
//  career-points total up top and a full history page behind each unlocked
//  trophy — what it was, when it happened, and the story behind it.
//
//  Presented in the accepted Career light-card design language (pale
//  canvas, white cards, ink headings, green accents, gold reserved for
//  genuine emphasis, monospaced figures), readable on compact landscape:
//  category sections stack as one column, achievement tiles flow in a
//  lazy grid, and every label scales rather than clips. Every value shown
//  comes straight from the authoritative GameStore state —
//  `unlockedAchievements`, `achievementUnlocks`, `careerAchievementPoints`
//  — nothing here recalculates, reinterprets or stores anything, and the
//  unlock rule (`unlock(_:)`'s insert-once guard) is untouched.
//
//  Presented both as a full sheet (from Settings' whole-building
//  treatment) and embedded by the Settings detail page — the close
//  control only exists in the sheet presentation, matching the Manager
//  Office / Hall of Fame `showsClose` convention.
//
//  Stable `career.achievements.*` identifiers support the focused UI
//  tests.
//

import SwiftUI

struct AchievementGalleryView: View {
    let store: GameStore
    let showsClose: Bool

    init(store: GameStore, showsClose: Bool = true) {
        self.store = store
        self.showsClose = showsClose
    }

    @State private var selected: AchievementKind?
    @Environment(\.dismiss) private var dismiss

    private var unlockedCount: Int { store.unlockedAchievements.count }
    private var totalCount: Int { AchievementKind.allCases.count }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    ForEach(AchievementCategory.allCases, id: \.self) { category in
                        categorySection(category)
                    }
                    endAnchor
                }
                .padding(14)
                .padding(.trailing, 6) // breathing room around the floating close
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier(CareerIdentifiers.achievementsScroll)

            // The Settings sheet presents this whole-building style; the
            // Settings detail page hosts it inside its own back-bar layout,
            // where the extra close control would duplicate the back bar.
            if showsClose {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
                        .padding(12)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier(CareerIdentifiers.achievementsClose)
                .accessibilityLabel("Close achievements")
            }
        }
        .font(.system(.body, design: .monospaced))
        .sheet(item: $selected) { kind in
            AchievementHistorySheet(store: store, kind: kind)
        }
    }

    // MARK: Header band

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "medal.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52)
                .background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("ACHIEVEMENTS")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Text("\(store.userClub.name) · SEASON \(store.season)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("UNLOCKED")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Text("\(unlockedCount)/\(totalCount)")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(unlockedCount == totalCount ? CareerPalette.line : CareerPalette.ink)
                Text("\(store.careerAchievementPoints.formatted()) PTS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .monospacedDigit()
            }
        }
        .padding(.trailing, showsClose ? 42 : 0) // keep the summary clear of the pinned close
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.achievementsHeader)
        .accessibilityLabel("""
        Achievements. \(unlockedCount) of \(totalCount) unlocked, \
        \(store.careerAchievementPoints.formatted()) career points. \
        \(store.userClub.name), season \(store.season).
        """)
    }

    // MARK: Category sections

    private func categorySection(_ category: AchievementCategory) -> some View {
        let kinds = AchievementKind.allCases.filter { $0.category == category }
        let done = kinds.filter { store.unlockedAchievements.contains($0) }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: category))
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text(category.rawValue.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
                Text("\(done)/\(kinds.count)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(done == kinds.count ? CareerPalette.line : CareerPalette.mutedInk)
                    .monospacedDigit()
            }
            // Achievement tiles flow 2-across on compact landscape phones
            // (3 on wide iPad-class widths), stacking instead of clipping.
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(kinds) { kind in
                    Button {
                        Haptics.tap()
                        selected = kind
                    } label: {
                        AchievementCard(kind: kind, unlocked: store.unlockedAchievements.contains(kind))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(CareerIdentifiers.achievementsCard(kind.rawValue))
                    .accessibilityLabel("\(kind.rawValue). \(unlocked(kind) ? "Unlocked" : "Locked"). \(kind.subtitle)")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .accessibilityElement(children: .contain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.achievementsCategory(category.rawValue))
        .accessibilityLabel("\(category.rawValue) achievements. \(done) of \(kinds.count) unlocked.")
    }

    private func unlocked(_ kind: AchievementKind) -> Bool {
        store.unlockedAchievements.contains(kind)
    }

    private var endAnchor: some View {
        Color.clear
            .frame(height: 1)
            .accessibilityIdentifier(CareerIdentifiers.achievementsEnd)
    }

    private func icon(for category: AchievementCategory) -> String {
        switch category {
        case .trophies:   return "trophy.fill"
        case .character:  return "heart.text.square.fill"
        case .milestones: return "flag.checkered"
        case .legacy:     return "building.columns.fill"
        }
    }
}

private struct AchievementCard: View {
    let kind: AchievementKind
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                ZStack {
                    TrophyView(kind: kind.trophy.kind, tier: unlocked ? kind.trophy.tier : .bronze, size: 34)
                        .opacity(unlocked ? 1 : 0.25)
                        .grayscale(unlocked ? 0 : 1)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(CareerPalette.ink.opacity(0.45))
                            .offset(x: 14, y: 12)
                        }
                }
                Spacer()
                Text("+\(kind.points)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(unlocked ? CareerPalette.line : CareerPalette.mutedInk.opacity(0.6))
                    .monospacedDigit()
            }
            Text(kind.rawValue)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(unlocked ? CareerPalette.ink : CareerPalette.mutedInk)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            if unlocked {
                Text("UNLOCKED")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
            } else {
                Text(kind.subtitle)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            unlocked ? Retro.gold.opacity(0.35) : CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 5, y: 2)
    }
}

/// An unlocked achievement's history page — locked ones get a shorter,
/// spoiler-free version of the same sheet. One stable scroll container,
/// a pinned always-reachable close, and every value read straight off the
/// store's unlock record.
private struct AchievementHistorySheet: View {
    let store: GameStore
    let kind: AchievementKind
    @Environment(\.dismiss) private var dismiss

    private var unlock: AchievementUnlock? { store.achievementUnlocks[kind] }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CareerPalette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    identityCard
                    if unlock != nil {
                        historyCard
                        pointsCard
                    } else {
                        lockedCard
                    }
                }
                .padding(14)
                .padding(.trailing, 6) // breathing room around the floating close
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .accessibilityIdentifier(CareerIdentifiers.achievementsDetail(kind.rawValue))

            // Pinned close — always reachable, sits above the scroll.
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(CareerPalette.mutedInk.opacity(0.55))
                    .padding(12)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(CareerIdentifiers.achievementsDetailClose)
            .accessibilityLabel("Close achievement record")
        }
        .font(.system(.body, design: .monospaced))
    }

    // MARK: Identity card

    private var identityCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((unlock != nil ? Retro.gold : CareerPalette.canvas).opacity(0.3))
                    .frame(width: 64, height: 64)
                TrophyView(kind: kind.trophy.kind, tier: unlock != nil ? kind.trophy.tier : .bronze, size: 44)
                    .opacity(unlock != nil ? 1 : 0.3)
                    .grayscale(unlock != nil ? 0 : 1)
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                unlock != nil ? Retro.gold.opacity(0.5) : CareerPalette.line.opacity(0.18)))

            VStack(alignment: .leading, spacing: 3) {
                Text(unlock != nil ? kind.flavorTitle : kind.rawValue.uppercased())
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(kind.subtitle)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("POINTS")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
                Text("+\(kind.points)")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
                    .monospacedDigit()
            }
        }
        .padding(.trailing, 42) // reserve the pinned close button's corner
        .padding(14)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
    }

    // MARK: Unlock history card

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(CareerPalette.line)
                Text("HOW IT HAPPENED")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                Spacer()
            }
            if let unlock {
                Text(unlock.context)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink.opacity(0.9))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Season \(unlock.season) · \(unlock.date.formatted(.dateTime.day().month(.wide).year()))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(CareerPalette.mutedInk)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Retro.gold.opacity(0.35)))
        .shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CareerIdentifiers.achievementsDetailHistory)
    }

    // MARK: Points / locked cards

    private var pointsCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(CareerPalette.ink)
                .accessibilityHidden(true)
            Text("+\(kind.points) CAREER POINTS")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.ink)
                .monospacedDigit()
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Retro.gold.opacity(0.25))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Retro.gold.opacity(0.5)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(CareerIdentifiers.achievementsDetailPoints)
    }

    private var lockedCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(CareerPalette.mutedInk)
            Text("LOCKED — KEEP PLAYING")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.achievementsDetailLocked)
        .accessibilityLabel("Locked. Keep playing to unlock this achievement.")
    }
}
