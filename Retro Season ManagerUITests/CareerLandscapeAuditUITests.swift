//
//  CareerLandscapeAuditUITests.swift
//  Retro Season ManagerUITests
//
//  Read-only compact-landscape audit tour for the Career main game shell:
//  visits every sidebar destination with the deterministic navigation
//  fixture, captures a screenshot per screen, and logs accessibility
//  red flags (missing labels, sub-24pt tap targets, off-screen buttons)
//  to stdout for evidence-driven fixes. Asserts only what must always
//  hold; the audit findings drive the actual fixes.
//
//  The app is landscape-locked: XCUIDevice.orientation is never written
//  and all interactions are existence waits plus native element taps.
//

import XCTest

final class CareerLandscapeAuditUITests: XCTestCase {

    override func setUpWithError() throws {
        // This slow diagnostic tour is opt-in; the focused polish tests
        // provide the normal CI gate. Enable this in the test scheme's
        // environment when collecting a fresh audit.
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RSM_RUN_LANDSCAPE_AUDIT"] == "1",
                          "Set RSM_RUN_LANDSCAPE_AUDIT=1 to run the diagnostic tour")
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_CAREER_NAVIGATION"]
        app.launch()
        return app
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/career_audit_\(name).png"))
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: name, payload: png)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Logs user-facing accessibility red flags for on-screen elements.
    private func auditVisible(_ app: XCUIApplication, _ screen: String) {
        var findings: [String] = []
        func frameOf(_ el: XCUIElement) -> CGRect? {
            // Some elements (e.g. buttons with invalid activation points)
            // throw when XCUITest resolves hittability/frames — record them
            // as findings instead of letting the tour die on them.
            let exists = el.waitForExistence(timeout: 1)
            if !exists { return nil }
            return el.frame
        }
        func walk(_ elements: [XCUIElement]) {
            for el in elements {
                guard let f = frameOf(el) else { continue }
                let label = el.label.trimmingCharacters(in: .whitespaces)
                let isTextual = el.elementType == .staticText || el.elementType == .image
                if !isTextual && label.isEmpty && f.width > 1 {
                    findings.append("unlabelled \(el.elementType.rawValue) frame=\(f)")
                }
                if el.elementType == .button && f.width > 1 {
                    let minSide = min(f.width, f.height)
                    if minSide < 24 && minSide > 0 {
                        findings.append("tiny target button '\(label)' \(minSide)pt frame=\(f)")
                    }
                    let screenH = app.frame.height
                    if f.minY > screenH + 4 || f.maxY < -4 {
                        findings.append("off-screen button '\(label)' frame=\(f) screenH=\(screenH)")
                    }
                }
                if el.elementType == .scrollView && f.width > 1 {
                    findings.append("scrollView: frame=\(f)")
                }
            }
        }
        walk(app.buttons.allElementsBoundByIndex)
        walk(app.scrollViews.allElementsBoundByIndex)
        print("=== AUDIT \(screen): \(findings.isEmpty ? "clean" : "") ===")
        findings.forEach { print("   FLAG: \($0)") }
        print("=== END AUDIT \(screen) ===")
    }

    private func sidebarItems(_ app: XCUIApplication) -> [(id: String, name: String)] {
        [("career.nav.home", "home"),
         ("career.nav.squad", "squad"),
         ("career.nav.table", "table"),
         ("career.nav.fixtures", "fixtures"),
         ("career.nav.club", "club"),
         ("career.nav.manager", "manager"),
         ("career.nav.search", "search"),
         ("career.nav.transfers", "transfers"),
         ("career.nav.inbox", "inbox"),
         ("career.nav.settings", "settings")]
    }

    /// Focused audit of the three pinned/late destinations (the full tour
    /// spends minutes on the scout list's hundreds of rows).
    func testAuditQuickTourTransfersInboxSettings() throws {
        let app = launch()
        let squadTab = app.buttons["career.nav.squad"]
        XCTAssertTrue(squadTab.waitForExistence(timeout: 20), "Sidebar missing")
        for (id, name) in [("career.nav.transfers", "transfers"),
                           ("career.nav.inbox", "inbox"),
                           ("career.nav.settings", "settings")] {
            let tab = app.buttons[id]
            guard tab.waitForExistence(timeout: 6) else { continue }
            tab.tap()
            _ = anyElement(app, "career.\(name).screen").waitForExistence(timeout: 8)
            shot(app, "quick_\(name)")
            auditVisible(app, name)
        }
    }

    func testAuditTourAllSidebarScreensOnLandscape() throws {
        let app = launch()
        let squadTab = app.buttons["career.nav.squad"]
        XCTAssertTrue(squadTab.waitForExistence(timeout: 20), "Sidebar missing")

        for (id, name) in sidebarItems(app) {
            let tab = app.buttons[id]
            guard tab.waitForExistence(timeout: 6) else {
                print("=== AUDIT \(name): tab missing, skipping ===")
                continue
            }
            tab.tap()
            // Every screen marks its root with career.<screen>.screen;
            // wait for it, bounded, then audit whatever rendered.
            _ = anyElement(app, "career.\(name).screen").waitForExistence(timeout: 8)
            shot(app, name)
            auditVisible(app, name)
        }
    }
}
