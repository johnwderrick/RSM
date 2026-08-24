import XCTest
import UIKit
@testable import Retro_Season_Manager

/// Verifies that the experience-selector's normal/pressed artwork selection
/// (shared by the button styles and UI) stays in sync with a button's press
/// state, and that every referenced asset actually exists in the app bundle.
final class ExperienceSelectorArtworkTests: XCTestCase {

    // MARK: - Selection logic

    func testCareerEntrySwapsToPressedArtworkOnPress() {
        XCTAssertEqual(ExperienceSelectorArtwork.entry(.career, pressed: false), "RSMCareerEntryButton")
        XCTAssertEqual(ExperienceSelectorArtwork.entry(.career, pressed: true), "RSMCareerEntryButtonPressed")
    }

    func testLegendsEntrySwapsToPressedArtworkOnPress() {
        XCTAssertEqual(ExperienceSelectorArtwork.entry(.legends, pressed: false), "RSMLegendsEntryButton")
        XCTAssertEqual(ExperienceSelectorArtwork.entry(.legends, pressed: true), "RSMLegendsEntryButtonPressed")
    }

    func testSettingsSwapsToPressedArtworkOnPress() {
        XCTAssertEqual(ExperienceSelectorArtwork.settings(pressed: false), "RSMSettingsButton")
        XCTAssertEqual(ExperienceSelectorArtwork.settings(pressed: true), "RSMSettingsButtonPressed")
    }

    func testNormalAndPressedNamesDifferForEveryButton() {
        // If normal == pressed, the button would render the same image in both
        // states, meaning the two-state wiring is broken.
        for kind in [ExperienceSelectorArtwork.Entry.career, .legends] {
            XCTAssertNotEqual(ExperienceSelectorArtwork.entry(kind, pressed: false),
                              ExperienceSelectorArtwork.entry(kind, pressed: true),
                              "Entry artwork should differ between press states")
        }
        XCTAssertNotEqual(ExperienceSelectorArtwork.settings(pressed: false),
                          ExperienceSelectorArtwork.settings(pressed: true))
    }

    // MARK: - Asset existence

    func testAllReferencedAssetsExistInBundle() {
        let expected = [
            "RSMCareerEntryButton",
            "RSMCareerEntryButtonPressed",
            "RSMLegendsEntryButton",
            "RSMLegendsEntryButtonPressed",
            "RSMSettingsButton",
            "RSMSettingsButtonPressed",
        ]
        for name in expected {
            XCTAssertNotNil(UIImage(named: name), "Missing asset in app bundle: \(name)")
        }
    }
}
