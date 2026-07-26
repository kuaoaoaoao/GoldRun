import XCTest
import SwiftUI
import AppKit
@testable import coolRun

@MainActor
final class InterfaceRenderTests: XCTestCase {
    func testGoldDecisionCardRendersAtMenuBarWidth() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let records = (0..<96).map { index in
            let trend = Double(index) * 0.16
            let rhythm = sin(Double(index) / 5) * 2.4
            return GoldPriceRecord(
                price: 682 + trend + rhythm,
                timestamp: start.addingTimeInterval(Double(index) * 300),
                source: "Preview"
            )
        }
        let snapshot = try XCTUnwrap(GoldAnalysisEngine.makeSnapshot(records: records))
        let report = try XCTUnwrap(
            GoldAdvancedStrategy.analyze(
                records: records,
                snapshot: snapshot,
                signal: nil
            )
        )

        try render(
            GoldDecisionSummaryCard(report: report)
                .padding(10)
                .frame(width: 304),
            size: NSSize(width: 304, height: 180),
            filename: "coolrun-gold-decision-preview.png"
        )
    }

    func testEnglishLearningRendersAtMenuBarSize() throws {
        try render(
            EnglishLearningView()
                .frame(width: 304, height: 464)
                .environment(\.colorScheme, .light),
            size: NSSize(width: 304, height: 464),
            filename: "coolrun-english-preview.png"
        )
    }

    private func render<Content: View>(
        _ content: Content,
        size: NSSize,
        filename: String
    ) throws {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        let representation = try XCTUnwrap(
            hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        let pngData = try XCTUnwrap(
            representation.representation(using: .png, properties: [:])
        )
        let output = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(filename)
        try pngData.write(to: output)

        XCTAssertEqual(representation.size.width, size.width)
        XCTAssertEqual(representation.size.height, size.height)
    }
}
