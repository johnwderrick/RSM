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
                    #if DEBUG
                    Button("RESET MANAGER ONBOARDING") { store.resetManagerOnboardingForDebug(); onBack() }
                        .buttonStyle(IdentitySecondaryButtonStyle())
                    #endif
                }
                .frame(maxWidth: 760)
            } else {
                Text("Manager profile not created yet.").foregroundStyle(LegendsPalette.navy)
            }
        }
        .sheet(isPresented: $editing) { LegendsManagerEditView(store: store) }
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

struct LegendsManagerEditView: View {
    let store: LegendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var surname = ""
    @State private var nationality = "England"
    @State private var dateOfBirth = Date()
    @State private var error: String?

    var body: some View {
        ZStack { LegendsPalette.navy.ignoresSafeArea(); VStack(spacing: 14) {
            Text("EDIT MANAGER IDENTITY").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.white)
            HStack(spacing: 10) { editField("FIRST NAME", text: $firstName); editField("SURNAME", text: $surname) }
            Picker("Nationality", selection: $nationality) { ForEach(nations, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu).tint(.white)
            DatePicker("DATE OF BIRTH", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date).foregroundStyle(.white)
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            HStack { Button("CANCEL") { dismiss() }.buttonStyle(IdentitySecondaryButtonStyle()); Button("SAVE") { save() }.buttonStyle(IdentityPrimaryButtonStyle(color: LegendsPalette.green)) }
        }.padding(24).frame(maxWidth: 620) }
        .onAppear { if let manager = store.profile.managerProfile { firstName = manager.firstName; surname = manager.surname; nationality = manager.nationalityCode; dateOfBirth = manager.dateOfBirth } }
    }

    private func editField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).identityLabel(); TextField(title, text: text).foregroundStyle(.white).padding(9).background(.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8)) }.frame(maxWidth: .infinity)
    }
    private func save() {
        guard var manager = store.profile.managerProfile else { return }
        let first = LegendsManagerIdentityValidation.cleanName(firstName); let last = LegendsManagerIdentityValidation.cleanName(surname)
        guard LegendsManagerIdentityValidation.validName(first), LegendsManagerIdentityValidation.validName(last) else { error = "Enter a valid first name and surname."; return }
        guard LegendsManagerIdentityValidation.validDateOfBirth(dateOfBirth) else { error = "Manager age must be between 30 and 70."; return }
        manager.firstName = first; manager.surname = last; manager.nationalityCode = nationality; manager.dateOfBirth = dateOfBirth
        store.profile.managerProfile = manager; store.persist(); dismiss()
    }
    private let nations = ["England", "Scotland", "Wales", "Republic of Ireland", "France", "Germany", "Italy", "Spain", "Portugal", "Netherlands", "Brazil", "Argentina", "Japan", "South Korea"]
}

private struct IdentityPrimaryButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.white).padding(.horizontal, 22).padding(.vertical, 12).background(color).clipShape(Capsule()).scaleEffect(configuration.isPressed ? 0.96 : 1) }
}
private struct IdentitySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.82)).padding(.horizontal, 18).padding(.vertical, 11).background(.white.opacity(0.12)).clipShape(Capsule()).scaleEffect(configuration.isPressed ? 0.96 : 1) }
}
private extension Text {
    func identityLabel() -> some View { self.font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.65)) }
}
