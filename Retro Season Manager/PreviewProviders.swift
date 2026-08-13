//
//  PreviewProviders.swift
//  Retro Season Manager
//
//  Xcode canvas #Preview providers for the main screens.
//

import SwiftUI

#Preview {
    ContentView()
}

#Preview("Home Menu", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 4)
    store.advanceDay()
    store.advanceDay()
    store.advanceDay()
    return MainGameView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
        .background(Retro.background)
}

#Preview("Team / Tactics", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 4)
    return SquadView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
        .background(Retro.background)
}

@MainActor
private func matchPreviewStore() -> GameStore {
    let store = GameStore()
    store.newGame(clubIndex: 3)   // Stamford Blues — blue theme
    var days = 0
    while !store.isUserMatchToday && days < 90 { store.advanceDay(); days += 1 }
    store.beginUserMatch()
    if let live = store.live {
        // Advance the clock a little for a populated preview.
        for _ in 0..<70 { live.testAdvanceMinute() }
    }
    return store
}

#Preview("Live Match", traits: .landscapeLeft) {
    let store = matchPreviewStore()
    return Group {
        if let live = store.live {
            MatchView(store: store, live: live)
        }
    }
    .font(.system(.body, design: .monospaced))
    .foregroundStyle(Retro.text)
    .tint(Retro.accent)
    .background(Retro.background)
}

#Preview("Transfers", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 2)
    return TransfersView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
        .background(Retro.background)
}

#Preview("Player Profile", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 2)
    let target = store.transferMarket.first { $0.sellingClubIndex != nil }!
    store.scout(target)
    for _ in 0..<4 { store.advanceDay() }
    return PlayerProfileSheet(store: store, context: .market(target)) { _ in }
}

#Preview("Pre-Match Hub", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 4)
    var d = 0; while !store.isUserMatchToday && d < 90 { store.advanceDay(); d += 1 }
    store.enterPreMatch()
    return PreMatchHubView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
}

#Preview("Main Menu", traits: .landscapeLeft) {
    MainMenuView(store: GameStore())
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
}

#Preview("Club Select", traits: .landscapeLeft) {
    ClubSelectView(store: GameStore())
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
        .background(Retro.background)
}

#Preview("Division Tables", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 24)
    for _ in 0..<60 { store.advanceDay(); if store.isUserMatchToday { store.beginUserMatch(); store.live?.skipToEnd(); store.finishLiveMatch() } }
    return TableView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
        .background(Retro.background)
}


#Preview("Season Review", traits: .landscapeLeft) {
    let store = GameStore()
    store.newGame(clubIndex: 0)
    while !store.isSeasonOver {
        if store.isUserMatchToday { store.beginUserMatch(); store.live?.skipToEnd(); store.finishLiveMatch() }
        else { store.advanceDay() }
    }
    return SeasonReviewView(store: store)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Retro.text)
        .tint(Retro.accent)
}
