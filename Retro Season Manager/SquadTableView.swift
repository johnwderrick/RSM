//
//  SquadTableView.swift
//  Retro Season Manager
//
//  The Squad tab's full sortable roster table.
//

import SwiftUI

// MARK: - Full squad table (browse & sort the whole roster)

private enum SquadSortColumn: String, CaseIterable {
    case position = "POS", name = "NAME", age = "AGE", ability = "ABL", fitness = "FIT",
         value = "VALUE", wage = "WAGE", contract = "CONTRACT"
}

struct SquadTableView: View {
    let store: GameStore
    @State private var sortColumn: SquadSortColumn = .position
    @State private var ascending = true
    @State private var profile: ProfileContext?
    @State private var positionGroupFilter: Position?

    private var sortedPlayers: [Player] {
        let players = store.userClub.players.filter { positionGroupFilter == nil || $0.detailedPosition.broad == positionGroupFilter }
        let sorted: [Player]
        switch sortColumn {
        case .position:
            sorted = players.sorted {
                $0.detailedPosition.broad.order != $1.detailedPosition.broad.order
                    ? $0.detailedPosition.broad.order < $1.detailedPosition.broad.order
                    : $0.rating > $1.rating
            }
        case .name:     sorted = players.sorted { $0.name < $1.name }
        case .age:      sorted = players.sorted { $0.age < $1.age }
        case .ability:  sorted = players.sorted { $0.rating > $1.rating }
        case .fitness:  sorted = players.sorted { $0.fitness > $1.fitness }
        case .value:    sorted = players.sorted { $0.value > $1.value }
        case .wage:     sorted = players.sorted { $0.wage > $1.wage }
        case .contract: sorted = players.sorted { $0.contractYears < $1.contractYears }
        }
        return ascending ? sorted : sorted.reversed()
    }

    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            positionGroupRow
            header
            if let message {
                Text(message)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.highlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Retro.panel.opacity(0.5))
            }
            Divider().overlay(Retro.accent.opacity(0.25))
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedPlayers) { player in
                        SquadTableRow(store: store, player: player,
                                     isStarter: store.userStarterIDs.contains(player.id),
                                     markers: store.roleMarkers(for: player.id),
                                     contractExpiry: store.contractExpiryYear(player),
                                     onOpenProfile: { profile = .squad(player) },
                                     onMessage: { message = $0 })
                        Divider().overlay(Retro.accent.opacity(0.08))
                    }
                }
            }
        }
        .background(Retro.background)
        .sheet(item: $profile) { context in
            PlayerProfileSheet(store: store, context: context) { _ in }
        }
    }

    private var positionGroupRow: some View {
        HStack(spacing: 6) {
            groupChip(label: "ALL", isSelected: positionGroupFilter == nil) { positionGroupFilter = nil }
            ForEach(Position.allCases, id: \.self) { group in
                groupChip(label: group.rawValue, isSelected: positionGroupFilter == group) {
                    positionGroupFilter = (positionGroupFilter == group) ? nil : group
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func groupChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? Retro.background : Retro.text.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Retro.accent : Retro.panel.opacity(0.7))
                .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var header: some View {
        HStack(spacing: 8) {
            headerCell("POS", .position, width: 46, alignment: .leading)
            headerCell("NAME", .name, alignment: .leading)
            headerCell("AGE", .age, width: 36)
            headerCell("ABL", .ability, width: 54)
            headerCell("FIT", .fitness, width: 54)
            headerCell("VALUE", .value, width: 72)
            headerCell("WAGE/WK", .wage, width: 72)
            headerCell("CONTRACT", .contract, width: 78)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Retro.panel.opacity(0.7))
    }

    private func headerCell(_ title: String, _ column: SquadSortColumn, width: CGFloat? = nil,
                            alignment: Alignment = .center) -> some View {
        Button {
            if sortColumn == column { ascending.toggle() } else { sortColumn = column; ascending = true }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if sortColumn == column {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(sortColumn == column ? Retro.accent : Retro.text.opacity(0.7))
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
        }
        .buttonStyle(.plain)
    }
}

struct SquadTableRow: View {
    let store: GameStore
    let player: Player
    let isStarter: Bool
    var markers: [String] = []
    let contractExpiry: Int
    let onOpenProfile: () -> Void
    let onMessage: (String) -> Void

    /// Natural role first, then secondary roles, then whatever's left in
    /// the broad bucket — every role this player could plausibly move to.
    private var roleOptions: [DetailedPosition] {
        var roles = [player.detailedPosition] + player.secondaryPositions
        for candidate in DetailedPosition.plausibleRoles(for: player.position) where !roles.contains(candidate) {
            roles.append(candidate)
        }
        return roles
    }

    /// Roles genuinely worth training toward — no existing natural,
    /// secondary or related competence there yet.
    private var retrainableRoles: [DetailedPosition] {
        DetailedPosition.plausibleRoles(for: player.position)
            .filter { $0 != player.detailedPosition && player.fit(for: $0) <= 0 }
    }

    /// This player's fit for the exact pitch slot they're pinned to, if
    /// any — a glanceable warning ring for "I manually dragged someone
    /// into a spot they're not suited for", without needing to open the
    /// pitch view to notice. Auto-filled starters (no explicit pin) are
    /// already placed by best fit, so there's nothing to flag there.
    private var slotFitLevel: PositionFitLevel? {
        guard isStarter else { return nil }
        let position = player.position
        let count: Int
        switch position {
        case .goalkeeper: count = 1
        case .defender:   count = store.formation.defenders
        case .midfielder: count = store.formation.midfielders
        case .forward:    count = store.formation.forwards
        }
        for index in 0..<count {
            let key = "\(position.rawValue)-\(index)"
            if store.slotPins[key] == player.id {
                let role = DetailedPosition.expected(for: position, indexInRow: index, rowCount: count, wideIsWinger: store.formation.wideMidfieldersAreWingers)
                return player.fitLevel(for: role)
            }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(roleOptions, id: \.self) { role in
                    let dot = player.fitLevel(for: role) == .confident ? "🟢" : (player.fitLevel(for: role) == .okay ? "🟡" : "🔴")
                    Button("\(dot) \(role.fullName) — \(player.effectiveRating(for: role))") {
                        let change = store.assignStarter(player, forRole: role)
                        if case .blocked(let reason) = change {
                            onMessage(reason)
                        } else {
                            onMessage("\(surname(player.name)) moved to \(role.fullName).")
                        }
                    }
                }
                if isStarter {
                    Divider()
                    Button("Move to Bench", role: .destructive) {
                        store.toggleStarter(player)
                        onMessage("\(surname(player.name)) dropped to the bench.")
                    }
                }
                if player.retrainingRole == nil, !retrainableRoles.isEmpty {
                    Divider()
                    Menu("🎓 Retrain for…") {
                        ForEach(retrainableRoles, id: \.self) { role in
                            Button(role.fullName) {
                                switch store.beginRetraining(player, toward: role) {
                                case .started(let msg), .blocked(let msg):
                                    onMessage(msg)
                                }
                            }
                        }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(player.detailedPosition.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    if !player.secondaryPositions.isEmpty {
                        Text(player.secondaryPositions.map(\.rawValue).joined(separator: "/"))
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.55))
                    }
                }
                .foregroundStyle(Retro.background)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .frame(width: 46)
                .background(positionColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    (slotFitLevel != .confident ? slotFitLevel : nil).map { level in
                        RoundedRectangle(cornerRadius: 4).stroke(level.color, lineWidth: 2)
                    }
                )
            }

            Button(action: onOpenProfile) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(player.isInjured ? Color.red
                                  : (player.isSuspended ? Color.orange
                                     : (isStarter ? Retro.accent : Color.green.opacity(0.5))))
                            .frame(width: 6, height: 6)
                        if player.morale < 45 {
                            Text("☹")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.3))
                        }
                        Text(player.name)
                            .font(.system(size: 11, weight: isStarter ? .bold : .regular, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        ForEach(markers, id: \.self) { marker in
                            Text(marker)
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(Retro.background)
                                .padding(.horizontal, 3).padding(.vertical, 1)
                                .background(Retro.highlight)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                        if let role = player.retrainingRole {
                            Text("🎓\(role.rawValue) \(player.retrainingDaysRemaining)d")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(Retro.background)
                                .padding(.horizontal, 3).padding(.vertical, 1)
                                .background(Retro.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(player.age)")
                        .frame(width: 36)
                    OverallRatingView(rating: player.rating)
                        .frame(width: 54)
                    VStack(spacing: 2) {
                        Text("\(player.fitness)%")
                            .font(.system(size: 9, design: .monospaced))
                        FitnessBar(value: player.fitness).frame(height: 4)
                    }
                    .frame(width: 54)
                    Text(formatMoney(player.value))
                        .frame(width: 72)
                    Text(formatMoney(player.wage))
                        .frame(width: 72)
                    Text(player.contractYears <= 1 ? "Exp \(contractExpiry)" : "\(contractExpiry)")
                        .foregroundStyle(player.contractYears <= 1 ? Color(red: 0.95, green: 0.45, blue: 0.35) : Retro.text)
                        .frame(width: 78)
                }
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Retro.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(isStarter ? Retro.token.opacity(0.25) : Color.clear)
    }

    private var positionColor: Color {
        switch player.detailedPosition.broad {
        case .goalkeeper: return Retro.highlight
        case .defender:   return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .midfielder: return Retro.accent
        case .forward:    return Color(red: 1.0, green: 0.55, blue: 0.40)
        }
    }
}

