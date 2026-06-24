import Foundation

/**
 This file was an unholy mess of absolute crap. It implemented 3 classes, had a dictionary lookup
 mapped to a set of unreadable closures that depended on two of those classes. The original dev
 clearly gave up and worked out a clever hack to reusing his code by wrapping everything in an extra
 "and" evaluation instead of making a clear entry point.
 
 Oh and the closure dict was dynamically generated at runtime. ...
 
 This code runs whenever:
 - the initial survey card pops up (init)
 - an answer to any question is updated or cleared
 - the next, cancel, or skip buttons are pressed.
 - and SOMETIMES IT JUST RUNS IN THE BACKGROUND FOR NO REASON (this is a bug, at time of documenting I don't know where or why)

 When this code runs it runs for ALL QUESTIONS IN THE CURRENT SURVEY.
 SO.
 DO. NOT. try to condense this file.
 INDENT print statements in this file in order to distinguish them.
 DISABLE the print logic flag below after you are done debugging.
 
 */



/// Skip logic
class BWSkipStepNavigationRule: ORKSkipStepNavigationRule {
    let DOUBLE = "double" // must be equal to DOUBEL in surveyQuestionDisplayLogic
    let INT = "int" // must be equal to INT in surveyQuestionDisplayLogic
    var displayIf: [String: AnyObject] = [:] // it gets reassigned
    
    // convenience init with the nscoder populated - I don't know what its for but it was here before me.
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // convenience init with displayIf populated
    convenience init(displayIf: [String: AnyObject]?) {
        self.init(coder: NSCoder())
        self.displayIf = displayIf ?? [:]
        printQuestionLogic("\tconvenience init called, \tdisplayIf: \(self.displayIf)")
    }	
    
    override func stepShouldSkip(with taskResult: ORKTaskResult) -> Bool {
        printQuestionLogic("\tstepShouldSkip time!")
        // if there is no skip logic then the question should not be skipped
        
        // printQuestionLogic("\tstepShouldSkip: taskResult: \(taskResult), displayIf: \(self.displayIf)")
        
        if self.displayIf.isEmpty {
            // printQuestionLogic("\t\nQUESTION WITHOUT SKIP LOGIC\n")
            return false
        }
        
        if self.displayIf.count != 1 {
            fatalError("Encountered invalid size of outermost displayIf dictionary: \(self.displayIf.count)")
        }
        
        // evaluate - the logic returns true if there is a match, which means we need to invert the output of the logic, lol...
        let x = !evaluateSingleLogicPair(self.displayIf.keys.first!, self.displayIf.values.first!, taskResult)
        printQuestionLogic("stepShouldSkip - returning `\(x)`")
        return x
    }
    
}
