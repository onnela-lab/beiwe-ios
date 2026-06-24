import XCTest
import SurveyQuestionDisplayLogic


typealias Result = ORKResult
typealias StepRes = ORKStepResult
typealias QuestionRes = ORKQuestionResult
typealias ChoiceRes = ORKChoiceQuestionResult
typealias ScaleRes = ORKScaleQuestionResult
typealias TaskRes = ORKTaskResult


// Disable stdout buffering so print() output appears inline with test results.
class UnbufferedTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        setbuf(stdout, nil)
    }
}

// MARK: - extractAnswer

class ExtractAnswerTests: UnbufferedTestCase {

    // nil and empty on StepRes
    func testNilResultsReturnsEmpty() {
        let step = StepRes(results: nil)
        let (answers, typename) = extractAnswer(step)
        XCTAssertEqual(answers, [])
        XCTAssertEqual(typename, "double")
    }

    func testEmptyResultsReturnsEmpty() {
        let step = StepRes(results: [])
        let (answers, typename) = extractAnswer(step)
        XCTAssertEqual(answers, [])
        XCTAssertEqual(typename, "double")
    }

    // ChoiceQuestionResult
    
    func testChoiceResultWithAnswers() {
        let choice = ChoiceRes(choiceAnswers: [1, 2, 3] as [NSNumber])
        let step = StepRes(results: [choice])
        let (answers, typename) = extractAnswer(step)
        XCTAssertEqual(answers, [1, 2, 3])
        XCTAssertEqual(typename, "int")
    }

    func testChoiceResultNilAnswers() {
        let choice = ChoiceRes(choiceAnswers: nil)
        let step = StepRes(results: [choice])
        let (answers, typename) = extractAnswer(step)
        XCTAssertEqual(answers, [])
        XCTAssertEqual(typename, "int")
    }

    // QuestionResult 
    
    func testQuestionResultWithNumericString() {
        let q = QuestionRes(answer: "42.5")
        let step = StepRes(results: [q])
        let (answers, typename) = extractAnswer(step)
        XCTAssertEqual(answers.count, 1)
        XCTAssertEqual(answers[0].doubleValue, 42.5)
        XCTAssertEqual(typename, "double")
    }

    func testQuestionResultWithNilAnswer() {
        let q = QuestionRes(answer: nil)
        let step = StepRes(results: [q])
        let (answers, typename) = extractAnswer(step)
        XCTAssertEqual(answers, [])
        XCTAssertEqual(typename, "double")
    }

    func testQuestionResultWithNonNumericStringReturnsEmpty() {
        let q = QuestionRes(answer: "hello")
        let step = StepRes(results: [q])
        let (answers, typename) = extractAnswer(step)
        XCTAssertEqual(answers, [])
        XCTAssertEqual(typename, "double")
    }
    
    // ScaleQuestionResult
    
    func testScaleQuestionResultWithAnswers() {
        let scale = ScaleRes(scaleAnswer: 3)
        let step = StepRes(results: [scale])
        let (answers, typename) = extractAnswer(step)
        XCTAssertEqual(answers, [3])
        XCTAssertEqual(typename, "int")
    }
    func testScaleQuestionResultWithNilAnswer() {
        let scale = ScaleRes(scaleAnswer: nil)
        let step = StepRes(results: [scale])
        let (answers, typename) = extractAnswer(step)
        XCTAssertEqual(answers, [])
        XCTAssertEqual(typename, "int")
    }
}

// MARK: - do_choice_logic

class DoChoiceLogicTests: UnbufferedTestCase {

    func testNilChoiceAnswersReturnsEmpty() {
        let choice = ChoiceRes(choiceAnswers: nil)
        let (answers, typename) = do_choice_logic(choice)
        XCTAssertEqual(answers, [])
        XCTAssertEqual(typename, "int")
    }

    func testValidNumbersExtracted() {
        let choice = ChoiceRes(choiceAnswers: [0, 2] as [NSNumber])
        let (answers, typename) = do_choice_logic(choice)
        XCTAssertEqual(answers, [0, 2])
        XCTAssertEqual(typename, "int")
    }

    func testNonNumberEntriesFiltered() {
        let choice = ChoiceRes(choiceAnswers: ["bad", 1 as NSNumber, "also bad"] as [Any])
        let (answers, typename) = do_choice_logic(choice)
        XCTAssertEqual(answers, [1])
        XCTAssertEqual(typename, "int")
    }
}

// MARK: - double_comparisons

class DoubleComparisonsTests: UnbufferedTestCase {

    func testEqualsTrue() {
        XCTAssertTrue(double_comparisons("==", 5.0, [5.0]))
    }

    func testEqualsFalse() {
        XCTAssertFalse(double_comparisons("==", 5.0, [6.0]))
    }

    func testLessThanTrue() {
        XCTAssertTrue(double_comparisons("<", 10.0, [9.0]))
    }

    func testLessThanFalse() {
        XCTAssertFalse(double_comparisons("<", 10.0, [10.0]))
    }

    func testLessThanOrEqualOnBoundary() {
        XCTAssertTrue(double_comparisons("<=", 10.0, [10.0]))
    }

    func testGreaterThanTrue() {
        XCTAssertTrue(double_comparisons(">", 3.0, [5.0]))
    }

    func testGreaterThanFalse() {
        XCTAssertFalse(double_comparisons(">", 5.0, [3.0]))
    }

    func testGreaterThanOrEqualOnBoundary() {
        XCTAssertTrue(double_comparisons(">=", 5.0, [5.0]))
    }

    func testEmptyNumbersReturnsFalse() {
        XCTAssertFalse(double_comparisons("==", 5.0, []))
        XCTAssertFalse(double_comparisons(">", 5.0, []))
        XCTAssertFalse(double_comparisons("<", 5.0, []))
        XCTAssertFalse(double_comparisons(">=", 5.0, []))
        XCTAssertFalse(double_comparisons("<=", 5.0, []))
    }

    func testAnyMatchInListReturnsTrue() {
        XCTAssertTrue(double_comparisons("==", 3.0, [1.0, 2.0, 3.0]))
        XCTAssertTrue(double_comparisons(">", 2.0, [1.0, 2.0, 3.0]))
        XCTAssertTrue(double_comparisons("<", 4.0, [1.0, 2.0, 3.0]))
        XCTAssertTrue(double_comparisons(">=", 3.0, [1.0, 2.0, 3.0]))
        XCTAssertTrue(double_comparisons("<=", 3.0, [1.0, 2.0, 3.0]))
    }
}

// MARK: - int_comparisons

class IntComparisonsTests: UnbufferedTestCase {

    func testEqualsTrue() {
        XCTAssertTrue(int_comparisons("==", 5, [5]))
    }

    func testEqualsFalse() {
        XCTAssertFalse(int_comparisons("==", 5, [6]))
    }

    func testLessThanTrue() {
        XCTAssertTrue(int_comparisons("<", 10, [9]))
    }

    func testLessThanFalse() {
        XCTAssertFalse(int_comparisons("<", 10, [10]))
    }

    func testLessThanOrEqualOnBoundary() {
        XCTAssertTrue(int_comparisons("<=", 10, [10]))
    }

    func testGreaterThanTrue() {
        XCTAssertTrue(int_comparisons(">", 3, [5]))
    }

    func testGreaterThanFalse() {
        XCTAssertFalse(int_comparisons(">", 5, [3]))
    }

    func testGreaterThanOrEqualOnBoundary() {
        XCTAssertTrue(int_comparisons(">=", 5, [5]))
    }

    func testEmptyNumbersReturnsFalse() {
        XCTAssertFalse(int_comparisons("==", 5, []))
        XCTAssertFalse(int_comparisons(">", 5, []))
        XCTAssertFalse(int_comparisons("<", 5, []))
        XCTAssertFalse(int_comparisons(">=", 5, []))
        XCTAssertFalse(int_comparisons("<=", 5, []))
    }

    func testAnyMatchInListReturnsTrue() {
        XCTAssertTrue(int_comparisons("==", 3, [1, 2, 3]))
        XCTAssertTrue(int_comparisons(">", 2, [1, 2, 3]))
        XCTAssertTrue(int_comparisons("<", 4, [1, 2, 3]))
        XCTAssertTrue(int_comparisons(">=", 3, [1, 2, 3]))
        XCTAssertTrue(int_comparisons("<=", 3, [1, 2, 3]))
    }
}

// MARK: - numeric_logic

class NumericLogicTests: UnbufferedTestCase {

    func makeTaskResult(questionId: String, choiceAnswers: [NSNumber]) -> TaskRes {
        let choice = ChoiceRes(choiceAnswers: choiceAnswers)
        let step = StepRes(results: [choice])
        let task = TaskRes(stepResults: [questionId: step])
        return task
    }

    func makeTaskResult(questionId: String, numericAnswer: String) -> TaskRes {
        let q = QuestionRes(answer: numericAnswer)
        let step = StepRes(results: [q])
        let task = TaskRes(stepResults: [questionId: step])
        return task
    }

    func testMissingTargetReturnsFalse() {
        let task = TaskRes(stepResults: [:])
        XCTAssertFalse(numeric_logic("==", "missing_q", 5, task))
    }

    func testChoiceEqualsMatchTrue() {
        let task = makeTaskResult(questionId: "q1", choiceAnswers: [2])
        XCTAssertTrue(numeric_logic("==", "q1", 2, task))
    }

    func testChoiceEqualsMatchFalse() {
        let task = makeTaskResult(questionId: "q1", choiceAnswers: [3])
        XCTAssertFalse(numeric_logic("==", "q1", 2, task))
    }

    func testNumericOpenResponseGreaterThan() {
        let task = makeTaskResult(questionId: "q1", numericAnswer: "15.0")
        XCTAssertTrue(numeric_logic(">", "q1", 10, task))
    }

    func testNumericOpenResponseLessThan() {
        let task = makeTaskResult(questionId: "q1", numericAnswer: "5.0")
        XCTAssertTrue(numeric_logic("<", "q1", 10, task))
    }

    func testRadioButtonNoMatchFailsCondition() {
        let task = makeTaskResult(questionId: "q1", choiceAnswers: [2])
        XCTAssertFalse(numeric_logic("==", "q1", 3, task))
    }

    func testCheckboxAnyMatchSatisfiesCondition() {
        // checkbox question with multiple selections — any match is sufficient
        let task = makeTaskResult(questionId: "q1", choiceAnswers: [0, 1, 2])
        XCTAssertTrue(numeric_logic("==", "q1", 2, task))
    }

    func testCheckboxNoMatchFailsCondition() {
        // checkbox question with multiple selections — no match should fail
        let task = makeTaskResult(questionId: "q1", choiceAnswers: [0, 1, 2])
        XCTAssertFalse(numeric_logic("==", "q1", 3, task))
    }

    func testCheckboxInequalityAnyMatchTrue() {
        // [1, 3, 5] > 2 — answers 3 and 5 satisfy it, so any-match returns true
        let task = makeTaskResult(questionId: "q1", choiceAnswers: [1, 3, 5])
        XCTAssertTrue(numeric_logic(">", "q1", 2, task))
    }

    func testCheckboxInequalityNoMatchFalse() {
        // [0, 1] > 5 — no answer satisfies it
        let task = makeTaskResult(questionId: "q1", choiceAnswers: [0, 1])
        XCTAssertFalse(numeric_logic(">", "q1", 5, task))
    }

    func testCheckboxLessThanAnyMatchTrue() {
        // [10, 20, 30] < 15 — answer 10 satisfies it
        let task = makeTaskResult(questionId: "q1", choiceAnswers: [10, 20, 30])
        XCTAssertTrue(numeric_logic("<", "q1", 15, task))
    }

}

// MARK: - evaluateSingleLogicPair

class EvaluateSingleLogicPairTests: UnbufferedTestCase {

    // Build an TaskRes with a single choice question answer.
    func makeTask(_ questionId: String, choiceAnswers: [NSNumber]) -> TaskRes {
        let choice = ChoiceRes(choiceAnswers: choiceAnswers)
        let step = StepRes(results: [choice])
        let task = TaskRes(stepResults: [questionId: step])
        return task
    }

    // Construct a numeric payload: NSArray(["questionId", compareValue])
    func numericPayload(_ questionId: String, _ value: NSNumber) -> NSArray {
        return NSArray(array: [questionId, value])
    }

    // Construct an and/or payload: NSArray of NSDictionary, each {op: NSArray([qId, val])}
    func logicList(_ pairs: [(String, String, NSNumber)]) -> NSArray {
        return NSArray(array: pairs.map { (op, qId, val) in
            NSDictionary(dictionary: [op: numericPayload(qId, val)])
        })
    }

    // MARK: numeric dispatch

    func testNumericEqualsTrue() {
        let task = makeTask("q1", choiceAnswers: [3])
        XCTAssertTrue(evaluateSingleLogicPair("==", numericPayload("q1", 3), task))
    }

    func testNumericEqualsFalse() {
        let task = makeTask("q1", choiceAnswers: [4])
        XCTAssertFalse(evaluateSingleLogicPair("==", numericPayload("q1", 3), task))
    }

    func testNumericLessThan() {
        let task = makeTask("q1", choiceAnswers: [2])
        XCTAssertTrue(evaluateSingleLogicPair("<", numericPayload("q1", 5), task))
    }

    func testNumericGreaterThan() {
        let task = makeTask("q1", choiceAnswers: [7])
        XCTAssertTrue(evaluateSingleLogicPair(">", numericPayload("q1", 5), task))
    }

    // MARK: and

    func testAndAllConditionsTrue() {
        let task = makeTask("q1", choiceAnswers: [3])
        task.addStepResult(StepRes(results: [ChoiceRes(choiceAnswers: [7])]), forIdentifier: "q2")
        let payload = logicList([("==", "q1", 3), ("==", "q2", 7)])
        XCTAssertTrue(evaluateSingleLogicPair("and", payload, task))
    }

    func testAndOneConditionFalse() {
        let task = makeTask("q1", choiceAnswers: [3])
        task.addStepResult(StepRes(results: [ChoiceRes(choiceAnswers: [9])]), forIdentifier: "q2")
        let payload = logicList([("==", "q1", 3), ("==", "q2", 7)])  // q2 is 9, not 7
        XCTAssertFalse(evaluateSingleLogicPair("and", payload, task))
    }

    // MARK: or

    func testOrFirstConditionTrue() {
        let task = makeTask("q1", choiceAnswers: [3])
        task.addStepResult(StepRes(results: [ChoiceRes(choiceAnswers: [9])]), forIdentifier: "q2")
        let payload = logicList([("==", "q1", 3), ("==", "q2", 7)])  // q1 matches, q2 doesn't
        XCTAssertTrue(evaluateSingleLogicPair("or", payload, task))
    }

    func testOrAllConditionsFalse() {
        let task = makeTask("q1", choiceAnswers: [0])
        task.addStepResult(StepRes(results: [ChoiceRes(choiceAnswers: [0])]), forIdentifier: "q2")
        let payload = logicList([("==", "q1", 3), ("==", "q2", 7)])  // neither matches
        XCTAssertFalse(evaluateSingleLogicPair("or", payload, task))
    }

    // MARK: not

    func testNotInvertsTrue() {
        let task = makeTask("q1", choiceAnswers: [3])
        // q1 == 3 is true, not should flip it to false
        let payload = NSDictionary(dictionary: ["==": numericPayload("q1", 3)])
        XCTAssertFalse(evaluateSingleLogicPair("not", payload, task))
    }

    func testNotInvertsFalse() {
        let task = makeTask("q1", choiceAnswers: [0])
        // q1 == 3 is false, not should flip it to true
        let payload = NSDictionary(dictionary: ["==": numericPayload("q1", 3)])
        XCTAssertTrue(evaluateSingleLogicPair("not", payload, task))
    }

    // MARK: nested

    func testOrContainingAnd() {
        // or(and(q1==3, q2==7), q1==99) — q1 is 3, q2 is 7 → and is true → or is true
        let task = makeTask("q1", choiceAnswers: [3])
        task.addStepResult(StepRes(results: [ChoiceRes(choiceAnswers: [7])]), forIdentifier: "q2")
        let andPayload = logicList([("==", "q1", 3), ("==", "q2", 7)])
        let orPayload = NSArray(array: [
            NSDictionary(dictionary: ["and": andPayload]),
            NSDictionary(dictionary: ["==": numericPayload("q1", 99)]),
        ])
        XCTAssertTrue(evaluateSingleLogicPair("or", orPayload, task))
    }

}

// MARK: - nested logic structures

class NestedLogicTests: UnbufferedTestCase {

    // Build a task with multiple choice questions from a dict of questionId → selected indices.
    func makeTask(_ answers: [String: [NSNumber]]) -> TaskRes {
        let stepResults = answers.mapValues { nums in
            StepRes(results: [ChoiceRes(choiceAnswers: nums as [Any])])
        }
        return TaskRes(stepResults: stepResults)
    }

    func numericPayload(_ questionId: String, _ value: NSNumber) -> NSArray {
        return NSArray(array: [questionId, value])
    }

    // One NSDictionary entry for inside an and/or payload list.
    func entry(_ op: String, _ questionId: String, _ value: NSNumber) -> NSDictionary {
        return NSDictionary(dictionary: [op: numericPayload(questionId, value)])
    }

    // MARK: and containing or

    func testAndContainingOrAllTrue() {
        // and(or(q1==3, q1==5), q2==7) — q1=3 satisfies or, q2=7 satisfies and → true
        let task = makeTask(["q1": [3], "q2": [7]])
        let orPayload = NSArray(array: [entry("==", "q1", 3), entry("==", "q1", 5)])
        let andPayload = NSArray(array: [
            NSDictionary(dictionary: ["or": orPayload]),
            entry("==", "q2", 7),
        ])
        XCTAssertTrue(evaluateSingleLogicPair("and", andPayload, task))
    }

    func testAndContainingOrInnerFails() {
        // and(or(q1==3, q1==5), q2==7) — q1=0 fails or → and is false
        let task = makeTask(["q1": [0], "q2": [7]])
        let orPayload = NSArray(array: [entry("==", "q1", 3), entry("==", "q1", 5)])
        let andPayload = NSArray(array: [
            NSDictionary(dictionary: ["or": orPayload]),
            entry("==", "q2", 7),
        ])
        XCTAssertFalse(evaluateSingleLogicPair("and", andPayload, task))
    }

    func testAndContainingOrOuterFails() {
        // and(or(q1==3, q1==5), q2==7) — or passes but q2=0 fails and → false
        let task = makeTask(["q1": [3], "q2": [0]])
        let orPayload = NSArray(array: [entry("==", "q1", 3), entry("==", "q1", 5)])
        let andPayload = NSArray(array: [
            NSDictionary(dictionary: ["or": orPayload]),
            entry("==", "q2", 7),
        ])
        XCTAssertFalse(evaluateSingleLogicPair("and", andPayload, task))
    }

    // MARK: or containing and

    func testOrContainingAndSecondBranchTrue() {
        // or(q1==99, and(q1==3, q2==7)) — first branch fails, second passes → true
        let task = makeTask(["q1": [3], "q2": [7]])
        let andPayload = NSArray(array: [entry("==", "q1", 3), entry("==", "q2", 7)])
        let orPayload = NSArray(array: [
            entry("==", "q1", 99),
            NSDictionary(dictionary: ["and": andPayload]),
        ])
        XCTAssertTrue(evaluateSingleLogicPair("or", orPayload, task))
    }

    func testOrContainingAndBothFail() {
        // or(q1==99, and(q1==3, q2==7)) — q1=0, q2=0 → both branches false → false
        let task = makeTask(["q1": [0], "q2": [0]])
        let andPayload = NSArray(array: [entry("==", "q1", 3), entry("==", "q2", 7)])
        let orPayload = NSArray(array: [
            entry("==", "q1", 99),
            NSDictionary(dictionary: ["and": andPayload]),
        ])
        XCTAssertFalse(evaluateSingleLogicPair("or", orPayload, task))
    }

    // MARK: not wrapping and/or
    // (not wrapping not crashes — known bug in dispatch_negation, separate from this)

    func testNotWrappingAndTrue() {
        // not(and(q1==3, q2==7)) — both match so and=true → not flips to false
        let task = makeTask(["q1": [3], "q2": [7]])
        let andPayload = NSArray(array: [entry("==", "q1", 3), entry("==", "q2", 7)])
        XCTAssertFalse(evaluateSingleLogicPair("not", NSDictionary(dictionary: ["and": andPayload]), task))
    }

    func testNotWrappingAndFalse() {
        // not(and(q1==3, q2==7)) — q2=0 so and=false → not flips to true
        let task = makeTask(["q1": [3], "q2": [0]])
        let andPayload = NSArray(array: [entry("==", "q1", 3), entry("==", "q2", 7)])
        XCTAssertTrue(evaluateSingleLogicPair("not", NSDictionary(dictionary: ["and": andPayload]), task))
    }

    func testNotWrappingOrTrue() {
        // not(or(q1==3, q2==7)) — q1=3 so or=true → not flips to false
        let task = makeTask(["q1": [3], "q2": [0]])
        let orPayload = NSArray(array: [entry("==", "q1", 3), entry("==", "q2", 7)])
        XCTAssertFalse(evaluateSingleLogicPair("not", NSDictionary(dictionary: ["or": orPayload]), task))
    }

    func testNotWrappingOrFalse() {
        // not(or(q1==3, q2==7)) — neither matches so or=false → not flips to true
        let task = makeTask(["q1": [0], "q2": [0]])
        let orPayload = NSArray(array: [entry("==", "q1", 3), entry("==", "q2", 7)])
        XCTAssertTrue(evaluateSingleLogicPair("not", NSDictionary(dictionary: ["or": orPayload]), task))
    }

    // MARK: three-condition and/or

    func testThreeConditionAndAllTrue() {
        let task = makeTask(["q1": [1], "q2": [2], "q3": [3]])
        let payload = NSArray(array: [entry("==", "q1", 1), entry("==", "q2", 2), entry("==", "q3", 3)])
        XCTAssertTrue(evaluateSingleLogicPair("and", payload, task))
    }

    func testThreeConditionAndMiddleFails() {
        let task = makeTask(["q1": [1], "q2": [9], "q3": [3]])
        let payload = NSArray(array: [entry("==", "q1", 1), entry("==", "q2", 2), entry("==", "q3", 3)])
        XCTAssertFalse(evaluateSingleLogicPair("and", payload, task))
    }

    func testThreeConditionOrOnlyLastTrue() {
        let task = makeTask(["q1": [0], "q2": [0], "q3": [3]])
        let payload = NSArray(array: [entry("==", "q1", 1), entry("==", "q2", 2), entry("==", "q3", 3)])
        XCTAssertTrue(evaluateSingleLogicPair("or", payload, task))
    }

    func testThreeConditionOrAllFalse() {
        let task = makeTask(["q1": [0], "q2": [0], "q3": [0]])
        let payload = NSArray(array: [entry("==", "q1", 1), entry("==", "q2", 2), entry("==", "q3", 3)])
        XCTAssertFalse(evaluateSingleLogicPair("or", payload, task))
    }

    // MARK: unanswered questions

    func testAndWithUnansweredQuestionFails() {
        // q2 absent — unanswered question cannot satisfy any condition, so and fails
        let task = makeTask(["q1": [3]])
        let payload = NSArray(array: [entry("==", "q1", 3), entry("==", "q2", 7)])
        XCTAssertFalse(evaluateSingleLogicPair("and", payload, task))
    }

    func testOrWithAllUnansweredFails() {
        // only q1 answered but neither condition matches → false
        let task = makeTask(["q1": [0]])
        let payload = NSArray(array: [entry("==", "q1", 3), entry("==", "q2", 7)])
        XCTAssertFalse(evaluateSingleLogicPair("or", payload, task))
    }

    func testOrWithUnansweredButOtherMatches() {
        // q2 absent but q1 matches → or is true
        let task = makeTask(["q1": [3]])
        let payload = NSArray(array: [entry("==", "q1", 3), entry("==", "q2", 7)])
        XCTAssertTrue(evaluateSingleLogicPair("or", payload, task))
    }

    // MARK: not inside containers was broken and caused a crash.

    func testAndContainingNot() {
        // and(q1==3, not(q2==7)) — q1=3, q2=9 → should be true
        let task = makeTask(["q1": [3], "q2": [9]])
        let notPayload = NSDictionary(dictionary: ["==": numericPayload("q2", 7)])
        let andPayload = NSArray(array: [
            entry("==", "q1", 3),
            NSDictionary(dictionary: ["not": notPayload]),
        ])
        XCTAssertTrue(evaluateSingleLogicPair("and", andPayload, task))
    }

    func testOrContainingNot() {
        // or(not(q1==3), q2==7) — q1=0 so not is true → should be true
        let task = makeTask(["q1": [0], "q2": [0]])
        let notPayload = NSDictionary(dictionary: ["==": numericPayload("q1", 3)])
        let orPayload = NSArray(array: [
            NSDictionary(dictionary: ["not": notPayload]),
            entry("==", "q2", 7),
        ])
        XCTAssertTrue(evaluateSingleLogicPair("or", orPayload, task))
    }

    func testNotWrappingNot() {
        // not(not(q1==3)) — double negation, q1=3 → should be true
        let task = makeTask(["q1": [3]])
        let innerNot = NSDictionary(dictionary: ["==": numericPayload("q1", 3)])
        let outerNot = NSDictionary(dictionary: ["not": innerNot])
        XCTAssertTrue(evaluateSingleLogicPair("not", outerNot, task))
    }

    // MARK: failure paths for not inside containers

    func testAndContainingNotWhereFails() {
        // and(q1==3, not(q2==7)) — q1=3 but q2=7 so not is false → and fails
        let task = makeTask(["q1": [3], "q2": [7]])
        let notPayload = NSDictionary(dictionary: ["==": numericPayload("q2", 7)])
        let andPayload = NSArray(array: [
            entry("==", "q1", 3),
            NSDictionary(dictionary: ["not": notPayload]),
        ])
        XCTAssertFalse(evaluateSingleLogicPair("and", andPayload, task))
    }

    func testOrContainingNotWhereBothFail() {
        // or(not(q1==3), q2==7) — q1=3 so not is false, q2=0 so q2==7 is false → or fails
        let task = makeTask(["q1": [3], "q2": [0]])
        let notPayload = NSDictionary(dictionary: ["==": numericPayload("q1", 3)])
        let orPayload = NSArray(array: [
            NSDictionary(dictionary: ["not": notPayload]),
            entry("==", "q2", 7),
        ])
        XCTAssertFalse(evaluateSingleLogicPair("or", orPayload, task))
    }

}
