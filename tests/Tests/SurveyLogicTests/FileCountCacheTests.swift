import XCTest
@testable import SurveyQuestionDisplayLogic

/// source: Beiwe/Common.swift, copied by run_tests.sh
class FileCountCacheTests: XCTestCase {
    func testFirstCallComputes() {
        XCTAssertFalse(fileCountCacheIsFresh(computedAt: nil, now: 100, interval: 60))
    }

    func testFreshWithinInterval() {
        XCTAssertTrue(fileCountCacheIsFresh(computedAt: 100, now: 100, interval: 60))
        XCTAssertTrue(fileCountCacheIsFresh(computedAt: 100, now: 159.9, interval: 60))
    }

    func testStaleAfterInterval() {
        XCTAssertFalse(fileCountCacheIsFresh(computedAt: 100, now: 160, interval: 60))
        XCTAssertFalse(fileCountCacheIsFresh(computedAt: 100, now: 1000, interval: 60))
    }

    func testClockGoingBackwardsRecomputes() {
        XCTAssertFalse(fileCountCacheIsFresh(computedAt: 100, now: 99, interval: 60))
    }
}
