//
//  CareerTimelineView.swift
//
//  A connected vertical timeline of every beat in a career — job changes,
//  trophies, promotions, European nights, storied achievements, retirement
//  — generated from `careerTimeline()`.
//
//  This view renders INSIDE the Manager Office's shared scroll container
//  (the host owns the one vertical ScrollView), so it draws content only —
//  no container of its own, no background of its own. Light-card language:
//  white moment cards on the pale canvas, green connector, ink headings,
//  gold for trophy beats.
//

import SwiftUI

/// The Timeline tab's content. Hosted by `ManagerOfficeView`'s single
/// scroll container — deliberately NOT a ScrollView itself.
struct CareerTimelineView: View {
    let store: GameStore

    var body: some View {
        let moments = store.careerTimeline()
        VStack(alignment: .leading, spacing: 12) {
            if moments.isEmpty {
                emptyState
            } else {
                ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                    TimelineRow(moment: moment, isLast: index == moments.count - 1)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "scroll")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(CareerPalette.mutedInk.opacity(0.5))
            Text("Your story is just beginning.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CareerPalette.mutedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(CareerPalette.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CareerPalette.line.opacity(0.18)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CareerIdentifiers.timelineEmpty)
        .accessibilityLabel("Your story is just beginning. Play matches to start your timeline.")
    }
}

/// One connected timeline beat: a circled icon on the green connector
/// spine, with the year, headline and detail in a white card to the right.
private struct TimelineRow: View {
    let moment: CareerMoment
    let isLast: Bool

    private var isTrophy: Bool { moment.icon == "🏆" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Text(moment.icon)
                    .font(.system(size: 15))
                    .frame(width: 32, height: 32)
                    .background(isTrophy ? Retro.gold.opacity(0.15) : CareerPalette.canvas.opacity(0.8))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isTrophy ? Retro.gold.opacity(0.55) : CareerPalette.line.opacity(0.35), lineWidth: 1))
                if !isLast {
                    Rectangle()
                        .fill(CareerPalette.line.opacity(0.22))
                        .frame(width: 2)
                        .frame(minHeight: 22)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(moment.year))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(CareerPalette.line)
                    Text(moment.detail)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(CareerPalette.mutedInk.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                }
                Text(moment.headline)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CareerPalette.surface)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CareerPalette.line.opacity(0.18)))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(CareerIdentifiers.timelineRow(moment.year))
            .accessibilityLabel("\(moment.headline), \(moment.year). \(moment.detail)")
        }
    }
}
