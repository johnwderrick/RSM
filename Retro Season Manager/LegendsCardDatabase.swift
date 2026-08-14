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
        LegendsCard(id: "baggino-9394", name: "R. Baggino", season: "1993/94", era: .nineties,
                    club: "Turin Bianconeri", nation: "Italy", position: .attackingMid,
                    overall: 91, pace: 78, shooting: 88, passing: 85, dribbling: 92, defending: 35, physical: 60,
                    rarity: .legend, specialAbility: "Flair Finisher",
                    biography: "A ponytailed playmaker whose free-kicks and feints defined a generation."),
        LegendsCard(id: "berkendam-9798", name: "D. Berkendam", season: "1997/98", era: .nineties,
                    club: "Highbury", nation: "Netherlands", position: .striker,
                    overall: 90, pace: 72, shooting: 87, passing: 84, dribbling: 90, defending: 30, physical: 65,
                    rarity: .hero, specialAbility: "First-Time Finish",
                    biography: "A cerebral striker who made the impossible touch look inevitable."),
        LegendsCard(id: "cantina-9596", name: "E. Cantina", season: "1995/96", era: .nineties,
                    club: "Old Trafford Reds", nation: "France", position: .striker,
                    overall: 89, pace: 68, shooting: 85, passing: 80, dribbling: 86, defending: 32, physical: 74,
                    rarity: .hero, specialAbility: "Collar-Up Confidence",
                    biography: "Turned a struggling dressing room into champions through sheer force of will."),
        LegendsCard(id: "cantina-9596-retro", name: "E. Cantina", season: "1995/96", era: .legends,
                    club: "Old Trafford Reds", nation: "France", position: .striker,
                    overall: 92, pace: 70, shooting: 88, passing: 82, dribbling: 89, defending: 32, physical: 76,
                    rarity: .retroHero, specialAbility: "Collar-Up Confidence",
                    biography: "A boosted retro tribute card celebrating a swaggering mid-90s title run."),
        LegendsCard(id: "maldinho-9596", name: "P. Maldinho", season: "1995/96", era: .nineties,
                    club: "San Siro Rossoneri", nation: "Italy", position: .centreBack,
                    overall: 92, pace: 75, shooting: 45, passing: 78, dribbling: 70, defending: 93, physical: 85,
                    rarity: .icon, specialAbility: "Never Beaten 1v1",
                    biography: "A defender so composed that forwards rarely got a second chance to try again."),
        LegendsCard(id: "batigora-9596", name: "G. Batigora", season: "1995/96", era: .nineties,
                    club: "Elland Athletic", nation: "Argentina", position: .striker,
                    overall: 90, pace: 80, shooting: 92, passing: 65, dribbling: 78, defending: 25, physical: 88,
                    rarity: .hero, specialAbility: "Power Header",
                    biography: "Bullet volleys and thunderous headers, celebrated with arms outstretched."),

        // MARK: 2000s
        LegendsCard(id: "zeidan-0102", name: "Z. Zeidan", season: "2001/02", era: .twoThousands,
                    club: "Bernabéu Whites", nation: "France", position: .attackingMid,
                    overall: 93, pace: 70, shooting: 82, passing: 90, dribbling: 94, defending: 40, physical: 70,
                    rarity: .icon, specialAbility: "Roulette Turn",
                    biography: "A midfielder whose balance made the ball look tethered to his boot."),
        LegendsCard(id: "gaucinho-0304", name: "R. Gaucinho", season: "2003/04", era: .twoThousands,
                    club: "Camp Blaugrana", nation: "Brazil", position: .leftWing,
                    overall: 91, pace: 82, shooting: 84, passing: 87, dribbling: 96, defending: 28, physical: 68,
                    rarity: .legend, specialAbility: "Elastico Special",
                    biography: "Played with a smile that made even the opposition applaud."),
        LegendsCard(id: "figaro-0001", name: "L. Figaro", season: "2000/01", era: .twoThousands,
                    club: "Bernabéu Whites", nation: "Portugal", position: .rightWing,
                    overall: 89, pace: 83, shooting: 78, passing: 84, dribbling: 88, defending: 35, physical: 72,
                    rarity: .hero, specialAbility: "Stepover Burst",
                    biography: "A record-fee winger who terrorised full-backs down the right flank."),
        LegendsCard(id: "figaro-0001-golden", name: "L. Figaro", season: "2000/01", era: .legends,
                    club: "Portugal", nation: "Portugal", position: .rightWing,
                    overall: 92, pace: 85, shooting: 80, passing: 86, dribbling: 90, defending: 36, physical: 73,
                    rarity: .goldenGeneration, specialAbility: "Stepover Burst",
                    biography: "Part of a celebrated national golden generation that reached a major final."),
        LegendsCard(id: "beckway-0203", name: "D. Beckway", season: "2002/03", era: .twoThousands,
                    club: "Old Trafford Reds", nation: "England", position: .rightMid,
                    overall: 88, pace: 76, shooting: 80, passing: 92, dribbling: 80, defending: 40, physical: 70,
                    rarity: .hero, specialAbility: "Inch-Perfect Crosses",
                    biography: "A dead-ball specialist whose whipped deliveries set up a decade of goals."),
        LegendsCard(id: "nedvedka-0304", name: "P. Nedvedka", season: "2003/04", era: .twoThousands,
                    club: "Turin Bianconeri", nation: "Czech Republic", position: .centralMid,
                    overall: 88, pace: 80, shooting: 78, passing: 82, dribbling: 82, defending: 68, physical: 84,
                    rarity: .elite, specialAbility: "Box-to-Box Engine",
                    biography: "Ran every blade of grass twice over and still had energy for the winner."),
        LegendsCard(id: "buffonte-0506", name: "G. Buffonte", season: "2005/06", era: .twoThousands,
                    club: "Turin Bianconeri", nation: "Italy", position: .goalkeeper,
                    overall: 91, pace: 55, shooting: 20, passing: 60, dribbling: 40, defending: 40, physical: 82,
                    rarity: .icon, specialAbility: "Point-Blank Reflex",
                    biography: "Commanded his box like a general and rarely let a soft goal past him."),
        LegendsCard(id: "totthi-0506", name: "F. Totthi", season: "2005/06", era: .twoThousands,
                    club: "Valley Rovers", nation: "Italy", position: .attackingMid,
                    overall: 89, pace: 68, shooting: 82, passing: 86, dribbling: 87, defending: 38, physical: 74,
                    rarity: .hero, specialAbility: "Curled Chip",
                    biography: "One-club loyalty and a bag of outrageous chipped finishes."),
        LegendsCard(id: "miessi-0506", name: "L. Miessi", season: "2005/06", era: .twoThousands,
                    club: "Camp Blaugrana", nation: "Argentina", position: .rightWing,
                    overall: 84, pace: 86, shooting: 76, passing: 78, dribbling: 90, defending: 25, physical: 55,
                    rarity: .hero, specialAbility: "Low Centre of Gravity",
                    biography: "A teenage breakout whose close control already looked unfair."),
        LegendsCard(id: "renaldo-0405", name: "C. Renaldo", season: "2004/05", era: .twoThousands,
                    club: "Old Trafford Reds", nation: "Portugal", position: .rightWing,
                    overall: 85, pace: 91, shooting: 80, passing: 74, dribbling: 90, defending: 28, physical: 72,
                    rarity: .hero, specialAbility: "Stepover Combo",
                    biography: "Raw, direct and obsessed with beating the same man twice."),

        // MARK: 2010s
        LegendsCard(id: "miessi-1112", name: "L. Miessi", season: "2011/12", era: .twentyTens,
                    club: "Camp Blaugrana", nation: "Argentina", position: .rightWing,
                    overall: 95, pace: 88, shooting: 92, passing: 90, dribbling: 97, defending: 25, physical: 65,
                    rarity: .icon, specialAbility: "Impossible Angle",
                    biography: "A scoring season so absurd it rewrote what strikers were expected to do."),
        LegendsCard(id: "renaldo-1314", name: "C. Renaldo", season: "2013/14", era: .twentyTens,
                    club: "Bernabéu Whites", nation: "Portugal", position: .leftWing,
                    overall: 94, pace: 93, shooting: 93, passing: 82, dribbling: 90, defending: 30, physical: 88,
                    rarity: .icon, specialAbility: "Flying Volley",
                    biography: "Peak explosive power — half striker, half sprinter, all finisher."),
        LegendsCard(id: "iniestra-1011", name: "A. Iniestra", season: "2010/11", era: .twentyTens,
                    club: "Camp Blaugrana", nation: "Spain", position: .centralMid,
                    overall: 90, pace: 65, shooting: 75, passing: 91, dribbling: 93, defending: 55, physical: 60,
                    rarity: .legend, specialAbility: "Tight-Space Weave",
                    biography: "Never seemed to run fast, yet nobody could ever catch him with the ball."),
        LegendsCard(id: "aguerro-1112", name: "S. Aguerro", season: "2011/12", era: .twentyTens,
                    club: "Etihad Blues", nation: "Argentina", position: .striker,
                    overall: 89, pace: 84, shooting: 90, passing: 75, dribbling: 87, defending: 25, physical: 78,
                    rarity: .hero, specialAbility: "Injury-Time Winner",
                    biography: "Built a reputation on scoring the goals that decide entire seasons."),
        LegendsCard(id: "hazardly-1415", name: "E. Hazardly", season: "2014/15", era: .twentyTens,
                    club: "Stamford Blues", nation: "Belgium", position: .leftWing,
                    overall: 89, pace: 88, shooting: 82, passing: 84, dribbling: 93, defending: 30, physical: 68,
                    rarity: .hero, specialAbility: "Drop the Shoulder",
                    biography: "Glided past defenders as if the pitch tilted specially for him."),
        LegendsCard(id: "kantay-1617", name: "N. Kantay", season: "2016/17", era: .twentyTens,
                    club: "Stamford Blues", nation: "France", position: .holding,
                    overall: 87, pace: 82, shooting: 55, passing: 78, dribbling: 80, defending: 89, physical: 76,
                    rarity: .elite, specialAbility: "Interception Radar",
                    biography: "Seemed to read the opposition's next pass before they'd decided on it."),

        // MARK: 2020s
        LegendsCard(id: "mbappa-2223", name: "K. Mbappa", season: "2022/23", era: .twentyTwenties,
                    club: "Bernabéu Whites", nation: "France", position: .striker,
                    overall: 92, pace: 97, shooting: 88, passing: 78, dribbling: 91, defending: 28, physical: 76,
                    rarity: .icon, specialAbility: "Blistering Burst",
                    biography: "Sprint speed that turns a half-chance into a one-on-one in two touches."),
        LegendsCard(id: "mbappa-2223-tots", name: "K. Mbappa", season: "2022/23", era: .twentyTwenties,
                    club: "Bernabéu Whites", nation: "France", position: .striker,
                    overall: 95, pace: 98, shooting: 91, passing: 80, dribbling: 93, defending: 28, physical: 77,
                    rarity: .teamOfTheSeason, specialAbility: "Blistering Burst",
                    biography: "A boosted end-of-season tribute card for a golden-boot-winning campaign."),
        LegendsCard(id: "holland-2223", name: "E. Holland", season: "2022/23", era: .twentyTwenties,
                    club: "Etihad Blues", nation: "Norway", position: .striker,
                    overall: 91, pace: 89, shooting: 93, passing: 68, dribbling: 80, defending: 35, physical: 92,
                    rarity: .hero, specialAbility: "One-Touch Finish",
                    biography: "Built like a wall and finishes like a sniper — defenders rarely enjoy the matchup."),
        LegendsCard(id: "junior-2324", name: "V. Junior", season: "2023/24", era: .twentyTwenties,
                    club: "Bernabéu Whites", nation: "Brazil", position: .leftWing,
                    overall: 90, pace: 95, shooting: 82, passing: 78, dribbling: 92, defending: 28, physical: 70,
                    rarity: .hero, specialAbility: "Samba Feint",
                    biography: "Turns a footrace into a highlight reel every single time he gets the ball."),
        LegendsCard(id: "bellinghast-2324", name: "J. Bellinghast", season: "2023/24", era: .twentyTwenties,
                    club: "Bernabéu Whites", nation: "England", position: .centralMid,
                    overall: 89, pace: 80, shooting: 82, passing: 84, dribbling: 85, defending: 68, physical: 80,
                    rarity: .elite, specialAbility: "Late Box Arrival",
                    biography: "Arrives in the box a split second after the defence has stopped watching for him."),
        LegendsCard(id: "foddin-2223", name: "P. Foddin", season: "2022/23", era: .twentyTwenties,
                    club: "Etihad Blues", nation: "England", position: .attackingMid,
                    overall: 87, pace: 78, shooting: 78, passing: 85, dribbling: 89, defending: 40, physical: 62,
                    rarity: .rare, specialAbility: "Tight Turn",
                    biography: "Homegrown, two-footed and impossible to dispossess in a phone box."),

        // MARK: Future Stars
        LegendsCard(id: "marchetti-2526", name: "T. Marchetti", season: "2025/26", era: .futureStars,
                    club: "San Siro Nerazzurri", nation: "Italy", position: .striker,
                    overall: 78, pace: 90, shooting: 76, passing: 65, dribbling: 82, defending: 30, physical: 70,
                    rarity: .rare, specialAbility: "Raw Pace",
                    biography: "Still learning the finer points, but nobody in the league can catch him."),
        LegendsCard(id: "odusanya-2526", name: "K. Odusanya", season: "2025/26", era: .futureStars,
                    club: "Highbury", nation: "Nigeria", position: .rightWing,
                    overall: 76, pace: 88, shooting: 70, passing: 68, dribbling: 85, defending: 26, physical: 64,
                    rarity: .rare, specialAbility: "Explosive Cut-Inside",
                    biography: "Academy graduate already drawing comparisons to the club's greats."),
        LegendsCard(id: "lindqvist-2526", name: "M. Lindqvist", season: "2025/26", era: .futureStars,
                    club: "Bavarian Reds", nation: "Sweden", position: .centreBack,
                    overall: 75, pace: 78, shooting: 35, passing: 70, dribbling: 60, defending: 80, physical: 82,
                    rarity: .common, specialAbility: "Composed Under Pressure",
                    biography: "A calm ball-playing defender tipped for full international honours."),
        LegendsCard(id: "fontaine-2526", name: "D. Fontaine", season: "2025/26", era: .futureStars,
                    club: "Old Trafford Reds", nation: "France", position: .holding,
                    overall: 74, pace: 72, shooting: 50, passing: 76, dribbling: 72, defending: 78, physical: 74,
                    rarity: .common, specialAbility: "Tireless Cover",
                    biography: "Barely twenty and already the calmest head in a young midfield."),

        // MARK: Legends
        LegendsCard(id: "nascimento-62", name: "E. Nascimento", season: "1962 Golden Era", era: .legends,
                    club: "Camp Blaugrana", nation: "Brazil", position: .striker,
                    overall: 96, pace: 88, shooting: 94, passing: 82, dribbling: 95, defending: 30, physical: 78,
                    rarity: .legend, specialAbility: "Bicycle Kick",
                    biography: "Spoken about in whispers even by players who never saw him play."),
        LegendsCard(id: "maradana-8687", name: "D. Maradana", season: "1986/87", era: .legends,
                    club: "San Siro Nerazzurri", nation: "Argentina", position: .attackingMid,
                    overall: 96, pace: 82, shooting: 88, passing: 90, dribbling: 97, defending: 32, physical: 68,
                    rarity: .legend, specialAbility: "Slalom Dribble",
                    biography: "Dragged an entire team to glory almost single-footedly."),
        LegendsCard(id: "cruyffe-7172", name: "J. Cruyffe", season: "1971/72", era: .legends,
                    club: "Amsterdam Godenzonen", nation: "Netherlands", position: .striker,
                    overall: 95, pace: 84, shooting: 86, passing: 88, dribbling: 92, defending: 40, physical: 62,
                    rarity: .legend, specialAbility: "Turn of Genius",
                    biography: "Invented a piece of skill so good it still carries his name."),
        LegendsCard(id: "beckenwald-7273", name: "F. Beckenwald", season: "1972/73", era: .legends,
                    club: "Bavarian Reds", nation: "Germany", position: .centreBack,
                    overall: 94, pace: 74, shooting: 55, passing: 84, dribbling: 74, defending: 90, physical: 78,
                    rarity: .legend, specialAbility: "Libero Vision",
                    biography: "Redefined what a defender could be by simply refusing to stop attacking."),

        // MARK: Icons
        LegendsCard(id: "silveira-icon", name: "R. Silveira", season: "Icon", era: .icons,
                    club: "San Siro Nerazzurri", nation: "Brazil", position: .striker,
                    overall: 96, pace: 92, shooting: 95, passing: 76, dribbling: 93, defending: 25, physical: 84,
                    rarity: .icon, specialAbility: "Explosive First Touch",
                    biography: "Two knee reconstructions couldn't slow down the most feared striker of his era."),
        LegendsCard(id: "destefano-icon", name: "F. De Stefano", season: "Icon", era: .icons,
                    club: "Bernabéu Whites", nation: "Argentina", position: .striker,
                    overall: 96, pace: 80, shooting: 92, passing: 82, dribbling: 88, defending: 45, physical: 80,
                    rarity: .icon, specialAbility: "Complete Forward",
                    biography: "Scored in five straight continental finals and never once looked tired."),
        LegendsCard(id: "nascimento-immortal", name: "E. Nascimento", season: "Immortal", era: .icons,
                    club: "Camp Blaugrana", nation: "Brazil", position: .striker,
                    overall: 99, pace: 92, shooting: 97, passing: 86, dribbling: 98, defending: 32, physical: 80,
                    rarity: .immortal, specialAbility: "Bicycle Kick",
                    biography: "The ultimate tribute card — every stat maxed for the player people still argue is the greatest ever."),
        LegendsCard(id: "maldinho-icon", name: "P. Maldinho", season: "Icon", era: .icons,
                    club: "San Siro Rossoneri", nation: "Italy", position: .centreBack,
                    overall: 95, pace: 78, shooting: 48, passing: 82, dribbling: 74, defending: 97, physical: 88,
                    rarity: .icon, specialAbility: "Positional Perfection",
                    biography: "A career so clean he's remembered for the tackles he never needed to make."),
    ]
}
