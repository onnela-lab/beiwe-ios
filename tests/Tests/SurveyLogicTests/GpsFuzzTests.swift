import XCTest
@testable import SurveyQuestionDisplayLogic

/// source: Beiwe/Common.swift (gpsFuzz), copied by run_tests.sh. BD2: offsets must exist whenever fuzzing is on.
class GpsFuzzTests: XCTestCase {
    /// Returns the queued values in order, then repeats the last; ranges are ignored.
    private func seq(_ values: [Double]) -> GpsFuzzRandom {
        var i = 0
        return { _ in
            let v = values[min(i, values.count - 1)]
            i += 1
            return v
        }
    }

    // MARK: generators

    func testLatitudeGeneratorSkipsNearZero() {
        XCTAssertEqual(generateGpsLatitudeOffset(random: seq([0.0, 0.1, -0.2, 0.2, -0.15, 0.5])), 0.5)
    }

    func testLongitudeGeneratorSkipsNearZero() {
        XCTAssertEqual(generateGpsLongitudeOffset(random: seq([0, 5, -10, 10, -3, -45.5])), -45.5)
    }

    func testGeneratorsKeepValuesOutsideTheExcludedBand() {
        XCTAssertEqual(generateGpsLatitudeOffset(random: seq([-0.2000001])), -0.2000001)
        XCTAssertEqual(generateGpsLongitudeOffset(random: seq([10.0001])), 10.0001)
    }

    func testRealGeneratorsStayInRange() {
        for _ in 0..<2000 {
            let lat = generateGpsLatitudeOffset()
            let lng = generateGpsLongitudeOffset()
            XCTAssertTrue(abs(lat) > 0.2 && abs(lat) <= 1, "\(lat)")
            XCTAssertTrue(abs(lng) > 10 && abs(lng) <= 180, "\(lng)")
        }
    }

    func testGeneratorsRequestTheDocumentedRanges() {
        var latRange: ClosedRange<Double>?
        var lngRange: ClosedRange<Double>?
        _ = generateGpsLatitudeOffset(random: { latRange = $0; return 0.5 })
        _ = generateGpsLongitudeOffset(random: { lngRange = $0; return 50 })
        XCTAssertEqual(latRange, -1 ... 1)
        XCTAssertEqual(lngRange, -180 ... 180)
    }

    // MARK: ensureGpsFuzzOffsets

    func testFuzzOnWithUnsetOffsetsGenerates() {
        let r = ensureGpsFuzzOffsets(lat: 0, lng: 0, fuzzOn: true)
        XCTAssertTrue(r.generated)
        XCTAssertTrue(abs(r.lat) > 0.2 && abs(r.lat) <= 1)
        XCTAssertTrue(abs(r.lng) > 10 && abs(r.lng) <= 180)
    }

    func testFuzzOnWithUnsetOffsetsUsesInjectedSource() {
        let r = ensureGpsFuzzOffsets(lat: 0, lng: 0, fuzzOn: true, random: seq([0.7, -90]))
        XCTAssertEqual(r.lat, 0.7)
        XCTAssertEqual(r.lng, -90)
        XCTAssertTrue(r.generated)
    }

    func testFuzzOnWithSetOffsetsUnchanged() {
        let r = ensureGpsFuzzOffsets(lat: -0.4, lng: 33.3, fuzzOn: true, random: seq([0.9]))
        XCTAssertEqual(r.lat, -0.4)
        XCTAssertEqual(r.lng, 33.3)
        XCTAssertFalse(r.generated)
    }

    func testFuzzOnWithOneOffsetUnsetFillsOnlyThatOne() {
        let r = ensureGpsFuzzOffsets(lat: 0.6, lng: 0, fuzzOn: true, random: seq([-120]))
        XCTAssertEqual(r.lat, 0.6)
        XCTAssertEqual(r.lng, -120)
        XCTAssertTrue(r.generated)
    }

    func testFuzzOffLeavesOffsetsAlone() {
        let unset = ensureGpsFuzzOffsets(lat: 0, lng: 0, fuzzOn: false, random: seq([0.9]))
        XCTAssertEqual(unset.lat, 0)
        XCTAssertEqual(unset.lng, 0)
        XCTAssertFalse(unset.generated)
        let set = ensureGpsFuzzOffsets(lat: 0.5, lng: -50, fuzzOn: false)
        XCTAssertEqual(set.lat, 0.5)
        XCTAssertEqual(set.lng, -50)
        XCTAssertFalse(set.generated)
    }

    func testOffThenOnKeepsStoredOffsets() {
        let first = ensureGpsFuzzOffsets(lat: 0, lng: 0, fuzzOn: true, random: seq([0.5, 50]))
        let off = ensureGpsFuzzOffsets(lat: first.lat, lng: first.lng, fuzzOn: false)
        let again = ensureGpsFuzzOffsets(lat: off.lat, lng: off.lng, fuzzOn: true, random: seq([-0.9, -90]))
        XCTAssertEqual(again.lat, 0.5)
        XCTAssertEqual(again.lng, 50)
        XCTAssertFalse(again.generated)
    }

    // MARK: applyGpsFuzz

    func testLatitudeIsShifted() {
        let r = applyGpsFuzz(lat: 42.0, lng: -71.0, latOffset: 0.5, lngOffset: 0)
        XCTAssertEqual(r.lat, 42.5, accuracy: 1e-9)
        XCTAssertEqual(applyGpsFuzz(lat: 42.0, lng: 0, latOffset: -0.75, lngOffset: 0).lat, 41.25, accuracy: 1e-9)
    }

    func testLongitudeShiftWithoutWrap() {
        XCTAssertEqual(applyGpsFuzz(lat: 0, lng: -71.0, latOffset: 0, lngOffset: 30).lng, -41.0, accuracy: 1e-9)
        XCTAssertEqual(applyGpsFuzz(lat: 0, lng: 0, latOffset: 0, lngOffset: 0).lng, 0, accuracy: 1e-9)
    }

    func testLongitudeWrapsPastPositive180() {
        XCTAssertEqual(applyGpsFuzz(lat: 0, lng: 179, latOffset: 0, lngOffset: 5).lng, -176, accuracy: 1e-9)
        XCTAssertEqual(applyGpsFuzz(lat: 0, lng: 170, latOffset: 0, lngOffset: 180).lng, -10, accuracy: 1e-9)
    }

    func testLongitudeWrapsPastNegative180() {
        XCTAssertEqual(applyGpsFuzz(lat: 0, lng: -179, latOffset: 0, lngOffset: -5).lng, 176, accuracy: 1e-9)
        XCTAssertEqual(applyGpsFuzz(lat: 0, lng: -170, latOffset: 0, lngOffset: -180).lng, 10, accuracy: 1e-9)
    }

    func testLongitudeStaysInRangeForAllInputs() {
        for lng in stride(from: -180.0, through: 180.0, by: 7.5) {
            for off in stride(from: -180.0, through: 180.0, by: 11.0) {
                let out = applyGpsFuzz(lat: 0, lng: lng, latOffset: 0, lngOffset: off).lng
                XCTAssertTrue(out >= -180 && out < 180, "\(lng) + \(off) -> \(out)")
            }
        }
    }

    /// current behavior: latitude is not clamped, so it can leave +-90 near the poles
    func testLatitudeNotClampedNearPole() {
        XCTAssertEqual(applyGpsFuzz(lat: 89.9, lng: 0, latOffset: 0.9, lngOffset: 0).lat, 90.8, accuracy: 1e-9)
    }
}
