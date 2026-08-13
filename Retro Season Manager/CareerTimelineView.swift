//
//  CareerTimelineView.swift
//  Retro Season Manager
//
//  A scrollable, connected vertical timeline of every beat in a career —
//  job changes, trophies, promotions, European nights, storied
//  achievements, retirement — generated from `careerTimeline()`.
//

import SwiftUI

struct CareerTimelineView: View {
    let store: GameStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                let moments = store.careerTimeline()
                if moments.isEmpty {
                    Text("Your story is just beginning.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Retro.text.opacity(0.7))
                        .padding(.top, 8)
                } else {
                    ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                        TimelineRow(moment: moment, isLast: index == moments.count - 1)
                    }
                }
            }
            .padding()
        }
        .background(Retro.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("📜 CAREER TIMELINE")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.highlight)
            Text(store.managerName)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Retro.text.opacity(0.7))
        }
        .padding(.bottom, 14)
    }
}

private struct TimelineRow: View {
    let moment: CareerMoment
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(moment.icon)
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .background(Retro.panel)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Retro.accent.opacity(0.4), lineWidth: 1))
                if !isLast {
                    Rectangle()
                        .fill(Retro.accent.opacity(0.25))
                        .frame(width: 2)
                        .frame(minHeight: 28)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(moment.year)")
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(Retro.highlight)
                Text(moment.headline)
                    .font(.system(.callout, design: .monospaced).bold())
                    .foregroundStyle(Retro.text)
                Text(moment.detail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.6))
            }
            .padding(.bottom, 18)
            Spacer()
        }
    }
}
