//
//  LegendsPitchCoordinateSystemTests.swift
//  Retro Season ManagerTests
//
//  Phase 0 of the Legends 2D match simulator — guards the numeric pitch
//  geometry (LegendsPitchCoordinateSystem.swift) that replaces
//  DetailedPosition.expected(...)'s label-only row/index geometry.
//

import SwiftUI
import UIKit
import XCTest
@testable import Retro_Season_Manager

final class LegendsPitchCoordinateSystemTests: XCTestCase {

    func testGoalkeeperSitsDeepestForHomeTeam() {
        let gk = PitchCoordinateSystem.baseAnchor(role: .goalkeeper, indexInRow: 0, rowCount: 1, team: .home)
        let striker = PitchCoordinateSystem.baseAnchor(role: .striker, indexInRow: 0, rowCount: 1, team: .home)
        XCTAssertGreaterThan(gk.y, striker.y, "The home goalkeeper should sit deeper (larger y) than a home striker.")
    }

    func testRowDepthOrderingForHomeTeam() {
        let gk = PitchCoordinateSystem.baseAnchor(role: .goalkeeper, indexInRow: 0, rowCount: 1, team: .home)
        let cb = PitchCoordinateSystem.baseAnchor(role: .centreBack, indexInRow: 0, rowCount: 1, team: .home)
        let cm = PitchCoordinateSystem.baseAnchor(role: .centralMid, indexInRow: 0, rowCount: 1, team: .home)
        let st = PitchCoordinateSystem.baseAnchor(role: .striker, indexInRow: 0, rowCount: 1, team: .home)
        // Attacking toward y=0, so depth (y) should strictly decrease from
        // GK through defence, midfield, to attack.
        XCTAssertGreaterThan(gk.y, cb.y)
        XCTAssertGreaterThan(cb.y, cm.y)
        XCTAssertGreaterThan(cm.y, st.y)
    }

    func testXSpreadOrderingAcrossARow() {
        let rowCount = 4
        let points = (0..<rowCount).map {
            PitchCoordinateSystem.baseAnchor(role: .centreBack, indexInRow: $0, rowCount: rowCount, team: .home)
        }
        for i in 1..<points.count {
            XCTAssertGreaterThan(points[i].x, points[i - 1].x, "x should increase left-to-right with index.")
        }
        XCTAssertEqual(points.first!.x, 0.12, accuracy: 0.001)
        XCTAssertEqual(points.last!.x, 0.88, accuracy: 0.001)
    }

    func testSingleSlotRowIsHorizontallyCentered() {
        let point = PitchCoordinateSystem.baseAnchor(role: .holding, indexInRow: 0, rowCount: 1, team: .home)
        XCTAssertEqual(point.x, 0.5, accuracy: 0.0001)
    }

    func testAwayTeamMirrorsHomeTeamDepthNotSpread() {
        for role in DetailedPosition.allCases {
            let home = PitchCoordinateSystem.baseAnchor(role: role, indexInRow: 1, rowCount: 4, team: .home)
            let away = PitchCoordinateSystem.baseAnchor(role: role, indexInRow: 1, rowCount: 4, team: .away)
            XCTAssertEqual(away.y, 1 - home.y, accuracy: 0.0001, "Away should mirror home's depth around y=0.5.")
            XCTAssertEqual(away.x, home.x, accuracy: 0.0001, "Mirroring should only flip depth (y), not the x spread.")
        }
    }

    func testAnchorsCountMatchesSlotRolesForEveryFormation() {
        for formation in Formation.all {
            let roles = formation.slotRoles()
            let homeAnchors = PitchCoordinateSystem.anchors(for: formation, team: .home)
            let awayAnchors = PitchCoordinateSystem.anchors(for: formation, team: .away)
            XCTAssertEqual(homeAnchors.count, roles.count, "\(formation.name) home anchor count mismatch.")
            XCTAssertEqual(awayAnchors.count, roles.count, "\(formation.name) away anchor count mismatch.")
        }
    }

    func testAllAnchorsStayWithinTheUnitSquare() {
        for formation in Formation.all {
            for team: Side in [.home, .away] {
                for point in PitchCoordinateSystem.anchors(for: formation, team: team) {
                    XCTAssertGreaterThanOrEqual(point.x, 0, "\(formation.name)/\(team) x out of bounds")
                    XCTAssertLessThanOrEqual(point.x, 1, "\(formation.name)/\(team) x out of bounds")
                    XCTAssertGreaterThanOrEqual(point.y, 0, "\(formation.name)/\(team) y out of bounds")
                    XCTAssertLessThanOrEqual(point.y, 1, "\(formation.name)/\(team) y out of bounds")
                }
            }
        }
    }

    func testAnchorsOrderMatchesGoalkeeperFirstConvention() {
        // slotRoles()'s first entry is always the goalkeeper, so anchors's
        // first point should always be the goalkeeper's deep, centered spot.
        for formation in Formation.all {
            let anchors = PitchCoordinateSystem.anchors(for: formation, team: .home)
            XCTAssertEqual(anchors.first!.y, 0.94, accuracy: 0.0001, "\(formation.name) first anchor should be the GK's depth.")
            XCTAssertEqual(anchors.first!.x, 0.5, accuracy: 0.0001, "\(formation.name) first anchor should be centered.")
        }
    }
}

@MainActor
final class ExperienceSelectorLayoutTests: XCTestCase {
    private let deviceSizes: [CGSize] = [
        CGSize(width: 568, height: 320),   // iPhone SE landscape
        CGSize(width: 852, height: 393),   // Dynamic Island iPhone landscape
        CGSize(width: 932, height: 430),   // Pro Max-style landscape
        CGSize(width: 1180, height: 820),  // iPad landscape
        CGSize(width: 1366, height: 1024)  // iPad Pro landscape
    ]

    func testAspectFitPreservesArtworkRatioAtSupportedLandscapeSizes() {
        let expectedRatio = ExperienceSelectorLayout.referenceSize.width / ExperienceSelectorLayout.referenceSize.height

        for size in deviceSizes {
            let frame = ExperienceSelectorLayout.fittedArtworkFrame(in: size)
            XCTAssertEqual(frame.width / frame.height, expectedRatio, accuracy: 0.0001,
                           "Artwork must stay proportional at \(size)")
            XCTAssertGreaterThanOrEqual(frame.minX, -0.001)
            XCTAssertGreaterThanOrEqual(frame.minY, -0.001)
            XCTAssertLessThanOrEqual(frame.maxX, size.width + 0.001)
            XCTAssertLessThanOrEqual(frame.maxY, size.height + 0.001)
        }
    }

    func testBothEntryButtonsStayInsideTheirPanelsAndRemainSymmetric() {
        for size in deviceSizes {
            let artwork = ExperienceSelectorLayout.fittedArtworkFrame(in: size)
            let career = ExperienceSelectorLayout.frame(ExperienceSelectorLayout.careerButton, in: artwork)
            let legends = ExperienceSelectorLayout.frame(ExperienceSelectorLayout.legendsButton, in: artwork)
            let careerPanel = ExperienceSelectorLayout.frame(ExperienceSelectorLayout.careerPanel, in: artwork)
            let legendsPanel = ExperienceSelectorLayout.frame(ExperienceSelectorLayout.legendsPanel, in: artwork)

            XCTAssertTrue(careerPanel.intersects(career), "Career CTA must remain aligned with its artwork panel at \(size)")
            XCTAssertTrue(legendsPanel.intersects(legends), "Legends CTA must remain aligned with its artwork panel at \(size)")
            XCTAssertTrue(artwork.contains(career), "Career CTA must remain inside the fitted artwork at \(size)")
            XCTAssertTrue(artwork.contains(legends), "Legends CTA must remain inside the fitted artwork at \(size)")
            XCTAssertEqual(career.size.width, legends.size.width, accuracy: 0.001)
            XCTAssertEqual(career.size.height, legends.size.height, accuracy: 0.001)
        }
    }

    func testZeroGeometryDoesNotProduceInvalidFrames() {
        XCTAssertEqual(ExperienceSelectorLayout.fittedArtworkFrame(in: .zero), .zero)
        XCTAssertEqual(ExperienceSelectorLayout.fittedArtworkFrame(in: CGSize(width: -1, height: 300)), .zero)
    }

    /// Renderer smoke snapshots provide a visual regression artifact while
    /// the layout assertions above keep CI deterministic across devices.
    func testSelectorRendersNonTransparentSnapshotsAtDeviceSizes() async {
        for (index, size) in deviceSizes.enumerated() {
            let content = ExperienceSelectView(experience: .constant(nil))
                .frame(width: size.width, height: size.height)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 1
            renderer.proposedSize = ProposedViewSize(size)

            guard let image = renderer.cgImage else {
                return XCTFail("ImageRenderer produced no selector image at \(size)")
            }
            XCTAssertEqual(image.width, Int(size.width), "Snapshot width changed at \(size)")
            XCTAssertEqual(image.height, Int(size.height), "Snapshot height changed at \(size)")
            guard let pixelData = image.dataProvider?.data else {
                return XCTFail("Snapshot has no pixel buffer at \(size)")
            }
            let bytes = CFDataGetBytePtr(pixelData)
            let bytesPerPixel = max(1, image.bitsPerPixel / 8)
            let sampleRows = stride(from: 0, to: image.height, by: max(1, image.height / 16))
            let sampleColumns = stride(from: 0, to: image.width, by: max(1, image.width / 16))
            var sampledColours = Set<Int>()
            for row in sampleRows {
                for column in sampleColumns {
                    let offset = row * image.bytesPerRow + column * bytesPerPixel
                    guard let bytes, offset + 2 < image.bytesPerRow * image.height else { continue }
                    sampledColours.insert((Int(bytes[offset]) << 16) | (Int(bytes[offset + 1]) << 8) | Int(bytes[offset + 2]))
                }
            }
            XCTAssertGreaterThan(sampledColours.count, 8,
                                 "Selector snapshot should contain varied artwork pixels at \(size)")

            let attachment = XCTAttachment(image: UIImage(cgImage: image))
            attachment.name = "experience-selector-\(index)-\(Int(size.width))x\(Int(size.height))"
            attachment.lifetime = .deleteOnSuccess
            add(attachment)
        }
    }
}
