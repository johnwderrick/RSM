import SwiftUI

#if DEBUG
extension LegendsStore {
    /// Deterministic UI-test fixture for the redesigned Career Planning and
    /// Season Reports destinations.
    ///
    /// Planning side: the fully signed starter squad (mixed ages and career
    /// stages) with seeded careers whose intended retirement ages produce
    /// players retiring next season, within three seasons, and further out;
    /// two unsigned goalkeeper candidates so Replacement Watch has real
    /// matches; a varied age distribution via `cardAgeOffsets`.
    ///
    /// Reports side: three persisted season reports in the authoritative
    /// `profile.seasonReports` map, with Improved / Stable / Declining /
    /// Final Season / Retired entries, attribute gains and a squad-age
    /// warning. Presentation only — no season roll, retirement, or
    /// development calculation is executed here.
    func preparePlanningReportsFixtureForDebug() {
        profile = .starter()
        profile.managerProfile = LegendsManagerProfile(
            firstName: "Test", surname: "Manager", nationalityCode: "GB",
            dateOfBirth: Date(timeIntervalSince1970: 315_532_800), archetype: .architect
        )
        migrateOwnedPlayerRecords()

        // Two unsigned goalkeeper candidates with distinct names so the
        // Replacement Watch suggestions are deterministic and readable.
        profile.ownedCardIDs.insert("cechinho-0607")
        profile.ownedCardIDs.insert("casillante-0405")
        // A veteran cohort of higher-rarity cards the starter squad doesn't
        // include. Signing them (activated ⇒ signed by the migration) gives
        // the Retirement Radar deterministic next-season and within-three-
        // seasons groups alongside the starter squad's own players.
        for id in ["modricek-1617", "keegana-9394", "walkerino-1819",
                   "alabana-1920", "debrugne-2122", "baggino-9394", "hagiwara-9394"] {
            profile.ownedCardIDs.insert(id)
            profile.activatedCardIDs.insert(id)
        }
        migrateOwnedPlayerRecords()

        // Every signed player gets a real career record so stages, ages and
        // retirement distances come from the authoritative model.
        for card in activeClubPlayers where profile.playerCareers[card.id] == nil {
            profile.playerCareers[card.id] = Self.makeCareerState(for: card, signedSeason: profile.currentSeason)
        }

        // Deterministic age spread: two veterans projected to retire next
        // season (age = intendedRetirementAge - 1 ⇒ final-season + radar),
        // more within three seasons, and a varied young core. Offsets only
        // move the displayed age; the lifecycle policy stays authoritative.
        // Intended retirement ages from LegendsCareerLifecyclePolicy's
        // stable seeds: modricek-1617 → 37, keegana-9394 → 35,
        // walkerino-1819 → 37, alabana-1920 → 34, debrugne-2122 → 35,
        // baggino-9394 → 37 (late developer), hagiwara-9394 → 35.
        // Offsets place two of them exactly one season before retirement
        // (the next-season radar band) and the rest within three seasons.
        let ageOffsets: [String: Int] = [
            "modricek-1617": 6,   // 30 + 6 = 36 → retires at 37 (next season)
            "keegana-9394": 3,    // 31 + 3 = 34 → retires at 35 (next season)
            "walkerino-1819": 6,  // 28 + 6 = 34 → retires at 37 (within 3)
            "alabana-1920": 5,    // 27 + 5 = 32 → retires at 34 (within 3)
            "debrugne-2122": 5,   // 28 + 5 = 33 → retires at 35 (within 3)
            "baggino-9394": 6,    // 27 + 6 = 33 → retires at 37 (within 3)
            "hagiwara-9394": 5,   // 28 + 5 = 33 → retires at 35 (within 3)
            "bellinghast-2324": 1,
        ]
        for (id, offset) in ageOffsets where profile.playerCareers[id] != nil {
            profile.cardAgeOffsets[id] = offset
        }

        // A varied age distribution across the whole signed squad.
        let extraAges: [String: Int] = [
            "miessi-1112": 2, "renaldo-1314": 1, "iniestra-1011": 1,
            "aguerro-1112": 2, "hazardly-1415": 1, "kantay-1617": 1,
            "mbappa-2223": 1, "holland-2223": 2, "junior-2324": 1,
        ]
        for (id, offset) in extraAges where profile.playerCareers[id] != nil {
            profile.cardAgeOffsets[id] = (profile.cardAgeOffsets[id] ?? 0) + offset
        }

        // Three season reports with every category represented. Fields are
        // copies of what the real season roll persists (see
        // LegendsStore+Aging.swift closeSeason report construction).
        func entry(_ cardID: String, _ name: String, season: Int, ageBefore: Int, ageAfter: Int,
                   ovrBefore: Int, ovrAfter: Int, improved: Bool = false, stable: Bool = false,
                   declined: Bool = false, finalSeason: Bool = false, retired: Bool = false,
                   focus: LegendsDevelopmentFocus = .balanced, intensity: LegendsTrainingIntensity = .normal,
                   sessions: Int = 0, gains: [String: Int] = [:], explanation: String = "No training completed.",
                   position: DetailedPosition = .centralMid, favourite: Bool = false,
                   profile: LegendsCareerLifecyclePolicy.DevelopmentProfile = .standardDeveloper,
                   retirementRecordID: String? = nil) -> LegendsSeasonReportEntry {
            LegendsSeasonReportEntry(cardID: cardID, playerName: name, completedSeason: season,
                                     ageBefore: ageBefore, ageAfter: ageAfter, overallBefore: ovrBefore,
                                     overallAfter: ovrAfter, previousStage: "PRIME", newStage: "PRIME",
                                     developmentProfile: profile, improved: improved, stable: stable,
                                     declined: declined, enteredFinalSeason: finalSeason, retired: retired,
                                     retirementRecordID: retirementRecordID, position: position,
                                     favourite: favourite, attributeDeltas: [:],
                                     trainingFocus: focus, trainingIntensity: intensity,
                                     trainingSessions: sessions, trainingProgress: sessions > 0 ? 60 : 0,
                                     trainingAttributeGains: gains, trainingExplanation: explanation)
        }

        profile.seasonReports[3] = LegendsSeasonDevelopmentReport(
            season: 3,
            entries: [
                entry("miessi-1112", "L. Miessi", season: 3, ageBefore: 26, ageAfter: 27,
                      ovrBefore: 91, ovrAfter: 92, improved: true, focus: .dribbling,
                      intensity: .intensive, sessions: 4,
                      gains: ["Dribbling": 1, "Agility": 1],
                      explanation: "Intensive dribbling focus sharpened close control.",
                      position: .rightWing),
                entry("iniestra-1011", "A. Iniestra", season: 3, ageBefore: 28, ageAfter: 29,
                      ovrBefore: 88, ovrAfter: 88, stable: true, focus: .passing,
                      intensity: .normal, sessions: 2, gains: ["Passing": 1],
                      explanation: "Normal load kept passing crisp; overall held at peak.",
                      position: .centralMid),
                entry("modricek-1617", "L. Modricek", season: 3, ageBefore: 35, ageAfter: 36,
                      ovrBefore: 82, ovrAfter: 80, declined: true, focus: .passing,
                      intensity: .light, sessions: 1, gains: ["Passing": 1],
                      explanation: "Light load managed legs; pace declined with age.",
                      position: .centralMid),
                entry("keegana-9394", "K. Keegana", season: 3, ageBefore: 33, ageAfter: 34,
                      ovrBefore: 76, ovrAfter: 74, finalSeason: true,
                      explanation: "Enters the final contracted season.", position: .rightBack),
                entry("walkerino-1819", "T. Walkerino", season: 3, ageBefore: 32, ageAfter: 33,
                      ovrBefore: 78, ovrAfter: 76, declined: true,
                      explanation: "First decline past the peak years.", position: .rightBack),
                entry("mbappa-2223", "K. Mbappa", season: 3, ageBefore: 24, ageAfter: 25,
                      ovrBefore: 93, ovrAfter: 94, improved: true, focus: .shooting,
                      intensity: .intensive, sessions: 5,
                      gains: ["Finishing": 1, "Composure": 1],
                      explanation: "Elite shooting focus converted into a higher ceiling.",
                      position: .striker, favourite: true,
                      profile: .prodigy),
                entry("bellinghast-2324", "J. Bellinghast", season: 3, ageBefore: 21, ageAfter: 22,
                      ovrBefore: 84, ovrAfter: 86, improved: true, focus: .passing,
                      intensity: .normal, sessions: 3, gains: ["Passing": 1, "Vision": 1],
                      explanation: "Balanced development continued toward prime years.",
                      position: .centralMid),
                entry("buffonte-0506", "G. Buffonte", season: 3, ageBefore: 30, ageAfter: 31,
                      ovrBefore: 85, ovrAfter: 85, stable: true,
                      explanation: "Goalkeeper prime continues uninterrupted.",
                      position: .goalkeeper),
            ],
            squadAgeWarning: "Several starters are projected to retire next season.",
            positionsNeedingReplacements: ["Defender", "Midfielder"],
            signedAverageAgeAfter: 29)

        profile.seasonReports[2] = LegendsSeasonDevelopmentReport(
            season: 2,
            entries: [
                entry("modricek-1617", "L. Modricek", season: 2, ageBefore: 34, ageAfter: 35,
                      ovrBefore: 84, ovrAfter: 82, declined: true,
                      explanation: "Age-related decline began in midfield.", position: .centralMid),
                entry("holland-2223", "E. Holland", season: 2, ageBefore: 24, ageAfter: 25,
                      ovrBefore: 88, ovrAfter: 89, improved: true, focus: .shooting,
                      intensity: .normal, sessions: 3, gains: ["Finishing": 1],
                      explanation: "Steady shooting work added a goal threat.", position: .striker),
                entry("casillante", "I. Casillante", season: 2, ageBefore: 25, ageAfter: 26,
                      ovrBefore: 79, ovrAfter: 79, stable: true,
                      explanation: "Reliable backup season.", position: .goalkeeper),
            ],
            signedAverageAgeAfter: 28)

        profile.seasonReports[1] = LegendsSeasonDevelopmentReport(
            season: 1,
            entries: [
                entry("modricek-1617", "L. Modricek", season: 1, ageBefore: 32, ageAfter: 33,
                      ovrBefore: 86, ovrAfter: 86, stable: true,
                      explanation: "First season at the club; held peak form.", position: .centralMid),
                entry("keegana-9394", "K. Keegana", season: 1, ageBefore: 31, ageAfter: 32,
                      ovrBefore: 79, ovrAfter: 78, declined: true,
                      explanation: "Veteran legs managed carefully.", position: .rightBack),
                entry("miessi-1112", "L. Miessi", season: 1, ageBefore: 24, ageAfter: 25,
                      ovrBefore: 89, ovrAfter: 90, improved: true, focus: .dribbling,
                      intensity: .normal, sessions: 2, gains: ["Dribbling": 1],
                      explanation: "Dribbling focus paid off immediately.", position: .rightWing),
                entry("laudrupo-9293", "M. Laudrupo", season: 1, ageBefore: 29, ageAfter: 30,
                      ovrBefore: 84, ovrAfter: 84, retired: true,
                      explanation: "Retired after a distinguished debut season.",
                      position: .attackingMid, retirementRecordID: "ui-reports-laudrupo"),
            ],
            squadAgeWarning: "The squad is ageing in key positions.",
            signedAverageAgeAfter: 30)

        persist()
    }
}
#endif
