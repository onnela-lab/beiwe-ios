import XCTest
@testable import SurveyQuestionDisplayLogic

// source: Beiwe/Util/MiscHelpers.swift (gpsFuzz), copied by run_tests.sh. BD2: offsets must exist whenever fuzzing is on.

/// Returns the queued values in order, then repeats the last; ranges are ignored.
private func seq(_ values: [Double]) -> GpsFuzzRandom {
    var i = 0
    return { _ in
        let v = values[min(i, values.count - 1)]
        i += 1
        return v
    }
}

class GpsFuzzTests: XCTestCase {
    // MARK: generators

    // a near-zero latitude offset barely moves the point, so -0.2...0.2 is redrawn
    func testLatitudeOffsetRedrawsNearZero() {
        AssertEqual(generateGpsLatitudeOffset(random: seq([0.0, 0.1, -0.2, 0.2, -0.15, 0.5])), 0.5)
    }

    // a near-zero longitude offset barely moves the point, so -10...10 is redrawn
    func testLongitudeOffsetRedrawsNearZero() {
        AssertEqual(generateGpsLongitudeOffset(random: seq([0, 5, -10, 10, -3, -45.5])), -45.5)
    }

    // the excluded band is closed at +-0.2 / +-10; values just past it must be kept, not redrawn forever
    func testOffsetsJustOutsideTheExcludedBandAreKept() {
        AssertEqual(generateGpsLatitudeOffset(random: seq([-0.2000001])), -0.2000001)
        AssertEqual(generateGpsLongitudeOffset(random: seq([10.0001])), 10.0001)
    }

    // the real random source, not a seeded one, must give offsets in the documented ranges
    func testSystemRandomOffsetsStayInRange() {
        for _ in 0..<2000 {
            let lat = generateGpsLatitudeOffset()
            let lng = generateGpsLongitudeOffset()
            AssertTrue(abs(lat) > 0.2 && abs(lat) <= 1, "\(lat)")
            AssertTrue(abs(lng) > 10 && abs(lng) <= 180, "\(lng)")
        }
    }

    // offset ranges match the code moved out of RegisterViewController (-1...1 and -180...180)
    func testOffsetsAreDrawnFromTheDocumentedRanges() {
        var latRange: ClosedRange<Double>?
        var lngRange: ClosedRange<Double>?
        _ = generateGpsLatitudeOffset(random: { latRange = $0; return 0.5 })
        _ = generateGpsLongitudeOffset(random: { lngRange = $0; return 50 })
        AssertEqual(latRange, -1 ... 1)
        AssertEqual(lngRange, -180 ... 180)
    }

    // MARK: ensureGpsFuzzOffsets

    // BD2: fuzzing turned on after registration found offsets of 0 and uploaded exact coordinates
    func testFuzzingOnFillsUnsetOffsets() {
        let r = ensureGpsFuzzOffsets(lat: 0, lng: 0, fuzzOn: true)
        AssertTrue(r.generated)
        AssertTrue(abs(r.lat) > 0.2 && abs(r.lat) <= 1)
        AssertTrue(abs(r.lng) > 10 && abs(r.lng) <= 180)
    }

    // the filled offsets are the ones StudyManager saves to the study and hands to GPSManager
    func testFilledOffsetsAreTheGeneratedValues() {
        let r = ensureGpsFuzzOffsets(lat: 0, lng: 0, fuzzOn: true, random: seq([0.7, -90]))
        AssertEqual(r.lat, 0.7)
        AssertEqual(r.lng, -90)
        AssertTrue(r.generated)
    }

    // offsets made at registration must survive every relaunch, or fuzzed tracks jump between sessions
    func testFuzzingOnKeepsSetOffsets() {
        let r = ensureGpsFuzzOffsets(lat: -0.4, lng: 33.3, fuzzOn: true, random: seq([0.9]))
        AssertEqual(r.lat, -0.4)
        AssertEqual(r.lng, 33.3)
        AssertFalse(r.generated)
    }

    // 0.0 means unset per offset; a set latitude is kept while a missing longitude is filled
    func testFuzzingOnFillsOnlyTheUnsetOffset() {
        let r = ensureGpsFuzzOffsets(lat: 0.6, lng: 0, fuzzOn: true, random: seq([-120]))
        AssertEqual(r.lat, 0.6)
        AssertEqual(r.lng, -120)
        AssertTrue(r.generated)
    }

    // with fuzzing off nothing is generated or saved, set or not
    func testFuzzingOffLeavesOffsetsAlone() {
        let unset = ensureGpsFuzzOffsets(lat: 0, lng: 0, fuzzOn: false, random: seq([0.9]))
        AssertEqual(unset.lat, 0)
        AssertEqual(unset.lng, 0)
        AssertFalse(unset.generated)
        let set = ensureGpsFuzzOffsets(lat: 0.5, lng: -50, fuzzOn: false)
        AssertEqual(set.lat, 0.5)
        AssertEqual(set.lng, -50)
        AssertFalse(set.generated)
    }

    // a study toggling fuzzing off and on again keeps one offset pair, so its fuzzed data stays consistent
    func testFuzzingOffThenOnKeepsStoredOffsets() {
        let first = ensureGpsFuzzOffsets(lat: 0, lng: 0, fuzzOn: true, random: seq([0.5, 50]))
        let off = ensureGpsFuzzOffsets(lat: first.lat, lng: first.lng, fuzzOn: false)
        let again = ensureGpsFuzzOffsets(lat: off.lat, lng: off.lng, fuzzOn: true, random: seq([-0.9, -90]))
        AssertEqual(again.lat, 0.5)
        AssertEqual(again.lng, 50)
        AssertFalse(again.generated)
    }

    // MARK: applyGpsFuzz

    // latitude fuzz is a plain shift by the offset, both signs
    func testLatitudeIsShiftedByTheOffset() {
        let r = applyGpsFuzz(lat: 42.0, lng: -71.0, latOffset: 0.5, lngOffset: 0)
        AssertEqual(r.lat, 42.5, accuracy: 1e-9)
        AssertEqual(applyGpsFuzz(lat: 42.0, lng: 0, latOffset: -0.75, lngOffset: 0).lat, 41.25, accuracy: 1e-9)
    }

    // the +1260 / remainder / -180 wrap formula must be a plain shift when no wrap is needed
    func testLongitudeIsShiftedWithoutWrap() {
        AssertEqual(applyGpsFuzz(lat: 0, lng: -71.0, latOffset: 0, lngOffset: 30).lng, -41.0, accuracy: 1e-9)
        AssertEqual(applyGpsFuzz(lat: 0, lng: 0, latOffset: 0, lngOffset: 0).lng, 0, accuracy: 1e-9)
    }

    // a shift past +180 must come back in at -180, not upload an impossible longitude
    func testLongitudeWrapsPastPositive180() {
        AssertEqual(applyGpsFuzz(lat: 0, lng: 179, latOffset: 0, lngOffset: 5).lng, -176, accuracy: 1e-9)
        AssertEqual(applyGpsFuzz(lat: 0, lng: 170, latOffset: 0, lngOffset: 180).lng, -10, accuracy: 1e-9)
    }

    // a shift past -180 must come back in at +180 (the case the +1260 term exists for)
    func testLongitudeWrapsPastNegative180() {
        AssertEqual(applyGpsFuzz(lat: 0, lng: -179, latOffset: 0, lngOffset: -5).lng, 176, accuracy: 1e-9)
        AssertEqual(applyGpsFuzz(lat: 0, lng: -170, latOffset: 0, lngOffset: -180).lng, 10, accuracy: 1e-9)
    }

    // every longitude plus every allowed offset stays in -180..<180
    func testLongitudeStaysInRangeForAllInputs() {
        for lng in stride(from: -180.0, through: 180.0, by: 7.5) {
            for off in stride(from: -180.0, through: 180.0, by: 11.0) {
                let out = applyGpsFuzz(lat: 0, lng: lng, latOffset: 0, lngOffset: off).lng
                AssertTrue(out >= -180 && out < 180, "\(lng) + \(off) -> \(out)")
            }
        }
    }

    // BD2: latitude past the north pole came out above 90; it is reflected over the pole (and lng turned 180), not clamped
    func testLatitudeReflectsOverNorthPole() {
        let r = applyGpsFuzz(lat: 89.9, lng: 10, latOffset: 0.9, lngOffset: 0)
        AssertEqual(r.lat, 89.2, accuracy: 1e-9)
        AssertEqual(r.lng, -170, accuracy: 1e-9)
    }

    // same for the south pole: below -90 is reflected, not clamped
    func testLatitudeReflectsOverSouthPole() {
        let r = applyGpsFuzz(lat: -89.9, lng: -10, latOffset: -0.9, lngOffset: 0)
        AssertEqual(r.lat, -89.2, accuracy: 1e-9)
        AssertEqual(r.lng, 170, accuracy: 1e-9)
    }

    // the user's guard: whatever the random offsets, the output must be a valid latitude and longitude
    func testFuzzedOutputIsAlwaysValidForGeneratedOffsets() {
        let lats = [-90.0, -89.95, -45, 0, 45, 89.95, 90]
        let lngs = [-180.0, -90, 0, 90, 179.99, 180]
        for _ in 0..<2000 {
            let latOff = generateGpsLatitudeOffset()
            let lngOff = generateGpsLongitudeOffset()
            for lat in lats {
                for lng in lngs {
                    let out = applyGpsFuzz(lat: lat, lng: lng, latOffset: latOff, lngOffset: lngOff)
                    AssertTrue(out.lat >= -90 && out.lat <= 90 && out.lng >= -180 && out.lng < 180,
                               "in (\(lat), \(lng)) off (\(latOff), \(lngOff)) -> out (\(out.lat), \(out.lng))")
                }
            }
        }
    }

    // the "over 360" class: longitude extremes with extreme offsets must stay in -180..<180
    func testLongitudeExtremesStayInRange() {
        for lng in [-180.0, 180.0] {
            for off in [-180.0, 180.0] {
                let out = applyGpsFuzz(lat: 0, lng: lng, latOffset: 0, lngOffset: off).lng
                AssertTrue(out >= -180 && out < 180, "\(lng) + \(off) -> \(out)")
            }
        }
    }
}
