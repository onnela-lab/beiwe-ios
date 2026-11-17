import XCTest
@testable import SurveyQuestionDisplayLogic

/// source: Beiwe/Common.swift, copied by run_tests.sh
class LeftBehindFilesTests: XCTestCase {
    let abs = "/var/mobile/App/Library/Application Support/currentdata/pid_accel_1.csv"

    func testAbsoluteEntryMatchesItsFile() {
        XCTAssertEqual(leftBehindFilesToMove(entries: [abs], directoryListing: ["pid_accel_1.csv"]), ["pid_accel_1.csv"])
    }

    func testRelativeNameMatches() {
        XCTAssertEqual(leftBehindFilesToMove(entries: ["pid_accel_1.csv"], directoryListing: ["pid_accel_1.csv"]), ["pid_accel_1.csv"])
    }

    func testEntryForMissingFileIsDropped() {
        XCTAssertEqual(leftBehindEntriesToKeep(entries: [abs], directoryListing: ["other.csv"]), [])
        XCTAssertEqual(leftBehindFilesToMove(entries: [abs], directoryListing: ["other.csv"]), [])
    }

    func testEntryWhoseFileIsStillPresentIsKept() {
        XCTAssertEqual(leftBehindEntriesToKeep(entries: [abs], directoryListing: ["pid_accel_1.csv"]), [abs])
    }

    func testUnrelatedFilesAreNotTouched() {
        let listing = ["pid_accel_1.csv", "pid_gps_2.csv", "notes.txt"]
        XCTAssertEqual(leftBehindFilesToMove(entries: [abs], directoryListing: listing), ["pid_accel_1.csv"])
        XCTAssertEqual(leftBehindEntriesToKeep(entries: [abs], directoryListing: listing), [abs])
    }

    func testOldComparisonNeverMatched_oldBehavior_BD5() {
        // old code compared absolute entry vs relative name, never matched
        let listing = ["pid_accel_1.csv"]
        XCTAssertFalse([abs].contains(listing[0]))
        XCTAssertFalse(listing.contains(abs))
    }
}
