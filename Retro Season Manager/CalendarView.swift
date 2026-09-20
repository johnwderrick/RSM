//
//  CalendarView.swift
//  Retro Season Manager
//
//  The season schedule destination: a compact month overview, competition
//  filters and a full fixture/result schedule for the displayed month,
//  presented in the accepted Career light-card design language.
//
//  Every value shown comes from the authoritative GameStore calendar APIs
//  (fixtures/onDate:, cup ties/onDate:, date(forMatchday:), …) — nothing
//  here recalculates schedules or results. The competition filter is
//  presentation-only and never mutates the stored schedule.
//

import SwiftUI

struct CalendarView: View {
    let store: GameStore

    @State private var displayedMonth: Date
    @State private var selectedDate: Date
    @State private var filter: CompetitionFilter = .all
    @State private var message: String?
    @State private var squadClubIndex: IdentifiableInt?

    init(store: GameStore) {
        self.store = store
        _displayedMonth = State(initialValue: store.currentDate)
        _selectedDate = State(initialValue: store.currentDate)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryBand
                    if geo.size.width >= 900 {
                        HStack(alignment: .top, spacing: 12) {
                            monthCard.frame(width: 420)
                            VStack(alignment: .leading, spacing: 12) {
                                filterRow
                                nextFixtureCard
                                scheduleCard
                                dayDetail
                            }
                        }
                    } else {
                        monthCard
                        filterRow
                        nextFixtureCard
                        scheduleCard
                        dayDetail
                    }
                }
                .padding(14)
            }
            .accessibilityIdentifier("career.calendar.scroll")
            .background(CareerPalette.canvas)
        }
        .sheet(item: $squadClubIndex) { ClubSquadSheet(store: store, clubIndex: $0.value) }
    }

    // MARK: - Season summary

    private var summaryBand: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .black)).foregroundStyle(CareerPalette.line)
                .frame(width: 52, height: 52).background(CareerPalette.line.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text("SEASON SCHEDULE").font(.system(size: 15, weight: .black, design: .monospaced))
                Text("SEASON \(store.season) · \(store.divisionName(store.userDivisionTier).uppercased())")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
            }
            Spacer(minLength: 0)
            metric("TODAY", store.currentDate.formatted(.dateTime.day().month(.abbreviated)).uppercased())
            metric("MATCHDAY", "\(store.currentMatchday)")
            metric("PLAYED", "\(store.userClub.played)")
        }
        .foregroundStyle(CareerPalette.ink).padding(14).background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14)).shadow(color: CareerPalette.ink.opacity(0.07), radius: 7, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("career.calendar.summary")
        .accessibilityLabel("Season \(store.season) schedule. Today \(store.currentDate.formatted(.dateTime.day().month(.wide))). MATCHDAY \(store.currentMatchday). PLAYED \(store.userClub.played).")
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
            Text(value).font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.ink)
        }
    }

    // MARK: - Month card

    private var monthCard: some View {
        let isCurrentMonth = GameStore.calendar.isDate(displayedMonth, equalTo: store.currentDate, toGranularity: .month)
        return Card {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Button { shiftMonth(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 28, height: 28)
                            .foregroundStyle(CareerPalette.line)
                            .background(CareerPalette.canvas).clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("career.calendar.month.previous")

                    Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.ink)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("career.calendar.month.label")
                        .accessibilityLabel(displayedMonth.formatted(.dateTime.month(.wide).year()))
                        .accessibilityValue(displayedMonth.formatted(.dateTime.month(.wide).year()))

                    Button { shiftMonth(1) } label: {
                        Image(systemName: "chevron.right").frame(width: 28, height: 28)
                            .foregroundStyle(CareerPalette.line)
                            .background(CareerPalette.canvas).clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("career.calendar.month.next")

                    Button { Haptics.tap(); displayedMonth = store.currentDate; selectedDate = store.currentDate } label: {
                        Text("TODAY")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(isCurrentMonth ? CareerPalette.mutedInk : CareerPalette.line)
                            .padding(.horizontal, 9).padding(.vertical, 7)
                            .background(CareerPalette.canvas).clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("career.calendar.month.today")
                }

                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                    ForEach(Array(gridDays().enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 34)
                        }
                    }
                }
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        Haptics.tap()
        withAnimation(.easeOut(duration: 0.15)) {
            displayedMonth = GameStore.calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = GameStore.calendar.veryShortWeekdaySymbols
        let start = GameStore.calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// The displayed month's days, front-padded with nils so day 1 lands
    /// under the correct weekday column.
    private func gridDays() -> [Date?] {
        guard let monthInterval = GameStore.calendar.dateInterval(of: .month, for: displayedMonth),
              let daysInMonth = GameStore.calendar.range(of: .day, in: .month, for: displayedMonth)?.count
        else { return [] }
        let firstWeekday = GameStore.calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - GameStore.calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<daysInMonth {
            days.append(GameStore.calendar.date(byAdding: .day, value: offset, to: monthInterval.start))
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
        let isToday = GameStore.calendar.isDate(day, inSameDayAs: store.currentDate)
        let isSelected = GameStore.calendar.isDate(day, inSameDayAs: selectedDate)
        let hasEvent = store.hasCalendarEvent(onDate: day)
        let userDay = isUserDay(day)
        return Button {
            Haptics.tap()
            selectedDate = day
        } label: {
            VStack(spacing: 2) {
                Text("\(GameStore.calendar.component(.day, from: day))")
                    .font(.system(size: 11, weight: isToday ? .black : .semibold, design: .monospaced))
                Circle()
                    .fill(hasEvent ? (userDay ? Retro.highlight : CareerPalette.line.opacity(0.65)) : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(isSelected ? CareerPalette.line.opacity(0.16) : (isToday ? CareerPalette.line.opacity(0.07) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isToday ? CareerPalette.line.opacity(0.55) : .clear, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(CareerPalette.ink)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.formatted(.dateTime.day().month(.wide)))\(isToday ? ", today" : "")\(userDay ? ", your match" : (hasEvent ? ", event" : ""))")
    }

    // MARK: - Competition filters (presentation-only)

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(CompetitionFilter.allCases) { candidate in
                    Button { Haptics.tap(); filter = candidate } label: {
                        Text(candidate.rawValue).font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(filter == candidate ? .white : CareerPalette.mutedInk)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(filter == candidate ? CareerPalette.line : CareerPalette.surface).clipShape(Capsule())
                            .overlay(Capsule().stroke(CareerPalette.line.opacity(filter == candidate ? 0 : 0.18)))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("career.calendar.filter.\(candidate.slug)")
                    .accessibilityAddTraits(filter == candidate ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Next fixture

    @ViewBuilder private var nextFixtureCard: some View {
        if let fixture = store.nextUserFixture {
            let home = fixture.homeIndex == store.userClubIndex
            let opponentIndex = home ? fixture.awayIndex : fixture.homeIndex
            let opponent = store.clubs[opponentIndex]
            Card("NEXT FIXTURE", subtitle: "MATCHDAY \(fixture.matchday)", symbol: "calendar.badge.clock",
                 headerID: "career.calendar.nextFixture") {
                HStack(spacing: 10) {
                    CrestView(shortName: opponent.shortName, size: 38, color: store.color(forClubIndex: opponentIndex))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(opponent.name).font(.system(size: 12, weight: .black, design: .monospaced)).lineLimit(1)
                        Text((home ? "HOME" : "AWAY") + " · "
                             + store.date(forMatchday: fixture.matchday).formatted(.dateTime.weekday(.wide).day().month(.abbreviated)).uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                    }
                    Spacer()
                    Text(String(repeating: "★", count: store.fixtureDifficulty(opponentIndex: opponentIndex)))
                        .font(.system(size: 9)).foregroundStyle(Retro.highlight)
                }
            }
            .accessibilityLabel("Next fixture, MATCHDAY \(fixture.matchday), \(home ? "home" : "away") against \(opponent.name) on \(store.date(forMatchday: fixture.matchday).formatted(.dateTime.day().month(.wide)))")
        }
    }

    // MARK: - Month schedule

    private var monthRows: [ScheduleRow] {
        guard let interval = GameStore.calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        var rows: [ScheduleRow] = []
        var day = interval.start
        while day < interval.end {
            rows.append(contentsOf: scheduleRows(on: day))
            day = GameStore.calendar.date(byAdding: .day, value: 1, to: day) ?? interval.end
        }
        return rows
    }

    /// All of the user division's fixtures and cup ties scheduled on one
    /// day, straight from the authoritative per-day store queries.
    private func scheduleRows(on day: Date) -> [ScheduleRow] {
        var rows: [ScheduleRow] = []
        for fixture in store.friendlyFixtures(onDate: day) {
            rows.append(ScheduleRow(date: day, kind: .friendly, homeIndex: fixture.homeIndex, awayIndex: fixture.awayIndex,
                                    played: fixture.played, homeGoals: fixture.homeGoals, awayGoals: fixture.awayGoals,
                                    context: "FRIENDLY"))
        }
        for fixture in store.fixtures(onDate: day) {
            rows.append(ScheduleRow(date: day, kind: .league, homeIndex: fixture.homeIndex, awayIndex: fixture.awayIndex,
                                    played: fixture.played, homeGoals: fixture.homeGoals, awayGoals: fixture.awayGoals,
                                    context: "MD \(fixture.matchday)"))
        }
        if let tie = store.communityShieldTie(onDate: day) {
            rows.append(ScheduleRow(date: day, kind: .communityShield, homeIndex: tie.homeIndex, awayIndex: tie.awayIndex,
                                    played: tie.played, homeGoals: tie.homeGoals, awayGoals: tie.awayGoals,
                                    context: GameStore.communityShieldName.uppercased()))
        }
        if let tie = store.uefaSuperCupTie(onDate: day) {
            rows.append(ScheduleRow(date: day, kind: .uefaSuperCup, homeIndex: tie.homeIndex, awayIndex: tie.awayIndex,
                                    played: tie.played, homeGoals: tie.homeGoals, awayGoals: tie.awayGoals,
                                    context: GameStore.uefaSuperCupName.uppercased()))
        }
        for tie in store.cupTies(onDate: day) where !tie.isBye {
            rows.append(ScheduleRow(date: day, kind: .nationalCup, homeIndex: tie.homeIndex, awayIndex: tie.awayIndex,
                                    played: tie.played, homeGoals: tie.homeGoals, awayGoals: tie.awayGoals,
                                    context: store.cupRoundLabel.uppercased()))
        }
        for tie in store.leagueCupTies(onDate: day) where !tie.isBye {
            rows.append(ScheduleRow(date: day, kind: .leagueTrophy, homeIndex: tie.homeIndex, awayIndex: tie.awayIndex,
                                    played: tie.played, homeGoals: tie.homeGoals, awayGoals: tie.awayGoals,
                                    context: store.leagueCupRoundLabel.uppercased()))
        }
        for tie in store.euroTies(onDate: day) where !tie.isBye {
            rows.append(ScheduleRow(date: day, kind: .continentalCup, homeIndex: tie.homeIndex, awayIndex: tie.awayIndex,
                                    played: tie.played, homeGoals: tie.homeGoals, awayGoals: tie.awayGoals,
                                    context: store.euroRoundLabel.uppercased()))
        }
        for tie in store.uefaCupTies(onDate: day) where !tie.isBye {
            rows.append(ScheduleRow(date: day, kind: .midweekCup, homeIndex: tie.homeIndex, awayIndex: tie.awayIndex,
                                    played: tie.played, homeGoals: tie.homeGoals, awayGoals: tie.awayGoals,
                                    context: store.uefaCupRoundLabel.uppercased()))
        }
        return rows
    }

    private var visibleRows: [ScheduleRow] {
        monthRows.filter { filter.shows($0.kind) }
    }

    private var scheduleCard: some View {
        Card("SCHEDULE",
             subtitle: displayedMonth.formatted(.dateTime.month(.wide).year()).uppercased(),
             symbol: "list.bullet.rectangle", headerID: "career.calendar.schedule") {
            let rows = visibleRows
            if rows.isEmpty {
                Text("No fixtures in \(displayedMonth.formatted(.dateTime.month(.wide))) for this competition.")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .accessibilityIdentifier("career.calendar.empty")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        scheduleRow(row, index: index)
                        if index < rows.count - 1 { Rectangle().fill(CareerPalette.line.opacity(0.08)).frame(height: 1) }
                    }
                }
            }
        }
    }

    private func scheduleRow(_ row: ScheduleRow, index: Int) -> some View {
        let home = store.clubs[row.homeIndex]
        let away = store.clubs[row.awayIndex]
        let isUser = involvesUser(row.homeIndex, row.awayIndex)
        let userIsHome = row.homeIndex == store.userClubIndex
        let scored = userIsHome ? row.homeGoals : row.awayGoals
        let conceded = userIsHome ? row.awayGoals : row.homeGoals
        let resultBadge: String? = row.played && isUser ? (scored > conceded ? "W" : (scored == conceded ? "D" : "L")) : nil

        let state: String
        let stateColor: Color
        if let resultBadge {
            state = "\(resultBadge) \(scored)–\(conceded)"
            stateColor = resultBadge == "W" ? CareerPalette.line : (resultBadge == "D" ? CareerPalette.mutedInk : .orange)
        } else if row.played {
            state = "\(row.homeGoals)–\(row.awayGoals)"
            stateColor = CareerPalette.mutedInk
        } else {
            state = row.context
            stateColor = CareerPalette.line
        }

        let opponentIndex = isUser ? (userIsHome ? row.awayIndex : row.homeIndex) : row.homeIndex
        let opponent = store.clubs[opponentIndex]

        return HStack(spacing: 8) {
            VStack(spacing: 0) {
                Text(row.date.formatted(.dateTime.day()))
                Text(row.date.formatted(.dateTime.month(.abbreviated)).uppercased())
            }
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(CareerPalette.mutedInk)
            .frame(width: 30, alignment: .leading)

            if isUser {
                Text(userIsHome ? "H" : "A")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white).frame(width: 16, height: 16)
                    .background(userIsHome ? CareerPalette.line : CareerPalette.mutedInk)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                CrestView(shortName: opponent.shortName, size: 20, color: store.color(forClubIndex: opponentIndex))
                Text(opponent.shortName).lineLimit(1)
            } else {
                CrestView(shortName: home.shortName, size: 20, color: store.color(forClubIndex: row.homeIndex))
                Text(home.shortName).lineLimit(1)
                Text("V").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                CrestView(shortName: away.shortName, size: 20, color: store.color(forClubIndex: row.awayIndex))
                Text(away.shortName).lineLimit(1)
            }
            Spacer(minLength: 3)

            if !row.played, isUser {
                Text(String(repeating: "★", count: store.fixtureDifficulty(opponentIndex: opponentIndex)))
                    .font(.system(size: 8)).foregroundStyle(Retro.highlight)
            }
            Text(state).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(stateColor)
        }
        .font(.system(size: 10, design: .monospaced)).foregroundStyle(CareerPalette.ink)
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(isUser ? CareerPalette.line.opacity(0.10) : Color.clear)
        .overlay(alignment: .leading) { Rectangle().fill(isUser ? CareerPalette.line : Color.clear).frame(width: 3) }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            squadClubIndex = IdentifiableInt(value: opponentIndex)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("career.calendar.row.\(row.played && isUser ? "played" : "upcoming").\(index)")
        .accessibilityLabel("\(row.context), \(isUser ? (userIsHome ? "home" : "away") + " against " + opponent.name : home.name + " versus " + away.name), \(row.played ? "played " + state : "upcoming")")
    }

    // MARK: - Selected-day detail + sim controls

    private var dayDetail: some View {
        Card(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()).uppercased(),
             subtitle: GameStore.calendar.isDate(selectedDate, inSameDayAs: store.currentDate) ? "TODAY" : "SELECTED DAY",
             symbol: "calendar.day.timeline.left", headerID: "career.calendar.dayDetail") {
            dayDetailBody
        }
    }

    @ViewBuilder private var dayDetailBody: some View {
        let rows = scheduleRows(on: selectedDate)
        let dayNews = store.news(onDate: selectedDate)
        VStack(alignment: .leading, spacing: 10) {
            if rows.isEmpty && dayNews.isEmpty {
                Text("Nothing scheduled or reported on this day.")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
            } else {
                ForEach(rows) { row in
                    HStack(spacing: 8) {
                        Text(row.kind.competitionName)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPalette.mutedInk).frame(width: 92, alignment: .leading)
                        Text(involvesUser(row.homeIndex, row.awayIndex)
                             ? store.clubs[row.homeIndex].shortName + (row.homeIndex == store.userClubIndex ? " v " : " at ") + store.clubs[row.awayIndex].shortName
                             : store.clubs[row.homeIndex].shortName + " v " + store.clubs[row.awayIndex].shortName)
                            .font(.system(size: 10, weight: involvesUser(row.homeIndex, row.awayIndex) ? .black : .regular, design: .monospaced))
                            .foregroundStyle(CareerPalette.ink)
                        Spacer()
                        if row.played {
                            Text("\(row.homeGoals)–\(row.awayGoals)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.line)
                        }
                    }
                }
                ForEach(dayNews) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.category.glyph).font(.system(size: 10, design: .monospaced)).foregroundStyle(CareerPalette.line)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.ink)
                            Text(item.body).font(.system(size: 8, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                        }
                    }
                }
            }
            simToDateBar
            if let message {
                Text(message)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPalette.line)
            }
        }
    }

    @ViewBuilder private var simToDateBar: some View {
        if !store.isSeasonOver && selectedDate > store.currentDate {
            HStack(spacing: 8) {
                Button {
                    Haptics.impact()
                    let target = selectedDate
                    store.runHeavy("Simming to \(target.formatted(.dateTime.day().month(.abbreviated)))…") {
                        let before = store.currentDate
                        await store.simTo(date: target)
                        if GameStore.calendar.isDate(store.currentDate, inSameDayAs: target) {
                            message = "Simmed to \(store.currentDate.formatted(.dateTime.day().month(.abbreviated).year()))."
                        } else if store.currentDate > before {
                            message = "Stopped early on \(store.currentDate.formatted(.dateTime.day().month(.abbreviated).year())) — needs your attention."
                        }
                        displayedMonth = store.currentDate
                        selectedDate = store.currentDate
                    }
                } label: {
                    Text("SIM TO \(selectedDate.formatted(.dateTime.day().month(.abbreviated)).uppercased())")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(CareerPalette.line).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("career.calendar.simTo")

                Button {
                    Haptics.warning()
                    let target = selectedDate
                    store.runHeavy("Force-simming to \(target.formatted(.dateTime.day().month(.abbreviated)))…") {
                        await store.forceSimTo(date: target)
                        message = "Force-simmed to \(store.currentDate.formatted(.dateTime.day().month(.abbreviated).year())) — every match along the way was auto-resolved."
                        displayedMonth = store.currentDate
                        selectedDate = store.currentDate
                    }
                } label: {
                    Text("FORCE SIM")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .foregroundStyle(.orange)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("career.calendar.forceSim")
            }
        }
    }
}

// MARK: - Supporting types

/// Presentation-only competition filter for the schedule. `ALL` shows every
/// event, including one-off trophies and pre-season friendlies; the named
/// competitions map onto the store's authoritative tie collections.
private enum CompetitionFilter: String, CaseIterable, Identifiable {
    case all = "ALL", league = "LEAGUE", nationalCup = "NATIONAL CUP"
    case leagueTrophy = "LEAGUE TROPHY", continentalCup = "CONTINENTAL CUP", midweekCup = "MIDWEEK CUP"

    var id: String { rawValue }

    var slug: String { rawValue.lowercased().replacingOccurrences(of: " ", with: "-") }

    func shows(_ kind: ScheduleRow.Kind) -> Bool {
        guard self != .all else { return true }
        return kind.competitionFilter == self
    }
}

/// One fixture or cup tie in the month schedule, flattened from the
/// authoritative per-day store queries.
private struct ScheduleRow: Identifiable {
    enum Kind {
        case league, nationalCup, leagueTrophy, continentalCup, midweekCup
        case communityShield, uefaSuperCup, friendly

        var competitionName: String {
            switch self {
            case .league: return "LEAGUE"
            case .nationalCup: return GameStore.cupName.uppercased()
            case .leagueTrophy: return GameStore.leagueCupName.uppercased()
            case .continentalCup: return GameStore.euroName.uppercased()
            case .midweekCup: return GameStore.uefaCupName.uppercased()
            case .communityShield: return GameStore.communityShieldName.uppercased()
            case .uefaSuperCup: return GameStore.uefaSuperCupName.uppercased()
            case .friendly: return "FRIENDLY"
            }
        }

        /// The filter that surfaces this kind; one-off trophies and
        /// friendlies only appear under ALL.
        var competitionFilter: CompetitionFilter? {
            switch self {
            case .league: return .league
            case .nationalCup: return .nationalCup
            case .leagueTrophy: return .leagueTrophy
            case .continentalCup: return .continentalCup
            case .midweekCup: return .midweekCup
            case .communityShield, .uefaSuperCup, .friendly: return nil
            }
        }
    }

    let date: Date
    let kind: Kind
    let homeIndex: Int
    let awayIndex: Int
    let played: Bool
    let homeGoals: Int
    let awayGoals: Int
    let context: String

    var id: UUID = UUID()
}

/// The shared light-card container used by the redesigned Career
/// destinations. Cards without a title render content only.
private struct Card<Content: View>: View {
    let titleText: String
    let subtitleText: String
    let symbolName: String?
    let headerID: String?
    let content: Content

    init(_ title: String = "", subtitle: String = "", symbol: String? = nil, headerID: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.titleText = title
        self.subtitleText = subtitle
        self.symbolName = symbol
        self.headerID = headerID
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !titleText.isEmpty {
                HStack(spacing: 8) {
                    if let symbolName { Image(systemName: symbolName).foregroundStyle(CareerPalette.line) }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(titleText).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(CareerPalette.ink)
                        if !subtitleText.isEmpty {
                            Text(subtitleText).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(CareerPalette.mutedInk)
                        }
                    }
                    Spacer()
                }
                // The identifier lives on the header only: identifiers applied
                // to a whole card propagate onto every child accessibility
                // element and clobber identifiers the content set itself.
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(headerID ?? "")
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CareerPalette.line.opacity(0.16)))
        .clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: CareerPalette.ink.opacity(0.06), radius: 6, y: 2)
    }
}
