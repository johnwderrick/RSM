//
//  PitchView.swift
//  Retro Season Manager
//
//  The tactics pitch itself, its slot-picking sheets, and the small
//  shapes/tokens it's built from.
//

import SwiftUI

// MARK: - Pitch

struct PitchView: View {
    let store: GameStore
    @Binding var message: String?
    @State private var pickerTarget: SlotPickerTarget?
    @State private var draggingKey: String?

    var body: some View {
        ZStack {
            PitchBackground()
            PitchGridDots()
            VStack(spacing: 6) {
                frontLine
                row(.defender, store.formation.defenders, indices: Array(0..<store.formation.defenders))
                row(.goalkeeper, 1, indices: [0])
            }
            .padding(16)
        }
        .padding(10)
        .sheet(item: $pickerTarget) { target in
            PositionPickerSheet(store: store, role: target.role, currentPlayerID: target.currentPlayerID) { player in
                let change = store.assignStarter(player, forRole: target.role)
                if case .blocked(let reason) = change {
                    message = reason
                } else {
                    message = "\(surname(player.name)) selected at \(target.role.rawValue)."
                }
            } onBench: {
                guard let id = target.currentPlayerID,
                      let player = store.userClub.players.first(where: { $0.id == id }) else { return }
                store.toggleStarter(player)
                message = "\(surname(player.name)) dropped to the bench."
            }
        }
    }

    /// The attacking line(s) above the back four. A genuine front-three
    /// shape (4-3-3 and similar, where two "midfielders" are really
    /// wingers) merges the wide pair with the striker(s) into one settled
    /// front line — LW / ST / RW side by side, like a real team sheet —
    /// with the remaining central midfielders in their own row below. Any
    /// other formation (a classic 4-4-2, say) keeps forwards and midfield
    /// as two separate single-line rows.
    @ViewBuilder
    private var frontLine: some View {
        let midCount = store.formation.midfielders
        if store.formation.wideMidfieldersAreWingers {
            combinedFrontRow(midCount: midCount)
            let central = centralMidIndices(midCount)
            if !central.isEmpty {
                row(.midfielder, midCount, indices: central)
            }
        } else {
            row(.forward, store.formation.forwards, indices: Array(0..<store.formation.forwards))
            row(.midfielder, midCount, indices: Array(0..<midCount))
        }
    }

    private func centralMidIndices(_ count: Int) -> [Int] {
        (0..<count).filter {
            let role = DetailedPosition.expected(for: .midfielder, indexInRow: $0, rowCount: count, wideIsWinger: true)
            return role != .leftWing && role != .rightWing
        }
    }

    /// One HStack mixing the wide midfielder slots and the forward slots
    /// together, left wing → striker(s) → right wing, so a 4-3-3's front
    /// three genuinely reads as one line rather than the winger sitting a
    /// row apart from the man he's meant to be playing alongside.
    private func combinedFrontRow(midCount: Int) -> some View {
        let wideIndices = (0..<midCount).filter {
            let role = DetailedPosition.expected(for: .midfielder, indexInRow: $0, rowCount: midCount, wideIsWinger: true)
            return role == .leftWing || role == .rightWing
        }
        let leftWide = wideIndices.first
        let rightWide = wideIndices.count > 1 ? wideIndices.last : nil
        let forwardCount = store.formation.forwards
        let midPlayers = slotPlayers(.midfielder, midCount)
        let fwdPlayers = slotPlayers(.forward, forwardCount)

        return HStack(spacing: 4) {
            if let leftWide {
                tokenView(position: .midfielder, index: leftWide, count: midCount, player: midPlayers[leftWide])
            }
            ForEach(0..<forwardCount, id: \.self) { index in
                tokenView(position: .forward, index: index, count: forwardCount, player: fwdPlayers[index])
            }
            if let rightWide {
                tokenView(position: .midfielder, index: rightWide, count: midCount, player: midPlayers[rightWide])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ position: Position, _ count: Int, indices subsetIndices: [Int]) -> some View {
        let players = slotPlayers(position, count)
        return HStack(spacing: 4) {
            ForEach(subsetIndices, id: \.self) { index in
                tokenView(position: position, index: index, count: count, player: players[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tokenView(position: Position, index: Int, count: Int, player: Player?) -> some View {
        let role = DetailedPosition.expected(for: position, indexInRow: index, rowCount: count, wideIsWinger: store.formation.wideMidfieldersAreWingers)
        let key = slotKey(position, index)
        return PlayerToken(
            player: player,
            role: role.rawValue,
            fitLevel: player?.fitLevel(for: role) ?? .confident,
            onTap: { pickerTarget = SlotPickerTarget(role: role, currentPlayerID: player?.id) }
        )
        .frame(maxWidth: .infinity)
        .opacity(draggingKey == key ? 0.5 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .onChanged { _ in draggingKey = key }
                .onEnded { drag in
                    swapWithNeighbour(position, index: index, count: count,
                                      playerID: player?.id, movedRight: drag.translation.width > 0)
                    draggingKey = nil
                }
        )
    }

    /// Swaps a slot with its next-door neighbour in the same broad-position
    /// group (index-1 for a leftward drag, index+1 for a rightward one) —
    /// simple, deliberately decoupled from real pixel geometry, so it can't
    /// ever destabilise the surrounding layout the way frame-tracking did.
    private func swapWithNeighbour(_ position: Position, index: Int, count: Int, playerID: UUID?, movedRight: Bool) {
        guard let playerID, count > 1 else { return }
        let neighbourIndex = movedRight ? index + 1 : index - 1
        guard neighbourIndex >= 0, neighbourIndex < count else { return }
        let slots = slotPlayers(position, count)
        Haptics.tap()
        let neighbourPlayerID = slots[neighbourIndex]?.id
        store.setSlotPin(slotKey(position, neighbourIndex), playerID: playerID)
        store.setSlotPin(slotKey(position, index), playerID: neighbourPlayerID)
    }

    private func slotKey(_ position: Position, _ index: Int) -> String { "\(position.rawValue)-\(index)" }

    /// The selected players filling a row's slots. Explicit drag-placed
    /// pins are honoured first; anyone left over fills the remaining
    /// slots by best natural/secondary fit, same as before pins existed.
    private func slotPlayers(_ position: Position, _ count: Int) -> [Player?] {
        guard count > 0 else { return [] }
        var pool = store.userClub.players.filter { store.userStarterIDs.contains($0.id) && $0.position == position }
        var slots: [Player?] = Array(repeating: nil, count: count)

        for index in 0..<count {
            guard let pinnedID = store.slotPins[slotKey(position, index)],
                  let player = pool.first(where: { $0.id == pinnedID }) else { continue }
            slots[index] = player
            pool.removeAll { $0.id == pinnedID }
        }

        let order = (0..<count).filter { slots[$0] == nil }.sorted { a, b in
            let aEdge = a == 0 || a == count - 1
            let bEdge = b == 0 || b == count - 1
            if aEdge != bEdge { return aEdge }
            return a < b
        }
        for index in order {
            let role = DetailedPosition.expected(for: position, indexInRow: index, rowCount: count, wideIsWinger: store.formation.wideMidfieldersAreWingers)
            func score(_ p: Player) -> Double { Double(p.effectiveRating(for: role)) * (0.9 + 0.1 * Double(p.fitness) / 100) }
            guard let best = pool.max(by: { score($0) < score($1) }) else { continue }
            slots[index] = best
            pool.removeAll { $0.id == best.id }
        }
        return slots
    }

}

/// Identifies which pitch slot the quick-select sheet is filling.
struct SlotPickerTarget: Identifiable {
    let role: DetailedPosition
    let currentPlayerID: UUID?
    var id: String { role.rawValue + "-" + (currentPlayerID?.uuidString ?? "empty") }
}

/// Wraps a plain Int as Identifiable, for `.sheet(item:)` bindings keyed by
/// a club index (e.g. tapping a team name to view their squad).
struct IdentifiableInt: Identifiable {
    let value: Int
    var id: Int { value }
}

/// A read-only look at any club's full squad — reached by tapping a team
/// name anywhere in the league table or a fixture list.
struct ClubSquadSheet: View {
    let store: GameStore
    let clubIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var profile: ProfileContext?

    private var club: Club { store.clubs[clubIndex] }
    private var sortedPlayers: [Player] {
        club.players.sorted {
            if $0.position.order != $1.position.order { return $0.position.order < $1.position.order }
            return $0.rating > $1.rating
        }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                header
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(sortedPlayers) { player in
                            Button {
                                Haptics.tap()
                                profile = .scouted(player, clubIndex: clubIndex)
                            } label: {
                                row(player)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
            }
            .padding(20)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .sheet(item: $profile) { context in
            PlayerProfileSheet(store: store, context: context) { _ in }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CrestView(shortName: club.shortName, size: 44, color: store.color(forClubIndex: clubIndex))
            VStack(alignment: .leading, spacing: 2) {
                Text(club.name)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Retro.accent)
                Text("\(store.clubDivisionLabel(forClubIndex: clubIndex)) · \(store.starRating(forClubIndex: clubIndex))★ · \(club.players.count) players")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Retro.text.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ player: Player) -> some View {
        HStack(spacing: 10) {
            Text(player.detailedPosition.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Retro.background)
                .frame(width: 42)
                .padding(.vertical, 4)
                .background(positionColor(player))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(player.name)
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(Retro.text)
                .lineLimit(1)
            Spacer()
            Text("\(player.age)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
                .frame(width: 24)
            OverallRatingView(rating: player.rating)
        }
        .padding(10)
        .background(Retro.panel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func positionColor(_ player: Player) -> Color {
        switch player.detailedPosition.broad {
        case .goalkeeper: return Retro.highlight
        case .defender:   return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .midfielder: return Retro.accent
        case .forward:    return Color(red: 1.0, green: 0.55, blue: 0.40)
        }
    }
}

/// Quick-select: ranks every eligible squad player for one specific pitch
/// slot by their rating at that role, so picking a natural fit takes one tap.
struct PositionPickerSheet: View {
    let store: GameStore
    let role: DetailedPosition
    let currentPlayerID: UUID?
    let onPick: (Player) -> Void
    let onBench: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// Eligible players for this slot — anyone already nailed into a
    /// different starting slot is left off the list, aside from whoever
    /// currently occupies this one.
    private var candidates: [Player] {
        store.userClub.players
            .filter { $0.position == role.broad }
            .filter { $0.id == currentPlayerID || !store.userStarterIDs.contains($0.id) }
            .sorted { $0.effectiveRating(for: role) > $1.effectiveRating(for: role) }
    }

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SELECT \(role.fullName.uppercased())")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Retro.text)
                }
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(candidates) { player in
                            candidateRow(player)
                        }
                    }
                }
            }
            .padding()
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
    }

    private func candidateRow(_ player: Player) -> some View {
        let isCurrent = player.id == currentPlayerID
        let unavailable = player.isInjured || player.isSuspended
        return Button {
            if isCurrent { onBench() } else { onPick(player) }
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(player.detailedPosition.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .frame(width: 40)
                    .background(fitColor(player))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.system(.callout, design: .monospaced).bold())
                    Text("\(fitLabel(player)) · \(player.fitnessLabel) · Age \(player.age)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                    FitnessBar(value: player.fitness).frame(width: 90, height: 4)
                }

                Spacer()

                Text("\(player.effectiveRating(for: role))")
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)

                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Retro.accent)
                }
            }
            .padding(10)
            .background(isCurrent ? Retro.token.opacity(0.35) : Retro.panel.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(unavailable && !isCurrent ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(unavailable && !isCurrent)
    }

    private func fitLabel(_ player: Player) -> String {
        switch player.fit(for: role) {
        case 2:  return "Natural"
        case 1:  return "Can play"
        case 0:  return "Makeshift"
        default: return "Out of position"
        }
    }

    private func fitColor(_ player: Player) -> Color {
        player.fitLevel(for: role).color
    }
}

/// A thin bar showing match fitness, green-to-red by condition.
struct FitnessBar: View {
    let value: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Retro.text.opacity(0.15))
                Capsule().fill(color)
                    .frame(width: geo.size.width * CGFloat(value) / 100)
            }
        }
    }

    private var color: Color {
        switch value {
        case 75...:   return Retro.accent
        case 50..<75: return Retro.highlight
        default:      return Color(red: 0.9, green: 0.35, blue: 0.35)
        }
    }
}

/// A single player token (or empty slot) on the pitch.
struct PlayerToken: View {
    let player: Player?
    let role: String
    var fitLevel: PositionFitLevel = .confident
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(role)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Retro.background)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Retro.highlight)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                if let player {
                    VStack(spacing: 1) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(fitLevel.color)
                                .frame(width: 6, height: 6)
                            Text(surname(player.name))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .foregroundStyle(.white)
                        }
                        Text("\(player.rating)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .frame(minWidth: 52)
                    .background(Retro.token)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(fitLevel == .poor ? fitLevel.color : Retro.tokenEdge, lineWidth: fitLevel == .poor ? 1.5 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 52, height: 30)
                        .background(Color.black.opacity(0.25))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4])))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// The green pitch with mown stripes and markings.
struct PitchBackground: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(Array(0..<7), id: \.self) { index in
                    (index.isMultiple(of: 2) ? Retro.pitch : Retro.pitchLight)
                }
            }
            PitchMarkings()
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                .padding(4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// A faint placement grid over the pitch, the way a real tactics board
/// marks out even slot positions — purely decorative, sits under the
/// player tokens.
struct PitchGridDots: View {
    private let columns = 7
    private let rows = 10

    var body: some View {
        // Built from plain stacks rather than a GeometryReader — a
        // GeometryReader used directly inside a ZStack has no intrinsic
        // size of its own, which can make the ZStack (and everything
        // sized relative to it) report the wrong size to its parent.
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { _ in
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { _ in
                        Spacer(minLength: 0)
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 3, height: 3)
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .allowsHitTesting(false)
    }
}

/// Simple top-down pitch markings.
struct PitchMarkings: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        // Halfway line.
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        // Centre circle.
        let radius = min(rect.width, rect.height) * 0.11
        path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius,
                                   width: radius * 2, height: radius * 2))
        // Penalty boxes at each end.
        let boxWidth = rect.width * 0.5
        let boxHeight = rect.height * 0.15
        path.addRect(CGRect(x: rect.midX - boxWidth / 2, y: rect.minY,
                            width: boxWidth, height: boxHeight))
        path.addRect(CGRect(x: rect.midX - boxWidth / 2, y: rect.maxY - boxHeight,
                            width: boxWidth, height: boxHeight))
        return path
    }
}

// MARK: - Squad list (right column)

struct SquadListPanel: View {
    let store: GameStore
    @Binding var message: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SQUAD")
                    .foregroundStyle(Retro.accent)
                Spacer()
                Text("ROLE")
                    .foregroundStyle(Retro.text.opacity(0.7))
            }
            .font(.system(.caption, design: .monospaced).bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Retro.panel)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(sortedPlayers) { player in
                        Button {
                            handleTap(player)
                        } label: {
                            SquadListRow(player: player,
                                         isStarter: store.userStarterIDs.contains(player.id),
                                         markers: store.roleMarkers(for: player.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Retro.background)
    }

    private var sortedPlayers: [Player] {
        store.userClub.players.sorted {
            if $0.position.order != $1.position.order { return $0.position.order < $1.position.order }
            return $0.rating > $1.rating
        }
    }

    private func handleTap(_ player: Player) {
        switch store.toggleStarter(player) {
        case .blocked(let reason): message = reason
        case .added:               message = "\(surname(player.name)) added to the XI."
        case .removed:             message = "\(surname(player.name)) dropped to the bench."
        }
    }
}

struct SquadListRow: View {
    let player: Player
    let isStarter: Bool
    var markers: [String] = []

    var body: some View {
        HStack(spacing: 8) {
            Text(player.position.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Retro.background)
                .frame(width: 32)
                .padding(.vertical, 3)
                .background(positionColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Circle()
                .fill(player.isInjured ? Color.red
                      : (player.isSuspended ? Color.orange
                         : (isStarter ? Retro.accent : Color.green.opacity(0.5))))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
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
                }
                subtitle
                    .font(.system(size: 8, design: .monospaced))
            }

            Spacer(minLength: 2)

            Text(player.detailedPosition.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(isStarter ? Retro.background : Retro.text)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isStarter ? Retro.highlight : Retro.panel)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(isStarter ? Retro.token.opacity(0.35) : Color.clear)
        .foregroundStyle(Retro.text)
    }

    private var subtitle: Text {
        if player.isInjured {
            return Text("Injured \(player.injuryWeeks)w").foregroundStyle(Retro.text.opacity(0.7))
        }
        if player.isSuspended {
            return Text("Suspended \(player.suspensionMatches)").foregroundStyle(Retro.text.opacity(0.7))
        }
        let base = Text("R\(player.rating) · Age \(player.age) · ").foregroundStyle(Retro.text.opacity(0.7))
        let contract = Text(player.contractYears <= 1 ? "Exp" : "\(player.contractYears)y")
            .foregroundStyle(player.contractYears <= 1 ? Color(red: 0.95, green: 0.45, blue: 0.35) : Retro.text.opacity(0.7))
        let goals = player.goals > 0
            ? Text(" · \(player.goals)⚽︎").foregroundStyle(Retro.text.opacity(0.7))
            : Text("")
        let fitness = player.fitness < 75
            ? Text(" · \(player.fitness)%").foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.35))
            : Text("")
        return base + contract + goals + fitness
    }

    private var positionColor: Color {
        switch player.position {
        case .goalkeeper: return Retro.highlight
        case .defender:   return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .midfielder: return Retro.accent
        case .forward:    return Color(red: 1.0, green: 0.55, blue: 0.40)
        }
    }
}


