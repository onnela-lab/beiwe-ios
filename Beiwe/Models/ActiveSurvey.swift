import Foundation
import ObjectMapper

/// ActiveSurvey is a mappable (json-backed database object) that holds the current state of a survey
/// that the study participant is taking.
class ActiveSurvey: Mappable {
    // the survey data
    var survey: Survey? // has to be optional because of the required init
    
    // state information
    var isComplete: Bool = false // set to true when the particiant has completed the survey
    var received: TimeInterval = 0 // time the survey was received by the app?
    var stepOrder: [Int]? // sorting for randomizing questions
    
    // the data!
    var rkAnswers: Data? // answers for researchkit
    var bwAnswers: [String: String] = [:] // recorded answers
    
    // The most recent relevant survey logic - never cleared once populated.
    // Create a new ActiveSurvey to clear.
    var mostRecentNotificationUUIDs: String?
    
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
        self.rkAnswers <- (map["rk_answers"], transformNSData)  // this is survey restoration data
        self.bwAnswers <- map["bk_answers"]
        self.stepOrder <- map["stepOrder"]
        
        // NOT TO BE CLEARED IN THE RESET LOGIC
        self.mostRecentNotificationUUIDs <- map["mostRecentSurveyNotificationUUID"]
    }

    // resets the survey to its original configuration
    func reset(_ survey: Survey) {
        // clear out answers
        self.rkAnswers = nil
        self.bwAnswers = [:]
        self.isComplete = false
        
        // with memory the questions are drawn when the survey is opened (questionOrderOnOpen), not when a new survey arrives
        if survey.randomize && survey.randomizeWithMemory {
            self.stepOrder = nil
            return
        }
        
        // set up the step ordering (shuffle if the steps are shuffled)
        var steps = [Int](0 ..< survey.questions.count)
        if survey.randomize {
            _ = shuffle(&steps) // (shuffle returns the list for chaining but is in-place)
        }
        self.stepOrder = steps
    }
}

/// Android's shuffleJSONArrayWithMemory on question ids: walk a shuffle, take ids not in `memory` until `count`
/// (nil/<= 0 = all unseen), record them. None unseen -> clear memory, draw again. So the last round can be short.
/// Ids, not indices, so memory survives survey edits. `shuffle(n)` is a permutation of 0..<n (injectable for tests).
func randomQuestionSelection(questionIds: [String], memory: [String], count: Int?,
                             shuffle: (Int) -> [Int]) -> (indices: [Int], memory: [String]) {
    let limit = (count ?? 0) > 0 ? count! : Int.max
    var newMemory = memory
    var seen = Set(memory)  // duplicate ids in a survey: first one wins (Android crashes)
    var indices: [Int] = []
    for i in shuffle(questionIds.count) where indices.count < limit && !seen.contains(questionIds[i]) {
        seen.insert(questionIds[i])
        newMemory.append(questionIds[i])
        indices.append(i)
    }
    if indices.isEmpty && !questionIds.isEmpty && !memory.isEmpty {
        return randomQuestionSelection(questionIds: questionIds, memory: [], count: count, shuffle: shuffle)
    }
    return (indices, newMemory)
}

/// Question order for a survey being opened. A stored order is kept so a partly answered survey resumes; with
/// memory, a new draw is recorded on the study at open (like Android's setUpQuestions), so a new survey that is never
/// opened uses nothing.
func questionOrderOnOpen(activeSurvey: ActiveSurvey, survey: Survey, study: Study?,
                         shuffle: (Int) -> [Int] = { Array(0 ..< $0).shuffled() }) -> [Int] {
    return SurveyLock.with {
        if let order = activeSurvey.stepOrder {
            return order
        }
        var order = Array(0 ..< survey.questions.count)
        if survey.randomize && survey.randomizeWithMemory {
            let memory = survey.surveyId.flatMap { study?.surveyQuestionMemory[$0] } ?? []
            let draw = randomQuestionSelection(questionIds: survey.questions.map { $0.questionId }, memory: memory,
                                               count: survey.numberOfRandomQuestions, shuffle: shuffle)
            order = draw.indices
            if let surveyId = survey.surveyId {
                study?.surveyQuestionMemory[surveyId] = draw.memory
            }
        }
        activeSurvey.stepOrder = order
        return order
    }
}

/// How many of stepOrder to show. A memory draw is already cut to size; a pre-BS7fix stored order is a full shuffle.
func displayedQuestionCount(survey: Survey, stepOrder: [Int]) -> Int {
    if survey.randomize && survey.randomizeWithMemory {
        let n = survey.numberOfRandomQuestions ?? 0
        return n > 0 ? min(stepOrder.count, n) : stepOrder.count
    }
    return survey.randomize ? min(survey.questions.count, survey.numberOfRandomQuestions ?? 999) : survey.questions.count
}
