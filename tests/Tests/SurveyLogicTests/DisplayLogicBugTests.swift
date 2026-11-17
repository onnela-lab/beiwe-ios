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
