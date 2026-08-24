//
//  AppSettingsView.swift
//  Retro Season Manager
//
//  Settings reachable from the top-level "Choose your experience" screen,
//  before either mode has been entered. Genuinely global concerns only
//  (audio, app info) — Career Mode's own save-specific settings live in
//  SettingsView, RSM Legends' in LegendsSettingsView. This screen used to
//  just show SettingsView(store:) directly, which meant Career Mode's
//  Manager Profile/Board Confidence/Trophy Cabinet menu (all built around
//  an active career save) rendered here against an empty, not-yet-started
//  GameStore — a leftover copy, not a real top-level settings screen.
//

import SwiftUI

struct AppSettingsView: View {
    @State private var soundEnabled = !SoundManager.shared.isMuted

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.015, blue: 0.025).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("SETTINGS")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    appSettingsPanel(title: "AUDIO", icon: "speaker.wave.2.fill") {
                        Toggle(isOn: $soundEnabled) {
                            Text("Sound Effects")
                                .font(.system(.footnote, design: .monospaced).bold())
                                .foregroundStyle(.white)
                        }
                        .tint(Retro.emerald)
                        .onChange(of: soundEnabled) { _, newValue in
                            SoundManager.shared.isMuted = !newValue
                            if newValue { SoundManager.shared.play(.buttonTap) }
                        }
                    }

                    appSettingsPanel(title: "ABOUT", icon: "info.circle.fill") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Retro Season Manager")
                                .font(.system(.callout, design: .monospaced).bold())
                                .foregroundStyle(.white)
                            Text("An old-school football management sim.")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.65))
                            Text("Version \(appVersion)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    Text("Career Mode and RSM Legends each have their own in-mode settings for save data, difficulty and progress — this screen only covers what's shared between them.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .font(.system(.body, design: .monospaced))
    }

    private func appSettingsPanel<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(.caption, design: .monospaced).bold())
            }
            .foregroundStyle(.white.opacity(0.7))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}
