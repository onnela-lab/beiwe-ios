import Foundation
import ObjectMapper

/// ActiveSurvey is a mappable (json-backed database object) that holds the current state of a survey
/// that the study participant is taking.
class ActiveSurvey: Mappable {
    // unused...
    // var notification: UILocalNotification?
    // var nextScheduledTime: TimeInterval = 0
    
    // the survey data
    var survey: Survey? // has to be optional because of the required init
    
    // state information
    var isComplete: Bool = false // set to true when the particiant has completed the survey
    var received: TimeInterval = 0 // time the survey was received by the app?
    var stepOrder: [Int]? // sorting for randomizing questions
    
    // the data!
    var rkAnswers: Data?  // answers for researchkit
    var bwAnswers: [String: String] = [:] // recorded answers
    
    init(survey: Survey) {
        self.survey = survey
        self.reset(survey)
    }

    required init?(map: Map) {} // required by mappable, unused

    // Mappable - ok, we have some survey state that is stored - probably in the recline database
    func mapping(map: Map) {
        // mappable json values as declared in class above
        self.isComplete <- map["is_complete"]
        self.survey <- map["survey"]
        self.received <- map["received"]
        self.rkAnswers <- (map["rk_answers"], transformNSData)
        self.bwAnswers <- map["bk_answers"]
        self.stepOrder <- map["stepOrder"]
        // unused
        // nextScheduledTime     <- map["expires"]
        // notification    <- (map["notification"], transformNotification)
    }

    // resets the survey to its original configuration
    func reset(_ survey: Survey) {
        // clear out answers
        self.rkAnswers = nil
        self.bwAnswers = [:]
        self.isComplete = false
                
        // set up the step ordering (shuffle if the steps are shuffled)
        var steps = [Int](0 ..< survey.questions.count)
        if survey.randomize {
            _ = shuffle(&steps) // (shuffle returns the list for chaining but is in-place)
        }
        // print("shuffle steps \(steps)")
        
        // if the survey is set to only display a subset of questions, determine that number of questions.
        let numQuestions = survey.randomize ? min(survey.questions.count, survey.numberOfRandomQuestions ?? 999) : survey.questions.count
        
        // randomize-with-memory logic
        if var order = stepOrder, survey.randomizeWithMemory && numQuestions > 0 {
            // We must have already asked a bunch of questions, otherwise stepOrder would be nil.  Remove them
            order.removeFirst(min(numQuestions, order.count))
            // remove all in stepOrder that are greater than count.  Could happen if questions are deleted after stepOrder already set...
            order = order.filter({ $0 < survey.questions.count })
            if order.count < numQuestions {
                order.append(contentsOf: steps)
            }
            
            // If we have a repeat in the first X steps, move it to the end and try again..
            // log.info("proposed order \(order)")
            var index: Int = numQuestions - 1
            while index > 0 {
                let val = order[index]
                if order[0 ..< index].contains(val) {
                    order.remove(at: index)
                    order.append(val)
                } else {
                    index = index - 1
                }
            }
            // update step order
            self.stepOrder = order
            // print("proposed stepOrder \(order)")
        } else {
            // case: everything else (no randomization or randomization with memory)
            self.stepOrder = steps
        }
        // print("final stepOrder \(self.stepOrder)")
    }
}
