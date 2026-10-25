import Darwin
import SwiftUI
import UIKit
import XCTest
@testable import Retro_Season_Manager

/// Activates a Calendar schedule row through UIKit's accessibility API —
/// `accessibilityActivate()`, the call assistive technologies make for a
/// double-tap — and checks it opens the opponent's squad sheet, as a
/// touch on the row does.
///
/// This exercises the element SwiftUI publishes and its default action.
/// It is not VoiceOver: no speech, focus order or gesture handling is
/// involved, so it does not stand in for a VoiceOver pass on a device.
///
/// SwiftUI only publishes its UIKit accessibility tree while an
/// accessibility client is active, so the test switches on the system's
/// accessibility automation mode first (test process only, simulator).
@MainActor
final class CalendarRowAccessibilityActivationTests: XCTestCase {

    func testScheduleRowAccessibilityActivationOpensOpponentSquadSheet() async throws {
        try enableAccessibilityAutomation()
        let store = await makeTestStore()
        store.prepareCareerNavigationFixtureForDebug()

        // A tall landscape-width window so the whole schedule is laid out.
        let host = UIHostingController(rootView: CalendarView(store: store))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 874, height: 2400))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        await settle()

        var seen: [String] = []
        let found = firstElement(in: host.view) {
            let identifier = accessibilityIdentifier(of: $0)
            if seen.count < 400 { seen.append("\(type(of: $0)) id='\(identifier)' label='\($0.accessibilityLabel ?? "")'") }
            // The user's own upcoming fixture ("…, home against X, upcoming").
            return identifier.hasPrefix("career.calendar.row.upcoming.")
                && ($0.accessibilityLabel ?? "").contains(" against ")
        }
        if found == nil {
            let dump = XCTAttachment(string: seen.joined(separator: "\n"))
            dump.name = "calendar_accessibility_walk"
            dump.lifetime = .keepAlways
            add(dump)
        }
        let row = try XCTUnwrap(found, "The user's upcoming schedule row should be published as an accessibility "
            + "element (walked \(seen.count) nodes; see the calendar_accessibility_walk attachment)")
        XCTAssertTrue(row.accessibilityTraits.contains(.button), "The row should carry the button trait")

        let label = try XCTUnwrap(row.accessibilityLabel)
        let opponent = try XCTUnwrap(opponentName(fromRowLabel: label),
                                     "The user's row label should name the opponent: '\(label)'")
        XCTAssertNil(host.presentedViewController, "No sheet should be open before activation")

        XCTAssertTrue(row.accessibilityActivate(), "The row should handle accessibility activation")

        let deadline = Date().addingTimeInterval(5)
        while host.presentedViewController == nil, Date() < deadline {
            await settle(0.1)
        }
        let sheet = try XCTUnwrap(host.presentedViewController,
                                  "Activation should present the club squad sheet")
        await settle()
        let title = firstElement(in: sheet.view) { $0.accessibilityLabel == opponent }
        XCTAssertNotNil(title, "The presented sheet should be \(opponent)'s squad")

        // Tear the sheet and window down and let UIKit release them while
        // this test still holds `store`. Left to UIKit, the sheet's hosting
        // view drops the last store reference from a run-loop autorelease
        // pool during the *next* test, outside any task, and GameStore's
        // main-actor deinit then hits the Concurrency runtime's TaskLocal
        // double-free (see makeTestStore()).
        sheet.dismiss(animated: false)
        window.rootViewController = nil
        window.isHidden = true
        await settle()
        withExtendedLifetime(store) {}
    }

    // MARK: - Helpers

    /// `_AXSSetAutomationEnabled` is the switch UI-testing and inspection
    /// tools flip; without an active client SwiftUI publishes no elements.
    private func enableAccessibilityAutomation() throws {
        guard let handle = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let symbol = dlsym(handle, "_AXSSetAutomationEnabled") else {
            throw XCTSkip("Accessibility automation switch unavailable on this runtime")
        }
        typealias SetEnabled = @convention(c) (Int32) -> Void
        unsafeBitCast(symbol, to: SetEnabled.self)(1)
    }

    private func settle(_ seconds: TimeInterval = 0.5) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }

    /// SwiftUI's accessibility nodes answer `accessibilityIdentifier`
    /// without adopting `UIAccessibilityIdentification`, so ask by selector.
    private func accessibilityIdentifier(of node: NSObject) -> String {
        if let identified = node as? UIAccessibilityIdentification, let id = identified.accessibilityIdentifier {
            return id
        }
        let selector = NSSelectorFromString("accessibilityIdentifier")
        guard node.responds(to: selector) else { return "" }
        return node.perform(selector)?.takeUnretainedValue() as? String ?? ""
    }

    /// "<context>, home against <Opponent>, upcoming" → "<Opponent>".
    private func opponentName(fromRowLabel label: String) -> String? {
        guard let start = label.range(of: " against "),
              let end = label.range(of: ", ", options: .backwards),
              start.upperBound < end.lowerBound else { return nil }
        return String(label[start.upperBound..<end.lowerBound])
    }

    /// Depth-first walk of the UIKit accessibility tree SwiftUI publishes.
    private func firstElement(in root: NSObject, where match: (NSObject) -> Bool) -> NSObject? {
        var stack: [NSObject] = [root]
        var visited = 0
        while let node = stack.popLast(), visited < 20_000 {
            visited += 1
            if node !== root, match(node) { return node }
            // Lazy containers (SwiftUI's lazy stacks) can report an empty
            // `accessibilityElements` but still vend children by index.
            var children = (node.accessibilityElements as? [NSObject]) ?? []
            if children.isEmpty {
                let count = node.accessibilityElementCount()
                if count != NSNotFound, count > 0 {
                    children = (0..<count).compactMap { node.accessibilityElement(at: $0) as? NSObject }
                }
            }
            if children.isEmpty, let view = node as? UIView {
                children = view.subviews
            }
            stack.append(contentsOf: children.reversed())
        }
        return nil
    }
}
