import XCTest
import ObjectMapper
@testable import SurveyQuestionDisplayLogic

/// BS7: "randomize without replacement" must match Android: memory is question ids per survey id on the study,
/// drawn when the survey is opened, so it survives pushes (new ActiveSurvey each), restarts and survey edits.
class RandomizeWithMemoryTests: XCTestCase {

    // MARK: pure selection, shared fixture

    private struct Case: Decodable {
        let name: String
        let question_ids: [String]
        let memory: [String]
        let count: Int?
        let shuffles: [[Int]]
        let selected_indices: [Int]
        let selected_ids: [String]
        let memory_after: [String]
    }

    private struct Cases: Decodable {
        let cases: [Case]
    }

    func testFixtureCases() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "randomize_with_memory", withExtension: "json", subdirectory: "Fixtures"))
        let cases = try JSONDecoder().decode(Cases.self, from: Data(contentsOf: url)).cases
        XCTAssertFalse(cases.isEmpty)
        for c in cases {
            var shuffles = c.shuffles
            let r = randomQuestionSelection(
                questionIds: c.question_ids, memory: c.memory, count: c.count,
                shuffle: { n in
                    let p = shuffles.removeFirst()
                    XCTAssertEqual(p.count, n, c.name)
                    return p
                }
            )
            XCTAssertEqual(r.indices, c.selected_indices, c.name)
            XCTAssertEqual(r.indices.map { c.question_ids[$0] }, c.selected_ids, c.name)
            XCTAssertEqual(r.memory, c.memory_after, c.name)
            XCTAssertTrue(shuffles.isEmpty, "\(c.name): unused shuffles")
        }
    }

    // 10 questions, 3 per survey -> 3,3,3,1, every question once per round, then a fresh round
    func testFullRoundsWithRealShuffle() {
        let ids = (1 ... 10).map { "q\($0)" }
        for _ in 0 ..< 50 {
            var memory: [String] = []
            var round: [String] = []
            for expected in [3, 3, 3, 1] {
                let r = randomQuestionSelection(questionIds: ids, memory: memory, count: 3, shuffle: { Array(0 ..< $0).shuffled() })
                XCTAssertEqual(r.indices.count, expected)
                round += r.indices.map { ids[$0] }
                memory = r.memory
            }
            XCTAssertEqual(round.sorted(), ids.sorted())
            let next = randomQuestionSelection(questionIds: ids, memory: memory, count: 3, shuffle: { Array(0 ..< $0).shuffled() })
            XCTAssertEqual(next.indices.count, 3)
            XCTAssertEqual(next.memory, next.indices.map { ids[$0] })
        }
    }

    // MARK: models: open, push, reset

    private func question(_ id: String) -> GenericSurveyQuestion {
        return Mapper<GenericSurveyQuestion>().map(JSON: ["question_id": id, "question_type": "info_text_box"])!
    }

    private func makeSurvey(ids: [String], randomize: Bool, memory: Bool, count: Int?) -> Survey {
        var s = Mapper<Survey>().mapArray(JSONObject: loadFixture("survey_download_payload"))![0]
        s.questions = ids.map(question)
        s.randomize = randomize
        s.randomizeWithMemory = memory
        s.numberOfRandomQuestions = count
        return s
    }

    private func makeStudy() -> Study {
        return Mapper<Study>().map(JSON: [:])!
    }

    private func shown(_ survey: Survey, _ order: [Int]) -> [String] {
        return order.prefix(displayedQuestionCount(survey: survey, stepOrder: order)).map { survey.questions[$0].questionId }
    }

    // the bug: every push builds a new ActiveSurvey, which used to draw fresh each time
    func testMemoryAcrossPushes() {
        let ids = (1 ... 10).map { "q\($0)" }
        let survey = makeSurvey(ids: ids, randomize: true, memory: true, count: 3)
        let study = makeStudy()
        var seen: [String] = []
        for expected in [3, 3, 3, 1] {
            let active = ActiveSurvey(survey: survey)  // a push
            XCTAssertNil(active.stepOrder)
            let q = shown(survey, questionOrderOnOpen(activeSurvey: active, survey: survey, study: study))
            XCTAssertEqual(q.count, expected)
            XCTAssertTrue(Set(q).isDisjoint(with: seen))
            seen += q
            XCTAssertEqual(study.surveyQuestionMemory[survey.surveyId!], seen)
        }
        XCTAssertEqual(seen.sorted(), ids.sorted())
        let q = shown(survey, questionOrderOnOpen(activeSurvey: ActiveSurvey(survey: survey), survey: survey, study: study))
        XCTAssertEqual(q.count, 3)
        XCTAssertEqual(study.surveyQuestionMemory[survey.surveyId!], q)
    }

    func testPushWithoutOpenConsumesNothing() {
        let survey = makeSurvey(ids: ["a", "b", "c"], randomize: true, memory: true, count: 1)
        let study = makeStudy()
        for _ in 0 ..< 5 {
            study.activeSurveys[survey.surveyId!] = ActiveSurvey(survey: survey)
        }
        XCTAssertTrue(study.surveyQuestionMemory.isEmpty)
    }

    func testReopenKeepsOrderAndMemory() {
        let survey = makeSurvey(ids: (1 ... 6).map { "q\($0)" }, randomize: true, memory: true, count: 2)
        let study = makeStudy()
        let active = ActiveSurvey(survey: survey)
        let first = questionOrderOnOpen(activeSurvey: active, survey: survey, study: study)
        let memory = study.surveyQuestionMemory
        XCTAssertEqual(active.stepOrder, first)
        for _ in 0 ..< 3 {
            XCTAssertEqual(questionOrderOnOpen(activeSurvey: active, survey: survey, study: study), first)
        }
        XCTAssertEqual(study.surveyQuestionMemory, memory)
    }

    func testMemoryCountNilOrZeroShowsAllUnseen() {
        for count in [nil, 0] as [Int?] {
            let survey = makeSurvey(ids: ["a", "b", "c", "d"], randomize: true, memory: true, count: count)
            let study = makeStudy()
            study.surveyQuestionMemory[survey.surveyId!] = ["b"]
            let q = shown(survey, questionOrderOnOpen(activeSurvey: ActiveSurvey(survey: survey), survey: survey, study: study))
            XCTAssertEqual(q.sorted(), ["a", "c", "d"])
        }
    }

    func testAlwaysAvailableResetDrawsUnseenOnNextOpen() {
        var survey = makeSurvey(ids: ["a", "b", "c", "d"], randomize: true, memory: true, count: 2)
        survey.alwaysAvailable = true
        let study = makeStudy()
        let active = ActiveSurvey(survey: survey)
        let first = shown(survey, questionOrderOnOpen(activeSurvey: active, survey: survey, study: study))
        active.isComplete = true
        active.reset(survey)  // clear_out_completed_surveys
        XCTAssertNil(active.stepOrder)
        let second = shown(survey, questionOrderOnOpen(activeSurvey: active, survey: survey, study: study))
        XCTAssertEqual((first + second).sorted(), ["a", "b", "c", "d"])
    }

    func testSurveyEditedBetweenSurveysUsesIds() {
        let study = makeStudy()
        let v1 = makeSurvey(ids: ["a", "b", "c", "d"], randomize: true, memory: true, count: 2)
        study.surveyQuestionMemory[v1.surveyId!] = ["a", "b"]
        // c deleted, e added, order changed
        let v2 = makeSurvey(ids: ["e", "d", "a", "b"], randomize: true, memory: true, count: 2)
        let q = shown(v2, questionOrderOnOpen(activeSurvey: ActiveSurvey(survey: v2), survey: v2, study: study))
        XCTAssertEqual(q.sorted(), ["d", "e"])
        XCTAssertEqual(study.surveyQuestionMemory[v2.surveyId!]!.sorted(), ["a", "b", "d", "e"])
    }

    // MARK: unchanged paths

    func testRandomizeWithoutMemoryUnchanged() {
        let survey = makeSurvey(ids: (1 ... 6).map { "q\($0)" }, randomize: true, memory: false, count: 2)
        let study = makeStudy()
        let active = ActiveSurvey(survey: survey)
        let stored = active.stepOrder!
        XCTAssertEqual(stored.sorted(), Array(0 ..< 6))  // full shuffle at push, as before
        XCTAssertEqual(questionOrderOnOpen(activeSurvey: active, survey: survey, study: study), stored)
        XCTAssertEqual(displayedQuestionCount(survey: survey, stepOrder: stored), 2)
        XCTAssertTrue(study.surveyQuestionMemory.isEmpty)
        // count nil or 0 -> all (Android rule); 9 of 5 -> 5
        for count in [nil, 0] as [Int?] {
            XCTAssertEqual(displayedQuestionCount(survey: makeSurvey(ids: ["a", "b"], randomize: true, memory: false, count: count), stepOrder: [1, 0]), 2)
        }
        let five = makeSurvey(ids: (1 ... 5).map { "q\($0)" }, randomize: true, memory: false, count: 9)
        XCTAssertEqual(displayedQuestionCount(survey: five, stepOrder: [4, 3, 2, 1, 0]), 5)
    }

    func testNotRandomizedUnchanged() {
        for memory in [false, true] {  // randomize_with_memory is ignored without randomize
            let survey = makeSurvey(ids: ["a", "b", "c"], randomize: false, memory: memory, count: 1)
            let study = makeStudy()
            let active = ActiveSurvey(survey: survey)
            XCTAssertEqual(active.stepOrder, [0, 1, 2])
            let order = questionOrderOnOpen(activeSurvey: active, survey: survey, study: study)
            XCTAssertEqual(shown(survey, order), ["a", "b", "c"])
            XCTAssertTrue(study.surveyQuestionMemory.isEmpty)
        }
    }

    // stored by the pre-fix app: a full shuffle on the ActiveSurvey; show its first N, record nothing
    func testLegacyStoredFullOrderStillShowsN() {
        let survey = makeSurvey(ids: ["a", "b", "c", "d"], randomize: true, memory: true, count: 2)
        let study = makeStudy()
        let active = Mapper<ActiveSurvey>().map(JSON: ["stepOrder": [3, 1, 0, 2], "survey": survey.toJSON()])!
        XCTAssertEqual(shown(survey, questionOrderOnOpen(activeSurvey: active, survey: survey, study: study)), ["d", "b"])
        XCTAssertTrue(study.surveyQuestionMemory.isEmpty)
    }

    // MARK: persistence

    func testMemoryPersistsWithStudy() {
        let study = makeStudy()
        study.surveyQuestionMemory = ["s1": ["q2", "q1"], "s2": []]
        let json = study.toJSON()
        XCTAssertEqual(json["survey_question_memory"] as? [String: [String]], ["s1": ["q2", "q1"], "s2": []])
        let back = Mapper<Study>().map(JSON: json)!
        XCTAssertEqual(back.surveyQuestionMemory, study.surveyQuestionMemory)
        XCTAssertEqual(Mapper<Study>().map(JSON: [:])!.surveyQuestionMemory, [:])  // docs from before the field
    }

    func testNilStepOrderRoundTrips() {
        let survey = makeSurvey(ids: ["a", "b"], randomize: true, memory: true, count: 1)
        let json = ActiveSurvey(survey: survey).toJSON()
        XCTAssertNil(json["stepOrder"])
        XCTAssertNil(Mapper<ActiveSurvey>().map(JSON: json)!.stepOrder)
    }
}
