//
//  PlayerSearchView.swift
//  Retro Season Manager
//
//  The player search / scouting tab.
//

import SwiftUI

// MARK: - Player search

private struct SearchResult: Identifiable {
    let player: Player
    let clubIndex: Int
    var id: UUID { player.id }
}

struct PlayerSearchView: View {
    let store: GameStore
    @State private var query = ""
    @State private var positionFilter: DetailedPosition?
    @State private var shortlistOnly = false
    @State private var profile: ProfileContext?
    @State private var message: String?
    @State private var showingReports = false

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isActive: Bool { shortlistOnly || trimmedQuery.count >= 2 || positionFilter != nil }

    private static let resultCap = 60

    private var allMatches: [SearchResult] {
        guard isActive else { return [] }
        if shortlistOnly {
            return store.shortlistedResults.map { SearchResult(player: $0.player, clubIndex: $0.clubIndex) }
        }
        var matches: [SearchResult] = []
        for (index, club) in store.clubs.enumerated() {
            for player in club.players {
                if trimmedQuery.count >= 2 && !player.name.localizedCaseInsensitiveContains(trimmedQuery) { continue }
                if let positionFilter, player.detailedPosition != positionFilter { continue }
                matches.append(SearchResult(player: player, clubIndex: index))
            }
        }
        return matches.sorted { $0.player.rating > $1.player.rating }
    }

    var body: some View {
        // Computed once per render rather than re-scanning and re-sorting
        // every club's squad up to four times over (once each for the
        // empty-state check, the truncated list, and the "showing top N
        // of M" message).
        let matches = allMatches
        let capped = Array(matches.prefix(Self.resultCap))

        VStack(alignment: .leading, spacing: 14) {
            Text("PLAYER SEARCH")
                .font(.system(.headline, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)

            scoutingToolbar
            searchField
            positionFilterRow

            if let message {
                Text(message)
                    .font(.system(.footnote, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Retro.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !isActive {
                Text("Type at least 2 characters, or pick a position, to search every club in the pyramid.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                Spacer()
            } else if capped.isEmpty {
                Text(shortlistOnly ? "Your shortlist is empty. Star a player's profile to add them."
                                    : "No players found for \"\(query)\".")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
                Spacer()
            } else {
                if matches.count > Self.resultCap {
                    Text("Showing top \(Self.resultCap) of \(matches.count) matches by rating — refine your search to narrow it down.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                }
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(capped) { result in
                            resultRow(result)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(item: $profile) { context in
            PlayerProfileSheet(store: store, context: context) { message = $0 }
        }
        .sheet(isPresented: $showingReports) {
            ScoutReportsSheet(store: store) { context in
                showingReports = false
                profile = context
            }
        }
    }

    /// Active scouting missions — send a scout out into the wider world
    /// (or specifically after youth talent) instead of only ever being
    /// able to search for players you already know exist, plus a running
    /// list of every report filed so far.
    private var scoutingToolbar: some View {
        HStack(spacing: 8) {
            scoutButton("🌍 SCOUT WORLD") { store.scoutTheWorld(youthOnly: false) }
            scoutButton("🎓 SCOUT YOUTH") { store.scoutTheWorld(youthOnly: true) }
            Spacer()
            Button {
                Haptics.tap()
                showingReports = true
            } label: {
                Text("REPORTS (\(store.scoutedReports.count))")
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Retro.panel)
                    .foregroundStyle(Retro.text)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func scoutButton(_ title: String, action: @escaping () -> String) -> some View {
        Button {
            Haptics.impact()
            message = action()
        } label: {
            Text(title)
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Retro.accent)
                .foregroundStyle(Retro.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!store.transferWindowOpen)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Retro.text.opacity(0.6))
            TextField("Search players by name…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Retro.text)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Retro.text.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Retro.panel.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var positionFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(label: "★ SHORTLIST", isSelected: shortlistOnly) { shortlistOnly.toggle() }
                filterChip(label: "ALL", isSelected: !shortlistOnly && positionFilter == nil) {
                    shortlistOnly = false; positionFilter = nil
                }
                ForEach(DetailedPosition.allCases, id: \.self) { role in
                    filterChip(label: role.rawValue, isSelected: !shortlistOnly && positionFilter == role) {
                        shortlistOnly = false
                        positionFilter = (positionFilter == role) ? nil : role
                    }
                }
            }
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(label)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(isSelected ? Retro.background : Retro.text.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Retro.accent : Retro.panel.opacity(0.7))
                .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func resultRow(_ result: SearchResult) -> some View {
        let club = store.clubs[result.clubIndex]
        let player = result.player
        let isShortlisted = store.isShortlisted(player.id)
        return HStack(spacing: 6) {
            Button {
                Haptics.tap()
                profile = .scouted(player, clubIndex: result.clubIndex)
            } label: {
                HStack(spacing: 10) {
                    CrestView(shortName: club.shortName, size: 32, color: store.color(forClubIndex: result.clubIndex))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(player.name)
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(Retro.text)
                        Text("\(club.name) · \(player.detailedPosition.fullName) · Age \(player.age)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.7))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        OverallRatingView(rating: player.rating)
                        if result.clubIndex != store.userClubIndex {
                            Text(player.contractYears <= 0 ? "FREE" : formatMoney(store.negotiatedFee(for: player)))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Retro.highlight)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            Button {
                Haptics.tap()
                store.toggleShortlist(player.id)
            } label: {
                Image(systemName: isShortlisted ? "star.fill" : "star")
                    .foregroundStyle(isShortlisted ? Retro.highlight : Retro.text.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Retro.panel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

