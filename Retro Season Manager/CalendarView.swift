//
//  CalendarView.swift
//  Retro Season Manager
//
//  The fixtures calendar tab.
//

import SwiftUI

// MARK: - Fixtures

struct CalendarView: View {
    let store: GameStore
    @State private var displayedMonth: Date
    @State private var selectedDate: Date
    @State private var message: String?
    @State private var squadClubIndex: IdentifiableInt?

    private static let gridCalendar = Calendar(identifier: .gregorian)

    init(store: GameStore) {
        self.store = store
        _displayedMonth = State(initialValue: store.currentDate)
        _selectedDate = State(initialValue: store.currentDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let message {
                    Text(message)
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Retro.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                monthGrid
                simToDateBar
                dayDetail
            }
            .padding()
        }
        .sheet(item: $squadClubIndex) { wrapped in
            ClubSquadSheet(store: store, clubIndex: wrapped.value)
        }
    }

    @ViewBuilder
    private var simToDateBar: some View {
        if !store.isSeasonOver && selectedDate > store.currentDate {
            HStack(spacing: 8) {
                Button {
                    Haptics.impact()
                    let target = selectedDate
                    store.runHeavy("Simming to \(target.formatted(.dateTime.day().month(.abbreviated)))…") {
                        let before = store.currentDate
                        await store.simTo(date: target)
                        if Self.gridCalendar.isDate(store.currentDate, inSameDayAs: target) {
                            message = "Simmed to \(store.currentDate.formatted(.dateTime.day().month(.abbreviated).year()))."
                        } else if store.currentDate > before {
                            message = "Stopped early on \(store.currentDate.formatted(.dateTime.day().month(.abbreviated).year())) — needs your attention."
                        }
                        displayedMonth = store.currentDate
                    }
                } label: {
                    Text("SIM TO \(selectedDate.formatted(.dateTime.day().month(.abbreviated)).uppercased())")
                        .font(.system(.callout, design: .monospaced).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Retro.accent)
                        .foregroundStyle(Retro.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    Haptics.warning()
                    let target = selectedDate
                    store.runHeavy("Force-simming to \(target.formatted(.dateTime.day().month(.abbreviated)))…") {
                        await store.forceSimTo(date: target)
                        message = "Force-simmed to \(store.currentDate.formatted(.dateTime.day().month(.abbreviated).year())) — every match along the way was auto-resolved."
                        displayedMonth = store.currentDate
                    }
                } label: {
                    Text("FORCE SIM")
                        .font(.system(.callout, design: .monospaced).bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Retro.panel)
                        .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.35))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.95, green: 0.55, blue: 0.35).opacity(0.5), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var header: some View {
        HStack {
            Text("CALENDAR")
                .font(.system(.headline, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            Spacer()
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 26, height: 26)
            }
            .buttonStyle(PressableButtonStyle())
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(.callout, design: .monospaced).bold())
                .frame(minWidth: 150)
                .multilineTextAlignment(.center)
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 26, height: 26)
            }
            .buttonStyle(PressableButtonStyle())
            Button {
                Haptics.tap()
                displayedMonth = store.currentDate
                selectedDate = store.currentDate
            } label: {
                Text("TODAY")
                    .font(.system(.caption, design: .monospaced).bold())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Retro.panel)
                    .foregroundStyle(Retro.text)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func shiftMonth(_ delta: Int) {
        Haptics.tap()
        displayedMonth = Self.gridCalendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
    }

    private var monthGrid: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                ForEach(Array(gridDays().enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = Self.gridCalendar.veryShortWeekdaySymbols
        let start = Self.gridCalendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// The displayed month's days, front-padded with nils so day 1 lands
    /// under the correct weekday column.
    private func gridDays() -> [Date?] {
        guard let monthInterval = Self.gridCalendar.dateInterval(of: .month, for: displayedMonth),
              let daysInMonth = Self.gridCalendar.range(of: .day, in: .month, for: displayedMonth)?.count
        else { return [] }
        let firstWeekday = Self.gridCalendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - Self.gridCalendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<daysInMonth {
            days.append(Self.gridCalendar.date(byAdding: .day, value: offset, to: monthInterval.start))
        }
        return days
    }

    private func involvesUser(_ index: Int, _ index2: Int) -> Bool {
        index == store.userClubIndex || index2 == store.userClubIndex
    }

    private func isUserDay(_ day: Date) -> Bool {
        store.fixtures(onDate: day).contains { involvesUser($0.homeIndex, $0.awayIndex) }
            || store.cupTies(onDate: day).contains { involvesUser($0.homeIndex, $0.awayIndex) }
            || store.leagueCupTies(onDate: day).contains { involvesUser($0.homeIndex, $0.awayIndex) }
            || store.euroTies(onDate: day).contains { involvesUser($0.homeIndex, $0.awayIndex) }
            || store.uefaCupTies(onDate: day).contains { involvesUser($0.homeIndex, $0.awayIndex) }
            || store.communityShieldTie(onDate: day).map { involvesUser($0.homeIndex, $0.awayIndex) } ?? false
            || store.uefaSuperCupTie(onDate: day).map { involvesUser($0.homeIndex, $0.awayIndex) } ?? false
    }

    private func dayCell(_ day: Date) -> some View {
        let isToday = Self.gridCalendar.isDate(day, inSameDayAs: store.currentDate)
        let isSelected = Self.gridCalendar.isDate(day, inSameDayAs: selectedDate)
        let hasEvent = store.hasCalendarEvent(onDate: day)
        let userDay = isUserDay(day)
        return Button {
            Haptics.tap()
            selectedDate = day
        } label: {
            VStack(spacing: 3) {
                Text("\(Self.gridCalendar.component(.day, from: day))")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular, design: .monospaced))
                Circle()
                    .fill(hasEvent ? (userDay ? Retro.highlight : Retro.accent.opacity(0.7)) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(isSelected ? Retro.accent.opacity(0.25) : (isToday ? Retro.panel.opacity(0.7) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isToday ? Retro.accent.opacity(0.5) : .clear, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Retro.text)
    }

    @ViewBuilder
    private var dayDetail: some View {
        let dayFixtures = store.fixtures(onDate: selectedDate)
        let friendlies = store.friendlyFixtures(onDate: selectedDate)
        let cup = store.cupTies(onDate: selectedDate)
        let leagueCup = store.leagueCupTies(onDate: selectedDate)
        let euro = store.euroTies(onDate: selectedDate)
        let uefaCup = store.uefaCupTies(onDate: selectedDate)
        let communityShield = store.communityShieldTie(onDate: selectedDate)
        let uefaSuperCup = store.uefaSuperCupTie(onDate: selectedDate)
        let dayNews = store.news(onDate: selectedDate)

        Panel(title: selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()).uppercased()) {
            if dayFixtures.isEmpty && friendlies.isEmpty && cup.isEmpty && leagueCup.isEmpty && euro.isEmpty
                && uefaCup.isEmpty && communityShield == nil && uefaSuperCup == nil && dayNews.isEmpty {
                Text("Nothing scheduled or reported on this day.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.7))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if !friendlies.isEmpty {
                        sectionLabel("PRE-SEASON FRIENDLY")
                        VStack(spacing: 4) { ForEach(friendlies) { fixtureRow($0) } }
                    }
                    if !dayFixtures.isEmpty {
                        sectionLabel("LEAGUE — \(store.divisionName(store.userDivisionTier).uppercased())")
                        VStack(spacing: 4) { ForEach(dayFixtures) { fixtureRow($0) } }
                    }
                    if let communityShield {
                        sectionLabel(GameStore.communityShieldName.uppercased())
                        tieRow(communityShield)
                    }
                    if let uefaSuperCup {
                        sectionLabel(GameStore.uefaSuperCupName.uppercased())
                        tieRow(uefaSuperCup)
                    }
                    if !cup.isEmpty {
                        sectionLabel(GameStore.cupName.uppercased())
                        VStack(spacing: 4) { ForEach(cup) { tieRow($0) } }
                    }
                    if !leagueCup.isEmpty {
                        sectionLabel(GameStore.leagueCupName.uppercased())
                        VStack(spacing: 4) { ForEach(leagueCup) { tieRow($0) } }
                    }
                    if !euro.isEmpty {
                        sectionLabel(GameStore.euroName.uppercased())
                        VStack(spacing: 4) { ForEach(euro) { tieRow($0) } }
                    }
                    if !uefaCup.isEmpty {
                        sectionLabel(GameStore.uefaCupName.uppercased())
                        VStack(spacing: 4) { ForEach(uefaCup) { tieRow($0) } }
                    }
                    if !dayNews.isEmpty {
                        sectionLabel("NEWS")
                        VStack(alignment: .leading, spacing: 6) { ForEach(dayNews) { newsRow($0) } }
                    }
                }
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, design: .monospaced).bold())
            .foregroundStyle(Retro.text.opacity(0.6))
    }

    private func fixtureRow(_ fixture: Fixture) -> some View {
        let home = store.clubs[fixture.homeIndex]
        let away = store.clubs[fixture.awayIndex]
        let isUser = involvesUser(fixture.homeIndex, fixture.awayIndex)
        return HStack {
            Text(home.shortName).frame(width: 44, alignment: .leading)
                .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: fixture.homeIndex) }
            if fixture.played {
                Text("\(fixture.homeGoals) - \(fixture.awayGoals)").foregroundStyle(Retro.highlight)
            } else {
                Text(" v ").foregroundStyle(Retro.text.opacity(0.8))
            }
            Text(away.shortName).frame(width: 44, alignment: .trailing)
                .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: fixture.awayIndex) }
            Spacer()
        }
        .font(.system(.callout, design: .monospaced).weight(isUser ? .bold : .regular))
        .foregroundStyle(isUser ? Retro.highlight : Retro.text)
    }

    private func tieRow(_ tie: CupTie) -> some View {
        let isUser = involvesUser(tie.homeIndex, tie.awayIndex)
        return Group {
            if tie.isBye {
                HStack {
                    Text(store.clubs[tie.homeIndex].shortName)
                        .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.homeIndex) }
                    Spacer()
                    Text("bye").foregroundStyle(Retro.text.opacity(0.7))
                }
            } else {
                HStack {
                    Text(store.clubs[tie.homeIndex].shortName).frame(width: 48, alignment: .leading)
                        .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.homeIndex) }
                    if tie.played {
                        Text("\(tie.homeGoals)-\(tie.awayGoals)").foregroundStyle(Retro.highlight)
                        if tie.onPenalties {
                            Text("(p)").font(.system(.caption2, design: .monospaced)).foregroundStyle(Retro.text.opacity(0.7))
                        }
                    } else {
                        Text(" v ").foregroundStyle(Retro.text.opacity(0.6))
                    }
                    Text(store.clubs[tie.awayIndex].shortName).frame(width: 48, alignment: .trailing)
                        .onTapGesture { Haptics.tap(); squadClubIndex = IdentifiableInt(value: tie.awayIndex) }
                    Spacer()
                }
            }
        }
        .font(.system(.callout, design: .monospaced).weight(isUser ? .bold : .regular))
        .foregroundStyle(isUser ? Retro.highlight : Retro.text)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(isUser ? Retro.panel : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func newsRow(_ item: NewsItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(item.category.glyph)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Retro.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(.footnote, design: .monospaced).bold())
                Text(item.body)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.8))
            }
        }
    }
}

