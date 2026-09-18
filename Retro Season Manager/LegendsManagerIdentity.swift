//
//  LegendsManagerIdentity.swift
//  Retro Season Manager
//
//  Persistent manager identity for RSM Legends. This is deliberately
//  independent from collectible manager cards and from Career Mode's
//  GameStore manager data.
//

import Foundation
import SwiftUI
import UIKit

struct LegendsManagerCareerStats: Codable, Hashable {
    var matches = 0
    var wins = 0
    var draws = 0
    var losses = 0
    var goalsScored = 0
    var goalsConceded = 0
    var promotions = 0
    var highestDivisionRawValue = LegendsDivision.division10.rawValue
    var packsOpened = 0
    var uniquePlayersCollected = 0
    var challengesCompleted = 0
    var trophies = 0
    var longestWinningStreak = 0

    var winPercentage: Int {
        guard matches > 0 else { return 0 }
        return Int((Double(wins) / Double(matches) * 100).rounded())
    }
}

enum LegendsManagerTrait: String, Codable, CaseIterable, Hashable {
    case masterPlanner = "MASTER PLANNER"
    case relentless = "RELENTLESS"
    case tacticalMind = "TACTICAL MIND"
    case fearless = "FEARLESS"
    case controlledChaos = "CONTROLLED CHAOS"
    case youthDeveloper = "YOUTH DEVELOPER"
    case bigGameManager = "BIG GAME MANAGER"
    case comebackKing = "COMEBACK KING"
    case defensiveMaster = "DEFENSIVE MASTER"
    case attackingGenius = "ATTACKING GENIUS"
    case motivator = "MOTIVATOR"
    case roadWarrior = "ROAD WARRIOR"
    case packSpecialist = "PACK SPECIALIST"
    case collector = "COLLECTOR"
}

enum LegendsManagerNickname: String, Codable, CaseIterable, Hashable {
    case architect = "THE ARCHITECT"
    case general = "THE GENERAL"
    case professor = "THE PROFESSOR"
    case maverick = "THE MAVERICK"
    case strategist = "THE STRATEGIST"
    case academyKing = "THE ACADEMY KING"
    case conqueror = "THE CONQUEROR"
    case invincible = "THE INVINCIBLE"
    case collector = "THE COLLECTOR"
    case giantKiller = "THE GIANT KILLER"
    case tactician = "THE TACTICIAN"
    case entertainer = "THE ENTERTAINER"
    case wall = "THE WALL"
    case comebackKing = "THE COMEBACK KING"
    case legend = "THE LEGEND"
}

enum LegendsManagerArchetype: String, Codable, CaseIterable, Identifiable, Hashable {
    case architect, general, professor, maverick, strategist

    var id: String { rawValue }
    var nickname: LegendsManagerNickname {
        switch self {
        case .architect: return .architect
        case .general: return .general
        case .professor: return .professor
        case .maverick: return .maverick
        case .strategist: return .strategist
        }
    }
    var personality: String {
        switch self {
        case .architect: return "Calm • Cerebral • Demanding"
        case .general: return "Intense • Disciplined • Motivational"
        case .professor: return "Experienced • Analytical • Composed"
        case .maverick: return "Bold • Ambitious • Unpredictable"
        case .strategist: return "Patient • Methodical • Pragmatic"
        }
    }
    var philosophy: String {
        switch self {
        case .architect: return "POSSESSION"
        case .general: return "HIGH PRESS"
        case .professor: return "BALANCED"
        case .maverick: return "ATTACKING"
        case .strategist: return "COUNTER ATTACK"
        }
    }
    var formation: String {
        switch self {
        case .architect: return "4-3-3"
        case .general, .professor: return "4-2-3-1"
        case .maverick: return "4-3-3 ATTACK"
        case .strategist: return "4-1-4-1"
        }
    }
    var alternativeFormations: [String] {
        switch self {
        case .architect: return ["4-2-3-1"]
        case .general: return ["4-3-3"]
        case .professor: return ["4-3-3", "4-4-2"]
        case .maverick: return ["4-2-4"]
        case .strategist: return ["5-3-2"]
        }
    }
    var tempo: String {
        switch self {
        case .architect: return "PATIENT"
        case .general: return "VERY HIGH"
        case .professor: return "ADAPTIVE"
        case .maverick: return "FAST"
        case .strategist: return "CONTROLLED"
        }
    }
    var pressing: String {
        switch self {
        case .architect: return "MEDIUM-HIGH"
        case .general: return "VERY HIGH"
        case .professor: return "MEDIUM"
        case .maverick: return "HIGH"
        case .strategist: return "LOW-MEDIUM"
        }
    }
    var defensiveLine: String {
        switch self {
        case .architect, .general, .maverick: return "HIGH"
        case .professor: return "MEDIUM"
        case .strategist: return "MEDIUM-LOW"
        }
    }
    var width: String {
        switch self {
        case .architect, .maverick: return "WIDE"
        case .general: return "BALANCED"
        case .professor: return "ADAPTIVE"
        case .strategist: return "COMPACT"
        }
    }
    var trait: LegendsManagerTrait {
        switch self {
        case .architect: return .masterPlanner
        case .general: return .relentless
        case .professor: return .tacticalMind
        case .maverick: return .fearless
        case .strategist: return .controlledChaos
        }
    }
    var description: String {
        switch self {
        case .architect: return "The Architect controls matches through possession, intelligent movement and technical quality. His teams are built rather than assembled."
        case .general: return "The General demands intensity from the first whistle to the last. His teams press relentlessly and refuse to give opponents time to breathe."
        case .professor: return "The Professor believes every opponent presents a different problem. Preparation and tactical flexibility are his greatest weapons."
        case .maverick: return "The Maverick believes football should entertain. Attack first, trust talented players and never be afraid to take risks."
        case .strategist: return "The Strategist builds success from organisation. His teams absorb pressure, remain disciplined and attack decisively when opportunities appear."
        }
    }
    var accent: Color {
        switch self {
        case .architect: return LegendsPalette.green
        case .general: return .red
        case .professor: return LegendsPalette.blue
        case .maverick: return LegendsPalette.orange
        case .strategist: return LegendsPalette.purple
        }
    }
    var portraitAsset: String { "Manager\(rawValue.capitalized)Portrait" }
    var fullBodyAsset: String { "Manager\(rawValue.capitalized)FullBody" }
}

struct LegendsManagerProfile: Codable, Hashable {
    var firstName: String
    var surname: String
    var nationalityCode: String
    var dateOfBirth: Date
    var archetype: LegendsManagerArchetype
    var reputation: Int = 0
    var careerStats = LegendsManagerCareerStats()
    var earnedTraits: Set<LegendsManagerTrait>
    var earnedNicknames: Set<LegendsManagerNickname>
    var activeNickname: LegendsManagerNickname

    var displayName: String { "\(firstName) \(surname)" }

    init(firstName: String, surname: String, nationalityCode: String, dateOfBirth: Date, archetype: LegendsManagerArchetype) {
        self.firstName = firstName
        self.surname = surname
        self.nationalityCode = nationalityCode
        self.dateOfBirth = dateOfBirth
        self.archetype = archetype
        self.earnedTraits = [archetype.trait]
        self.earnedNicknames = [archetype.nickname]
        self.activeNickname = archetype.nickname
    }

    var reputationTier: String {
        switch reputation {
        case 80...: return "LEGEND"
        case 65..<80: return "ICON"
        case 50..<65: return "RESPECTED"
        case 35..<50: return "ESTABLISHED"
        case 15..<35: return "PROSPECT"
        default: return "UNKNOWN"
        }
    }

    func age(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.year], from: dateOfBirth, to: referenceDate).year ?? 0)
    }
}

enum LegendsManagerIdentityValidation {
    static let maximumNameLength = 28

    static func cleanName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func validName(_ value: String) -> Bool {
        let clean = cleanName(value)
        guard !clean.isEmpty, clean.count <= maximumNameLength else { return false }
        return clean.unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar) || scalar == "'" || scalar == "-" || scalar == " "
        }
    }

    static func validDateOfBirth(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let age = calendar.dateComponents([.year], from: date, to: now).year ?? 0
        return (30...70).contains(age) && date <= now
    }
}

extension LegendsManagerProfile {
    /// Transforms this manager in place with a confirmed identity edit.
    /// Only identity fields change; XP, level (stored on LegendsProfile),
    /// career statistics, reputation, earned traits/nicknames and the active
    /// nickname are deliberately untouched. Returns false when the values
    /// are invalid (nothing is modified).
    mutating func applyIdentityEdit(firstName: String, surname: String,
                                    nationalityCode: String, dateOfBirth: Date,
                                    archetype: LegendsManagerArchetype) -> Bool {
        let cleanFirst = LegendsManagerIdentityValidation.cleanName(firstName)
        let cleanLast = LegendsManagerIdentityValidation.cleanName(surname)
        guard LegendsManagerIdentityValidation.validName(cleanFirst),
              LegendsManagerIdentityValidation.validName(cleanLast),
              LegendsManagerIdentityValidation.validDateOfBirth(dateOfBirth) else { return false }
        self.firstName = cleanFirst
        self.surname = cleanLast
        self.nationalityCode = nationalityCode
        self.dateOfBirth = dateOfBirth
        self.archetype = archetype
        return true
    }
}

extension LegendsStore {
    /// Applies a confirmed manager identity edit to the stored manager.
    /// The transform is strictly identity-only and idempotent: XP, level,
    /// career statistics, reputation, earned traits/nicknames and all other
    /// Legends progression are untouched, and re-applying the same values
    /// produces exactly the same state as applying them once. Returns false
    /// (with no change) when there is no manager or the values are invalid.
    @discardableResult
    func applyManagerIdentityEdit(firstName: String, surname: String,
                                  nationalityCode: String, dateOfBirth: Date,
                                  archetype: LegendsManagerArchetype) -> Bool {
        guard var manager = profile.managerProfile,
              manager.applyIdentityEdit(firstName: firstName, surname: surname,
                                        nationalityCode: nationalityCode,
                                        dateOfBirth: dateOfBirth, archetype: archetype) else { return false }
        profile.managerProfile = manager
        // Critical one-time action: always written, even with Auto-Save off.
        persistNow()
        return true
    }
}

extension LegendsStore {
    /// Uses LegendsStore's existing managerLevel/managerXP as the only
    /// canonical level system; identity stores only identity-specific data.
    func recordManagerMatch(_ result: LegendsMatchEngine.Result,
                            divisionSeasonResult: LegendsDivisionSeasonResult?,
                            completedChallengeCount: Int) {
        guard var manager = profile.managerProfile else { return }
        manager.careerStats.matches += 1
        manager.careerStats.goalsScored += result.teamGoals
        manager.careerStats.goalsConceded += result.opponentGoals
        switch result.outcome {
        case .win:
            manager.careerStats.wins += 1
            manager.careerStats.longestWinningStreak = max(manager.careerStats.longestWinningStreak, profile.currentWinStreak)
        case .draw: manager.careerStats.draws += 1
        case .loss: manager.careerStats.losses += 1
        }
        if let divisionSeasonResult {
            if divisionSeasonResult.outcome == .champion || divisionSeasonResult.outcome == .promoted {
                manager.careerStats.promotions += 1
                manager.reputation = min(100, manager.reputation + 6)
            }
            if divisionSeasonResult.outcome == .champion { manager.careerStats.trophies += 1 }
        }
        manager.careerStats.highestDivisionRawValue = min(manager.careerStats.highestDivisionRawValue, profile.division.rawValue)
        manager.careerStats.uniquePlayersCollected = profile.ownedCardIDs.count
        manager.careerStats.challengesCompleted += completedChallengeCount
        if profile.currentWinStreak >= 10 { manager.earnedNicknames.insert(.invincible) }
        if profile.ownedCardIDs.count >= 30 { manager.earnedNicknames.insert(.collector) }
        if profile.division == .worldLeague && result.outcome == .win { manager.earnedNicknames.insert(.conqueror) }
        if completedChallengeCount > 0 { manager.reputation = min(100, manager.reputation + 1) }
        profile.managerProfile = manager
        persist()
    }

    func recordManagerPackOpened() {
        guard var manager = profile.managerProfile else { return }
        manager.careerStats.packsOpened += 1
        manager.careerStats.uniquePlayersCollected = profile.ownedCardIDs.count
        profile.managerProfile = manager
        persist()
    }

    #if DEBUG
    func resetManagerOnboardingForDebug() {
        profile.managerProfile = nil
        persist()
    }
    #endif
}

struct LegendsManagerProfileView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    let onBack: () -> Void
    @State private var editing = false

    var body: some View {
        LegendsMenuShell(store: store, title: "MANAGER PROFILE", subtitle: "YOUR LEGENDS IDENTITY", icon: "person.crop.circle.fill", accent: LegendsPalette.green, onBack: onBack, currentNav: .profile, onNavigate: onNavigate) {
            if let manager = store.profile.managerProfile {
                VStack(spacing: 14) {
                    identityHero(manager)
                    statsPanel(manager)
                    tacticalPanel(manager)
                    nicknamePanel(manager)
                    editManagerButton
                    #if DEBUG
                    Button("RESET MANAGER ONBOARDING") { store.resetManagerOnboardingForDebug(); onBack() }
                        .buttonStyle(IdentitySecondaryButtonStyle())
                        .accessibilityIdentifier("manager.resetOnboarding")
                    #endif
                }
                .frame(maxWidth: 760)
            } else {
                Text("Manager profile not created yet.").foregroundStyle(LegendsPalette.navy)
            }
        }
        .sheet(isPresented: $editing) {
            LegendsManagerEditView(
                store: store,
                onCancel: { editing = false },
                onSave: { editing = false }
            )
                .accessibilityIdentifier("legends.managerEdit")
        }
    }

    /// The dedicated EDIT MANAGER action: a full-width primary row below the
    /// panels (alongside the compact EDIT in the identity hero), opening the
    /// polished identity-editing flow.
    private var editManagerButton: some View {
        Button {
            editing = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                Text("EDIT MANAGER")
            }
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(LegendsPalette.green)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier("manager.editManager")
    }

    private func identityHero(_ manager: LegendsManagerProfile) -> some View {
        HStack(spacing: 16) {
            managerPortrait(manager.archetype).frame(width: 110, height: 110).clipShape(Circle()).overlay(Circle().stroke(manager.archetype.accent, lineWidth: 3))
            VStack(alignment: .leading, spacing: 5) {
                Text(manager.displayName.uppercased()).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(LegendsPalette.navy)
                Text(manager.activeNickname.rawValue).font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(manager.archetype.accent)
                HStack(spacing: 5) { FlagView(nationality: manager.nationalityCode, width: 18); Text("\(manager.nationalityCode) · AGE \(manager.age())") }
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.65))
                Text("MANAGER LEVEL \(store.profile.managerLevel) · \(store.profile.managerXP) / \(max(1, store.profile.managerLevel * 100)) XP")
                    .font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.blue)
                LegendsProgressBar(value: Double(store.profile.managerXP) / Double(max(1, store.profile.managerLevel * 100)), tint: LegendsPalette.green, height: 8)
            }
            Spacer()
            Button("EDIT") { editing = true }.buttonStyle(IdentitySecondaryButtonStyle())
        }
        .padding(16).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(manager.archetype.accent.opacity(0.35), lineWidth: 2))
    }

    private func statsPanel(_ manager: LegendsManagerProfile) -> some View {
        LegendsDashboardPanel(title: "CAREER STATISTICS · \(manager.reputationTier)", icon: "chart.bar.fill", color: LegendsPalette.blue) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                profileStat("MATCHES", "\(manager.careerStats.matches)"); profileStat("WINS", "\(manager.careerStats.wins)"); profileStat("WIN %", "\(manager.careerStats.winPercentage)%")
                profileStat("PROMOTIONS", "\(manager.careerStats.promotions)"); profileStat("BEST DIV", manager.careerStats.highestDivisionRawValue == 0 ? "WORLD" : "DIV \(manager.careerStats.highestDivisionRawValue)"); profileStat("REPUTATION", "\(manager.reputation)/100")
                profileStat("PACKS", "\(manager.careerStats.packsOpened)"); profileStat("COLLECTED", "\(manager.careerStats.uniquePlayersCollected)"); profileStat("TROPHIES", "\(manager.careerStats.trophies)")
            }
        }
    }

    private func tacticalPanel(_ manager: LegendsManagerProfile) -> some View {
        LegendsDashboardPanel(title: "MANAGER IDENTITY", icon: "scope", color: manager.archetype.accent) {
            HStack(alignment: .top, spacing: 18) { profileStat("STYLE", manager.archetype.philosophy); profileStat("FORMATION", manager.archetype.formation); profileStat("TRAIT", manager.archetype.trait.rawValue); Spacer() }
        }
    }

    private func nicknamePanel(_ manager: LegendsManagerProfile) -> some View {
        LegendsDashboardPanel(title: "EARNED NICKNAMES", icon: "rosette", color: LegendsPalette.gold) {
            ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(Array(manager.earnedNicknames).sorted { $0.rawValue < $1.rawValue }, id: \.self) { nickname in Text(nickname.rawValue).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(nickname == manager.activeNickname ? LegendsPalette.navy : LegendsPalette.navy.opacity(0.45)).padding(7).background(nickname == manager.activeNickname ? LegendsPalette.goldWash : LegendsPalette.contentBackground).clipShape(Capsule()) } } }
        }
    }

    private func profileStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(value).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(LegendsPalette.navy); Text(title).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.55)) }
    }

    @ViewBuilder private func managerPortrait(_ option: LegendsManagerArchetype) -> some View {
        // scaledToFill, not scaledToFit — see LegendsManagerOnboardingView's
        // managerArtwork for why: the source photos aren't square, so
        // scaledToFit left a gap at the circle's edges.
        if UIImage(named: option.portraitAsset) != nil { Image(option.portraitAsset).resizable().scaledToFill() }
        else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(option.accent).padding(12) }
    }
}

/// Edits an established manager's identity: archetype/appearance, names,
/// nationality and date of birth. Mirrors the polished creation flow step
/// for step (same full-body aspect-correct artwork, same validation, same
/// review/confirmation stage) while staying a strictly separate flow: it
/// never touches the new-profile completion path and only ever transforms
/// the existing `LegendsManagerProfile`, so XP, level, career statistics,
/// earned nicknames, reputation, club identity and all Legends progression
/// are preserved untouched.
struct LegendsManagerEditView: View {
    let store: LegendsStore
    var onCancel: () -> Void = {}
    var onSave: () -> Void = {}
    @State private var archetype: LegendsManagerArchetype?
    @State private var step = 0
    @State private var firstName = ""
    @State private var surname = ""
    @State private var nationality = "England"
    @State private var dateOfBirth = Date()
    @State private var hasAppliedEdit = false

    private var cleanFirstName: String { LegendsManagerIdentityValidation.cleanName(firstName) }
    private var cleanSurname: String { LegendsManagerIdentityValidation.cleanName(surname) }
    private var namesValid: Bool {
        LegendsManagerIdentityValidation.validName(cleanFirstName) && LegendsManagerIdentityValidation.validName(cleanSurname)
    }
    private var dateValid: Bool { LegendsManagerIdentityValidation.validDateOfBirth(dateOfBirth) }
    /// True when the reviewed draft would change the stored identity. An
    /// unchanged draft can still be confirmed and closed without rewriting
    /// the saved profile.
    private var draftDiffers: Bool {
        guard let stored = store.profile.managerProfile else { return false }
        return archetype != stored.archetype
            || cleanFirstName != stored.firstName
            || cleanSurname != stored.surname
            || nationality != stored.nationalityCode
            || dateOfBirth != stored.dateOfBirth
    }

    var body: some View {
        ZStack {
            LegendsPalette.navy.ignoresSafeArea()
            Group {
                switch step {
                case 0: selection
                case 1: customization
                default: confirmation
                }
            }
            .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.2), value: step)
        .onAppear { loadStoredManager() }
        .interactiveDismissDisabled(step == 2)
    }

    private func loadStoredManager() {
        guard let manager = store.profile.managerProfile else { return }
        archetype = manager.archetype
        firstName = manager.firstName
        surname = manager.surname
        nationality = manager.nationalityCode
        dateOfBirth = manager.dateOfBirth
    }

    private var selection: some View {
        // Same landscape reachability contract as creation's selection step:
        // heading + full-body cards + detail panel + action exceed ~402pt of
        // landscape height, so the step owns a vertical scroll container.
        ScrollView {
            VStack(spacing: 14) {
                heading("EDIT YOUR MANAGER", subtitle: "Redefine the identity that leads your club. Your career continues untouched.")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(LegendsManagerArchetype.allCases) { option in
                            archetypeCard(option)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
                if let selected = archetype {
                    detailPanel(selected)
                    HStack {
                        Button("CANCEL") { onCancel() }.buttonStyle(IdentitySecondaryButtonStyle())
                            .accessibilityIdentifier("identity.edit.cancel")
                        Button("CONTINUE") { step = 1 }
                            .buttonStyle(IdentityPrimaryButtonStyle(color: selected.accent))
                            .accessibilityIdentifier("identity.edit.continue")
                    }
                } else {
                    Text("SELECT A PROFILE TO CONTINUE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(18)
        }
    }

    private var customization: some View {
        // Same keyboard/reachability contract as creation's customization
        // step: the scroll container reveals the action on compact phones,
        // and tapping outside the fields dismisses the keyboard where the
        // content fits the viewport (iPad compatibility mode).
        ScrollView {
            VStack(spacing: 16) {
                heading("MANAGER DETAILS", subtitle: "Update the name and details shown throughout your Legends career.")
                if let selected = archetype {
                    HStack(spacing: 14) {
                        ManagerIdentityArtwork.aspectFit(selected)
                            .frame(width: 92, height: 188)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selected.nickname.rawValue).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white)
                            Text("\(selected.philosophy) · \(selected.formation)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(selected.accent)
                        }
                    }
                }
                HStack(spacing: 12) {
                    editField("FIRST NAME", text: $firstName)
                    editField("SURNAME", text: $surname)
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("NATIONALITY").identityLabel()
                        Picker("Nationality", selection: $nationality) {
                            ForEach(LegendsManagerNations.all, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        .padding(8)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("identity.edit.nationality")
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("DATE OF BIRTH").identityLabel()
                        DatePicker("Date of Birth", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .tint(.white)
                            .padding(4)
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityIdentifier("identity.edit.dob")
                    }
                }
                if !namesValid { Text("Enter a first name and surname using letters, apostrophes or hyphens.").identityError() }
                if !dateValid { Text("Manager age must be between 30 and 70.").identityError() }
                HStack {
                    Button("BACK") { step = 0 }.buttonStyle(IdentitySecondaryButtonStyle())
                    Button("REVIEW PROFILE") { step = 2 }.buttonStyle(IdentityPrimaryButtonStyle(color: archetype?.accent ?? LegendsPalette.green)).disabled(!namesValid || !dateValid || archetype == nil)
                        .accessibilityIdentifier("identity.edit.review")
                }
            }
            .padding(24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { hideKeyboard() }
    }

    private var confirmation: some View {
        // Same scroll-container contract as creation's confirmation step.
        ScrollView {
            VStack(spacing: 13) {
                heading("REVIEW CHANGES", subtitle: "Your club career continues — XP, records, squad and progression are kept.")
                if let selected = archetype {
                    HStack(spacing: 18) {
                        ManagerIdentityArtwork.aspectFit(selected)
                            .frame(width: 116, height: 242)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected.accent, lineWidth: 3))
                        VStack(alignment: .leading, spacing: 7) {
                            Text("\(cleanFirstName) \(cleanSurname)".uppercased()).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(.white)
                            Text("\"\(selected.nickname.rawValue)\"").font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(selected.accent)
                            Text("\(nationality) · AGE \(LegendsManagerProfile(firstName: cleanFirstName, surname: cleanSurname, nationalityCode: nationality, dateOfBirth: dateOfBirth, archetype: selected).age())")
                                .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    HStack(spacing: 25) {
                        summaryValue("STYLE", selected.philosophy)
                        summaryValue("FORMATION", selected.formation)
                        summaryValue("TRAIT", selected.trait.rawValue)
                    }
                    Text("Your manager level, XP, career statistics, squad, collection and all progression carry over unchanged.")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.72)).multilineTextAlignment(.center).frame(maxWidth: 600)
                        .accessibilityIdentifier("identity.edit.promise")
                    HStack {
                        Button("BACK") { step = 1 }.buttonStyle(IdentitySecondaryButtonStyle())
                        Button("CANCEL") { onCancel() }.buttonStyle(IdentitySecondaryButtonStyle())
                            .accessibilityIdentifier("identity.edit.cancel")
                        Button("SAVE MANAGER") { applyEdit() }
                            .buttonStyle(IdentityPrimaryButtonStyle(color: selected.accent))
                            .disabled(hasAppliedEdit)
                            .accessibilityIdentifier("identity.edit.apply")
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    /// Applies the confirmed edit exactly once, transforming only the
    /// identity fields of the stored manager.
    private func applyEdit() {
        guard !hasAppliedEdit else { return }
        guard let selected = archetype,
              namesValid, dateValid,
              store.profile.managerProfile != nil else { return }
        hasAppliedEdit = true
        if draftDiffers,
           !store.applyManagerIdentityEdit(firstName: cleanFirstName, surname: cleanSurname,
                                           nationalityCode: nationality, dateOfBirth: dateOfBirth,
                                           archetype: selected) {
            hasAppliedEdit = false
            return
        }
        Haptics.success()
        onSave()
    }

    private func editField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).identityLabel()
            TextField(title, text: text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .padding(10)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity)
    }

    private func archetypeCard(_ option: LegendsManagerArchetype) -> some View {
        let selected = archetype == option
        return Button {
            Haptics.tap()
            archetype = option
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    LinearGradient(colors: [option.accent.opacity(0.95), LegendsPalette.navy], startPoint: .top, endPoint: .bottom)
                    ManagerIdentityArtwork.aspectFit(option)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                }
                .frame(width: 142, height: 297)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? .white : option.accent.opacity(0.55), lineWidth: selected ? 3 : 1))
                Text(option.nickname.rawValue)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(option.philosophy)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(option.accent)
            }
            .scaleEffect(selected ? 1.04 : 0.96)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(option.nickname.rawValue). \(option.philosophy) manager. Preferred formation \(option.formation).")
        .accessibilityIdentifier("identity.archetypeCard.\(option.rawValue)")
    }

    private func detailPanel(_ option: LegendsManagerArchetype) -> some View {
        HStack(spacing: 12) {
            ManagerIdentityArtwork.fill(option, fullBody: false)
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(option.accent, lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                Text(option.nickname.rawValue).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("\(option.philosophy) · \(option.formation) · \(option.trait.rawValue)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(option.accent)
                Text(option.description)
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.72)).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryValue(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) { Text(title).identityLabel(); Text(value).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.white) }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 5) {
            Text("RSM LEGENDS").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.green)
            Text(title).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white)
            Text(subtitle).font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Identity button/label styling is shared with manager creation and lives in
// LegendsManagerOnboardingView.swift (IdentityPrimaryButtonStyle,
// IdentitySecondaryButtonStyle, Text.identityLabel).
