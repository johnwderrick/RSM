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
    private static var isolatedTestingRoot: URL?

    /// Keeps regression-test saves out of a user's Documents directory.
    static func useIsolatedRootForTesting(_ root: URL?) {
        isolatedTestingRoot = root?.appendingPathComponent("saves", isDirectory: true)
    }

    enum DebugWriteFailure { case saveFile, index }
    /// Consumed by the next matching write; used to exercise disk failures
    /// without changing a real save or depending on filesystem permissions.
    static var debugFailNextWrite: DebugWriteFailure?
    static var debugFailNextRemoval = false
    static var isolatedRootForTesting: URL? { isolatedTestingRoot?.deletingLastPathComponent() }
#endif

    private static var directory: URL {
        #if DEBUG
        if let isolatedTestingRoot {
            try? FileManager.default.createDirectory(at: isolatedTestingRoot, withIntermediateDirectories: true)
            return isolatedTestingRoot
        }
        #endif
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("saves", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static var indexURL: URL { directory.appendingPathComponent("index.json") }
    private static let damagedIndexPrefix = "index.damaged-"

    static func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    /// Every save slot, most recently played first. Reads never write: a
    /// damaged index is rebuilt in memory from the save files alone.
    static func all() -> [SaveSlotInfo] {
        reconciled(recordedIndex() ?? []).sorted { $0.lastPlayed > $1.lastPlayed }
    }

    /// The index as recorded on disk, or nil when it is missing, unreadable or damaged.
    private static func recordedIndex() -> [SaveSlotInfo]? {
        guard let data = try? Data(contentsOf: indexURL) else { return nil }
        return try? JSONDecoder().decode([SaveSlotInfo].self, from: data)
    }

    /// The list a write must start from. A damaged index is copied aside
    /// first, so the bytes that failed to decode are never overwritten.
    /// Returns nil when the index cannot be read or that copy cannot be kept.
    private static func writableList() -> [SaveSlotInfo]? {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return reconciled([]) }
        guard let data = try? Data(contentsOf: indexURL) else { return nil }
        if let recorded = try? JSONDecoder().decode([SaveSlotInfo].self, from: data) {
            return reconciled(recorded)
        }
        guard keepDamagedIndex(data) else { return nil }
        return reconciled([])
    }

    /// Copies damaged index bytes beside the saves. Identical bytes are kept
    /// once, so repeated failed attempts do not pile up copies.
    private static func keepDamagedIndex(_ data: Data) -> Bool {
        let siblings = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let alreadyKept = siblings
            .filter { $0.lastPathComponent.hasPrefix(damagedIndexPrefix) }
            .contains { (try? Data(contentsOf: $0)) == data }
        if alreadyKept { return true }
        let backup = directory.appendingPathComponent("\(damagedIndexPrefix)\(UUID().uuidString).json")
        return (try? data.write(to: backup, options: .atomic)) != nil
    }

    /// Lists only recorded slots whose save file still exists, and adopts
    /// save files the index does not mention (for example, when the app
    /// stopped between a save write and its index update). Adopted slots
    /// take every field from the save itself; only the play time falls
    /// back to the file's modification date.
    private static func reconciled(_ recorded: [SaveSlotInfo]) -> [SaveSlotInfo] {
        let fm = FileManager.default
        var list = recorded.filter { fm.fileExists(atPath: fileURL(for: $0.id).path) }
        let known = Set(list.map(\.id))
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "json" {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  !known.contains(id),
                  let info = adoptedInfo(id: id, url: url) else { continue }
            list.append(info)
        }
        return list
    }

    private static func adoptedInfo(id: UUID, url: URL) -> SaveSlotInfo? {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(SaveState.self, from: data),
              state.clubs.indices.contains(state.userClubIndex) else { return nil }
        let club = state.clubs[state.userClubIndex]
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        return SaveSlotInfo(id: id, clubName: club.name, managerName: state.managerName ?? "",
                            season: state.season, divisionName: GameStore.divisionLabel(club.divisionTier),
                            lastPlayed: modified ?? state.currentDate)
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

    @discardableResult
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
        guard var list = writableList() else { return false }
        if let index = list.firstIndex(where: { $0.id == info.id }) {
            list[index] = info
        } else {
            list.append(info)
        }
        return write(list)
    }

    /// Deletes the save file first. If that fails the slot stays listed and
    /// nothing changes. The index entry is then dropped best-effort: reads
    /// ignore entries whose file is gone, so a failed index write cannot
    /// bring the deleted save back.
    @discardableResult
    static func remove(_ id: UUID) -> Bool {
        #if DEBUG
        if debugFailNextRemoval {
            debugFailNextRemoval = false
            return false
        }
        #endif
        let url = fileURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            guard (try? FileManager.default.removeItem(at: url)) != nil else { return false }
        }
        if let list = writableList() {
            write(list.filter { $0.id != id })
        }
        return true
    }

    @discardableResult
    static func rename(_ id: UUID, to name: String) -> Bool {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        guard var list = writableList() else { return false }
        guard let index = list.firstIndex(where: { $0.id == id }) else { return false }
        list[index].customName = title == list[index].clubName ? nil : title
        return write(list)
    }

    /// Older builds stored a renamed title in `clubName`. A successful load
    /// lets us compare it with the actual club in the save without decoding
    /// every save merely to render the picker.
    static func preserveLegacyRename(_ id: UUID, savedClubName: String) {
        guard var list = writableList() else { return }
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
