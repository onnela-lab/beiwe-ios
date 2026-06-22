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

let printQuestionLogic_enabled = false
public func printQuestionLogic(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    if printQuestionLogic_enabled {
        print(items, separator: separator, terminator: terminator)
    }
}


/// Skip logic
class BWSkipStepNavigationRule: ORKSkipStepNavigationRule {
    let DOUBLE = "double"
    let INT = "int"
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
        let x = !self.evaluateSingleLogicPair(self.displayIf.keys.first!, self.displayIf.values.first!, taskResult)
        printQuestionLogic("stepShouldSkip - returning `\(x)`")
        return x
    }
    
    /// The negation code is very verbose for the error messages, it gets its own function.
    func dispatch_negation(_ payload: AnyObject, _ taskResult: ORKTaskResult) -> Bool {
        
        printQuestionLogic("\tdispatch_negation: payload: \(payload), taskResult: \(taskResult)")
        
        // for these operators the payload will be a list of other logic pairs, assert that the
        // class is as expected
        guard let payload_dict = payload as? NSDictionary else {
            fatalError("Encountered invalid type of payload dict: \(payload.classForCoder)")
        }
        // assert that these values are not nil (might have redundant checks here, don't care.)
        if payload_dict.allKeys.first == nil || payload_dict.allValues.first == nil {
            fatalError("Encountered invalid contents of a payload dict: \(payload.classForCoder), key 1:\(payload_dict.allKeys.first), value 1:\(payload_dict.allValues.first)")
        }
        guard let first_key = payload_dict.allKeys.first as? String else {
            fatalError("bad first key \(payload_dict.allKeys.first)")
        }
        guard let first_value = payload_dict.allValues.first as? NSArray else {
            fatalError("bad first value \(payload_dict.allValues.first)")
        }
        // paylaod is a list of length 1
        if payload_dict.count != 1 {
            fatalError("Encountered invalid size of payload_dict for inversion: \(payload_dict.count)")
        }
        return !self.evaluateSingleLogicPair(first_key, first_value, taskResult)
    }
    
    /// `and` and `or` are very fiddly due to error messages, they get their own function.
    func dispatch_and_or(_ operation: String, _ payload: AnyObject, _ taskResult: ORKTaskResult) -> Bool {
        
        printQuestionLogic("\tdispatch_and_or - operation: `\(operation)`")
        
        // its an array of any number of NSDictionaries
        guard let payload_list = payload as? NSArray else {
            fatalError("Encountered invalid type of payload dict: \(payload.classForCoder), \(payload)")
        }
        
        // validate the list of dicts and throw useful errors
        for dict in payload_list {
            if let dict = dict as? NSDictionary {
                if let _ = dict.allKeys.first as? String {} else {
                    fatalError("Encountered invalid type in payload_list for and/or: \((dict.allKeys.first as AnyObject).classForCoder)")
                }
                if let _ = dict.allValues.first as? NSArray {} else {
                    fatalError("Encountered invalid type in payload_list for and/or: \((dict.allValues.first as AnyObject).classForCoder)")
                }
            } else {
                fatalError("Encountered invalid type in payload_list for and/or: \((dict as AnyObject).classForCoder)")
            }
        }
        
        // 'and' and 'or' should work fine on any size payload_list - and the NSDictionary cast has
        // already been tested above so we don't need to catch it.
        if operation == "or" {
            for dict in payload_list {
                if let dict = dict as? NSDictionary {
                    if self.evaluateSingleLogicPair(dict.allKeys.first as! String, dict.allValues.first as! NSArray, taskResult) {
                        return true
                    }
                }
            }
            return false // only after everything has returned false do we return false
        }
        
        if operation == "and" {
            // if there are any falses return false, otherwise return true
            for dict in payload_list {
                if let dict = dict as? NSDictionary {
                    if !self.evaluateSingleLogicPair(dict.allKeys.first as! String, dict.allValues.first as! NSArray, taskResult) {
                        return false
                    }
                }
            }
            return true // nothing failed, so it passed!
        }
        
        fatalError("unknown operation '\(operation)' inside and/or -- really should be unreachable")
    }
    
    /// consumes
    func evaluateSingleLogicPair(_ operation: String, _ payload: AnyObject, _ taskResult: ORKTaskResult) -> Bool {
        printQuestionLogic("\tevaluateSingleLogicPair start - operation: `\(operation)`")
        
        if operation == "not" {
            return dispatch_negation(payload, taskResult)
        }
        
        if ["or", "and"].contains(operation) {
            return dispatch_and_or(operation, payload, taskResult)
        }
        
        // numerical oporation dispatch with USEFUL ERROR MESSAGES.
        if ["==", "<", "<=", ">", ">="].contains(operation) {
            // payload in this case is a list of  two elements, a string (question id) and a numeric value
            guard let payload_list = payload as? [AnyObject] else {
                fatalError("Encountered invalid type for payload list: \(payload.classForCoder)")
            }
            guard payload_list.count == 2 else {
                fatalError("Encountered invalid size of payload list: \(payload_list.count), \(payload_list)")
            }
            guard let target = payload_list[0] as? String else {
                fatalError("Encountered invalid type for questiion id target: \(payload_list[0].classForCoder)")
            }
            guard let compare_me = payload_list[1] as? NSNumber else {
                fatalError("Encountered invalid type for comparison value: \(payload_list[1].classForCoder)")
            }
            return self.numeric_logic(operation, target, compare_me, taskResult)
        }
        
        // should be unreachable
        fatalError("Encountered invalid operation: \(operation)")
    }
    
    /// extracts the answer value to a given question result, indicates via a string the type of
    /// logical evaluation required.
    func extractAnswer(_ stepResult: ORKStepResult) -> ([NSNumber], String) {
        // there were no answers to the question, numerical type is irrelevant
        guard let results = stepResult.results else {
            // printQuestionLogic("\tno results, returning empty - \(stepResult.results)")
            return ([NSNumber](), self.DOUBLE)
        }
        
        if results.count == 0 {
            // printQuestionLogic("\t\t results count is 0?")
            return ([NSNumber](), self.DOUBLE)
        }
        
        // I think results[0] is sufficient because we only ever have single answers to questions.
        switch results[0] {
        case let choiceResult as ORKChoiceQuestionResult:
            // printQuestionLogic("\tcase - choiceResult")
            // choice (radio button and checkbox) questions
            return self.do_choice_stuff(choiceResult)
            
        case let questionResult as ORKQuestionResult:
            // printQuestionLogic("\tcase - questionResult")
            // numerical open response questions can provide floating-point answers, so need doubles
            if let answer = questionResult.answer {
                // this magically converts only valid numerical strings - apparently
                // '.' gets interpreted as zero, fine.
                if let number = Double(String(describing: answer)) {
                    return ([number as NSNumber], self.DOUBLE)
                }
                return ([NSNumber](), self.DOUBLE)
            }
            // questionResult.answer was null, can happen on numeric open response
            return ([NSNumber](), self.DOUBLE)
            
        case let scaleResult as ORKScaleQuestionResult:
            // printQuestionLogic("\tcase - scaleResult")
            // don't know what uses this.....
            if let answer: NSNumber = scaleResult.scaleAnswer {
                return ([answer], self.INT)
            }
            return ([NSNumber](), self.INT)
            
        default:
            fatalError("invalid step result type: \(results[0].classForCoder)")
        }
        // um, unreachable?
        // fatalError("unreachable code in extractAnswer \(results)")
    }
    
    /// choice question logic (radio buttons and checkboxes) operates on the selected answer number, rather
    /// than the value of the answer itself. They are slightly more cumbersome so have their own function.
    /// Choice question answers should be interpreted as ints.  return is like ([1,2], "int")
    /// These are indices, they are zero indexed
    func do_choice_stuff(_ choiceResult: ORKChoiceQuestionResult) -> ([NSNumber], String) {
        // printQuestionLogic("\t=== do_choice_stuff ===")
        guard let choiceAnswers = choiceResult.choiceAnswers else {
            return ([NSNumber](), self.INT)  // ([], "int")
        }
        
        var selected_answers = [NSNumber]()
        for choiceAnswer in choiceAnswers {
            if let num: NSNumber = choiceAnswer as? NSNumber {
                selected_answers.append(num)
            }
        }
        printQuestionLogic("\tdo_choice_stuff - selected_answers:", selected_answers)
        
        let x = (selected_answers, self.INT)
        printQuestionLogic("\tdo_choice_stuff - final return: \(x)")
        return x
    }
    
    /// takes a numerical operation, a target question, and a comparitor (and the blob of data to
    /// extract the question's answer from), it extracts everything, dispatches the correct
    /// comparitor, and returns a boolean of the comparison result.  If it cannot find the target
    /// question's answer, it returns false.
    func numeric_logic(_ operation: String, _ target: String, _ compare_me: NSNumber, _ taskResult: ORKTaskResult) -> Bool {
        
        let answer_numbers: [NSNumber]
        let comparison_primitive_type: String
        // if it isn't any of the operators try it as the question id
        if let targetAnswer: ORKStepResult = taskResult.stepResult(forStepIdentifier: target) {
            (answer_numbers, comparison_primitive_type) = self.extractAnswer(targetAnswer)
            printQuestionLogic("\tnumeric logic - extracted answer for `\(target)`: `\(answer_numbers)`")
        } else {
            printQuestionLogic("\tnumeric logic - couldn't find a step result for `\(target)`, returning false")
            // When there was no answer at all it means it is an unanswered question. The question
            // is unanswered, it cannot satisfy any numeric condition.
            return false // bug - this was set to return true - must be false.
        }
        
        if comparison_primitive_type == self.DOUBLE {
            return self.double_comparisons(operation, compare_me.doubleValue, answer_numbers)
        } else if comparison_primitive_type == self.INT {
            return self.int_comparisons(operation, compare_me.intValue, answer_numbers)
        } else {
            fatalError("Encountered invalid comparison_primitive_type: \(comparison_primitive_type)")
        }
    }
    
    /// some of our data types need to be compared as doubles, others as integers. These functions do the correct operator comparisons.
    /// All our answer outputs are contained as (potentially empty) lists of NSNumbers, so conversion is fairly easy.
    /// Comparisons return true if there are Any matches - this is to allow Checkbox questions to have comprehensible behavior with
    ///   multiselections, and has no effect on other question types.
    func double_comparisons(_ operation: String, _ compare_me: Double, _ numbers: [NSNumber]) -> Bool {
        var answer_numbers = [Double]()
        for num in numbers {
            answer_numbers.append(num.doubleValue)
        }
        printQuestionLogic("\tdouble - operator: \(operation), compare value: \(compare_me), answer values: \(answer_numbers)")
        
        if operation == "==" {
            for num in answer_numbers {
                if num == compare_me {
                    printQuestionLogic("\tdouble `\(num)` == `\(compare_me)` returned true")
                    return true
                }
            }
        } else if operation == "<" {
            for num in answer_numbers {
                if num < compare_me {
                    printQuestionLogic("\tdouble `\(num)` < `\(compare_me)` returned true")
                    return true
                }
            }
        } else if operation == "<=" {
            for num in answer_numbers {
                if num <= compare_me {
                    printQuestionLogic("\tdouble `\(num)` <= `\(compare_me)` returned true")
                    return true
                }
            }
        } else if operation == ">" {
            for num in answer_numbers {
                if num > compare_me {
                    printQuestionLogic("\tdouble `\(num)` > `\(compare_me)` returned true")
                    return true
                }
            }
        } else if operation == ">=" {
            for num in answer_numbers {
                if num >= compare_me {
                    printQuestionLogic("\tdouble `\(num)` >= `\(compare_me)` returned true")
                    return true
                }
            }
        }
        printQuestionLogic("\tdouble returned false")
        return false
    }
    
    /// see double_comparisons
    func int_comparisons(_ operation: String, _ compare_me: Int, _ numbers: [NSNumber]) -> Bool {
        var answer_numbers = [Int]()
        for num in numbers {
            answer_numbers.append(num.intValue)
        }
        printQuestionLogic("\tint - operator: \(operation), compare value: \(compare_me), answer values: \(answer_numbers)")
        
        if operation == "==" {
            for num in answer_numbers {
                printQuestionLogic("\tif \(num) == \(compare_me)")
                if num == compare_me {
                    printQuestionLogic("\tint compare return true")
                    return true
                }
            }
        } else if operation == "<" {
            for num in answer_numbers {
                printQuestionLogic("\tif \(num) < \(compare_me)")
                if num < compare_me {
                    printQuestionLogic("\tint compare return true")
                    return true
                }
            }
        } else if operation == "<=" {
            for num in answer_numbers {
                printQuestionLogic("\tif \(num) <= \(compare_me)")
                if num <= compare_me {
                    printQuestionLogic("\tint compare return true")
                    return true
                }
            }
        } else if operation == ">" {
            for num in answer_numbers {
                printQuestionLogic("\tif \(num) > \(compare_me)")
                if num > compare_me {
                    printQuestionLogic("\tint compare return true")
                    return true
                }
            }
        } else if operation == ">=" {
            for num in answer_numbers {
                printQuestionLogic("\tif \(num) >= \(compare_me)")
                if num >= compare_me {
                    printQuestionLogic("\tint compare return true")
                    return true
                }
            }
        }
        printQuestionLogic("\tint compare return false")
        return false
    }
}
