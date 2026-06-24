import Foundation

public class ORKResult: NSObject {
}

public class ORKStepResult: ORKResult {
    public var results: [ORKResult]?
    
    public init(results: [ORKResult]?) {
        self.results = results
    }
}

public class ORKQuestionResult: ORKResult {
    public var answer: Any?
    
    public init(answer: Any?) {
        self.answer = answer
    }
}

public class ORKChoiceQuestionResult: ORKQuestionResult {
    public var choiceAnswers: [Any]?
    
    public init(choiceAnswers: [Any]?) {
        self.choiceAnswers = choiceAnswers
        super.init(answer: nil)
    }
    public init(choiceAnswers: [Any]?, answer: Any?) {
        self.choiceAnswers = choiceAnswers
        super.init(answer: answer)
    }
}

public class ORKScaleQuestionResult: ORKQuestionResult {
    public var scaleAnswer: NSNumber?
    
    // public override init() {}
    public init(scaleAnswer: NSNumber?) {
        self.scaleAnswer = scaleAnswer
        super.init(answer: nil)
    }
    public init(scaleAnswer: NSNumber?, answer: Any?) {
        self.scaleAnswer = scaleAnswer
        super.init(answer: answer)
    }
}

public class ORKTaskResult: ORKResult {
    var _stepResults: [String: ORKStepResult] = [:]

    public init(stepResults: [String: ORKStepResult]) {
        self._stepResults = stepResults
    }

    public func stepResult(forStepIdentifier identifier: String) -> ORKStepResult? {
        return _stepResults[identifier]
    }

    public func addStepResult(_ result: ORKStepResult, forIdentifier identifier: String) {
        _stepResults[identifier] = result
    }
}
