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
    var store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var soundEnabled = !SoundManager.shared.isMuted
    @State private var confirmingDelete = false

    var body: some View {
        LegendsMenuShell(store: store, title: "SETTINGS", subtitle: "SOUND & CLUB DATA", icon: "gearshape.fill", accent: LegendsPalette.purple, onBack: onBack, currentNav: .settings, onNavigate: onNavigate) {
            VStack(spacing: 14) {
                LegendsDashboardPanel(title: "AUDIO", icon: "speaker.wave.2.fill", color: LegendsPalette.blue) {
                    Toggle(isOn: $soundEnabled) {
                        Text("Sound Effects")
                            .font(.system(.footnote, design: .monospaced).bold())
                            .foregroundStyle(LegendsPalette.navy)
                    }
                    .tint(LegendsPalette.green)
                    .onChange(of: soundEnabled) { _, newValue in
                        SoundManager.shared.isMuted = !newValue
                        if newValue { SoundManager.shared.play(.buttonTap) }
                    }
                }

                LegendsDashboardPanel(title: "DANGER ZONE", icon: "exclamationmark.triangle.fill", color: Retro.warning) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Deletes your club, collection and progress. This can't be undone.")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.68))

                        Button {
                            Haptics.tap()
                            confirmingDelete = true
                        } label: {
                            Text("DELETE CLUB")
                                .font(.system(.footnote, design: .monospaced).bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Retro.warning)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }

                Text("RSM Legends is an offline card-collecting mode built alongside Career Mode.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 8)
            }
            .frame(maxWidth: 520)
        }
        .alert("Delete this club?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Haptics.tap()
                store.deleteClub()
                onBack()
            }
        } message: {
            Text("This can't be undone.")
        }
    }

}
