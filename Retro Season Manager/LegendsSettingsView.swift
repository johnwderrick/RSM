//
//  LegendsSettingsView.swift
//  Retro Season Manager
//
//  Settings (Phase 10) — currently just the sound toggle SoundManager
//  has been waiting on since it was first written ("not wired to a
//  Settings toggle yet, but the hook exists"). The toggle is app-wide
//  (Career Mode shares the same SoundManager), not Legends-specific.
//

import SwiftUI

struct LegendsSettingsView: View {
    var onBack: () -> Void

    @State private var soundEnabled = !SoundManager.shared.isMuted

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                header
                Panel(title: "AUDIO") {
                    Toggle(isOn: $soundEnabled) {
                        Text("Sound Effects")
                            .font(.system(.footnote, design: .monospaced).bold())
                            .foregroundStyle(Retro.text)
                    }
                    .tint(Retro.accent)
                    .onChange(of: soundEnabled) { _, newValue in
                        SoundManager.shared.isMuted = !newValue
                        if newValue { SoundManager.shared.play(.buttonTap) }
                    }
                }
                .frame(maxWidth: 420)
                .padding(.horizontal)

                Spacer()

                Text("RSM Legends is an offline card-collecting mode built alongside Career Mode.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Retro.text.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    Haptics.tap()
                    onBack()
                } label: {
                    Text("‹ Back")
                        .font(.system(.callout, design: .monospaced).bold())
                        .foregroundStyle(Retro.text)
                }
                .buttonStyle(PressableButtonStyle())
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Text("SETTINGS")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
        }
    }
}
