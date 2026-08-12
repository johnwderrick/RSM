//
//  SaveSlots.swift
//  Retro Season Manager
//
//  Lightweight metadata for multiple named career saves, kept separate
//  from the (potentially large) save files themselves so the "load game"
//  list can render instantly without decoding every save on disk.
//

import Foundation

struct SaveSlotInfo: Codable, Identifiable, Equatable {
    let id: UUID
    var clubName: String
    var managerName: String
    var season: Int
    var divisionName: String
    var lastPlayed: Date
}

enum SaveSlots {
    private static var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("saves", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static var indexURL: URL { directory.appendingPathComponent("index.json") }

    static func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    /// Every save slot, most recently played first.
    static func all() -> [SaveSlotInfo] {
        guard let data = try? Data(contentsOf: indexURL),
              let list = try? JSONDecoder().decode([SaveSlotInfo].self, from: data) else { return [] }
        return list.sorted { $0.lastPlayed > $1.lastPlayed }
    }

    private static func write(_ list: [SaveSlotInfo]) {
        if let data = try? JSONEncoder().encode(list) { try? data.write(to: indexURL) }
    }

    static func upsert(_ info: SaveSlotInfo) {
        var list = all()
        if let index = list.firstIndex(where: { $0.id == info.id }) {
            list[index] = info
        } else {
            list.append(info)
        }
        write(list)
    }

    static func remove(_ id: UUID) {
        write(all().filter { $0.id != id })
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    static func rename(_ id: UUID, to name: String) {
        var list = all()
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index].clubName = name
        write(list)
    }

    /// The most recently played slot's id, for a one-tap "Continue".
    static var mostRecentID: UUID? { all().first?.id }
}
