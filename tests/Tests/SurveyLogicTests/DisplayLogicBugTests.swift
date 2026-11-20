import XCTest
@testable import SurveyQuestionDisplayLogic

// MARK: helpers

/// a task where q1 was answered with this choice
private func choiceTask(answer: NSNumber) -> TaskRes {
    return TaskRes(stepResults: ["q1": StepRes(results: [ChoiceRes(choiceAnswers: [answer])])])
}

/// display logic `{op: ["q1", value]}` against q1 answered with `answer`
private func evaluateComparison(_ op: String, _ value: AnyObject, answer: NSNumber) throws -> Bool {
    return try evaluateSingleLogicPair(op, ["q1" as NSString, value] as NSArray, choiceTask(answer: answer))
}

/// pins current behavior, bugs included. inputs are in Fixtures/*.json
class DisplayLogicBugTests: UnbufferedTestCase {

    private func taskResult(for c: [String: Any]) -> ORKTaskResult {
        let answer = c["answer"]!
        let result: ORKResult
        switch c["kind"] as! String {
        case "choice": result = ChoiceRes(choiceAnswers: answer as! [NSNumber])
        case "scale": result = ScaleRes(scaleAnswer: answer as? NSNumber)
        case "numeric": result = QuestionRes(answer: answer as! String)
        default: fatalError("bad fixture kind")
        }
        return TaskRes(stepResults: ["q1": StepRes(results: [result])])
    }

    // pins BS15: decimals are truncated in choice/slider comparisons, flip when fixed
    func testDecimalTruncation_currentBehavior_BS15() {
        let fixture = loadFixture("display_logic_decimal_truncation") as! [String: Any]
        let cases = fixture["cases"] as! [[String: Any]]
        XCTAssertEqual(cases.count, 12)
        for c in cases {
            let got = numeric_logic(c["op"] as! String, "q1", c["compare"] as! NSNumber, taskResult(for: c))
            XCTAssertEqual(got, c["expected_today"] as! Bool, c["name"] as! String)
        }
    }

    // same cases via evaluateSingleLogicPair
    // pins BS15: decimals are truncated in choice/slider comparisons, flip when fixed
    func testDecimalTruncationViaLogicPair_currentBehavior_BS15() throws {
        let cases = (loadFixture("display_logic_decimal_truncation") as! [String: Any])["cases"] as! [[String: Any]]
        for c in cases {
            let payload: [AnyObject] = ["q1" as NSString, c["compare"] as! NSNumber]
            let got = try evaluateSingleLogicPair(c["op"] as! String, payload as NSArray, taskResult(for: c))
            XCTAssertEqual(got, c["expected_today"] as! Bool, c["name"] as! String)
        }
    }
}

/// Android coerces numeric strings in display-logic payloads (getInt/getDouble); non-numeric strings error.
class StringComparisonValueTests: UnbufferedTestCase {

    // BS23: iOS ignored "3" and always showed the question; Android compares it like 3
    func testNumericStringComparisonValueMatchesNumber() throws {
        for op in ["==", "!=", "<", "<=", ">", ">="] {
            for answer in [2, 3, 4] as [NSNumber] {
                AssertEqual(try evaluateComparison(op, "3" as NSString, answer: answer),
                            try evaluateComparison(op, 3 as NSNumber, answer: answer), "\(op) \(answer)")
            }
        }
    }

    // double-encoded survey content can leave quote characters in the value; they are stripped before parsing
    func testQuotedNumericStringComparisonValueMatchesNumber() throws {
        for value in ["\"3\"", "'3'", " \" 3 \" ", "\"3.0\""] {
            for answer in [2, 3, 4] as [NSNumber] {
                AssertEqual(try evaluateComparison("==", value as NSString, answer: answer),
                            try evaluateComparison("==", 3 as NSNumber, answer: answer), "\(value) \(answer)")
            }
        }
        AssertThrowsError(try evaluateComparison("==", "\"abc\"" as NSString, answer: 3))
        AssertThrowsError(try evaluateComparison("==", "\"\"" as NSString, answer: 3))
    }

    // a decimal string must follow the same rule as a decimal number: choice answers compare as ints, 3.5 -> 3 (BS15)
    func testDecimalStringComparisonValueTruncatesLikeNumber() throws {
        AssertTrue(try evaluateComparison("==", "3.5" as NSString, answer: 3))
    }

    // a non-numeric value errors like on Android, so the caller falls back to showing the question
    func testNonNumericStringComparisonValueThrows() {
        AssertThrowsError(try evaluateComparison("==", "abc" as NSString, answer: 3))
    }
}
