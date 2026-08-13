import XCTest
@testable import Retro_Season_Manager

final class CareerStoryGenerationTests: XCTestCase {
    private func storyStore() async -> GameStore {
        let store = await makeTestStore()
        await MainActor.run {
            store.managerName = "Alex Rivera"
            store.startYear = 2000
            store.clubs = [Club(name: "Test Club", shortName: "TST", players: [])]
            store.userClubIndex = 0
        }
        return store
    }

    func testEmptyCareerReturnsPlaceholderBiography() async {
        let store = await storyStore()
        let bio = await MainActor.run { store.generateAutobiography() }
        XCTAssertEqual(bio, "Alex Rivera's story is just beginning.")
    }

    func testJobStartBeatOpensTheBiography() async {
        let store = await storyStore()
        await MainActor.run {
            store.history = [SeasonRecord(season: 1, label: "2000/01", userClub: "Test Club",
                                          userDivision: "First Division", userPosition: 5,
                                          champion: "Rival FC", cupWinner: "—", euroWinner: "—",
                                          communityShieldWinner: "—")]
        }
        let bio = await MainActor.run { store.generateAutobiography() }
        XCTAssertEqual(bio, "Alex Rivera took over Test Club in 2000.")
    }

    func testTrophyBeatIsParsedFromCareerHonoursAndMatchedToItsSeason() async {
        let store = await storyStore()
        await MainActor.run {
            store.history = [SeasonRecord(season: 1, label: "2000/01", userClub: "Test Club",
                                          userDivision: "First Division", userPosition: 1,
                                          champion: "Test Club", cupWinner: "—", euroWinner: "—",
                                          communityShieldWinner: "—")]
            store.careerHonours = ["🏆 First Division title (2000/01)"]
        }
        let bio = await MainActor.run { store.generateAutobiography() }
        XCTAssertEqual(bio, "Alex Rivera took over Test Club in 2000. Won the First Division title in 2000.")
    }

    func testCareerTimelineProducesOneMomentPerBeatInSeasonOrder() async {
        let store = await storyStore()
        await MainActor.run {
            store.history = [
                SeasonRecord(season: 1, label: "2000/01", userClub: "Test Club", userDivision: "First Division",
                            userPosition: 5, champion: "Rival FC", cupWinner: "—", euroWinner: "—", communityShieldWinner: "—"),
                SeasonRecord(season: 2, label: "2001/02", userClub: "Test Club", userDivision: "First Division",
                            userPosition: 1, champion: "Test Club", cupWinner: "—", euroWinner: "—", communityShieldWinner: "—"),
            ]
            store.careerHonours = ["🏆 First Division title (2001/02)"]
        }
        let timeline = await MainActor.run { store.careerTimeline() }
        XCTAssertEqual(timeline.map(\.headline), ["Took over Test Club", "Won the First Division title"])
        XCTAssertEqual(timeline.map(\.year), [2000, 2001])
    }

    func testRetirementBeatOnlyAppearsOnceCareerEnded() async {
        let store = await storyStore()
        await MainActor.run {
            store.history = [SeasonRecord(season: 1, label: "2000/01", userClub: "Test Club",
                                          userDivision: "First Division", userPosition: 5,
                                          champion: "Rival FC", cupWinner: "—", euroWinner: "—",
                                          communityShieldWinner: "—")]
            store.careerEnded = true
            store.season = 1
        }
        let timeline = await MainActor.run { store.careerTimeline() }
        XCTAssertEqual(timeline.last?.headline, "Retired")
    }
}
