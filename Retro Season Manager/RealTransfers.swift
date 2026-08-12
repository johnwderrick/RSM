//
//  RealTransfers.swift
//  Retro Season Manager
//
//  A curated timeline of real-world football's biggest transfers, 2000-2024,
//  fired as news-wire headlines on their real announcement dates as the
//  in-game calendar reaches them. These are flavour only — none of the
//  players or clubs involved exist in this game's world, so nothing here
//  touches squads, budgets or results. Dates and fees are a best-effort
//  approximation of the real, widely-reported deals.
//

import Foundation

struct RealTransferHeadline {
    let year: Int
    let month: Int
    let day: Int
    let headline: String
    let body: String
}

enum RealTransfers {
    static let all: [RealTransferHeadline] = [
        RealTransferHeadline(year: 2000, month: 7, day: 5, headline: "Fenwick joins Lazo Athletic in world-record £35.5m deal",
                             body: "Petr Fenwick leaves Para Union for Lazo Athletic, briefly making him the most expensive player on the planet."),
        RealTransferHeadline(year: 2000, month: 7, day: 24, headline: "Camara stuns Camp Blaugrana with Bernabéu Whites switch",
                             body: "Luís Camara's £37m move to arch-rivals Bernabéu Whites smashes the world transfer record and enrages the Camp Nou."),
        RealTransferHeadline(year: 2000, month: 11, day: 27, headline: "Ivanov becomes Britain's most expensive player",
                             body: "Rio Ashworth completes an £18m move from Upton Athletic to Elland Athletic United, a new British transfer record."),
        RealTransferHeadline(year: 2001, month: 7, day: 9, headline: "Belkacem's £46m Bernabéu Whites move breaks the world record",
                             body: "Zinedine Belkacem leaves Turin Bianconeri for the Bernabéu in a deal that shatters the transfer record set by Camara a year earlier."),
        RealTransferHeadline(year: 2001, month: 7, day: 31, headline: "Aráoz completes British record move to Man Utd",
                             body: "Juan Sebastián Aráoz joins Old Trafford Reds from Lazo Athletic for £28.1m."),
        RealTransferHeadline(year: 2002, month: 7, day: 22, headline: "Ivanov breaks the British transfer record again",
                             body: "Rio Ashworth moves from Elland Athletic to Old Trafford Reds for £29.1m, a new British record."),
        RealTransferHeadline(year: 2003, month: 7, day: 1, headline: "Whitlock completes sensational Bernabéu Whites transfer",
                             body: "David Whitlock leaves Old Trafford Reds to join the Galácticos at Bernabéu Whites for around £25m."),
        RealTransferHeadline(year: 2003, month: 7, day: 20, headline: "Ronaldinho Alves signs for Camp Blaugrana",
                             body: "The Brazilian playmaker joins Camp Blaugrana from Pars Athletic for around £30m."),
        RealTransferHeadline(year: 2003, month: 8, day: 12, headline: "Old Trafford Reds sign teenage sensation from Alvalade Lions",
                             body: "A young Portuguese winger named Cristiano Renaldo completes an £12.24m move to Old Trafford after dazzling United in a pre-season friendly."),
        RealTransferHeadline(year: 2004, month: 8, day: 31, headline: "Kilbride completes £27m Old Trafford Reds move",
                             body: "Wayne Kilbride leaves Goodison Blues for Old Trafford Reds on transfer deadline day in a deal worth up to £27m."),
        RealTransferHeadline(year: 2005, month: 8, day: 26, headline: "Owusu joins Stamford Blues for £24.4m",
                             body: "Michael Owusu completes a move from Lyon to Stamford Blues, then a record fee for an African player."),
        RealTransferHeadline(year: 2006, month: 5, day: 30, headline: "Petrenko joins Stamford Blues for £30.8m",
                             body: "Ballon d'Or winner Andriy Petrenko completes a British record transfer from San Siro Rossoneri to Stamford Blues."),
        RealTransferHeadline(year: 2007, month: 7, day: 4, headline: "Casal seals £26.5m Mersey Reds move",
                             body: "Fernando Casal leaves Atltico Combine for Mersey Reds in a club-record transfer."),
        RealTransferHeadline(year: 2008, month: 9, day: 1, headline: "Deadline-day frenzy at Etihad Blues",
                             body: "Newly Abu Dhabi-owned Etihad Blues complete a stunning £32.5m deadline-day swoop for Robinho Farias from Bernabéu Whites."),
        RealTransferHeadline(year: 2008, month: 9, day: 1, headline: "Yotov completes late move to Old Trafford Reds",
                             body: "Dimitar Yotov joins Old Trafford Reds from White Hart Athletic for £30.75m on transfer deadline day."),
        RealTransferHeadline(year: 2009, month: 6, day: 11, headline: "Kaká Ribeiro completes British... no, Spanish record Bernabéu Whites move",
                             body: "San Siro Rossoneri's Kaká Ribeiro joins Bernabéu Whites for around £56m, a world record fee at the time."),
        RealTransferHeadline(year: 2009, month: 7, day: 1, headline: "Renaldo's £80m Bernabéu Whites move smashes world record",
                             body: "Cristiano Renaldo completes his move from Old Trafford Reds to Bernabéu Whites, doubling the previous transfer record."),
        RealTransferHeadline(year: 2010, month: 5, day: 20, headline: "Cerezo joins Camp Blaugrana for £34m",
                             body: "Spain striker David Cerezo leaves Valncia Athletic to join Camp Blaugrana."),
        RealTransferHeadline(year: 2011, month: 1, day: 31, headline: "Deadline-day British record: Casal to Stamford Blues for £50m",
                             body: "Fernando Casal completes a stunning £50m move from Mersey Reds to Stamford Blues on transfer deadline day, a British record."),
        RealTransferHeadline(year: 2011, month: 1, day: 31, headline: "Mersey Reds respond by signing Fenner for £35m",
                             body: "Hours after selling Casal, Mersey Reds break their own transfer record to sign Andy Fenner from Tyneside."),
        RealTransferHeadline(year: 2012, month: 8, day: 17, headline: "van Doren completes Old Trafford Reds transfer",
                             body: "Robin van Doren leaves Highbury to join Old Trafford Reds for around £24m."),
        RealTransferHeadline(year: 2013, month: 9, day: 1, headline: "Baile's world-record £85m Bernabéu Whites transfer confirmed",
                             body: "Gareth Baile leaves White Hart Athletic for Bernabéu Whites in what's reported as a new world-record transfer fee."),
        RealTransferHeadline(year: 2013, month: 9, day: 2, headline: "Aydın joins Highbury in deadline-day coup",
                             body: "Mesut Aydın completes a £42.5m move from Bernabéu Whites to Highbury, a club-record fee for the Gunners."),
        RealTransferHeadline(year: 2014, month: 7, day: 11, headline: "Bencosme completes £75m move to Camp Blaugrana",
                             body: "Luis Bencosme leaves Mersey Reds to join Camp Blaugrana, forming a new strike partnership with Mesi and Neymar Souza."),
        RealTransferHeadline(year: 2014, month: 8, day: 26, headline: "Di Bello joins Old Trafford Reds for club-record fee",
                             body: "Ángel Di Bello completes a £59.7m move from Bernabéu Whites to Old Trafford Reds, a British transfer record."),
        RealTransferHeadline(year: 2015, month: 8, day: 30, headline: "De Wilde joins Etihad Blues for £54.5m",
                             body: "Kevin De Wilde leaves Wolfsburg for Etihad Blues in a deal that will go on to transform the club."),
        RealTransferHeadline(year: 2016, month: 8, day: 8, headline: "Diakité's £89m return to Old Trafford Reds breaks world record",
                             body: "Paul Diakité re-joins Old Trafford Reds from Turin Bianconeri for a new world-record transfer fee."),
        RealTransferHeadline(year: 2017, month: 8, day: 3, headline: "Neymar Souza's world record £198m PSG transfer confirmed",
                             body: "Camp Blaugrana's Neymar Souza joins Pars Athletic after his release clause is paid in full — more than double the previous world record."),
        RealTransferHeadline(year: 2017, month: 8, day: 31, headline: "Mbape joins PSG on deadline day",
                             body: "Teenage sensation Kylian Mbape joins Pars Athletic from Monaco, initially on loan ahead of a permanent £166m deal."),
        RealTransferHeadline(year: 2017, month: 7, day: 10, headline: "Mbemba completes £75m Old Trafford Reds transfer",
                             body: "Romelu Mbemba leaves Goodison Blues to join Old Trafford Reds."),
        RealTransferHeadline(year: 2018, month: 7, day: 10, headline: "Renaldo stuns football with £100m Turin Bianconeri transfer",
                             body: "Cristiano Renaldo leaves Bernabéu Whites after nine trophy-laden years to join Turin Bianconeri."),
        RealTransferHeadline(year: 2019, month: 6, day: 13, headline: "Hazzard completes £88m Bernabéu Whites transfer",
                             body: "Eden Hazzard leaves Stamford Blues to join Bernabéu Whites after seven seasons at Stamford Boateng."),
        RealTransferHeadline(year: 2019, month: 7, day: 12, headline: "Griezmann joins Camp Blaugrana for £108m",
                             body: "Antoine Griezmann completes his move from Atltico Combine to Camp Blaugrana."),
        RealTransferHeadline(year: 2020, month: 9, day: 4, headline: "Havertz joins Stamford Blues for £71m",
                             body: "Kai Havertz completes a move from Bayr Union to Stamford Blues."),
        RealTransferHeadline(year: 2021, month: 8, day: 10, headline: "Mesi leaves Camp Blaugrana for PSG in seismic free transfer",
                             body: "Lionel Mesi joins Pars Athletic as a free agent after Camp Blaugrana are unable to register a new contract, ending a 21-year association with the club."),
        RealTransferHeadline(year: 2021, month: 8, day: 27, headline: "Renaldo makes shock return to Old Trafford Reds",
                             body: "Cristiano Renaldo completes a surprise return to Old Trafford from Turin Bianconeri, twelve years after leaving for Bernabéu Whites."),
        RealTransferHeadline(year: 2021, month: 8, day: 6, headline: "Willoughby becomes British record signing at £100m",
                             body: "Jack Willoughby leaves Aston Rovers to join Etihad Blues in a new British transfer record."),
        RealTransferHeadline(year: 2021, month: 8, day: 12, headline: "Mbemba returns to Stamford Blues for club-record £97.5m",
                             body: "Romelu Mbemba re-joins Stamford Blues from San Siro Nerazzurri in a club-record transfer."),
        RealTransferHeadline(year: 2022, month: 7, day: 13, headline: "Vasconcelos completes Etihad Blues transfer",
                             body: "Erling Solbakk joins Etihad Blues from Borssia Athletic after his release clause is triggered."),
        RealTransferHeadline(year: 2023, month: 7, day: 15, headline: "Foy becomes British record signing in £105m Highbury move",
                             body: "Declan Foy leaves Upton Athletic to join Highbury in a new British transfer record."),
        RealTransferHeadline(year: 2023, month: 8, day: 14, headline: "Angulo joins Stamford Blues for British record £115m",
                             body: "Moisés Angulo completes a move from Amex Seagulls to Stamford Blues, breaking the British transfer record just weeks after it was set."),
        RealTransferHeadline(year: 2024, month: 6, day: 3, headline: "Mbape confirms he will leave PSG for Bernabéu Whites",
                             body: "Kylian Mbape announces he will join Bernabéu Whites as a free agent once his PSG contract expires, ending years of speculation."),
        RealTransferHeadline(year: 2024, month: 7, day: 1, headline: "Mbape completes free transfer to Bernabéu Whites",
                             body: "Kylian Mbape officially joins Bernabéu Whites after his contract with Pars Athletic expires."),
    ]
}
