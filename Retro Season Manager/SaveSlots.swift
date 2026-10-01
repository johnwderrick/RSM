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
    /// A user-chosen save title is independent of the current club, which
    /// may change during a career.
    var customName: String? = nil

    var displayName: String { customName ?? clubName }
}

enum SaveSlots {
#if DEBUG
    enum DebugWriteFailure { case saveFile, index }
    /// Consumed by the next matching write; used to exercise disk failures
    /// without changing a real save or depending on filesystem permissions.
    static var debugFailNextWrite: DebugWriteFailure?
#endif

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
        guard let list = try? readIndex() else { return [] }
        return list.sorted { $0.lastPlayed > $1.lastPlayed }
    }

    /// A missing index is a fresh install. A damaged or unreadable index is
    /// an error: never replace it with an empty list during a save.
    private static func readIndex() throws -> [SaveSlotInfo] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return [] }
        return try JSONDecoder().decode([SaveSlotInfo].self, from: Data(contentsOf: indexURL))
    }

    @discardableResult
    static func writeSaveData(_ data: Data, for id: UUID) -> Bool {
#if DEBUG
        if debugFailNextWrite == .saveFile {
            debugFailNextWrite = nil
            return false
        }
#endif
        do {
            try data.write(to: fileURL(for: id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func write(_ list: [SaveSlotInfo]) -> Bool {
#if DEBUG
        if debugFailNextWrite == .index {
            debugFailNextWrite = nil
            return false
        }
#endif
        do {
            try JSONEncoder().encode(list).write(to: indexURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func upsert(_ info: SaveSlotInfo) -> Bool {
        guard var list = try? readIndex() else { return false }
        if let index = list.firstIndex(where: { $0.id == info.id }) {
            list[index] = info
        } else {
            list.append(info)
        }
        return write(list)
    }

    @discardableResult
    static func remove(_ id: UUID) -> Bool {
        guard let list = try? readIndex(), write(list.filter { $0.id != id }) else { return false }
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        return (try? FileManager.default.removeItem(at: url)) != nil
    }

    static func rename(_ id: UUID, to name: String) {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        guard var list = try? readIndex() else { return }
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index].customName = title == list[index].clubName ? nil : title
        write(list)
    }

    /// Older builds stored a renamed title in `clubName`. A successful load
    /// lets us compare it with the actual club in the save without decoding
    /// every save merely to render the picker.
    static func preserveLegacyRename(_ id: UUID, savedClubName: String) {
        guard var list = try? readIndex() else { return }
        guard let index = list.firstIndex(where: { $0.id == id }),
              list[index].customName == nil,
              list[index].clubName != savedClubName else { return }
        list[index].customName = list[index].clubName
        list[index].clubName = savedClubName
        write(list)
    }

    /// The most recently played slot's id, for a one-tap "Continue".
    static var mostRecentID: UUID? { all().first?.id }
}
