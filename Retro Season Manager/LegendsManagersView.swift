//
//  LegendsManagersView.swift
//  Retro Season Manager
//
//  Managers (Phase 9) — collect and assign a single active manager for
//  their tactical bonus and club-affinity chemistry link.
//

import SwiftUI

struct LegendsManagersView: View {
    let store: LegendsStore
    var onBack: () -> Void

    var body: some View {
        ZStack {
            Retro.background.ignoresSafeArea()
            VStack(spacing: 14) {
                header
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(LegendsManagerDatabase.all) { manager in
                            managerRow(manager)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                LegendsBackButton(action: onBack)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Text("MANAGERS")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(Retro.accent)
            Text("\(store.profile.ownedManagerIDs.count)/\(LegendsManagerDatabase.all.count) OWNED")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Retro.text.opacity(0.6))
        }
    }

    private func managerRow(_ manager: LegendsManagerCard) -> some View {
        let owned = store.profile.ownedManagerIDs.contains(manager.id)
        let active = store.profile.activeManagerID == manager.id
        return Button {
            guard owned else { return }
            Haptics.tap()
            withAnimation(.spring(duration: 0.3)) {
                store.setActiveManager(active ? nil : manager.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(owned ? Retro.accent : Retro.text.opacity(0.3))

                VStack(alignment: .leading, spacing: 4) {
                    Text(owned ? manager.name : "???")
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(owned ? Retro.text : Retro.text.opacity(0.4))
                    if owned {
                        Text(manager.specialty)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.6))
                            .lineLimit(2)
                        Text("\(manager.nation) · Affinity: \(manager.affinityClub)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.highlight)
                    } else {
                        Text("Win matches for a chance to unlock a manager.")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Retro.text.opacity(0.4))
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    if owned {
                        Text("+\(manager.tacticalBonus)")
                            .font(.system(.callout, design: .monospaced).bold())
                            .foregroundStyle(Retro.gold)
                    }
                    if active {
                        Text("ACTIVE")
                            .font(.system(size: 9, design: .monospaced).bold())
                            .foregroundStyle(Retro.emerald)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(12)
            .background(Retro.panel.opacity(owned ? 0.7 : 0.35))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Retro.emerald.opacity(0.6) : Retro.accent.opacity(owned ? 0.2 : 0.08), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!owned)
    }
}
