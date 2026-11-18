import XCTest
import ObjectMapper
@testable import SurveyQuestionDisplayLogic

/// BS12: survey state on Study is touched from main, network callbacks and the heartbeat queue.
/// Run under Thread Sanitizer with `./run_tests.sh --tsan`.
class SurveyStateRaceTests: XCTestCase {
    private let n = 1000

    private func makeStudy() -> (Study, [Survey]) {
        let surveys = Mapper<Survey>().mapArray(JSONObject: loadFixture("survey_download_payload"))!
        return (Mapper<Study>().map(JSON: [:])!, surveys)
    }

    // the crash paths unlocked: checkForNewSurveys/activate_surveys mutating, Recline.save serializing,
    // setDefaultParameters iterating. Expected to race (and may crash), so opt-in.
    func testRaceDemo_unlocked() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BS12_RACE_DEMO"] == "1", "set BS12_RACE_DEMO=1 to run the unlocked race demo")
        let (study, base) = makeStudy()
        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) {
            for i in 0..<self.n {
                var s = base[i % base.count]
                s.surveyId = "s\(i)"
                study.surveys.append(s)
                study.activeSurveys[s.surveyId!] = ActiveSurvey(survey: s)
                study.surveyPushNotificationUUIDs = (study.surveyPushNotificationUUIDs ?? []) + ["u\(i)"]
            }
        }
        DispatchQueue.global().async(group: group) {
            for _ in 0..<30 { _ = Mapper<Study>().toJSON(study) }
        }
        DispatchQueue.global().async(group: group) {
            for _ in 0..<self.n {
                var ids: [String] = []
                for (id, active) in study.activeSurveys where !active.isComplete { ids.append(id) }
                _ = study.surveyPushNotificationUUIDs?.count
            }
        }
        group.wait()
    }

    // same pattern through SurveyLock, plus a presenter-style ActiveSurvey write and a nested save; no lost updates
    func testSurveyLockSerializesSurveyState() {
        let (study, base) = makeStudy()
        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) {
            for i in 0..<self.n {
                var s = base[i % base.count]
                s.surveyId = "s\(i)"
                SurveyLock.with {
                    study.surveys.append(s)
                    study.activeSurveys[s.surveyId!] = ActiveSurvey(survey: s)
                    study.surveyPushNotificationUUIDs = (study.surveyPushNotificationUUIDs ?? []) + ["u\(i)"]
                }
            }
        }
        DispatchQueue.global().async(group: group) {
            for _ in 0..<30 { _ = Mapper<Study>().toJSON(study) }
        }
        DispatchQueue.global().async(group: group) {
            for _ in 0..<self.n {
                _ = SurveyLock.with { () -> [String] in
                    var ids: [String] = []
                    for (id, active) in study.activeSurveys where !active.isComplete { ids.append(id) }
                    return ids
                }
                _ = SurveyLock.with { study.surveyPushNotificationUUIDs }?.count
                _ = study.surveyExists(surveyId: "s0")
            }
        }
        DispatchQueue.global().async(group: group) {
            for i in 0..<self.n {
                SurveyLock.with { study.activeSurveys["s\(i / 2)"]?.bwAnswers["q"] = "\(i)" }
                // recursive: a save while already holding the lock must not deadlock
                if i % 100 == 0 { SurveyLock.with { _ = Mapper<Study>().toJSON(study) } }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 120), .success, "deadlocked")

        XCTAssertEqual(study.surveys.count, n)
        XCTAssertEqual(study.activeSurveys.count, n)
        XCTAssertEqual(study.surveyPushNotificationUUIDs?.count, n)
        XCTAssertEqual(Set(study.activeSurveys.keys).count, n)
        let back = Mapper<Study>().map(JSON: Mapper<Study>().toJSON(study))!
        XCTAssertEqual(back.surveys.count, n)
        XCTAssertEqual(back.activeSurveys.count, n)
    }
}
