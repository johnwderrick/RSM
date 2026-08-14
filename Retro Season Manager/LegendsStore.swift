//
//  LegendsStore.swift
//  Retro Season Manager
//
//  The single source of truth for RSM Legends — a standalone collecting
//  mode with its own save file and progression, entirely separate from
//  Career Mode's GameStore. Mirrors GameStore's own single-observable,
//  file-per-domain convention rather than introducing several small
//  observables for one mode.
//

import Foundation
import SwiftUI

enum LegendsDivision: Int, Codable, CaseIterable {
    case worldLeague = 0
    case division1 = 1, division2, division3, division4, division5
    case division6, division7, division8, division9, division10

    var displayName: String {
        self == .worldLeague ? "World League" : "Division \(rawValue)"
    }
}

struct LegendsProfile: Codable {
    var clubName: String
    var crestShort: String
    var crestColorRGB: [Double]
    var managerLevel: Int
    var managerXP: Int
    var coins: Int
    var packTokens: Int
    var division: LegendsDivision
    var teamRating: Int

    static func starter() -> LegendsProfile {
        LegendsProfile(clubName: "RSM Legends FC", crestShort: "RSM",
                        crestColorRGB: [0.10, 0.76, 0.35],
                        managerLevel: 1, managerXP: 0,
                        coins: 500, packTokens: 3,
                        division: .division10, teamRating: 0)
    }
}

@MainActor
@Observable
final class LegendsStore {
    private(set) var profile: LegendsProfile

    init() {
        profile = Self.load() ?? .starter()
    }

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("legends_profile.json")
    }

    private static func load() -> LegendsProfile? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(LegendsProfile.self, from: data)
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: Self.fileURL)
    }
}
