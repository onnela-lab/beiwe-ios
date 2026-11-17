import XCTest
@testable import SurveyQuestionDisplayLogic

/// source: Beiwe/Common.swift, copied by run_tests.sh
/// The default time zone is set to New York to mimic a New York phone.
class IsoTimeTests: XCTestCase {
    var savedZone: TimeZone!

    override func setUp() {
        savedZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/New_York")!
    }

    override func tearDown() {
        NSTimeZone.default = savedZone
    }

    func testDstGapIsReadAsUTC() {
        XCTAssertEqual(isoStringToTimeInterval(timeString: "2026-03-08T02:30:00"), 1772937000)
    }

    func testZonelessIsUTC() {
        XCTAssertEqual(isoStringToTimeInterval(timeString: "2026-01-15T14:00:00"), 1768485600)
    }

    func testOffsetIsHonored() {
        XCTAssertEqual(isoStringToTimeInterval(timeString: "2026-01-15T09:00:00-05:00"), 1768485600)
        XCTAssertEqual(isoStringToTimeInterval(timeString: "2026-01-15T09:00:00-0500"), 1768485600)
    }

    func testZuluIsHonored() {
        XCTAssertEqual(isoStringToTimeInterval(timeString: "2026-01-15T14:00:00Z"), 1768485600)
    }

    func testZuluWithFractionalSecondsIsHonored() {
        XCTAssertEqual(
            isoStringToTimeInterval(timeString: "2026-01-15T14:00:00.123Z"), 1768485600.123, accuracy: 0.0005
        )
    }

    func testFallBackHour() {
        XCTAssertEqual(isoStringToTimeInterval(timeString: "2026-11-01T06:30:00"), 1793514600)
    }

    func testNilIsZero() {
        XCTAssertEqual(isoStringToTimeInterval(timeString: nil), 0)
    }

    func testGarbageIsZero() {
        XCTAssertEqual(isoStringToTimeInterval(timeString: "garbage"), 0)
    }
}
