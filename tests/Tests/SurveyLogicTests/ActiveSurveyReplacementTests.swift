import XCTest
import ObjectMapper
@testable import SurveyQuestionDisplayLogic

/// BS4: a completed trigger-on-first-download survey must stay hidden when the downloaded definition changes.
class ActiveSurveyReplacementTests: XCTestCase {
    private func makeSurvey(trigger: Bool, always: Bool, timings: [[Int]] = []) -> Survey {
        var s = Mapper<Survey>().mapArray(JSONObject: loadFixture("survey_download_payload"))![0]
        s.triggerOnFirstDownload = trigger
        s.alwaysAvailable = always
        s.timings = timings
        return s
    }

    // the backend's 7-day window shifts timings daily, which is enough for Survey.== to differ
    private func shifted(_ s: Survey) -> Survey {
        var t = s
        t.timings = [[0, 3600], [], [], [], [], [], []]
        XCTAssertNotEqual(s, t)
        return t
    }

    func testNewSurveyIsInserted() {
        let s = makeSurvey(trigger: true, always: false)
        let r = activeSurveyReplacement(existing: nil, downloaded: s)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.survey, s)
        XCTAssertFalse(r!.isComplete)
    }

    func testUnchangedIsLeftAlone() {
        for complete in [true, false] {
            let s = makeSurvey(trigger: true, always: false)
            let existing = ActiveSurvey(survey: s)
            existing.isComplete = complete
            XCTAssertNil(activeSurveyReplacement(existing: existing, downloaded: s))
        }
    }

    func testCompletedTriggerSurveyStaysCompleteWhenDefinitionChanges() {
        let old = makeSurvey(trigger: true, always: false)
        let existing = ActiveSurvey(survey: old)
        existing.isComplete = true
        let new = shifted(old)
        let r = activeSurveyReplacement(existing: existing, downloaded: new)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.survey, new)  // new content stored for the next push
        XCTAssertTrue(r!.isComplete)    // and still hidden
    }

    func testIncompleteTriggerSurveyIsReplaced() {
        let old = makeSurvey(trigger: true, always: false)
        let existing = ActiveSurvey(survey: old)
        existing.bwAnswers = ["q": "a"]
        let new = shifted(old)
        let r = activeSurveyReplacement(existing: existing, downloaded: new)
        XCTAssertEqual(r?.survey, new)
        XCTAssertFalse(r!.isComplete)
        XCTAssertTrue(r!.bwAnswers.isEmpty)  // BS5: partial progress is lost, locked in as current behavior
    }

    func testAlwaysAvailableChangedIsReset() {
        let old = makeSurvey(trigger: false, always: true)
        let existing = ActiveSurvey(survey: old)
        existing.isComplete = true
        let new = shifted(old)
        let r = activeSurveyReplacement(existing: existing, downloaded: new)
        XCTAssertEqual(r?.survey, new)
        XCTAssertFalse(r!.isComplete)
    }

    func testTriggerAndAlwaysAvailableIsResetLikeAlwaysAvailable() {
        let old = makeSurvey(trigger: true, always: true)
        let existing = ActiveSurvey(survey: old)
        existing.isComplete = true
        let r = activeSurveyReplacement(existing: existing, downloaded: shifted(old))
        XCTAssertNotNil(r)
        XCTAssertFalse(r!.isComplete)
    }
}
