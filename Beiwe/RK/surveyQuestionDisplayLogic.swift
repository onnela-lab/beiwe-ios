/**
 This file contains testable code for the logic for question display in a survey.
 */
import Foundation

// can't import these....
fileprivate let DOUBLE = "double"
fileprivate let INT = "int"


let printQuestionLogic_enabled = false
public func printQuestionLogic(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    if printQuestionLogic_enabled {
        print(items, separator: separator, terminator: terminator)
    }
}


/// Malformed display logic; the caller shows the question rather than crashing (same as Android).
public struct DisplayLogicError: Error, CustomStringConvertible {
    public let description: String
    init(_ description: String) { self.description = description }
}


/// Top-level entry point. Malformed logic anywhere in the tree shows the question and ignores all of it.
public func shouldQuestionDisplay(_ displayIf: [String: AnyObject], _ taskResult: ORKTaskResult, onError: ((DisplayLogicError) -> Void)? = nil) -> Bool {
    if displayIf.isEmpty {
        return true
    }
    do {
        guard displayIf.count == 1, let key = displayIf.keys.first, let value = displayIf.values.first else {
            throw DisplayLogicError("Encountered invalid size of outermost displayIf dictionary: \(displayIf.count)")
        }
        return try evaluateSingleLogicPair(key, value, taskResult)
    } catch let error as DisplayLogicError {
        onError?(error)
        return true
    } catch {
        return true // unreachable, only DisplayLogicError is thrown
    }
}


/// The negation code is very verbose for the error messages, it gets its own function.
func dispatch_negation(_ payload: AnyObject, _ taskResult: ORKTaskResult) throws -> Bool {
    
    printQuestionLogic("\tdispatch_negation: payload: \(payload), taskResult: \(taskResult)")
    
    // for these operators the payload will be a list of other logic pairs, assert that the
    // class is as expected
    guard let payload_dict = payload as? NSDictionary else {
        throw DisplayLogicError("Encountered invalid type of payload dict: \(String(describing: payload.classForCoder))")
    }
    // assert that these values are not nil (might have redundant checks here, don't care.)
    if payload_dict.allKeys.first == nil || payload_dict.allValues.first == nil {
        throw DisplayLogicError("Encountered invalid contents of a payload dict: \(String(describing: payload.classForCoder)), key 1:\(String(describing: payload_dict.allKeys.first)), value 1:\(String(describing: payload_dict.allValues.first))")
    }
    guard let first_key = payload_dict.allKeys.first as? String else {
        throw DisplayLogicError("bad first key \(String(describing: payload_dict.allKeys.first))")
    }
    // guard let first_value = payload_dict.allValues.first as? NSArray else {
    //     fatalError("bad first value \(payload_dict.allValues.first)")
    // }
    
    let first_value: AnyObject
    if let v = payload_dict.allValues.first as? NSArray {
        first_value = v as AnyObject
    } else if let v = payload_dict.allValues.first as? NSDictionary {
        first_value = v
    }
    else {
        throw DisplayLogicError("bad first value \(String(describing: payload_dict.allValues.first))")
    }
    
    // paylaod is a list of length 1
    if payload_dict.count != 1 {
        throw DisplayLogicError("Encountered invalid size of payload_dict for inversion: \(payload_dict.count)")
    }
    return try !evaluateSingleLogicPair(first_key, first_value, taskResult)
}


/// `and` and `or` are very fiddly and have error messages, they get their own function.
func dispatch_and_or(_ operation: String, _ payload: AnyObject, _ taskResult: ORKTaskResult) throws -> Bool {
    
    printQuestionLogic("\tdispatch_and_or - operation: `\(operation)`")
    
    // its an array of any number of NSDictionaries
    guard let payload_list = payload as? NSArray else {
        throw DisplayLogicError("Encountered invalid type 1 of payload dict: \(String(describing: payload.classForCoder)), \(payload)")
    }
    
    // validate the list of dicts and throw useful errors
    for dict in payload_list {
        if let dict = dict as? NSDictionary {
            if let _ = dict.allKeys.first as? String {} else {
                throw DisplayLogicError("Encountered invalid type 2 in payload_list for and/or: \(String(describing: (dict.allKeys.first as AnyObject).classForCoder))")
            }
            if let _ = dict.allValues.first as? NSDictionary {
                // this path executes when there is a NOT inside an AND
                
            } else if let _ = dict.allValues.first as? NSArray {} else {
                throw DisplayLogicError("Encountered invalid type 3 in payload_list for and/or: \(String(describing: (dict.allValues.first as AnyObject).classForCoder))")
            }
        } else {
            throw DisplayLogicError("Encountered invalid type 4 in payload_list for and/or: \(String(describing: (dict as AnyObject).classForCoder))")
        }
    }
    
    // evaluate every child before combining (no short-circuit) so bad logic anywhere throws, like Android
    var results = [Bool]()
    for dict in payload_list {
        if let dict = dict as? NSDictionary {
            let key = dict.allKeys.first as! String // validated above
            if let an_array = dict.allValues.first as? NSArray {
                results.append(try evaluateSingleLogicPair(key, an_array, taskResult))
            } else if let an_dict = dict.allValues.first as? NSDictionary {
                results.append(try evaluateSingleLogicPair(key, an_dict, taskResult))
            }
        }
    }
    if operation == "or" {
        return results.contains(true)
    }
    if operation == "and" {
        return !results.contains(false)
    }
    
    throw DisplayLogicError("unknown operation '\(operation)' inside and/or -- really should be unreachable")
}



/// Takes our logical and data primitive and calls the appropriate logic evaluation function.
/// A logic pair is one logic operation as a string, and one payload.
public func evaluateSingleLogicPair(_ operation: String, _ payload: AnyObject, _ taskResult: ORKTaskResult) throws -> Bool {
    printQuestionLogic("\tevaluateSingleLogicPair start - operation: `\(operation)`")
    
    if operation == "not" {
        return try dispatch_negation(payload, taskResult)
    }
    
    if ["or", "and"].contains(operation) {
        return try dispatch_and_or(operation, payload, taskResult)
    }
    
    // numerical oporation dispatch with USEFUL ERROR MESSAGES.
    if ["==", "!=", "<", "<=", ">", ">="].contains(operation) {
        // payload in this case is a list of  two elements, a string (question id) and a numeric value
        guard let payload_list = payload as? [AnyObject] else {
            throw DisplayLogicError("Encountered invalid type for payload list: \(String(describing: payload.classForCoder))")
        }
        guard payload_list.count == 2 else {
            throw DisplayLogicError("Encountered invalid size of payload list: \(payload_list.count), \(payload_list)")
        }
        guard let target = payload_list[0] as? String else {
            throw DisplayLogicError("Encountered invalid type for questiion id target: \(String(describing: payload_list[0].classForCoder))")
        }
        guard let compare_me = payload_list[1] as? NSNumber else {
            throw DisplayLogicError("Encountered invalid type for comparison value: \(String(describing: payload_list[1].classForCoder))")
        }
        return numeric_logic(operation, target, compare_me, taskResult)
    }
    
    // unknown operator
    throw DisplayLogicError("Encountered invalid operation: \(operation)")
}



/// extracts the answer value to a given question result, indicates via a string the type of
/// logical evaluation required.
public func extractAnswer(_ stepResult: ORKStepResult) -> ([NSNumber], String) {
    // there were no answers to the question, numerical type is irrelevant
    guard let results = stepResult.results else {
        // printQuestionLogic("\tno results, returning empty - \(stepResult.results)")
        return ([NSNumber](), DOUBLE)
    }
    
    if results.count == 0 {
        // printQuestionLogic("\t\t results count is 0?")
        return ([NSNumber](), DOUBLE)
    }
    
    // I think results[0] is sufficient because we only ever have single answers to questions.
    switch results[0] {
    case let choiceResult as ORKChoiceQuestionResult:
        // printQuestionLogic("\tcase - choiceResult")
        // choice (radio button and checkbox) questions
        return do_choice_logic(choiceResult)
        
    case let scaleResult as ORKScaleQuestionResult:
        // printQuestionLogic("\tcase - scaleResult")
        // don't know what uses this.....
        if let answer: NSNumber = scaleResult.scaleAnswer {
            return ([answer], INT)
        }
        return ([NSNumber](), INT)
        
    case let questionResult as ORKQuestionResult:  // questionResult is the superclass so has to go under the more specific subclasses
        // printQuestionLogic("\tcase - questionResult")
        // numerical open response questions can provide floating-point answers, so need doubles
        if let answer = questionResult.answer {
            // this magically converts only valid numerical strings - apparently
            // '.' gets interpreted as zero, fine.
            if let number = Double(String(describing: answer)) {
                return ([number as NSNumber], DOUBLE)
            }
            return ([NSNumber](), DOUBLE)
        }
        // questionResult.answer was null, can happen on numeric open response
        return ([NSNumber](), DOUBLE)
        
    default:
        fatalError("invalid step result type: \(results[0].classForCoder)")
    }
}


/// choice question logic (radio buttons and checkboxes) operates on the selected answer number, rather
/// than the value of the answer itself. They are slightly more cumbersome so have their own function.
/// Choice question answers should be interpreted as ints.  return is like ([1,2], "int")
/// These are indices, they are zero indexed
public func do_choice_logic(_ choiceResult: ORKChoiceQuestionResult) -> ([NSNumber], String) {
    // printQuestionLogic("\t=== do_choice_stuff ===")
    guard let choiceAnswers = choiceResult.choiceAnswers else {
        return ([NSNumber](), INT)  // ([], "int")
    }
    
    var selected_answers = [NSNumber]()
    for choiceAnswer in choiceAnswers {
        if let num: NSNumber = choiceAnswer as? NSNumber {
            selected_answers.append(num)
        }
    }
    printQuestionLogic("\tdo_choice_stuff - selected_answers:", selected_answers)
    
    let x = (selected_answers, INT)
    printQuestionLogic("\tdo_choice_stuff - final return: \(x)")
    return x
}


/// takes a numerical operation, a target question, and a comparitor (and the blob of data to
/// extract the question's answer from), it extracts everything, dispatches the correct
/// comparitor, and returns a boolean of the comparison result.  If it cannot find the target
/// question's answer, it returns false.
public func numeric_logic(_ operation: String, _ target: String, _ compare_me: NSNumber, _ taskResult: ORKTaskResult) -> Bool {
    
    let answer_numbers: [NSNumber]
    let comparison_primitive_type: String
    // if it isn't any of the operators try it as the question id
    if let targetAnswer: ORKStepResult = taskResult.stepResult(forStepIdentifier: target) {
        (answer_numbers, comparison_primitive_type) = extractAnswer(targetAnswer)
        printQuestionLogic("\tnumeric logic - extracted answer for `\(target)`: `\(answer_numbers)`")
    } else {
        printQuestionLogic("\tnumeric logic - couldn't find a step result for `\(target)`, returning false")
        // When there was no answer at all it means it is an unanswered question. The question
        // is unanswered, it cannot satisfy any numeric condition.
        return false // bug - this was set to return true - must be false.
    }
    
    if comparison_primitive_type == DOUBLE {
        return double_comparisons(operation, compare_me.doubleValue, answer_numbers)
    } else if comparison_primitive_type == INT {
        return int_comparisons(operation, compare_me.intValue, answer_numbers)
    } else {
        fatalError("Encountered invalid comparison_primitive_type: \(comparison_primitive_type)")
    }
}


/// some of our data types need to be compared as doubles, others as integers. These functions do the correct operator comparisons.
/// All our answer outputs are contained as (potentially empty) lists of NSNumbers, so conversion is fairly easy.
/// Comparisons return true if there are Any matches - this is to allow Checkbox questions to have comprehensible behavior with
///   multiselections, and has no effect on other question types.
public func double_comparisons(_ operation: String, _ compare_me: Double, _ numbers: [NSNumber]) -> Bool {
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
    } else if operation == "!=" {
        // "not in" for multiselect; unanswered stays false
        return !answer_numbers.isEmpty && !answer_numbers.contains(compare_me)
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
public func int_comparisons(_ operation: String, _ compare_me: Int, _ numbers: [NSNumber]) -> Bool {
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
    } else if operation == "!=" {
        // "not in" for multiselect; unanswered stays false
        return !answer_numbers.isEmpty && !answer_numbers.contains(compare_me)
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
