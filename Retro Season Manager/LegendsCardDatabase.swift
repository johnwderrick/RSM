//
//  LegendsCardDatabase.swift
//  Retro Season Manager
//
//  The master card database for RSM Legends (Phase 3 — Collection
//  Database). Every name here is fictionalized in the same style already
//  used for Career Mode's historical squads (a real-sounding first name
//  paired with an invented surname) rather than an exact real player
//  name — no card is an unaltered real footballer. Clubs are drawn from
//  the same fictional club identities Career Mode already uses
//  (HistoricalSquads2010.swift etc.), so both modes share one football
//  world. Nations are real countries, matching how nationality is
//  already handled for Career Mode players (see Player.nationality).
//
//  `age` is the player's age *as depicted on this specific card* (a
//  young breakout card and a peak card of the same person carry
//  different ages, same as the real seasons/flavor text already
//  suggest). It feeds the seasonal aging/decline system in
//  LegendsStore+Aging.swift — see that file for which eras are exempt.
//

import SwiftUI

enum LegendsEra: String, CaseIterable, Codable {
    case nineties = "1990s"
    case twoThousands = "2000s"
    case twentyTens = "2010s"
    case twentyTwenties = "2020s"
    case futureStars = "Future Stars"
    case legends = "Legends"
    case icons = "Icons"
}

enum LegendsRarity: String, CaseIterable, Codable {
    case common = "Common"
    case rare = "Rare"
    case elite = "Elite"
    case hero = "Hero"
    case legend = "Legend"
    case icon = "Icon"
    case immortal = "Immortal"
    case retroHero = "Retro Hero"
    case goldenGeneration = "Golden Generation"
    case teamOfTheSeason = "Team of the Season"

    /// Weakest to strongest, for sorting a collection grid by rarity.
    var tier: Int {
        switch self {
        case .common: return 0
        case .rare: return 1
        case .elite: return 2
        case .hero: return 3
        case .retroHero: return 4
        case .goldenGeneration: return 4
        case .teamOfTheSeason: return 4
        case .legend: return 5
        case .icon: return 6
        case .immortal: return 7
        }
    }

    /// Relative pack-pull weight — common cards should come up far more
    /// often than the pool's raw composition would suggest, since the
    /// 40-card database itself already skews toward Hero and above (see
    /// LegendsPacks.swift). A high pull rate for top rarities is exactly
    /// what makes them feel unrewarding to actually own.
    var pullWeight: Double {
        switch self {
        case .common: return 100
        case .rare: return 55
        case .elite: return 28
        case .hero: return 12
        case .retroHero: return 4
        case .goldenGeneration: return 3
        case .teamOfTheSeason: return 3
        case .legend: return 2.5
        case .icon: return 1
        case .immortal: return 0.25
        }
    }

    /// Kept within the app's own retro-green/gold/blue accent set rather
    /// than introducing a new rainbow of rarity colours.
    var tint: Color {
        switch self {
        case .common: return Retro.text.opacity(0.55)
        case .rare: return Retro.pitchGreen
        case .elite: return Retro.emerald
        case .hero: return Retro.royalBlue
        case .retroHero: return Retro.forest
        case .goldenGeneration: return Retro.gold
        case .teamOfTheSeason: return Retro.royalBlue
        case .legend: return Retro.gold
        case .icon: return Retro.gold
        case .immortal: return Retro.pureWhite
        }
    }
}

struct LegendsCard: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let season: String
    let age: Int
    let era: LegendsEra
    let club: String
    let nation: String
    let position: DetailedPosition
    let overall: Int
    let pace: Int
    let shooting: Int
    let passing: Int
    let dribbling: Int
    let defending: Int
    let physical: Int
    let rarity: LegendsRarity
    let specialAbility: String
    let biography: String
}

enum LegendsCardDatabase {
    static let all: [LegendsCard] = [
        // MARK: 1990s
        LegendsCard(id: "baggino-9394", name: "R. Baggino", season: "1993/94", age: 27, era: .nineties,
                    club: "Turin Bianconeri", nation: "Italy", position: .attackingMid,
                    overall: 91, pace: 78, shooting: 88, passing: 85, dribbling: 92, defending: 35, physical: 60,
                    rarity: .legend, specialAbility: "Flair Finisher",
                    biography: "A ponytailed playmaker whose free-kicks and feints defined a generation."),
        LegendsCard(id: "berkendam-9798", name: "D. Berkendam", season: "1997/98", age: 28, era: .nineties,
                    club: "Highbury", nation: "Netherlands", position: .striker,
                    overall: 90, pace: 72, shooting: 87, passing: 84, dribbling: 90, defending: 30, physical: 65,
                    rarity: .hero, specialAbility: "First-Time Finish",
                    biography: "A cerebral striker who made the impossible touch look inevitable."),
        LegendsCard(id: "cantina-9596", name: "E. Cantina", season: "1995/96", age: 29, era: .nineties,
                    club: "Old Trafford Reds", nation: "France", position: .striker,
                    overall: 89, pace: 68, shooting: 85, passing: 80, dribbling: 86, defending: 32, physical: 74,
                    rarity: .hero, specialAbility: "Collar-Up Confidence",
                    biography: "Turned a struggling dressing room into champions through sheer force of will."),
        LegendsCard(id: "cantina-9596-retro", name: "E. Cantina", season: "1995/96", age: 29, era: .legends,
                    club: "Old Trafford Reds", nation: "France", position: .striker,
                    overall: 92, pace: 70, shooting: 88, passing: 82, dribbling: 89, defending: 32, physical: 76,
                    rarity: .retroHero, specialAbility: "Collar-Up Confidence",
                    biography: "A boosted retro tribute card celebrating a swaggering mid-90s title run."),
        LegendsCard(id: "maldinho-9596", name: "P. Maldinho", season: "1995/96", age: 27, era: .nineties,
                    club: "San Siro Rossoneri", nation: "Italy", position: .centreBack,
                    overall: 92, pace: 75, shooting: 45, passing: 78, dribbling: 70, defending: 93, physical: 85,
                    rarity: .icon, specialAbility: "Never Beaten 1v1",
                    biography: "A defender so composed that forwards rarely got a second chance to try again."),
        LegendsCard(id: "batigora-9596", name: "G. Batigora", season: "1995/96", age: 26, era: .nineties,
                    club: "Elland Athletic", nation: "Argentina", position: .striker,
                    overall: 90, pace: 80, shooting: 92, passing: 65, dribbling: 78, defending: 25, physical: 88,
                    rarity: .hero, specialAbility: "Power Header",
                    biography: "Bullet volleys and thunderous headers, celebrated with arms outstretched."),

        // MARK: 2000s
        LegendsCard(id: "zeidan-0102", name: "Z. Zeidan", season: "2001/02", age: 29, era: .twoThousands,
                    club: "Bernabéu Whites", nation: "France", position: .attackingMid,
                    overall: 93, pace: 70, shooting: 82, passing: 90, dribbling: 94, defending: 40, physical: 70,
                    rarity: .icon, specialAbility: "Roulette Turn",
                    biography: "A midfielder whose balance made the ball look tethered to his boot."),
        LegendsCard(id: "gaucinho-0304", name: "R. Gaucinho", season: "2003/04", age: 23, era: .twoThousands,
                    club: "Camp Blaugrana", nation: "Brazil", position: .leftWing,
                    overall: 91, pace: 82, shooting: 84, passing: 87, dribbling: 96, defending: 28, physical: 68,
                    rarity: .legend, specialAbility: "Elastico Special",
                    biography: "Played with a smile that made even the opposition applaud."),
        LegendsCard(id: "figaro-0001", name: "L. Figaro", season: "2000/01", age: 22, era: .twoThousands,
                    club: "Bernabéu Whites", nation: "Portugal", position: .rightWing,
                    overall: 89, pace: 83, shooting: 78, passing: 84, dribbling: 88, defending: 35, physical: 72,
                    rarity: .hero, specialAbility: "Stepover Burst",
                    biography: "A record-fee winger who terrorised full-backs down the right flank."),
        LegendsCard(id: "figaro-0001-golden", name: "L. Figaro", season: "2000/01", age: 22, era: .legends,
                    club: "Portugal", nation: "Portugal", position: .rightWing,
                    overall: 92, pace: 85, shooting: 80, passing: 86, dribbling: 90, defending: 36, physical: 73,
                    rarity: .goldenGeneration, specialAbility: "Stepover Burst",
                    biography: "Part of a celebrated national golden generation that reached a major final."),
        LegendsCard(id: "beckway-0203", name: "D. Beckway", season: "2002/03", age: 27, era: .twoThousands,
                    club: "Old Trafford Reds", nation: "England", position: .rightMid,
                    overall: 88, pace: 76, shooting: 80, passing: 92, dribbling: 80, defending: 40, physical: 70,
                    rarity: .hero, specialAbility: "Inch-Perfect Crosses",
                    biography: "A dead-ball specialist whose whipped deliveries set up a decade of goals."),
        LegendsCard(id: "nedvedka-0304", name: "P. Nedvedka", season: "2003/04", age: 29, era: .twoThousands,
                    club: "Turin Bianconeri", nation: "Czech Republic", position: .centralMid,
                    overall: 88, pace: 80, shooting: 78, passing: 82, dribbling: 82, defending: 68, physical: 84,
                    rarity: .elite, specialAbility: "Box-to-Box Engine",
                    biography: "Ran every blade of grass twice over and still had energy for the winner."),
        LegendsCard(id: "buffonte-0506", name: "G. Buffonte", season: "2005/06", age: 28, era: .twoThousands,
                    club: "Turin Bianconeri", nation: "Italy", position: .goalkeeper,
                    overall: 91, pace: 55, shooting: 20, passing: 60, dribbling: 40, defending: 40, physical: 82,
                    rarity: .icon, specialAbility: "Point-Blank Reflex",
                    biography: "Commanded his box like a general and rarely let a soft goal past him."),
        LegendsCard(id: "totthi-0506", name: "F. Totthi", season: "2005/06", age: 29, era: .twoThousands,
                    club: "Valley Rovers", nation: "Italy", position: .attackingMid,
                    overall: 89, pace: 68, shooting: 82, passing: 86, dribbling: 87, defending: 38, physical: 74,
                    rarity: .hero, specialAbility: "Curled Chip",
                    biography: "One-club loyalty and a bag of outrageous chipped finishes."),
        LegendsCard(id: "miessi-0506", name: "L. Miessi", season: "2005/06", age: 18, era: .twoThousands,
                    club: "Camp Blaugrana", nation: "Argentina", position: .rightWing,
                    overall: 84, pace: 86, shooting: 76, passing: 78, dribbling: 90, defending: 25, physical: 55,
                    rarity: .hero, specialAbility: "Low Centre of Gravity",
                    biography: "A teenage breakout whose close control already looked unfair."),
        LegendsCard(id: "renaldo-0405", name: "C. Renaldo", season: "2004/05", age: 19, era: .twoThousands,
                    club: "Old Trafford Reds", nation: "Portugal", position: .rightWing,
                    overall: 85, pace: 91, shooting: 80, passing: 74, dribbling: 90, defending: 28, physical: 72,
                    rarity: .hero, specialAbility: "Stepover Combo",
                    biography: "Raw, direct and obsessed with beating the same man twice."),

        // MARK: 2010s
        LegendsCard(id: "miessi-1112", name: "L. Miessi", season: "2011/12", age: 24, era: .twentyTens,
                    club: "Camp Blaugrana", nation: "Argentina", position: .rightWing,
                    overall: 95, pace: 88, shooting: 92, passing: 90, dribbling: 97, defending: 25, physical: 65,
                    rarity: .icon, specialAbility: "Impossible Angle",
                    biography: "A scoring season so absurd it rewrote what strikers were expected to do."),
        LegendsCard(id: "renaldo-1314", name: "C. Renaldo", season: "2013/14", age: 28, era: .twentyTens,
                    club: "Bernabéu Whites", nation: "Portugal", position: .leftWing,
                    overall: 94, pace: 93, shooting: 93, passing: 82, dribbling: 90, defending: 30, physical: 88,
                    rarity: .icon, specialAbility: "Flying Volley",
                    biography: "Peak explosive power — half striker, half sprinter, all finisher."),
        LegendsCard(id: "iniestra-1011", name: "A. Iniestra", season: "2010/11", age: 26, era: .twentyTens,
                    club: "Camp Blaugrana", nation: "Spain", position: .centralMid,
                    overall: 90, pace: 65, shooting: 75, passing: 91, dribbling: 93, defending: 55, physical: 60,
                    rarity: .legend, specialAbility: "Tight-Space Weave",
                    biography: "Never seemed to run fast, yet nobody could ever catch him with the ball."),
        LegendsCard(id: "aguerro-1112", name: "S. Aguerro", season: "2011/12", age: 23, era: .twentyTens,
                    club: "Etihad Blues", nation: "Argentina", position: .striker,
                    overall: 89, pace: 84, shooting: 90, passing: 75, dribbling: 87, defending: 25, physical: 78,
                    rarity: .hero, specialAbility: "Injury-Time Winner",
                    biography: "Built a reputation on scoring the goals that decide entire seasons."),
        LegendsCard(id: "hazardly-1415", name: "E. Hazardly", season: "2014/15", age: 23, era: .twentyTens,
                    club: "Stamford Blues", nation: "Belgium", position: .leftWing,
                    overall: 89, pace: 88, shooting: 82, passing: 84, dribbling: 93, defending: 30, physical: 68,
                    rarity: .hero, specialAbility: "Drop the Shoulder",
                    biography: "Glided past defenders as if the pitch tilted specially for him."),
        LegendsCard(id: "kantay-1617", name: "N. Kantay", season: "2016/17", age: 25, era: .twentyTens,
                    club: "Stamford Blues", nation: "France", position: .holding,
                    overall: 87, pace: 82, shooting: 55, passing: 78, dribbling: 80, defending: 89, physical: 76,
                    rarity: .elite, specialAbility: "Interception Radar",
                    biography: "Seemed to read the opposition's next pass before they'd decided on it."),

        // MARK: 2020s
        LegendsCard(id: "mbappa-2223", name: "K. Mbappa", season: "2022/23", age: 23, era: .twentyTwenties,
                    club: "Bernabéu Whites", nation: "France", position: .striker,
                    overall: 92, pace: 97, shooting: 88, passing: 78, dribbling: 91, defending: 28, physical: 76,
                    rarity: .icon, specialAbility: "Blistering Burst",
                    biography: "Sprint speed that turns a half-chance into a one-on-one in two touches."),
        LegendsCard(id: "mbappa-2223-tots", name: "K. Mbappa", season: "2022/23", age: 23, era: .twentyTwenties,
                    club: "Bernabéu Whites", nation: "France", position: .striker,
                    overall: 95, pace: 98, shooting: 91, passing: 80, dribbling: 93, defending: 28, physical: 77,
                    rarity: .teamOfTheSeason, specialAbility: "Blistering Burst",
                    biography: "A boosted end-of-season tribute card for a golden-boot-winning campaign."),
        LegendsCard(id: "holland-2223", name: "E. Holland", season: "2022/23", age: 22, era: .twentyTwenties,
                    club: "Etihad Blues", nation: "Norway", position: .striker,
                    overall: 91, pace: 89, shooting: 93, passing: 68, dribbling: 80, defending: 35, physical: 92,
                    rarity: .hero, specialAbility: "One-Touch Finish",
                    biography: "Built like a wall and finishes like a sniper — defenders rarely enjoy the matchup."),
        LegendsCard(id: "junior-2324", name: "V. Junior", season: "2023/24", age: 23, era: .twentyTwenties,
                    club: "Bernabéu Whites", nation: "Brazil", position: .leftWing,
                    overall: 90, pace: 95, shooting: 82, passing: 78, dribbling: 92, defending: 28, physical: 70,
                    rarity: .hero, specialAbility: "Samba Feint",
                    biography: "Turns a footrace into a highlight reel every single time he gets the ball."),
        LegendsCard(id: "bellinghast-2324", name: "J. Bellinghast", season: "2023/24", age: 20, era: .twentyTwenties,
                    club: "Bernabéu Whites", nation: "England", position: .centralMid,
                    overall: 89, pace: 80, shooting: 82, passing: 84, dribbling: 85, defending: 68, physical: 80,
                    rarity: .elite, specialAbility: "Late Box Arrival",
                    biography: "Arrives in the box a split second after the defence has stopped watching for him."),
        LegendsCard(id: "foddin-2223", name: "P. Foddin", season: "2022/23", age: 22, era: .twentyTwenties,
                    club: "Etihad Blues", nation: "England", position: .attackingMid,
                    overall: 87, pace: 78, shooting: 78, passing: 85, dribbling: 89, defending: 40, physical: 62,
                    rarity: .rare, specialAbility: "Tight Turn",
                    biography: "Homegrown, two-footed and impossible to dispossess in a phone box."),

        // MARK: Future Stars
        LegendsCard(id: "marchetti-2526", name: "T. Marchetti", season: "2025/26", age: 17, era: .futureStars,
                    club: "San Siro Nerazzurri", nation: "Italy", position: .striker,
                    overall: 78, pace: 90, shooting: 76, passing: 65, dribbling: 82, defending: 30, physical: 70,
                    rarity: .rare, specialAbility: "Raw Pace",
                    biography: "Still learning the finer points, but nobody in the league can catch him."),
        LegendsCard(id: "odusanya-2526", name: "K. Odusanya", season: "2025/26", age: 18, era: .futureStars,
                    club: "Highbury", nation: "Nigeria", position: .rightWing,
                    overall: 76, pace: 88, shooting: 70, passing: 68, dribbling: 85, defending: 26, physical: 64,
                    rarity: .rare, specialAbility: "Explosive Cut-Inside",
                    biography: "Academy graduate already drawing comparisons to the club's greats."),
        LegendsCard(id: "lindqvist-2526", name: "M. Lindqvist", season: "2025/26", age: 18, era: .futureStars,
                    club: "Bavarian Reds", nation: "Sweden", position: .centreBack,
                    overall: 75, pace: 78, shooting: 35, passing: 70, dribbling: 60, defending: 80, physical: 82,
                    rarity: .common, specialAbility: "Composed Under Pressure",
                    biography: "A calm ball-playing defender tipped for full international honours."),
        LegendsCard(id: "fontaine-2526", name: "D. Fontaine", season: "2025/26", age: 19, era: .futureStars,
                    club: "Old Trafford Reds", nation: "France", position: .holding,
                    overall: 74, pace: 72, shooting: 50, passing: 76, dribbling: 72, defending: 78, physical: 74,
                    rarity: .common, specialAbility: "Tireless Cover",
                    biography: "Barely twenty and already the calmest head in a young midfield."),

        // MARK: Legends
        LegendsCard(id: "nascimento-62", name: "E. Nascimento", season: "1962 Golden Era", age: 24, era: .legends,
                    club: "Camp Blaugrana", nation: "Brazil", position: .striker,
                    overall: 96, pace: 88, shooting: 94, passing: 82, dribbling: 95, defending: 30, physical: 78,
                    rarity: .legend, specialAbility: "Bicycle Kick",
                    biography: "Spoken about in whispers even by players who never saw him play."),
        LegendsCard(id: "maradana-8687", name: "D. Maradana", season: "1986/87", age: 26, era: .legends,
                    club: "San Siro Nerazzurri", nation: "Argentina", position: .attackingMid,
                    overall: 96, pace: 82, shooting: 88, passing: 90, dribbling: 97, defending: 32, physical: 68,
                    rarity: .legend, specialAbility: "Slalom Dribble",
                    biography: "Dragged an entire team to glory almost single-footedly."),
        LegendsCard(id: "cruyffe-7172", name: "J. Cruyffe", season: "1971/72", age: 24, era: .legends,
                    club: "Amsterdam Godenzonen", nation: "Netherlands", position: .striker,
                    overall: 95, pace: 84, shooting: 86, passing: 88, dribbling: 92, defending: 40, physical: 62,
                    rarity: .legend, specialAbility: "Turn of Genius",
                    biography: "Invented a piece of skill so good it still carries his name."),
        LegendsCard(id: "beckenwald-7273", name: "F. Beckenwald", season: "1972/73", age: 26, era: .legends,
                    club: "Bavarian Reds", nation: "Germany", position: .centreBack,
                    overall: 94, pace: 74, shooting: 55, passing: 84, dribbling: 74, defending: 90, physical: 78,
                    rarity: .legend, specialAbility: "Libero Vision",
                    biography: "Redefined what a defender could be by simply refusing to stop attacking."),

        // MARK: Icons
        LegendsCard(id: "silveira-icon", name: "R. Silveira", season: "Icon", age: 25, era: .icons,
                    club: "San Siro Nerazzurri", nation: "Brazil", position: .striker,
                    overall: 96, pace: 92, shooting: 95, passing: 76, dribbling: 93, defending: 25, physical: 84,
                    rarity: .icon, specialAbility: "Explosive First Touch",
                    biography: "Two knee reconstructions couldn't slow down the most feared striker of his era."),
        LegendsCard(id: "destefano-icon", name: "F. De Stefano", season: "Icon", age: 27, era: .icons,
                    club: "Bernabéu Whites", nation: "Argentina", position: .striker,
                    overall: 96, pace: 80, shooting: 92, passing: 82, dribbling: 88, defending: 45, physical: 80,
                    rarity: .icon, specialAbility: "Complete Forward",
                    biography: "Scored in five straight continental finals and never once looked tired."),
        LegendsCard(id: "nascimento-immortal", name: "E. Nascimento", season: "Immortal", age: 24, era: .icons,
                    club: "Camp Blaugrana", nation: "Brazil", position: .striker,
                    overall: 99, pace: 92, shooting: 97, passing: 86, dribbling: 98, defending: 32, physical: 80,
                    rarity: .immortal, specialAbility: "Bicycle Kick",
                    biography: "The ultimate tribute card — every stat maxed for the player people still argue is the greatest ever."),
        LegendsCard(id: "maldinho-icon", name: "P. Maldinho", season: "Icon", age: 26, era: .icons,
                    club: "San Siro Rossoneri", nation: "Italy", position: .centreBack,
                    overall: 95, pace: 78, shooting: 48, passing: 82, dribbling: 74, defending: 97, physical: 88,
                    rarity: .icon, specialAbility: "Positional Perfection",
                    biography: "A career so clean he's remembered for the tackles he never needed to make."),

        // MARK: Goalkeepers, full-backs and midfield depth
        // The original 40-card pass leaned heavily toward attackers (14
        // strikers, 1 goalkeeper, 0 full-backs) — impossible to field a
        // realistic XI in every formation. No new strikers here; every
        // card below targets a position that was thin or missing.
        LegendsCard(id: "neuwald-2223", name: "N. Neuwald", season: "2022/23", age: 27, era: .twentyTwenties,
                    club: "Bavarian Reds", nation: "Germany", position: .goalkeeper,
                    overall: 90, pace: 58, shooting: 25, passing: 74, dribbling: 55, defending: 55, physical: 85,
                    rarity: .hero, specialAbility: "Sweeper Keeper",
                    biography: "Plays ten yards off his line and dares strikers to try lobbing him."),
        LegendsCard(id: "cechinho-0607", name: "P. Cechinho", season: "2006/07", age: 24, era: .twoThousands,
                    club: "Stamford Blues", nation: "Czech Republic", position: .goalkeeper,
                    overall: 82, pace: 50, shooting: 15, passing: 55, dribbling: 35, defending: 35, physical: 84,
                    rarity: .rare, specialAbility: "Commanding Presence",
                    biography: "Built like a wall and just as hard to beat from close range."),
        LegendsCard(id: "casillante-0405", name: "I. Casillante", season: "2004/05", age: 23, era: .twoThousands,
                    club: "Bernabéu Whites", nation: "Spain", position: .goalkeeper,
                    overall: 88, pace: 60, shooting: 18, passing: 58, dribbling: 40, defending: 38, physical: 78,
                    rarity: .hero, specialAbility: "Big Match Save",
                    biography: "Never looked more comfortable than with the whole season on the line."),
        LegendsCard(id: "terstegan-1819", name: "M. Terstegan", season: "2018/19", age: 26, era: .twentyTens,
                    club: "Camp Blaugrana", nation: "Germany", position: .goalkeeper,
                    overall: 86, pace: 55, shooting: 20, passing: 78, dribbling: 50, defending: 34, physical: 80,
                    rarity: .elite, specialAbility: "Ball-Playing Keeper",
                    biography: "Effectively an extra passer in a back three when he's got the ball."),
        LegendsCard(id: "donnaruma-2021", name: "E. Donnaruma", season: "2020/21", age: 21, era: .twentyTwenties,
                    club: "San Siro Rossoneri", nation: "Italy", position: .goalkeeper,
                    overall: 80, pace: 62, shooting: 15, passing: 60, dribbling: 42, defending: 30, physical: 88,
                    rarity: .rare, specialAbility: "Reflex Save",
                    biography: "A teenager thrown into a first-team goal and never looked back."),
        LegendsCard(id: "kahnwald-0001", name: "O. Kahnwald", season: "2000/01", age: 27, era: .legends,
                    club: "Bavarian Reds", nation: "Germany", position: .goalkeeper,
                    overall: 93, pace: 50, shooting: 20, passing: 60, dribbling: 40, defending: 40, physical: 90,
                    rarity: .legend, specialAbility: "Titan Between the Posts",
                    biography: "Roared at his own defenders as often as the opposition — and it worked."),
        LegendsCard(id: "oblakov-1617", name: "J. Oblakov", season: "2016/17", age: 24, era: .twentyTens,
                    club: "Etihad Blues", nation: "Slovenia", position: .goalkeeper,
                    overall: 85, pace: 54, shooting: 16, passing: 62, dribbling: 44, defending: 36, physical: 82,
                    rarity: .elite, specialAbility: "Point-Blank Wall",
                    biography: "Quietly posted the best save ratio in the league three years running."),
        LegendsCard(id: "mesliere-2526", name: "S. Mesliere", season: "2025/26", age: 19, era: .futureStars,
                    club: "Elland Athletic", nation: "France", position: .goalkeeper,
                    overall: 73, pace: 56, shooting: 12, passing: 55, dribbling: 38, defending: 25, physical: 76,
                    rarity: .common, specialAbility: "Quick Reactions",
                    biography: "Still raw with his kicking, but shot-stopping instincts you can't teach."),

        LegendsCard(id: "robertino-1819", name: "A. Robertino", season: "2018/19", age: 24, era: .twentyTens,
                    club: "Etihad Blues", nation: "Scotland", position: .leftBack,
                    overall: 87, pace: 84, shooting: 55, passing: 78, dribbling: 75, defending: 82, physical: 74,
                    rarity: .hero, specialAbility: "Overlap Run",
                    biography: "Delivers a cross like a winger and defends like it's personal."),
        LegendsCard(id: "vierinha-1112", name: "M. Vierinha", season: "2011/12", age: 23, era: .twentyTens,
                    club: "Bernabéu Whites", nation: "Brazil", position: .leftBack,
                    overall: 90, pace: 88, shooting: 60, passing: 80, dribbling: 88, defending: 75, physical: 68,
                    rarity: .legend, specialAbility: "Samba Overlap",
                    biography: "Attacks like a winger who forgot he's supposed to be a defender."),
        LegendsCard(id: "alabana-1920", name: "T. Alabana", season: "2019/20", age: 27, era: .twentyTens,
                    club: "Bavarian Reds", nation: "Austria", position: .leftBack,
                    overall: 85, pace: 78, shooting: 58, passing: 82, dribbling: 78, defending: 84, physical: 76,
                    rarity: .elite, specialAbility: "Versatile Cover",
                    biography: "Comfortable enough to play four different positions across one season."),
        LegendsCard(id: "davison-2223", name: "A. Davison", season: "2022/23", age: 20, era: .twentyTwenties,
                    club: "Bavarian Reds", nation: "Canada", position: .leftBack,
                    overall: 80, pace: 92, shooting: 50, passing: 68, dribbling: 78, defending: 72, physical: 74,
                    rarity: .rare, specialAbility: "Explosive Overlap",
                    biography: "Turns defence into attack in about three strides flat."),
        LegendsCard(id: "estevinho-2526", name: "L. Estevinho", season: "2025/26", age: 18, era: .futureStars,
                    club: "Dragão Dragons", nation: "Portugal", position: .leftBack,
                    overall: 72, pace: 85, shooting: 42, passing: 62, dribbling: 68, defending: 66, physical: 64,
                    rarity: .common, specialAbility: "Raw Speed",
                    biography: "Academy graduate whose recovery pace bails out every positional mistake."),

        LegendsCard(id: "alvarinho-0607", name: "D. Alvarinho", season: "2006/07", age: 24, era: .twoThousands,
                    club: "Camp Blaugrana", nation: "Brazil", position: .rightBack,
                    overall: 87, pace: 85, shooting: 62, passing: 82, dribbling: 85, defending: 74, physical: 68,
                    rarity: .hero, specialAbility: "Wing-Back Surge",
                    biography: "Played so far forward some nights he was a spare winger."),
        LegendsCard(id: "walkerino-1819", name: "T. Walkerino", season: "2018/19", age: 28, era: .twentyTens,
                    club: "Etihad Blues", nation: "England", position: .rightBack,
                    overall: 84, pace: 95, shooting: 48, passing: 70, dribbling: 68, defending: 78, physical: 76,
                    rarity: .rare, specialAbility: "Recovery Pace",
                    biography: "Nobody outruns a lost cause with this man chasing back."),
        LegendsCard(id: "cancelinho-2122", name: "J. Cancelinho", season: "2021/22", age: 27, era: .twentyTwenties,
                    club: "Etihad Blues", nation: "Portugal", position: .rightBack,
                    overall: 88, pace: 87, shooting: 60, passing: 85, dribbling: 84, defending: 76, physical: 70,
                    rarity: .elite, specialAbility: "Inverted Full-Back",
                    biography: "Tucks inside to build play like a fifth midfielder on matchday."),
        LegendsCard(id: "carvahlinho-1516", name: "S. Carvahlinho", season: "2015/16", age: 23, era: .twentyTens,
                    club: "Bernabéu Whites", nation: "Spain", position: .rightBack,
                    overall: 83, pace: 80, shooting: 50, passing: 76, dribbling: 72, defending: 82, physical: 74,
                    rarity: .elite, specialAbility: "Relentless Motor",
                    biography: "Runs every channel twice and still tracks the overlap."),
        LegendsCard(id: "fontebasso-2526", name: "B. Fontebasso", season: "2025/26", age: 18, era: .futureStars,
                    club: "Turin Bianconeri", nation: "Italy", position: .rightBack,
                    overall: 74, pace: 86, shooting: 48, passing: 60, dribbling: 66, defending: 68, physical: 66,
                    rarity: .rare, specialAbility: "Two-Footed Threat",
                    biography: "Comfortable enough on his left to switch flanks mid-game."),

        LegendsCard(id: "ramosinho-1213", name: "S. Ramosinho", season: "2012/13", age: 26, era: .twentyTens,
                    club: "Bernabéu Whites", nation: "Spain", position: .centreBack,
                    overall: 89, pace: 72, shooting: 65, passing: 72, dribbling: 65, defending: 92, physical: 88,
                    rarity: .hero, specialAbility: "Late Header",
                    biography: "The kind of defender opposition strikers start watching over their shoulder for."),
        LegendsCard(id: "dijkerman-1819", name: "V. Dijkerman", season: "2018/19", age: 27, era: .twentyTens,
                    club: "Etihad Blues", nation: "Netherlands", position: .centreBack,
                    overall: 92, pace: 78, shooting: 50, passing: 78, dribbling: 68, defending: 94, physical: 90,
                    rarity: .legend, specialAbility: "Aerial Dominance",
                    biography: "Didn't lose a single individual duel for the better part of two years."),
        LegendsCard(id: "varanova-1718", name: "R. Varanova", season: "2017/18", age: 23, era: .twentyTens,
                    club: "Bernabéu Whites", nation: "France", position: .centreBack,
                    overall: 84, pace: 82, shooting: 40, passing: 72, dribbling: 62, defending: 87, physical: 82,
                    rarity: .elite, specialAbility: "Recovery Speed",
                    biography: "So quick recovering that a lost first step barely seems to matter."),

        LegendsCard(id: "busquetti-1011", name: "S. Busquetti", season: "2010/11", age: 22, era: .twentyTens,
                    club: "Camp Blaugrana", nation: "Spain", position: .holding,
                    overall: 85, pace: 55, shooting: 50, passing: 86, dribbling: 78, defending: 82, physical: 68,
                    rarity: .elite, specialAbility: "Screen the Defense",
                    biography: "Always seems to be standing exactly where the danger was about to happen."),
        LegendsCard(id: "rodrigez-2223", name: "T. Rodrigez", season: "2022/23", age: 26, era: .twentyTwenties,
                    club: "Etihad Blues", nation: "Spain", position: .holding,
                    overall: 89, pace: 62, shooting: 62, passing: 88, dribbling: 80, defending: 85, physical: 82,
                    rarity: .hero, specialAbility: "Metronome",
                    biography: "Barely gives the ball away and never seems to hurry doing it."),
        LegendsCard(id: "toureski-1314", name: "Y. Toureski", season: "2013/14", age: 26, era: .twentyTens,
                    club: "Etihad Blues", nation: "Ivory Coast", position: .holding,
                    overall: 87, pace: 68, shooting: 68, passing: 78, dribbling: 76, defending: 76, physical: 90,
                    rarity: .rare, specialAbility: "Surging Runs",
                    biography: "A midfielder built like a centre-back who scores like a striker."),
        LegendsCard(id: "camarindo-2526", name: "D. Camarindo", season: "2025/26", age: 19, era: .futureStars,
                    club: "Bernabéu Whites", nation: "France", position: .holding,
                    overall: 76, pace: 80, shooting: 55, passing: 72, dribbling: 74, defending: 70, physical: 76,
                    rarity: .rare, specialAbility: "Box-to-Box Energy",
                    biography: "Covers every blade of grass and still arrives fresh for extra time."),

        LegendsCard(id: "alonzo-0405", name: "X. Alonzo", season: "2004/05", age: 23, era: .twoThousands,
                    club: "Bernabéu Whites", nation: "Spain", position: .centralMid,
                    overall: 86, pace: 55, shooting: 68, passing: 90, dribbling: 74, defending: 72, physical: 70,
                    rarity: .hero, specialAbility: "Raking Long Pass",
                    biography: "Can switch the point of attack from one box to the other, first time."),
        LegendsCard(id: "modricek-1617", name: "L. Modricek", season: "2016/17", age: 30, era: .twentyTens,
                    club: "Bernabéu Whites", nation: "Croatia", position: .centralMid,
                    overall: 91, pace: 68, shooting: 72, passing: 90, dribbling: 90, defending: 62, physical: 62,
                    rarity: .legend, specialAbility: "Vision Passing",
                    biography: "Slight enough to overlook until he's turned three markers inside out."),
        LegendsCard(id: "debrugne-2122", name: "K. De Brugne", season: "2021/22", age: 28, era: .twentyTwenties,
                    club: "Etihad Blues", nation: "Belgium", position: .centralMid,
                    overall: 92, pace: 72, shooting: 82, passing: 93, dribbling: 86, defending: 64, physical: 74,
                    rarity: .icon, specialAbility: "Pinpoint Through Ball",
                    biography: "Sees passes that don't exist yet and threads them anyway."),
        LegendsCard(id: "camarasa-2526", name: "E. Camarasa", season: "2025/26", age: 18, era: .futureStars,
                    club: "Camp Blaugrana", nation: "Spain", position: .centralMid,
                    overall: 76, pace: 70, shooting: 62, passing: 78, dribbling: 76, defending: 58, physical: 62,
                    rarity: .rare, specialAbility: "Composed Passer",
                    biography: "Plays like he's been in the first team for a decade already."),

        LegendsCard(id: "giggston-9596", name: "R. Giggston", season: "1995/96", age: 22, era: .nineties,
                    club: "Old Trafford Reds", nation: "Wales", position: .leftMid,
                    overall: 87, pace: 84, shooting: 72, passing: 82, dribbling: 90, defending: 40, physical: 68,
                    rarity: .hero, specialAbility: "Silky Wing Play",
                    biography: "A jinking run down the left that defenders still have nightmares about."),
        LegendsCard(id: "robbenov-1213", name: "A. Robbenov", season: "2012/13", age: 29, era: .twentyTens,
                    club: "Bavarian Reds", nation: "Netherlands", position: .leftMid,
                    overall: 90, pace: 90, shooting: 84, passing: 74, dribbling: 90, defending: 32, physical: 64,
                    rarity: .icon, specialAbility: "Cut Inside Curler",
                    biography: "Everyone in the stadium knows he's cutting inside — doesn't matter."),
        LegendsCard(id: "musialaite-2526", name: "Y. Musialaite", season: "2025/26", age: 18, era: .futureStars,
                    club: "Bavarian Reds", nation: "Poland", position: .leftMid,
                    overall: 77, pace: 82, shooting: 68, passing: 68, dribbling: 82, defending: 34, physical: 60,
                    rarity: .rare, specialAbility: "Tight Dribble",
                    biography: "Teenager already too clever for defenders twice his age."),

        LegendsCard(id: "balewski-0910", name: "G. Balewski", season: "2009/10", age: 20, era: .twoThousands,
                    club: "Bernabéu Whites", nation: "Wales", position: .rightMid,
                    overall: 88, pace: 96, shooting: 86, passing: 70, dribbling: 82, defending: 34, physical: 80,
                    rarity: .legend, specialAbility: "Rocket Shot",
                    biography: "Hit shots so hard goalkeepers just turned to watch them fly in."),
        LegendsCard(id: "dimarinho-1415", name: "A. Di Marinho", season: "2014/15", age: 26, era: .twentyTens,
                    club: "Old Trafford Reds", nation: "Argentina", position: .rightMid,
                    overall: 87, pace: 88, shooting: 74, passing: 82, dribbling: 86, defending: 36, physical: 62,
                    rarity: .hero, specialAbility: "Whipped Delivery",
                    biography: "Delivers a cross with such curl it seems to defy the near post."),

        LegendsCard(id: "ozelinho-1213", name: "K. Ozelinho", season: "2012/13", age: 24, era: .twentyTens,
                    club: "Highbury", nation: "Germany", position: .attackingMid,
                    overall: 87, pace: 62, shooting: 68, passing: 92, dribbling: 88, defending: 32, physical: 56,
                    rarity: .hero, specialAbility: "Killer Pass",
                    biography: "Racked up assists other playmakers could only dream of."),
        LegendsCard(id: "fernandaz-2223", name: "B. Fernandaz", season: "2022/23", age: 27, era: .twentyTwenties,
                    club: "Old Trafford Reds", nation: "Portugal", position: .attackingMid,
                    overall: 87, pace: 68, shooting: 80, passing: 88, dribbling: 82, defending: 42, physical: 64,
                    rarity: .elite, specialAbility: "Set-Piece Specialist",
                    biography: "Arrives late into the box like it's the one thing he trains for."),
    ]
}
