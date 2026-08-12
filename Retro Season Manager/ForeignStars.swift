//
//  ForeignStars.swift
//  Retro Season Manager
//
//  A handful of real, recognisable players seeded into the more notable
//  clubs of the new Spain/Italy/Germany/France top-flight pools, so a
//  European draw throws up some familiar names rather than an entirely
//  generated squad. Not exhaustive — only clubs/players I'm reasonably
//  confident about for the 2000/01 season are included; everyone else in
//  these divisions stays fully generated. Positions and ages are a game
//  abstraction, not researched to the same depth as the English pyramid.
//

import Foundation

struct ForeignStar {
    let club: String
    let name: String
    let detailedPosition: DetailedPosition
    let age: Int
    let rating: Int
}

enum ForeignStars {
    static let all: [ForeignStar] = [
        // Spain
        ForeignStar(club: "Valncia Athletic", name: "Chidi Aldous", detailedPosition: .centralMid, age: 26, rating: 82),
        ForeignStar(club: "Valncia Athletic", name: "Kofi Castellan", detailedPosition: .leftWing, age: 25, rating: 74),
        ForeignStar(club: "Deprtivo Rovers", name: "Andre Petrov", detailedPosition: .attackingMid, age: 30, rating: 80),
        ForeignStar(club: "Deprtivo Rovers", name: "Tunde Keita", detailedPosition: .striker, age: 24, rating: 78),
        ForeignStar(club: "Atltico Combine", name: "Niklas Bernard", detailedPosition: .attackingMid, age: 25, rating: 78),
        ForeignStar(club: "Cela Union", name: "Andre Harding", detailedPosition: .attackingMid, age: 31, rating: 79),
        ForeignStar(club: "Real Wanderers", name: "Milan Keita", detailedPosition: .striker, age: 27, rating: 74),
        ForeignStar(club: "Athetic Rangers", name: "Felipe Keita", detailedPosition: .striker, age: 26, rating: 70),
        ForeignStar(club: "Real Sporting", name: "Karim Sandham", detailedPosition: .leftWing, age: 23, rating: 76),
        ForeignStar(club: "Real Sporting", name: "Hugo Vogel", detailedPosition: .striker, age: 28, rating: 74),
        ForeignStar(club: "Malorca Dynamo", name: "Nico Ndiaye", detailedPosition: .striker, age: 19, rating: 74),
        ForeignStar(club: "Alaés Comrades", name: "Stefano Halvorsen", detailedPosition: .striker, age: 26, rating: 76),
        ForeignStar(club: "Espnyol Rovers", name: "Daniel Solheim", detailedPosition: .striker, age: 22, rating: 72),
        ForeignStar(club: "Sevlla Combine", name: "Niklas Baumann", detailedPosition: .leftWing, age: 17, rating: 62),
        ForeignStar(club: "Málga Wanderers", name: "Shane Vasconcelos", detailedPosition: .striker, age: 28, rating: 74),

        // Italy
        ForeignStar(club: "Lazo Athletic", name: "Petr Fenwick", detailedPosition: .striker, age: 25, rating: 88),
        ForeignStar(club: "Lazo Athletic", name: "Anton Harding", detailedPosition: .centreBack, age: 24, rating: 87),
        ForeignStar(club: "Tiber Reds", name: "Francesco Amadori", detailedPosition: .attackingMid, age: 24, rating: 87),
        ForeignStar(club: "Tiber Reds", name: "Gabriel Ordoñez", detailedPosition: .striker, age: 31, rating: 87),
        ForeignStar(club: "Tiber Reds", name: "Gordon Rousseau", detailedPosition: .attackingMid, age: 23, rating: 78),
        ForeignStar(club: "Para Union", name: "Gianluigi Serrano", detailedPosition: .goalkeeper, age: 22, rating: 86),
        ForeignStar(club: "Para Union", name: "Owen Aldous", detailedPosition: .centreBack, age: 28, rating: 84),
        ForeignStar(club: "Fioentina Wanderers", name: "Aaron Eriksson", detailedPosition: .attackingMid, age: 28, rating: 85),
        ForeignStar(club: "Fioentina Wanderers", name: "Rasmus Winters", detailedPosition: .striker, age: 23, rating: 78),
        ForeignStar(club: "Brecia Rangers", name: "Roberto Fanti", detailedPosition: .attackingMid, age: 33, rating: 82),
        ForeignStar(club: "Udiese Rangers", name: "Niklas Radley", detailedPosition: .attackingMid, age: 25, rating: 76),
        ForeignStar(club: "Ataanta Athletic", name: "Gareth Fenwick", detailedPosition: .attackingMid, age: 30, rating: 74),
        ForeignStar(club: "Bolgna Combine", name: "Mathis Serrano", detailedPosition: .striker, age: 32, rating: 76),
        ForeignStar(club: "Pergia Sporting", name: "Karim Zeman", detailedPosition: .striker, age: 21, rating: 68),
        ForeignStar(club: "Regina Dynamo", name: "Callum Berg", detailedPosition: .striker, age: 29, rating: 70),

        // Germany
        ForeignStar(club: "Borssia Athletic", name: "Julio Ashcroft", detailedPosition: .attackingMid, age: 24, rating: 74),
        ForeignStar(club: "Borssia Athletic", name: "Rasmus Reuter", detailedPosition: .striker, age: 31, rating: 72),
        ForeignStar(club: "Schlke Rovers", name: "Oskar Calder", detailedPosition: .striker, age: 28, rating: 78),
        ForeignStar(club: "Bayr Union", name: "Michael Reinholt", detailedPosition: .attackingMid, age: 24, rating: 82),
        ForeignStar(club: "Bayr Union", name: "Jonas Rusev", detailedPosition: .leftWing, age: 26, rating: 76),
        ForeignStar(club: "VfB Wanderers", name: "Dario Lefevre", detailedPosition: .attackingMid, age: 33, rating: 76),
        ForeignStar(club: "Hamurger Rangers", name: "Gustavo Cahill", detailedPosition: .striker, age: 28, rating: 76),
        ForeignStar(club: "Werer Combine", name: "Erik Cahill", detailedPosition: .leftWing, age: 33, rating: 72),
        ForeignStar(club: "Herha Sporting", name: "Jamie Lindqvist", detailedPosition: .striker, age: 32, rating: 72),
        ForeignStar(club: "Kaierslautern Reserve", name: "Nathan Krause", detailedPosition: .striker, age: 33, rating: 70),
        ForeignStar(club: "Kaierslautern Reserve", name: "Hugo Sandham", detailedPosition: .attackingMid, age: 32, rating: 80),
        ForeignStar(club: "1860 Athletic", name: "Wesley Hartmann", detailedPosition: .striker, age: 32, rating: 74),
        ForeignStar(club: "Borssia Athletic", name: "Jens Wieland", detailedPosition: .goalkeeper, age: 31, rating: 80),
        ForeignStar(club: "Herha Sporting", name: "Steven Lefevre", detailedPosition: .attackingMid, age: 20, rating: 78),
        ForeignStar(club: "Schlke Rovers", name: "Craig Dubois", detailedPosition: .attackingMid, age: 31, rating: 74),
        ForeignStar(club: "FC Combine", name: "Ivan Halvorsen", detailedPosition: .centralMid, age: 34, rating: 72),

        // France
        ForeignStar(club: "Pars Athletic", name: "Luca Rousseau", detailedPosition: .centreBack, age: 28, rating: 76),
        ForeignStar(club: "Pars Athletic", name: "Magnus Lefevre", detailedPosition: .leftWing, age: 25, rating: 76),
        ForeignStar(club: "Pars Athletic", name: "Nicolas Bertrand", detailedPosition: .striker, age: 21, rating: 78),
        ForeignStar(club: "Olypique Rovers", name: "Bruno Harding", detailedPosition: .striker, age: 28, rating: 76),
        ForeignStar(club: "Olypique Rovers", name: "Mark Grantham", detailedPosition: .centreBack, age: 22, rating: 74),
        ForeignStar(club: "Olypique Union", name: "Pietro Diallo", detailedPosition: .striker, age: 29, rating: 78),
        ForeignStar(club: "AS Wanderers", name: "Diego Keita", detailedPosition: .striker, age: 30, rating: 72),
        ForeignStar(club: "RC Rangers", name: "Colin Petrov", detailedPosition: .attackingMid, age: 27, rating: 72),
        ForeignStar(club: "Girndins Combine", name: "Felix Mendes", detailedPosition: .attackingMid, age: 25, rating: 76),
        ForeignStar(club: "Nanes Sporting", name: "Bruno Castellan", detailedPosition: .goalkeeper, age: 21, rating: 74),
        ForeignStar(club: "AJ Dynamo", name: "Karim Dvorak", detailedPosition: .striker, age: 19, rating: 66),
        ForeignStar(club: "Moselle Athletic", name: "Petr Cahill", detailedPosition: .centralMid, age: 25, rating: 70),
        ForeignStar(club: "Renes Olympic", name: "Petr Novotný", detailedPosition: .goalkeeper, age: 18, rating: 66),
        ForeignStar(club: "AS Wanderers", name: "Carlos Aldous", detailedPosition: .rightWing, age: 24, rating: 76),
        ForeignStar(club: "AJ Dynamo", name: "Milan Fischer", detailedPosition: .attackingMid, age: 20, rating: 68),
        ForeignStar(club: "Lile Rangers", name: "Gordon Girard", detailedPosition: .centreBack, age: 26, rating: 68),
    ]
}
