//
//  LegendsLiveMatchView.swift
//  Retro Season Manager
//
//  The live match presentation for RSM Legends' full-parity match
//  engine (LegendsLiveMatch.swift) — mirrors MatchDayView.swift's
//  MatchView/SubsSheet composition (fixed score bar, flexible
//  commentary feed, fixed control bar) restyled with Legends' own Retro
//  chrome. No stadium background art and no animated pitch — explicitly
//  descoped, Legends stays text/UI-based per the design doc.
//

import SwiftUI

struct LegendsLiveMatchView: View {
    let store: LegendsStore
    let live: LegendsLiveMatch
    var onFinished: () -> Void

    @State private var showSubs = false
    @State private var hasFinishedHandoff = false

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 0) {
                scoreBar
                commentaryFeed
                Divider().background(Retro.accent.opacity(0.2))
                controlBar
            }

            if live.isFinished {
                fullTimeOverlay
            }
        }
        .onAppear { live.start() }
        .sheet(isPresented: $showSubs) {
            LegendsSubsSheet(live: live)
        }
    }

    // MARK: - Score bar

    private var opponentBadgeColor: Color {
        var gen = SeededGenerator(seed: live.opponent.name)
        return Color(hue: Double.random(in: 0...1, using: &gen), saturation: 0.5, brightness: 0.75)
    }

    private var clockText: String {
        if live.isFinished { return "FT" }
        if live.isHalfTime { return "HT" }
        if live.minute > 90 { return "90+\(live.minute - 90)'" }
        return "\(live.minute)'"
    }

    private var scoreBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                CrestView(shortName: store.profile.crestShort, size: 34, color: Color(rgb: store.profile.crestColorRGB))
                Text(store.profile.clubName)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                    .lineLimit(1)

                Spacer()

                VStack(spacing: 2) {
                    Text("\(live.teamGoals) – \(live.opponentGoals)")
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(Retro.highlight)
                    Text(clockText)
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(Retro.text.opacity(0.7))
                }

                Spacer()

                Text(live.opponent.name)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                    .lineLimit(1)
                ClubBadgeView(name: live.opponent.name, shortName: String(live.opponent.name.prefix(3)).uppercased(),
                              size: 34, primaryColor: opponentBadgeColor)

                playPauseButton
            }

            minuteProgress
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Retro.panel)
    }

    private var playPauseButton: some View {
        Button {
            Haptics.tap()
            live.togglePause()
        } label: {
            Text(live.isFinished ? "FT" : (live.isPaused ? "▶" : "⏸"))
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(live.isFinished ? Retro.text.opacity(0.4) : (live.isPaused ? Retro.accent : Retro.highlight))
                .frame(width: 32, height: 32)
                .background(Retro.background.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(live.isFinished)
    }

    private var minuteProgress: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Retro.background.opacity(0.5))
                Capsule().fill(Retro.accent)
                    .frame(width: geo.size.width * CGFloat(min(live.minute, live.totalMinutes)) / CGFloat(max(live.totalMinutes, 1)))
            }
        }
        .frame(height: 3)
    }

    // MARK: - Commentary feed

    private var commentaryFeed: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(live.commentary.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(.system(.footnote, design: .monospaced).weight(line.text.contains("GOAL") ? .bold : .regular))
                            .foregroundStyle(commentaryColor(line.text))
                            .multilineTextAlignment(commentaryAlignment(line.side))
                            .frame(maxWidth: .infinity, alignment: commentaryFrameAlignment(line.side))
                            .id(index)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: live.commentary.count) { _, _ in
                withAnimation { proxy.scrollTo(live.commentary.count - 1, anchor: .bottom) }
            }
        }
    }

    private func commentaryColor(_ text: String) -> Color {
        if text.contains("GOAL") { return Retro.highlight }
        if text.contains("Full-time") || text.contains("Half-time") || text.contains("Kick-off") { return Retro.accent }
        return Retro.text.opacity(0.9)
    }

    private func commentaryAlignment(_ side: Side?) -> TextAlignment {
        switch side {
        case .home: return .leading
        case .away: return .trailing
        case nil: return .center
        }
    }

    private func commentaryFrameAlignment(_ side: Side?) -> Alignment {
        switch side {
        case .home: return .leading
        case .away: return .trailing
        case nil: return .center
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        VStack(spacing: 8) {
            momentumBar

            HStack(spacing: 8) {
                ForEach([1.0, 2.0, 3.0], id: \.self) { value in
                    Button {
                        Haptics.tap()
                        live.setSpeed(value)
                    } label: {
                        Text("\(Int(value))×")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(live.speed == value ? Retro.background : Retro.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(live.speed == value ? Retro.accent : Retro.background.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                Button {
                    Haptics.tap()
                    live.skipToEnd()
                } label: {
                    Text("SKIP")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(Retro.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Retro.warning)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())

                Spacer()

                Picker("Mentality", selection: Binding(get: { live.userMentality }, set: { live.userMentality = $0 })) {
                    ForEach(Mentality.allCases) { mentality in
                        Text(mentality.rawValue).tag(mentality)
                    }
                }
                .pickerStyle(.menu)
                .tint(Retro.accent)

                Picker("Instruction", selection: Binding(get: { live.userInstruction }, set: { live.userInstruction = $0 })) {
                    ForEach(MatchInstruction.allCases) { instruction in
                        Text(instruction.rawValue).tag(instruction)
                    }
                }
                .pickerStyle(.menu)
                .tint(Retro.highlight)

                Button {
                    Haptics.tap()
                    showSubs = true
                } label: {
                    Text("SUBS \(live.subsLeft)/5")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(live.subsLeft == 0 ? Retro.text.opacity(0.4) : Retro.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Retro.background.opacity(0.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(live.subsLeft == 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Retro.panel)
    }

    private var momentumBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                Capsule().fill(Retro.accent.opacity(0.8))
                    .frame(width: geo.size.width * CGFloat(live.momentum))
                Capsule().fill(Retro.text.opacity(0.3))
            }
        }
        .frame(height: 4)
    }

    // MARK: - Full time

    private var fullTimeOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            Panel(title: "FULL TIME") {
                VStack(spacing: 14) {
                    Text("\(store.profile.clubName)  \(live.teamGoals) – \(live.opponentGoals)  \(live.opponent.name)")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                        .multilineTextAlignment(.center)

                    Button {
                        guard !hasFinishedHandoff else { return }
                        hasFinishedHandoff = true
                        Haptics.tap()
                        onFinished()
                    } label: {
                        Text("CONTINUE ▸")
                            .font(.system(.headline, design: .monospaced).bold())
                            .foregroundStyle(Retro.background)
                            .frame(maxWidth: 220)
                            .padding(.vertical, 12)
                            .background(Retro.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(hasFinishedHandoff)
                }
            }
            .frame(maxWidth: 380)
        }
    }
}

private struct LegendsSubsSheet: View {
    let live: LegendsLiveMatch
    @Environment(\.dismiss) private var dismiss

    @State private var offCardID: String? = nil
    @State private var onCardID: String? = nil

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SUBSTITUTIONS")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(Retro.accent)
                    Spacer()
                    Text("\(live.subsLeft) remaining")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                }
                .padding(.horizontal)
                .padding(.top, 16)

                HStack(alignment: .top, spacing: 12) {
                    column(title: "OFF (on pitch)", cards: live.userOnPitchCards, selected: $offCardID)
                    column(title: "ON (bench)", cards: live.userBenchCards, selected: $onCardID)
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(PressableButtonStyle())
                        .foregroundStyle(Retro.text)

                    Button {
                        guard let off = offCardID, let on = onCardID else { return }
                        Haptics.tap()
                        if live.makeUserSub(offCardID: off, onCardID: on) { dismiss() }
                    } label: {
                        Text("MAKE SUB")
                            .font(.system(.footnote, design: .monospaced).bold())
                            .foregroundStyle(Retro.background)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background((offCardID != nil && onCardID != nil && live.subsLeft > 0) ? Retro.accent : Retro.text.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(offCardID == nil || onCardID == nil || live.subsLeft == 0)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }

    private func column(title: String, cards: [LegendsCard], selected: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.6))
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(cards) { card in
                        Button {
                            Haptics.tap()
                            selected.wrappedValue = card.id
                        } label: {
                            HStack {
                                Circle().fill(card.rarity.tint).frame(width: 8, height: 8)
                                Text(card.name)
                                    .font(.system(.caption, design: .monospaced).bold())
                                    .foregroundStyle(Retro.text)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(8)
                            .background(selected.wrappedValue == card.id ? Retro.accent.opacity(0.3) : Retro.panel.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .frame(maxWidth: .infinity)
    }
}
