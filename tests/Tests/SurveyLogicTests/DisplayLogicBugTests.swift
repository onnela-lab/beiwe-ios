import XCTest
@testable import SurveyQuestionDisplayLogic

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
    private func task(choice: NSNumber) -> TaskRes {
        TaskRes(stepResults: ["q1": StepRes(results: [ChoiceRes(choiceAnswers: [choice])])])
    }

    private func eval(_ op: String, _ value: AnyObject, answer: NSNumber) throws -> Bool {
        try evaluateSingleLogicPair(op, ["q1" as NSString, value] as NSArray, task(choice: answer))
    }

    func testNumericStringBehavesLikeNumber() throws {
        for op in ["==", "!=", "<", "<=", ">", ">="] {
            for answer in [2, 3, 4] as [NSNumber] {
                XCTAssertEqual(try eval(op, "3" as NSString, answer: answer), try eval(op, 3 as NSNumber, answer: answer), "\(op) \(answer)")
            }
        }
    }

    func testDecimalStringParses() throws {
        // choice answers compare as ints, so 3.5 truncates to 3
        XCTAssertTrue(try eval("==", "3.5" as NSString, answer: 3))
    }

    func testNonNumericStringThrows() {
        XCTAssertThrowsError(try eval("==", "abc" as NSString, answer: 3))
    }
}
