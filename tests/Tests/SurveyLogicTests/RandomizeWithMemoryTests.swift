import XCTest
import ObjectMapper
@testable import SurveyQuestionDisplayLogic

// MARK: helpers

private func question(_ id: String) -> GenericSurveyQuestion {
    return Mapper<GenericSurveyQuestion>().map(JSON: ["question_id": id, "question_type": "info_text_box"])!
}

private func makeSurvey(ids: [String], randomize: Bool, memory: Bool, count: Int?) -> Survey {
    var s = Mapper<Survey>().mapArray(JSONObject: Fixtures.surveyDownloadPayload)![0]
    s.questions = ids.map(question)
    s.randomize = randomize
    s.randomizeWithMemory = memory
    s.numberOfRandomQuestions = count
    return s
}

private func makeStudy() -> Study {
    return Mapper<Study>().map(JSON: [:])!
}

/// question ids the participant sees for this order
private func shown(_ survey: Survey, _ order: [Int]) -> [String] {
    return order.prefix(displayedQuestionCount(survey: survey, stepOrder: order)).map { survey.questions[$0].questionId }
}

private func realShuffle(_ n: Int) -> [Int] {
    return Array(0 ..< n).shuffled()
}

/// one row of Fixtures.randomizeWithMemory
private struct SelectionCase: Decodable {
    let name: String
    let question_ids: [String]
    let memory: [String]
    let count: Int?
    let shuffles: [[Int]]
    let selected_indices: [Int]
    let selected_ids: [String]
    let memory_after: [String]
}

private func selectionCases() throws -> [SelectionCase] {
    struct File: Decodable {
        let cases: [SelectionCase]
    }
    return try JSONDecoder().decode(File.self, from: Fixtures.randomizeWithMemory).cases
}

/// BS7: "randomize without replacement" must match Android: memory is question ids per survey id on the study,
/// drawn when the survey is opened, so it survives new surveys (each push notification builds a new ActiveSurvey),
/// restarts and survey edits.
class RandomizeWithMemoryTests: XCTestCase {

    // MARK: pure selection

    // pins exact draws so iOS and the Kotlin port (same JSON table) pick the same questions as Android
    func testSelectionMatchesEveryFixtureCase() throws {
        let cases = try selectionCases()
        AssertFalse(cases.isEmpty)
        for c in cases {
            var shuffles = c.shuffles
            let r = randomQuestionSelection(
                questionIds: c.question_ids, memory: c.memory, count: c.count,
                shuffle: { n in
                    let p = shuffles.removeFirst()
                    AssertEqual(p.count, n, c.name)
                    return p
                }
            )
            AssertEqual(r.indices, c.selected_indices, c.name)
            AssertEqual(r.indices.map { c.question_ids[$0] }, c.selected_ids, c.name)
            AssertEqual(r.memory, c.memory_after, c.name)
            AssertTrue(shuffles.isEmpty, "\(c.name): unused shuffles")
        }
    }

    // the promise researchers rely on: no question repeats until every question has been shown
    func testRealShuffleShowsEveryQuestionOncePerRound() {
        let ids = (1 ... 10).map { "q\($0)" }
        for _ in 0 ..< 50 {
            var memory: [String] = []
            var round: [String] = []
            for expected in [3, 3, 3, 1] {  // 10 questions, 3 per survey
                let r = randomQuestionSelection(questionIds: ids, memory: memory, count: 3, shuffle: realShuffle)
                AssertEqual(r.indices.count, expected)
                round += r.indices.map { ids[$0] }
                memory = r.memory
            }
            AssertEqual(round.sorted(), ids.sorted())
            let next = randomQuestionSelection(questionIds: ids, memory: memory, count: 3, shuffle: realShuffle)
            AssertEqual(next.indices.count, 3)
            AssertEqual(next.memory, next.indices.map { ids[$0] })
        }
    }

    // MARK: models: open, new survey, reset

    // the BS7 bug: every new survey built a new ActiveSurvey that drew fresh, so questions repeated
    func testNewSurveysDrawUnseenQuestionsUntilRoundEnds() {
        let ids = (1 ... 10).map { "q\($0)" }
        let survey = makeSurvey(ids: ids, randomize: true, memory: true, count: 3)
        let study = makeStudy()
        var seen: [String] = []
        for expected in [3, 3, 3, 1] {
            let active = ActiveSurvey(survey: survey)  // a new survey
            AssertNil(active.stepOrder)
            let q = shown(survey, questionOrderOnOpen(activeSurvey: active, survey: survey, study: study))
            AssertEqual(q.count, expected)
            AssertTrue(Set(q).isDisjoint(with: seen))
            seen += q
            AssertEqual(study.surveyQuestionMemory[survey.surveyId!], seen)
        }
        AssertEqual(seen.sorted(), ids.sorted())
        let q = shown(survey, questionOrderOnOpen(activeSurvey: ActiveSurvey(survey: survey), survey: survey, study: study))
        AssertEqual(q.count, 3)
        AssertEqual(study.surveyQuestionMemory[survey.surveyId!], q)
    }

    // like Android, questions count as seen only when opened; missed surveys must not use them up
    func testUnopenedNewSurveysLeaveMemoryEmpty() {
        let survey = makeSurvey(ids: ["a", "b", "c"], randomize: true, memory: true, count: 1)
        let study = makeStudy()
        for _ in 0 ..< 5 {
            study.activeSurveys[survey.surveyId!] = ActiveSurvey(survey: survey)
        }
        AssertTrue(study.surveyQuestionMemory.isEmpty)
    }

    // a partly answered survey must resume with the same questions, not draw again
    func testReopeningKeepsQuestionOrderAndMemory() {
        let survey = makeSurvey(ids: (1 ... 6).map { "q\($0)" }, randomize: true, memory: true, count: 2)
        let study = makeStudy()
        let active = ActiveSurvey(survey: survey)
        let first = questionOrderOnOpen(activeSurvey: active, survey: survey, study: study)
        let memory = study.surveyQuestionMemory
        AssertEqual(active.stepOrder, first)
        for _ in 0 ..< 3 {
            AssertEqual(questionOrderOnOpen(activeSurvey: active, survey: survey, study: study), first)
        }
        AssertEqual(study.surveyQuestionMemory, memory)
    }

    // matches Android: with memory, a nil or 0 question count means every unseen question
    func testNoQuestionCountShowsAllUnseenQuestions() {
        for count in [nil, 0] as [Int?] {
            let survey = makeSurvey(ids: ["a", "b", "c", "d"], randomize: true, memory: true, count: count)
            let study = makeStudy()
            study.surveyQuestionMemory[survey.surveyId!] = ["b"]
            let q = shown(survey, questionOrderOnOpen(activeSurvey: ActiveSurvey(survey: survey), survey: survey, study: study))
            AssertEqual(q.sorted(), ["a", "c", "d"])
        }
    }

    // always-available surveys reuse one ActiveSurvey via reset, which must clear the order so memory applies
    func testCompletedAlwaysAvailableSurveyDrawsUnseenOnNextOpen() {
        var survey = makeSurvey(ids: ["a", "b", "c", "d"], randomize: true, memory: true, count: 2)
        survey.alwaysAvailable = true
        let study = makeStudy()
        let active = ActiveSurvey(survey: survey)
        let first = shown(survey, questionOrderOnOpen(activeSurvey: active, survey: survey, study: study))
        active.isComplete = true
        active.reset(survey)  // clear_out_completed_surveys
        AssertNil(active.stepOrder)
        let second = shown(survey, questionOrderOnOpen(activeSurvey: active, survey: survey, study: study))
        AssertEqual((first + second).sorted(), ["a", "b", "c", "d"])
    }

    // memory holds question ids, so researcher edits (delete, add, reorder) don't confuse which were seen
    func testEditedSurveySkipsSeenQuestionsById() {
        let study = makeStudy()
        let v1 = makeSurvey(ids: ["a", "b", "c", "d"], randomize: true, memory: true, count: 2)
        study.surveyQuestionMemory[v1.surveyId!] = ["a", "b"]
        // c deleted, e added, order changed
        let v2 = makeSurvey(ids: ["e", "d", "a", "b"], randomize: true, memory: true, count: 2)
        let q = shown(v2, questionOrderOnOpen(activeSurvey: ActiveSurvey(survey: v2), survey: v2, study: study))
        AssertEqual(q.sorted(), ["d", "e"])
        AssertEqual(study.surveyQuestionMemory[v2.surveyId!]!.sorted(), ["a", "b", "d", "e"])
    }

    // MARK: without memory, not randomized

    // the BS7 fix must not change surveys that randomize without memory
    func testRandomizeWithoutMemoryShowsFirstNOfFullShuffle() {
        let survey = makeSurvey(ids: (1 ... 6).map { "q\($0)" }, randomize: true, memory: false, count: 2)
        let study = makeStudy()
        let active = ActiveSurvey(survey: survey)
        let stored = active.stepOrder!
        AssertEqual(stored.sorted(), Array(0 ..< 6))  // full shuffle when the new survey arrives, as before
        AssertEqual(questionOrderOnOpen(activeSurvey: active, survey: survey, study: study), stored)
        AssertEqual(displayedQuestionCount(survey: survey, stepOrder: stored), 2)
        AssertTrue(study.surveyQuestionMemory.isEmpty)
    }

    // BS18: iOS showed an empty survey for count 0; Android and the backend treat 0 (or no count) as all questions
    func testRandomizeWithoutMemoryNoQuestionCountShowsAllQuestions() {
        for count in [nil, 0] as [Int?] {
            let survey = makeSurvey(ids: ["a", "b"], randomize: true, memory: false, count: count)
            AssertEqual(displayedQuestionCount(survey: survey, stepOrder: [1, 0]), 2, "count \(String(describing: count))")
        }
    }

    // a count above the number of questions must not index past the end of the survey
    func testRandomizeWithoutMemoryCountAboveTotalShowsEachQuestionOnce() {
        let survey = makeSurvey(ids: (1 ... 5).map { "q\($0)" }, randomize: true, memory: false, count: 9)
        AssertEqual(displayedQuestionCount(survey: survey, stepOrder: [4, 3, 2, 1, 0]), 5)
    }

    // the BS7 fix must not change surveys that don't randomize, even with the memory flag set
    func testNotRandomizedShowsAllQuestionsInOrder() {
        for memory in [false, true] {  // randomize_with_memory is ignored without randomize
            let survey = makeSurvey(ids: ["a", "b", "c"], randomize: false, memory: memory, count: 1)
            let study = makeStudy()
            let active = ActiveSurvey(survey: survey)
            AssertEqual(active.stepOrder, [0, 1, 2])
            let order = questionOrderOnOpen(activeSurvey: active, survey: survey, study: study)
            AssertEqual(shown(survey, order), ["a", "b", "c"])
            AssertTrue(study.surveyQuestionMemory.isEmpty)
        }
    }

    // an ActiveSurvey saved before BS7 holds a full shuffle and survives an app update; it must still show only N
    func testPreFixStoredOrderShowsOnlyFirstN() {
        let survey = makeSurvey(ids: ["a", "b", "c", "d"], randomize: true, memory: true, count: 2)
        let study = makeStudy()
        let active = Mapper<ActiveSurvey>().map(JSON: ["stepOrder": [3, 1, 0, 2], "survey": survey.toJSON()])!
        AssertEqual(shown(survey, questionOrderOnOpen(activeSurvey: active, survey: survey, study: study)), ["d", "b"])
        AssertTrue(study.surveyQuestionMemory.isEmpty)
    }

    // MARK: persistence

    // memory must survive app restarts, and Study docs saved before the field existed must still load
    func testMemorySavesAndLoadsWithStudy() {
        let study = makeStudy()
        study.surveyQuestionMemory = ["s1": ["q2", "q1"], "s2": []]
        let json = study.toJSON()
        AssertEqual(json["survey_question_memory"] as? [String: [String]], ["s1": ["q2", "q1"], "s2": []])
        let back = Mapper<Study>().map(JSON: json)!
        AssertEqual(back.surveyQuestionMemory, study.surveyQuestionMemory)
        AssertEqual(Mapper<Study>().map(JSON: [:])!.surveyQuestionMemory, [:])
    }

    // a saved, unopened memory survey must still draw on open after an app restart
    func testUnopenedActiveSurveySavesAndLoadsWithNoOrder() {
        let survey = makeSurvey(ids: ["a", "b"], randomize: true, memory: true, count: 1)
        let json = ActiveSurvey(survey: survey).toJSON()
        AssertNil(json["stepOrder"])
        AssertNil(Mapper<ActiveSurvey>().map(JSON: json)!.stepOrder)
    }
}
