//
//  GameStore+SaveSlotUITestFixture.swift
//  Retro Season Manager
//
//  An isolated DEBUG fixture for the main-menu Career Saves sheet.
//

import Foundation

#if DEBUG
extension GameStore {
    /// The UI-test launch argument opts into replacing only this simulator
    /// app's saves. Both entries are created through the real new-game and
    /// persistence path, so loading either exercises a valid career file.
    static func seedCareerSaveSlotsFixtureForDebug(corruptNewest: Bool = false) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("saves", isDirectory: true))
        try? FileManager.default.removeItem(at: legacySaveURL)

        let entries = catalogueEntries()
        for (offset, name) in ["Old Trafford Reds", "Highbury"].enumerated() {
            let clubIndex = entries.firstIndex { $0.name == name } ?? offset
            let career = GameStore()
            career.newGame(clubIndex: clubIndex, managerName: "Save Fixture \(offset + 1)")
            guard let id = career.currentSaveID,
                  var slot = SaveSlots.all().first(where: { $0.id == id }) else { continue }
            slot.lastPlayed = Date(timeIntervalSince1970: 1_800_000_000 + Double(offset * 86_400))
            SaveSlots.upsert(slot)
        }
        if corruptNewest, let newest = SaveSlots.all().first {
            try? Data("invalid career save".utf8).write(to: SaveSlots.fileURL(for: newest.id))
        }
    }
}
#endif
