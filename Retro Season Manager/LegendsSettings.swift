//
//  LegendsSettings.swift
//  Retro Season Manager
//
//  Redesigned Legends Settings (presentation, accessibility, save & data,
//  about) plus the small persisted presentation-preference layer it edits.
//
//  Preferences live in UserDefaults — independent from the Legends save
//  file — so deleting a club never resets how the app presents itself and
//  older saves decode with sensible defaults. Every preference has a real,
//  presentation-only effect; match timing authority, outcomes, economy and
//  progression are untouched.
//

import SwiftUI

/// UserDefaults-backed Legends presentation preferences.
///
/// All values default to the previously accepted behaviour, so existing
/// installs behave exactly as before until the user changes something.
@MainActor
enum LegendsPresentation {
    /// Complements the system Reduce Motion setting: when enabled, Legends
    /// skips its entrance fades and press-scale animations entirely. The
    /// system setting is always honoured on top of this.
    static let reduceMotionKey = "LegendsPresentation.reduceInterfaceMotion"

    /// Commentary text size used by the live 2D match's commentary feed.
    /// `medium` is the original fixed `.footnote` presentation.
    static let commentarySizeKey = "LegendsPresentation.commentaryTextSize"

    /// The Auto-Save preference read by `LegendsStore.persist()`.
    /// Stored here rather than in the save file so it can never prevent
    /// the user from saving or deleting that file, and so older saves
    /// need no migration. Missing key = autosave on.
    static let autosaveKey = "LegendsPresentation.autosaveEnabled"

    enum CommentaryTextSize: String, CaseIterable, Identifiable {
        case medium, large, extraLarge

        var id: String { rawValue }

        var label: String {
            switch self {
            case .medium: return "STANDARD"
            case .large: return "LARGE"
            case .extraLarge: return "XL"
            }
        }

        /// The text style the live commentary feed uses. Medium matches the
        /// original fixed `.footnote` presentation exactly.
        var textStyle: Font.TextStyle {
            switch self {
            case .medium: return .footnote
            case .large: return .body
            case .extraLarge: return .title3
            }
        }

        var accessibilitySummary: String {
            switch self {
            case .medium: return "Standard commentary text size"
            case .large: return "Large commentary text size"
            case .extraLarge: return "Extra large commentary text size"
            }
        }
    }

    static var reduceInterfaceMotion: Bool {
        UserDefaults.standard.bool(forKey: reduceMotionKey)
    }

    static var commentaryTextSize: CommentaryTextSize {
        CommentaryTextSize(rawValue: UserDefaults.standard.string(forKey: commentarySizeKey) ?? "")
            ?? .medium
    }

    static func setReduceInterfaceMotion(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: reduceMotionKey)
    }

    static func setCommentaryTextSize(_ size: CommentaryTextSize, defaults: UserDefaults = .standard) {
        defaults.set(size.rawValue, forKey: commentarySizeKey)
    }

    /// Returns every presentation preference to its default (the originally
    /// accepted behaviour). Sound and Auto-Save are intentionally left
    /// alone — sound is an app-wide preference shared with Career Mode,
    /// and autosave is a data-safety choice, not presentation.
    static func restoreDefaults(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: reduceMotionKey)
        defaults.removeObject(forKey: commentarySizeKey)
    }

    /// The effective motion suppression for Legends interface animation.
    /// The system accessibility setting always wins.
    static func motionSuppressed(systemReduceMotion: Bool) -> Bool {
        systemReduceMotion || reduceInterfaceMotion
    }
}

/// The redesigned Legends Settings destination.
struct LegendsSettingsView: View {
    var store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var soundEnabled = !SoundManager.shared.isMuted
    @AppStorage(LegendsPresentation.reduceMotionKey) private var reduceInterfaceMotion = false
    @AppStorage(LegendsPresentation.commentarySizeKey) private var commentarySizeRaw = LegendsPresentation.CommentaryTextSize.medium.rawValue
    @State private var lastSaved: Date?
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingDelete = false

    /// Syncs the visible state with authoritative store data each time
    /// the screen appears (a relaunch or restore could have changed it
    /// out from under the default @State value). The Auto-Save toggle is
    /// deliberately NOT mirrored here: it binds directly to the store's
    /// preference, so merely appearing can never fire a preference write.
    private func syncAutosaveState() {
        lastSaved = store.lastSavedDate
    }

    private var commentarySize: LegendsPresentation.CommentaryTextSize {
        LegendsPresentation.CommentaryTextSize(rawValue: commentarySizeRaw) ?? .medium
    }

    /// Compact, readable timestamp for the LAST SAVED row, e.g.
    /// "18 Sep 2026, 21:47:05". Second precision keeps consecutive saves
    /// distinguishable — autosave fires often. A cached formatter keeps
    /// re-renders cheap.
    static func savedDateText(_ date: Date) -> String {
        savedDateFormatter.string(from: date)
    }

    private static let savedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm:ss"
        return formatter
    }()

    /// Human relative description of a save time — "saved just now",
    /// "saved 2 minutes ago", … falling back to the absolute timestamp
    /// after a week. The `now` parameter keeps this deterministic for
    /// unit tests; callers in views use the default clock.
    static func relativeSavedText(_ date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(date)))
        if elapsed < 10 { return "saved just now" }
        if elapsed < 60 { return "saved less than a minute ago" }
        let minutes = elapsed / 60
        if minutes < 60 { return "saved \(minutes) minute\(minutes == 1 ? "" : "s") ago" }
        let hours = minutes / 60
        if hours < 24 { return "saved \(hours) hour\(hours == 1 ? "" : "s") ago" }
        let days = hours / 24
        if days < 7 { return "saved \(days) day\(days == 1 ? "" : "s") ago" }
        return "saved \(savedDateText(date))"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        LegendsMenuShell(store: store, title: "SETTINGS", subtitle: "PRESENTATION & CLUB DATA", icon: "gearshape.fill", accent: LegendsPalette.purple, onBack: onBack, currentNav: .settings, onNavigate: onNavigate) {
            VStack(spacing: 14) {
                summaryCard
                presentationSection
                accessibilitySection
                saveSection
                aboutSection
            }
            .frame(maxWidth: 560)
        }
        .sheet(isPresented: $confirmingDelete) {
            deleteConfirmationSheet
        }
        .onAppear(perform: syncAutosaveState)
        .onChange(of: scenePhase) { _, phase in
            // Data-safety checkpoint: whenever the app moves to the
            // background (or is briefly covered), write the current
            // progress to disk regardless of the Auto-Save preference.
            // Presentation-only with respect to gameplay: no state is
            // mutated beyond what is already in memory.
            if phase != .active {
                store.persistNow()
            } else {
                // Returning from a background checkpoint: refresh the
                // LAST SAVED row so it reflects the write that just happened.
                lastSaved = store.lastSavedDate
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        LegendsDashboardPanel(title: "CLUB SUMMARY", icon: "info.circle.fill", color: LegendsPalette.blue) {
            HStack(spacing: 14) {
                CrestView(shortName: store.profile.crestShort,
                          size: 40,
                          color: Color(rgb: store.profile.crestColorRGB),
                          badgeIndex: store.profile.crestBadgeIndex)
                    .accessibilityIdentifier("settings.summary.badge")

                VStack(alignment: .leading, spacing: 5) {
                    Text(store.profile.clubName)
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(LegendsPalette.navy)
                        .accessibilityIdentifier("settings.summary.clubName")

                    summaryRow("MANAGER", store.profile.managerProfile?.displayName ?? "Not created",
                               identifier: "settings.summary.manager")
                    summaryRow("LEVEL", "Lv \(store.profile.managerLevel)",
                               identifier: "settings.summary.level")
                    summaryRow("DIVISION", store.profile.division.displayName,
                               identifier: "settings.summary.division")
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 5) {
                    Text("SAVE STATUS")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                    HStack(spacing: 5) {
                        Circle()
                            .fill(store.autosaveEnabled ? LegendsPalette.green : LegendsPalette.navy.opacity(0.35))
                            .frame(width: 7, height: 7)
                        Text(store.autosaveEnabled ? "AUTO-SAVE ON" : "AUTO-SAVE OFF")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(store.autosaveEnabled ? LegendsPalette.green : LegendsPalette.navy.opacity(0.55))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(store.autosaveEnabled
                                        ? "Save status: automatic. Progress saves after every change."
                                        : "Save status: automatic saving paused. Critical actions still save.")
                    .accessibilityIdentifier("settings.summary.saveStatus")
                }
            }
        }
    }

    private func summaryRow(_ key: String, _ value: String, identifier: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(key): \(value)")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Presentation

    private var presentationSection: some View {
        LegendsDashboardPanel(title: "PRESENTATION", icon: "slider.horizontal.3", color: LegendsPalette.blue) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $soundEnabled) {
                    settingLabel("Sound Effects", detail: "Interface and match audio (app-wide)")
                }
                .tint(LegendsPalette.green)
                .accessibilityIdentifier("settings.sound.toggle")
                .onChange(of: soundEnabled) { _, newValue in
                    SoundManager.shared.isMuted = !newValue
                    if newValue { SoundManager.shared.play(.buttonTap) }
                }

                Divider().overlay(LegendsPalette.navy.opacity(0.12))

                Toggle(isOn: $reduceInterfaceMotion) {
                    settingLabel("Reduce Interface Motion",
                                 detail: "Skips entrance fades and button animations in Legends")
                }
                .tint(LegendsPalette.green)
                .accessibilityIdentifier("settings.motion.toggle")
                .accessibilityHint("Complements the system Reduce Motion setting, which always applies.")

                VStack(alignment: .leading, spacing: 6) {
                    settingLabel("Match Commentary Text Size",
                                 detail: "Applies to the live match commentary feed")
                    Picker("Match Commentary Text Size", selection: commentarySizeBinding) {
                        ForEach(LegendsPresentation.CommentaryTextSize.allCases) { size in
                            Text(size.label).tag(size.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(LegendsPalette.navy)
                    .accessibilityIdentifier("settings.commentary.size")
                }

                Button {
                    Haptics.tap()
                    LegendsPresentation.restoreDefaults()
                    soundEnabled = !SoundManager.shared.isMuted
                    reduceInterfaceMotion = LegendsPresentation.reduceInterfaceMotion
                    commentarySizeRaw = LegendsPresentation.commentaryTextSize.rawValue
                    SoundManager.shared.play(.buttonTap)
                } label: {
                    Text("RESTORE PRESENTATION DEFAULTS")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(LegendsPalette.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(LegendsPalette.blue.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("settings.restoreDefaults")
            }
        }
    }

    private var commentarySizeBinding: Binding<String> {
        Binding(
            get: { commentarySizeRaw },
            set: { newValue in
                Haptics.tap()
                commentarySizeRaw = newValue
            }
        )
    }

    private func settingLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.footnote, design: .monospaced).bold())
                .foregroundStyle(LegendsPalette.navy)
            Text(detail)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.62))
        }
    }

    // MARK: - Accessibility

    private var accessibilitySection: some View {
        LegendsDashboardPanel(title: "ACCESSIBILITY", icon: "accessibility", color: LegendsPalette.green) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Legends respects your system settings. Reduce Motion disables interface animations, and Dynamic Type scales text across the app.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                Text("The Reduce Interface Motion preference above adds a Legends-specific switch on top of the system setting.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Save & Data

    private var saveSection: some View {
        LegendsDashboardPanel(title: "SAVE & DATA", icon: "externaldrive.fill", color: LegendsPalette.cyan) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: Binding(
                        get: { store.autosaveEnabled },
                        set: { store.setAutosaveEnabled($0) }
                    )) {
                        settingLabel("Auto-Save",
                                     detail: "Saves after every match and every change")
                    }
                    .tint(LegendsPalette.green)
                    .accessibilityIdentifier("settings.autosave.toggle")
                    .accessibilityHint("When off, routine progress is not written to disk. Manager creation, manager editing and deleting the club always save.")
                    // The binding's setter performs the checkpoint; refresh
                    // the timestamp afterwards via the store's real state.
                    .onChange(of: store.autosaveEnabled) { _, _ in
                        lastSaved = store.lastSavedDate
                    }

                    Text("With Auto-Save on, your club is saved after every completed match — instant and live 2D — and after squad moves, training, transfers, packs, facilities and challenge updates. Turning it off pauses that; progress stays in memory and is saved when you turn it back on. Manager creation, editing and club deletion always save. The app also checkpoints your club whenever it moves to the background.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().overlay(LegendsPalette.navy.opacity(0.12))

                // Authoritative timestamp: read from the save file's own
                // modification date, so it is true even with Auto-Save off.
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LAST SAVED")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                        Text(lastSaved.map(Self.savedDateText) ?? "Not yet saved this session")
                            .font(.system(.footnote, design: .monospaced).weight(.semibold))
                            .foregroundStyle(lastSaved == nil ? LegendsPalette.navy.opacity(0.5) : LegendsPalette.navy)
                    }
                    Spacer()
                    Image(systemName: lastSaved == nil ? "tray" : "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(lastSaved == nil ? LegendsPalette.navy.opacity(0.35) : LegendsPalette.green)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("settings.save.lastSavedRow")
                .accessibilityLabel(lastSaved.map {
                    "Last saved \(Self.savedDateText($0)). Auto-save is \(store.autosaveEnabled ? "on" : "off")."
                } ?? "Not yet saved this session. Auto-save is \(store.autosaveEnabled ? "on" : "off").")

                // A live sibling line, deliberately OUTSIDE the row's
                // combined accessibility element above: the row keeps its
                // stable absolute-timestamp label, while this one stays
                // individually queryable. Re-renders every 5 seconds while
                // the screen is open so the wording never goes stale.
                if let lastSaved {
                    TimelineView(.periodic(from: .now, by: 5)) { context in
                        Text(Self.relativeSavedText(lastSaved, now: context.date))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(LegendsPalette.navy.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("settings.save.lastSaved.relative")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("DANGER ZONE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Retro.warning)

                    Text("Deleting your club removes your entire Legends save: manager identity, squad, collection, Hall entries, division progress, Balance, pack tokens, facilities and challenges.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)

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
                    .accessibilityIdentifier("settings.deleteClub")
                    .accessibilityHint("Requires confirmation. Deletes the entire Legends save.")
                }
            }
        }
    }

    private var deleteConfirmationSheet: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(LegendsPalette.navy.opacity(0.2))
                .frame(width: 42, height: 5)
                .padding(.top, 10)

            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Retro.warning)
                    .accessibilityHidden(true)

                Text("DELETE THIS CLUB?")
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(LegendsPalette.navy)

                Text("This permanently removes your entire Legends save — manager identity, squad, collection, Hall entries, division progress, Balance, pack tokens, facilities and challenges. This can't be undone.")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)

            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    confirmingDelete = false
                } label: {
                    Text("KEEP MY CLUB")
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(LegendsPalette.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LegendsPalette.navy.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("settings.delete.cancel")

                Button {
                    Haptics.tap()
                    confirmingDelete = false
                    store.deleteClub()
                    onBack()
                } label: {
                    Text("DELETE CLUB PERMANENTLY")
                        .font(.system(.footnote, design: .monospaced).bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Retro.warning)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("settings.delete.confirm")
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - About

    private var aboutSection: some View {
        LegendsDashboardPanel(title: "ABOUT", icon: "r.square.fill", color: LegendsPalette.purple) {
            VStack(alignment: .leading, spacing: 8) {
                aboutRow("APP", "RSM Legends")
                aboutRow("VERSION", appVersion, identifier: "settings.about.version")
                aboutRow("MODE", "Offline card-collecting club management")
                Text("RSM Legends is an offline card-collecting mode built alongside Career Mode. Your collection, careers and club progress stay on this device.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                    .padding(.top, 2)
            }
        }
    }

    private func aboutRow(_ key: String, _ value: String, identifier: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy.opacity(0.55))
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(LegendsPalette.navy)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(key): \(value)")
        .modifier(OptionalIdentifier(identifier: identifier))
    }
}

private struct OptionalIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
