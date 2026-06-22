import Foundation
import ObjectMapper
import ResearchKit

// example survey for testing - line too long, may break syntax highliting
///let contentJson = "{\"content\":[{\"answers\":[{\"text\":\"Never\"},{\"text\":\"Rarely\"},{\"text\":\"Occasionally\"},{\"text\":\"Frequently\"},{\"text\":\"Almost Constantly\"}],\"question_id\":\"6695d6c4-916b-4225-8688-89b6089a24d1\",\"question_text\":\"In the last 7 days, how OFTEN did you EAT BROCCOLI?\",\"question_type\":\"radio_button\"},{\"answers\":[{\"text\":\"None\"},{\"text\":\"Mild\"},{\"text\":\"Moderate\"},{\"text\":\"Severe\"},{\"text\":\"Very Severe\"}],\"display_if\":{\">\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",0]},\"question_id\":\"41d54793-dc4d-48d9-f370-4329a7bc6960\",\"question_text\":\"In the last 7 days, what was the SEVERITY of your CRAVING FOR BROCCOLI?\",\"question_type\":\"radio_button\"},{\"answers\":[{\"text\":\"Not at all\"},{\"text\":\"A little bit\"},{\"text\":\"Somewhat\"},{\"text\":\"Quite a bit\"},{\"text\":\"Very much\"}],\"display_if\":{\"and\":[{\">\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",0]},{\">\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",0]}]},\"question_id\":\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",\"question_text\":\"In the last 7 days, how much did your CRAVING FOR BROCCOLI INTERFERE with your usual or daily activities, (e.g. eating cauliflower)?\",\"question_type\":\"radio_button\"},{\"display_if\":{\"or\":[{\"and\":[{\"<=\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",3]},{\"==\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",2]},{\"<\":[\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",3]}]},{\"and\":[{\"<=\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",3]},{\"<\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",3]},{\"==\":[\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",2]}]},{\"and\":[{\"==\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",4]},{\"<=\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",1]},{\"<=\":[\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",1]}]}]},\"question_id\":\"9d7f737d-ef55-4231-e901-b3b68ca74190\",\"question_text\":\"While broccoli is a nutritious and healthful food, it's important to recognize that craving too much broccoli can have adverse consequences on your health.  If in a single day you find yourself eating broccoli steamed, stir-fried, and raw with a 'vegetable dip', you may be a broccoli addict.\\u000a\\u000aThis is an additional paragraph (following a double newline) warning you about the dangers of broccoli consumption.\",\"question_type\":\"info_text_box\"},{\"display_if\":{\"or\":[{\"and\":[{\"==\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",4]},{\"or\":[{\">=\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",2]},{\">=\":[\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",2]}]}]},{\"or\":[{\">=\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",3]},{\">=\":[\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",3]}]}]},\"question_id\":\"59f05c45-df67-40ed-a299-8796118ad173\",\"question_text\":\"OK, it sounds like your broccoli habit is getting out of hand.  Please call your clinician immediately.\",\"question_type\":\"info_text_box\"},{\"question_id\":\"9745551b-a0f8-4eec-9205-9e0154637513\",\"question_text\":\"How many pounds of broccoli per day could a woodchuck chuck if a woodchuck could chuck broccoli?\",\"question_type\":\"free_response\",\"text_field_type\":\"NUMERIC\"},{\"display_if\":{\"<\":[\"9745551b-a0f8-4eec-9205-9e0154637513\",10]},\"question_id\":\"cedef218-e1ec-46d3-d8be-e30cb0b2d3aa\",\"question_text\":\"That seems a little low.\",\"question_type\":\"info_text_box\"},{\"display_if\":{\"==\":[\"9745551b-a0f8-4eec-9205-9e0154637513\",10]},\"question_id\":\"64a2a19b-c3d0-4d6e-9c0d-06089fd00424\",\"question_text\":\"That sounds about right.\",\"question_type\":\"info_text_box\"},{\"display_if\":{\">\":[\"9745551b-a0f8-4eec-9205-9e0154637513\",10]},\"question_id\":\"166d74ea-af32-487c-96d6-da8d63cfd368\",\"question_text\":\"What?! No way- that's way too high!\",\"question_type\":\"info_text_box\"},{\"max\":\"5\",\"min\":\"1\",\"question_id\":\"059e2f4a-562a-498e-d5f3-f59a2b2a5a5b\",\"question_text\":\"On a scale of 1 (awful) to 5 (delicious) stars, how would you rate your dinner at Chez Broccoli Restaurant?\",\"question_type\":\"slider\"},{\"display_if\":{\">=\":[\"059e2f4a-562a-498e-d5f3-f59a2b2a5a5b\",4]},\"question_id\":\"6dd9b20b-9dfc-4ec9-cd29-1b82b330b463\",\"question_text\":\"Wow, you are a true broccoli fan.\",\"question_type\":\"info_text_box\"},{\"question_id\":\"ec0173c9-ac8d-449d-d11d-1d8e596b4ec9\",\"question_text\":\"THE END. This survey is over.\",\"question_type\":\"info_text_box\"}],\"settings\":{\"number_of_random_questions\":null,\"randomize\":false,\"randomize_with_memory\":false,\"trigger_on_first_download\":false},\"survey_type\":\"tracking_survey\",\"timings\":[[],[67500],[],[],[],[],[]]}"


let NO_ANSWER_SELECTED = "NO_ANSWER_SELECTED"


class TrackingSurveyPresenter: NSObject, ORKTaskViewControllerDelegate {
    /// headers for our 2 csv files, the survey answers, and the survey timings.
    /// (timings is human interaction with the buttons etc. of the survey.)
    static let headers = ["question id", "question type", "question text", "question answer options", "answer"]
    static let timingsHeaders = ["timestamp", "question id", "question type", "question text", "question answer options", "answer", "event"]
    static let surveyDataType = "surveyAnswers"
    static let timingDataType = "surveyTimings"
    
    var retainSelf: AnyObject?  // no clue - but if I remove this the End Task / Cancel / Done buttons no longer do anything.
    
    var surveyTimingsFile: DataStorage  /// ... the survey timings file
    
    // survey assets
    var activeSurvey: ActiveSurvey /// live object for this survey, in reality attached to the main menu(?)
    var questionSteps: [ORKStep]
    var stepOrder: [Int]
    var hasOptionalQuestionSteps: Bool
    var task: ORKTask? /// researchkit task, assigned way over in setup skiplogic
    
    /// UI stuff - not available until present() is called, must be optional
    var parent: UIViewController?
    var surveyViewController: BWORKTaskViewController?
    
    // we need to stash continue buttons when set to nil on required questions.
    var the_continue_button: UIBarButtonItem?
    var the_internal_continue_button: UIBarButtonItem?
    
    var currentQuestion: GenericSurveyQuestion?  // instantiation is weird
    
    var valueChangeHandler: Debouncer<String>?  // user input slow-downer, instantiation is weird
    
    // state
    var isComplete = false
    var questionIdToQuestion: [String: GenericSurveyQuestion] = [:] // question IDs to objects
    var finalQuestionId: String?
    var surveyId: String
    
    /// In old versions of the app this would execute at app load, possibly twice
    init(surveyId: String, activeSurvey: ActiveSurvey, survey: Survey) {
        print("Initializing presenter for survey `\(surveyId)`, active survey `\(activeSurvey)`, survey `\(survey.name)`")
        
        self.surveyId = surveyId
        self.activeSurvey = activeSurvey
        self.hasOptionalQuestionSteps = false
        self.questionSteps = [ORKStep]()
        
        // timings file
        let timingsName = TrackingSurveyPresenter.timingDataType + "_" + surveyId
        self.surveyTimingsFile = DataStorageManager.sharedInstance.createStore(
            timingsName, headers: TrackingSurveyPresenter.timingsHeaders
        )
        self.surveyTimingsFile.sanitize = true // replace commas with semicolons
        
        // if for some reason step order does not exist, we generate an order of 0..<(number of questions),
        // and also set the active survey's step order.
        self.stepOrder = activeSurvey.stepOrder ?? Array(0..<survey.questions.count)
        if activeSurvey.stepOrder == nil {
            activeSurvey.stepOrder = self.stepOrder
        }
        
        // make a question id lookup dict of question types, we need it for question logic
        let questions: [GenericSurveyQuestion] = survey.questions
        for question in questions {
            self.questionIdToQuestion[question.questionId] = question
        }
        
        // question count may be less than number of questions
        let numQuestions = survey.randomize ? min(questions.count, survey.numberOfRandomQuestions ?? 999) : questions.count
        
        super.init() /// cannot call self.method until we init....
        
        // setup the questions
        self.setupQuestionSteps(questions, numQuestions)
        self.setupSkipLogic(survey: survey)
        
        // if (self.activeSurvey.stepOrder![numQuestions - 1].questionId != self.lastQueestionId!) {
        //     fatalError("somehow miscalculated finalQuestionId")
        // }
        
    }
    
    /// create all the ORKSteps for the survey
    func setupQuestionSteps(_ questions: [GenericSurveyQuestion], _ numQuestions: Int) {
        
        for i in 0 ..< numQuestions {  
            
            // go through questions in step order
            let question: GenericSurveyQuestion = questions[self.stepOrder[i]]
            if let _ = question.displayIf {
                self.hasOptionalQuestionSteps = true
            }
            
            // different logic for every question type (for some reason question type is optional)
            if let questionType = question.questionType {
                
                self.doOneQuestion(question, questionType)
                // set to true if this question is the last item, based on numQuestions - which is the number of questions to display.
                // (which is rarely the last item in the list when randomizing)
                if i == (numQuestions - 1) {
                    self.finalQuestionId = question.questionId
                }
            }
        }
        
        // set up the finish-survey step
        let finishStep = ORKInstructionStep(identifier: "finished")
        finishStep.title = NSLocalizedString("survey_completed", comment: "")
        finishStep.text = StudyManager.sharedInstance.currentStudy?.studySettings?.submitSurveySuccessText
        questionSteps.append(finishStep)
    }
    
    
    func doOneQuestion(_ question: GenericSurveyQuestion, _ questionType: SurveyQuestionType) {
        // print("doOneQuestion called for question: \(question.questionId)")
        var step: ORKStep
        
        switch questionType {
        
        case .Checkbox, .RadioButton:
            
            // We have to do this intermediate variable pattern to get an ORKStep subclass.
            // `step = ORKQuestionStep(identifier: question.questionId)` is disallowed.
            let questionStep = ORKQuestionStep(identifier: question.questionId)
            step = questionStep
            
            // set up the question and its answers
            
            questionStep.answerFormat = ORKTextAnswerFormat.choiceAnswerFormat(
                with: questionType == .RadioButton ? .singleChoice : .multipleChoice,
                // create a textChoice for every question answer
                textChoices: question.selectionValues.enumerated().map { (index: Int, el: OneSelection) in
                    ORKTextChoice(text: el.text, value: index as NSNumber)
                }
            )
        
        case .Time:
            // its not clear what providing the withDefaultComponents parameter does, its still the current date
            let questionStep = ORKQuestionStep(identifier: question.questionId)
            step = questionStep
            questionStep.answerFormat = ORKTextAnswerFormat.timeOfDayAnswerFormat()
        
        case .Date:
            let questionStep = ORKQuestionStep(identifier: question.questionId)
            step = questionStep
            // dateAnswerFormat with all nils still defaults to the current date
            questionStep.answerFormat = ORKTextAnswerFormat.dateAnswerFormat(withDefaultDate: nil, minimumDate: nil, maximumDate: nil, calendar: nil)
        
        case .DateTime:
            // defaults to current date and time
            let questionStep = ORKQuestionStep(identifier: question.questionId)
            step = questionStep
            questionStep.answerFormat = ORKTextAnswerFormat.dateTime()
        
        case .FreeResponse:
            let questionStep = ORKQuestionStep(identifier: question.questionId)
            step = questionStep
            
            // the 3 types of text entry options - numeric is a text type.
            if let textFieldType = question.textFieldType {
                switch textFieldType {
                case .SingleLine:
                    let multiline_text = ORKTextAnswerFormat.textAnswerFormat()
                    multiline_text.multipleLines = false
                    questionStep.answerFormat = multiline_text
                case .MultiLine:
                    let singleline_text = ORKTextAnswerFormat.textAnswerFormat()
                    singleline_text.multipleLines = true
                    questionStep.answerFormat = singleline_text
                case .Numeric:
                    questionStep.answerFormat = ORKNumericAnswerFormat(
                        // numeric answers have min and max ranges, "unit" is a localizeable field for like miles vs kilometers.
                        style: .decimal, unit: nil, minimum: question.minValue as NSNumber?, maximum: question.maxValue as NSNumber?
                    )
                }
            }
        
        case .InformationText:
            step = ORKInstructionStep(identifier: question.questionId)
        
        case .Slider:
            // if somehow there are no values we default to 1 and 10
            let minValue = question.minValue ?? 1
            let maxValue = question.maxValue ?? 10
            let questionStep = ORKQuestionStep(identifier: question.questionId)
            step = questionStep
            // setting default value to minValue - 1 should result in a default value that is not visible
            questionStep.answerFormat = BWORKScaleAnswerFormat(
                maximumValue: maxValue, minimumValue: minValue, defaultValue: minValue - 1, step: 1
            )
        }
        
        step.text = question.prompt
        questionSteps.append(step)
    }
    
    /// Add question skip logic to each question
    func setupSkipLogic(survey: Survey) {
        // The two classes here, BWOrderedTask and BWNavigatableTask, have identical classes
        // except for their ORK superclasses.  It has always been this way.
        
        // (only if its not randomized and if there are no optional steps, e.g. you cannot randomize surveys with logic)
        if !survey.randomize && self.hasOptionalQuestionSteps {
            // Create a BWNavigatableTask, hand it the steps (ORKSteps).
            // attach a skip rule if the the question has skip logic.
            let navTask = BWNavigatableTask(identifier: "SurveyTask", steps: questionSteps)
            for step in questionSteps {
                let question = self.questionIdToQuestion[step.identifier]
                if let displayIf = question?.displayIf {
                    let navRule = BWSkipStepNavigationRule(displayIf: displayIf)
                    // print("\n\n\nI think we are on a next question now \n\n\n\n")
                    navTask.setSkip(navRule, forStepIdentifier: step.identifier)
                }
            }
            self.task = navTask
        } else {
            // case: no skip logic setup, just pass it in (can be factored out but whatever)
            self.task = BWOrderedTask(identifier: "SurveyTask", steps: questionSteps)
        }
    }
    
    /// function is called when the survey card interface is initially brought up.
    func present(_ parent: UIViewController) {
        self.parent = parent // don't even know if we need this
        
        // restore data for the active survey or start a new one.
        if let restorationData = activeSurvey.rkAnswers {
            print("present called, found restoration data: \(restorationData)")
            // if there is any restoration data it will all be _evaluated_ (not just instantiated)
            // at instantiation time.
            self.surveyViewController = BWORKTaskViewController(
                task: self.task!, restorationData: restorationData, delegate: self, error: nil
            )
        } else {
            self.surveyViewController = BWORKTaskViewController(task: self.task, taskRun: nil)
            self.surveyViewController!.delegate = self
        }
        
        let uuids = self.activeSurvey.mostRecentNotificationUUIDs ?? ""
        
        AppEventManager.sharedInstance.logAppEvent(
            event: "opened survey",
            msg: "survey_id: \(self.surveyId)",
            d1: "source_notification_uuids: \(uuids)"
        )
        
        self.retainSelf = self // so I guess this is a strong reference to itself?
        self.surveyViewController!.displayDiscard = false
        parent.present(self.surveyViewController!, animated: true, completion: nil)
    }
    
    // almost unreadable function that handles unpacking answers and saving them to a the answers dict
    func storeAnswer(_ identifier: String, result: ORKTaskResult) {
        guard let question = questionIdToQuestion[identifier],
              let stepResult = result.stepResult(forStepIdentifier: identifier) else {
            return
        }
        var answersString = ""
        
        if let questionType = question.questionType {
            // and now some mess
            switch questionType {
            case .Checkbox, .RadioButton:
                // if there are results...
                if let choiceResults = stepResult.results as? [ORKChoiceQuestionResult], choiceResults.count > 0, let choiceAnswers = choiceResults[0].choiceAnswers {
                    var arr: [String] = []
                    
                    for choice_answer in choiceAnswers {
                        // the choices are numbered, need to cast cast (why is it an NSNumber?)
                        if let num: NSNumber = choice_answer as? NSNumber {
                            let numValue: Int = num.intValue
                            if numValue >= 0 && numValue < question.selectionValues.count {
                                arr.append(question.selectionValues[numValue].text) // index access safety?
                            } else {
                                arr.append("")
                            }
                        } else { // if there was no number selected we need an empty string
                            arr.append("")
                        }
                    }
                    
                    // then populate the answers as a string for radio and checkbox
                    if questionType == .Checkbox {
                        answersString = self.arrayAnswer(arr)
                    } else {
                        answersString = arr.count > 0 ? arr[0] : "" // radio buttons have only one answer
                    }
                }
                
            case .FreeResponse:
                if let freeResponses = stepResult.results as? [ORKQuestionResult], freeResponses.count > 0 {
                    if let answer = freeResponses[0].answer {
                        answersString = String(describing: answer)
                    }
                }
                
            case .InformationText:
                break // ah you need an executable line in a switch-case
                
            case .Slider:
                if let sliderResults = stepResult.results as? [ORKScaleQuestionResult], sliderResults.count > 0 {
                    if let answer = sliderResults[0].scaleAnswer {
                        answersString = String(describing: answer)
                    }
                }
            case .Date:
                if let dateResponses = stepResult.results as? [ORKQuestionResult], dateResponses.count > 0 {
                    if let answer = dateResponses[0].answer as? Date {
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.dateFormat = "yyyy-MM-dd"
                        answersString = formatter.string(from: answer)
                    }
                }
            case .Time:
                if let timeResponses = stepResult.results as? [ORKQuestionResult], timeResponses.count > 0 {
                    if let answer = timeResponses[0].answer as? NSDateComponents {
                        var minute = ""
                        var hour = ""
                        if answer.minute < 10 { minute = "0\(answer.minute)" } else { minute = "\(answer.minute)" }
                        if answer.hour < 10 { hour = "0\(answer.hour)" } else { hour = "\(answer.hour)" }
                        answersString = "\(hour):\(minute)"
                    }
                }
            case .DateTime:
                if let datetimeResponses = stepResult.results as? [ORKQuestionResult], datetimeResponses.count > 0 {
                    if let answer = datetimeResponses[0].answer as? Date {
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.dateFormat = "yyyy-MM-dd HH:mm"
                        answersString = formatter.string(from: answer)
                    }
                }
            }
        }
        
        // no answer case
        if answersString == "" || answersString == "[]" {
            answersString = NO_ANSWER_SELECTED
        }
        self.activeSurvey.bwAnswers[identifier] = answersString
    }
    
    // extracts the answer out of a question object, returns a tuple of objects required for use in writing to a csv
    // the question type, the options for multiple choice questions, and the contents of the answer in string form.
    func getQuestionResponse(_ question: GenericSurveyQuestion) -> (String, String, String) {
        guard let questionType = question.questionType else {
            return ("", "", "") // this guard condition is unreachable
        }
        
        // get the answer
        var answerString: String
        if let answer = self.activeSurvey.bwAnswers[question.questionId] {
            answerString = answer
        } else {
            answerString = "NOT_PRESENTED"
        }
        
        // special cases for the various question types - these can all go into store answer?
        var optionsString = ""
        switch questionType {
        case .Checkbox, .RadioButton:
            optionsString = self.arrayAnswer(question.selectionValues.map { $0.text })
        case .FreeResponse:
            optionsString = "Text-field input type = " + (question.textFieldType?.rawValue ?? "")
        case .InformationText:
            answerString = ""
        case .Slider:
            if let minValue = question.minValue, let maxValue = question.maxValue {
                optionsString = "min = " + String(minValue) + "; max = " + String(maxValue)
                // this first comparison here expects the answer value from storeAnswer for slider questiions,
                // but it looks like it doesn't work? The second appears to be the functional logic.
                // If you ever work out why comparison 1 is wrong please document it or correct it.
                if Int(answerString) == (minValue - 1) || Int(answerString) == nil {
                    answerString = "NO_ANSWER_SELECTED"
                }
            }
        case .Date, .Time, .DateTime:
            break // fully formatted in storeAnswer
        }
        
        return (questionType.rawValue, optionsString, answerString)
    }
    
    // stores survey answers on a new DataStorage
    func finalizeSurveyAnswers() {
        guard let survey = activeSurvey.survey,
              let patientId = StudyManager.sharedInstance.currentStudy?.patientId else {
            return
        }
        guard survey.questions.count > 0 else {
            return
        }
        
        StudyManager.sharedInstance.currentStudy?.submittedTrackingSurveys =
            (StudyManager.sharedInstance.currentStudy?.submittedTrackingSurveys ?? 0)  + 1
        
        // set up data file
        let dataFile = DataStorage(
            type: TrackingSurveyPresenter.surveyDataType + "_" + surveyId,
            headers: TrackingSurveyPresenter.headers,
            patientId: patientId
        )
        dataFile.sanitize = true // replace commas with semicolons
        
        // no questions
        let numQuestions = survey.randomize ? min(survey.questions.count, survey.numberOfRandomQuestions ?? 999) : survey.questions.count
        if numQuestions == 0 {
            return
        }
        
        
        // store the questions line by line
        for i in 0 ..< numQuestions {
            let question: GenericSurveyQuestion = survey.questions[self.stepOrder[i]]
            var data: [String] = [question.questionId]
            let (questionType, optionsString, answersString) = self.getQuestionResponse(question)
            data.append(questionType)
            data.append(question.prompt ?? "")
            data.append(optionsString)
            data.append(answersString)
            dataFile.store(data)
        }
        dataFile.reset() // retires the file
        
        print("Finished writing survey answers to file for survey \(surveyId), active survey \(activeSurvey), survey \(survey.name)")
        
        AppEventManager.sharedInstance.logAppEvent(
            event: "saving survey answers",
            msg: "survey_id: \(surveyId)",
            d1: "source_notification_uuids: \(activeSurvey.mostRecentNotificationUUIDs ?? "")"
        )
    }
    
    // writes a timing event for the provided question (and value)
    func addTimingsEvent(_ event: String, question: GenericSurveyQuestion?, forcedValue: String? = nil) {
        // get the current time, then set up the timings event using the question
        var data: [String] = [String(Int64(Date().timeIntervalSince1970 * 1000))]
        if let question = question {
            data.append(question.questionId)
            let (questionType, optionsString, answersString) = self.getQuestionResponse(question)
            data.append(questionType)
            data.append(question.prompt ?? "")
            data.append(optionsString)
            data.append(forcedValue != nil ? forcedValue! : answersString)
        } else {
            // probably unreachable? populates empty values if the question isn't present.
            data.append(""); data.append(""); data.append(""); data.append("")
            data.append(forcedValue != nil ? forcedValue! : "")
        }
        data.append(event)
        // print("TimingsEvent: \(data.joined(separator: ","))")  // we don't need to see every timings event
        self.surveyTimingsFile.store(data)
    }
    
    func dismissCurrentQuestion() {
        // print("dismissCurrentQuestion")
        self.valueChangeHandler?.flush() // force the debouncer to fire and clear it
        self.valueChangeHandler = nil
        
        if let currentQuestion = currentQuestion {
            // print("dismissCurrentQuestion -- inner dismissed current question")
            // write a timings event that question has been dismissed?
            self.addTimingsEvent("dismissing question", question: currentQuestion)
            self.currentQuestion = nil
        }
    }
    
    // TODO: test if this is our only exit point from having a survey open and visible, we need to
    // now add the data storage reset calls
    func closeSurvey() {
        // print("closeSurvey called")
        self.retainSelf = nil // clear the reference to self...
        self.surveyTimingsFile.reset()
        
        StudyManager.sharedInstance.surveysUpdatedEvent.emit(0) // also unknown
        self.parent?.dismiss(animated: true, completion: nil) // dismiss the researchkit survey
    }
    
    // very simple pseudo json array
    func arrayAnswer(_ array: [String]) -> String {
        return "[" + array.joined(separator: ";") + "]"
    }
    
    // function that sets up necessary state for implementing required questions
    func handleRequiredQuestion(_ stepViewController: ORKStepViewController, _ identifier: String) -> Bool {
        // the isEnabled and isHidden properties for the continue and skip buttons are both os version blocked
        // (16 and 15, respectively) .... and isenabled doesn't do anything?
        
        if identifier != "finished", let question = questionIdToQuestion[identifier] {
            // print("handleRequiredQuestion... question id \(identifier)")
            // InformationText questions cannot be required and do not have skip buttons.
            if question.required && question.questionType != SurveyQuestionType.InformationText {
                // print("handleRequiredQuestion... required")
                // TODO: fix this bug, maybe it is specific to [radio buttons?]
                // setting the step as optional Doesn't work reliably. At least for the first question, if it is a radio button question,
                // the next button will be clickable all subsequent times after the first time it is answered. (this is at least true for
                // always available surveys)
                // stepViewController.step?.isOptional = false
                
                // If you don't remove both internal and regular buttons then they will suddenly reappear
                // after the participant interacts with the question answers. (Same for the continue button.)
                stepViewController.skipButtonItem = nil
                stepViewController.internalSkipButtonItem = nil

                // stash the continue buttons - these are always present together - these are different objects per-question
                if let a_continue_button = stepViewController.continueButtonItem {
                    self.the_continue_button = a_continue_button
                }
                if let an_internal_continue_button = stepViewController.internalContinueButtonItem {
                    self.the_internal_continue_button = an_internal_continue_button
                }
                
                // Determiine whether there is an answer to the current questiion.
                // (Testing for the empty string should be pointless due to behaviior in storeAnswer())
                if let some_answer = self.activeSurvey.bwAnswers[identifier], some_answer != "", some_answer != NO_ANSWER_SELECTED {
                    // print("handleRequiredQuestion...required... found an answer to the question, it is `\(some_answer)`...")
                    stepViewController.continueButtonItem = self.the_continue_button
                    stepViewController.internalContinueButtonItem = self.the_internal_continue_button
                    return true
                } else {
                    // print("handleRequiredQuestion... required...did not find an answer to the question...")
                    stepViewController.continueButtonItem = nil
                    stepViewController.internalContinueButtonItem = nil
                    return false
                }
            } else {
                // print("handleRequiredQuestion, not required")
            }
            
        }
        return true
    }
    
    
    //##############################################################################
    //########################### ORK Delegates ####################################
    //##############################################################################
    
    
    /** Tells the delegate that the current task has finished.
     
     Called when an unrecoverable error occurs, when the user has canceled a task, or when the user
     completes the last step in the task.
     
     @param taskViewController  The `ORKTaskViewController `instance that is returning the result.
     
     @param reason              An `ORKTaskViewControllerFinishReason` value indicating how the user
                                chose to complete the task.
     
     @param error   If failure occurred, an `NSError` object indicating the reason for the failure.
                    The value of this parameter is `nil` if `result` does not indicate failure.
     
     // TODO: is this called both when the cancel and end task button are pressed? or just one.
     
     Old notes:
     - called when a card is dismissed - including cancel button - end task menu item.
     - called when survey done button is pressed.
     */
    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        // print("\ntaskViewController FINISHED called - Q id:`\(taskViewController.currentStepViewController?.step?.identifier)`\n")
        // print("error: \(error)")
        
        // if let identifier = taskViewController.currentStepViewController?.step?.identifier {
        //     self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        // }
        
        self.dismissCurrentQuestion()
        if !self.isComplete {
            self.activeSurvey.rkAnswers = taskViewController.restorationData
            if let study = StudyManager.sharedInstance.currentStudy {
                Recline.shared.save(study)
                log.info("Tracking survey state saved.")
            }
        }
        self.closeSurvey()
    }
    
    /** Called when the participant's result has changed.
     Called on every character change of text input, sliders require a debouncer.
    
     @param taskViewController      The calling `ORKTaskViewController` instance.
     @param result                  The current value of the result.
    
     Old notes:
     - called when done, back, or next button is pressed.
     - called when input occurs, more-or-less.
     - NOT called when skip is pressed.
     */
    func taskViewController(_ taskViewController: ORKTaskViewController, didChange result: ORKTaskResult) {
        // print("\ntaskViewController RESULT CHANGED - Q id: `\(taskViewController.currentStepViewController?.step?.identifier)`\n")
        // print("taskViewController.currentStepViewController?.step: `\(taskViewController.currentStepViewController?.step)`")
        // print("\(result)\n(result.results)")
        
        // update the answer data for this question, if there is a question
        if let identifier = taskViewController.currentStepViewController!.step?.identifier {
            self.storeAnswer(identifier, result: result)
            let currentValue = self.activeSurvey.bwAnswers[identifier] // (type is now a str)
            // print("result changed, value is now `\(currentValue)`")
            
            self.valueChangeHandler?.call(currentValue)  // debounce
            // print("finished valuechange call...")
            
            // must to be called after the question answer has been updated
            self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        }
    }
    
    /** Asks the delegate if the task view controller should proceed (to the specified step).
     Called _before_ creating a step view controller (for the next or previous step).
     
     // TODO: document exact behavior when we return false.  Looks like default nothing?
     
     @param taskViewController     The calling `ORKTaskViewController` instance.
     @param step                   The step for which presentation is requested.
     
     Old notes:
     - called once when any survey card is displayed
     - called when back button is pressed
     - called _first_ on survey open with nil
     */
    func taskViewController(_ taskViewController: ORKTaskViewController, shouldPresent step: ORKStep) -> Bool {
        // print("\ntaskViewController SHOULD PRESENT? - Q id: `\(taskViewController.currentStepViewController?.step?.identifier)`\n")
        // print("taskViewController.currentStepViewController?.step: `\(taskViewController.currentStepViewController?.step)`")
        
        if let identifier = taskViewController.currentStepViewController?.step?.identifier {
            self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        }
        self.dismissCurrentQuestion()
        return true // returning false here this doesn't block the back button
    }
    
    /** Tells the delegate that a step view controller is about to be displayed. Do setup.
     
     Called before presentation of the step view controller, regardless of direction of navigation.
     No return value.
     
     @param taskViewController       The calling `ORKTaskViewController` instance.
     @param stepViewController       The `ORKStepViewController` that is about to be displayed.
     
     Old notes:
     - When back button is pressed, once with the 'current' question, once with the previous question
     - When next/skip button is pressed, once with the 'current' question, once with the next question
     */
    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        // print("\ntaskViewController ABOUT TO DISPLAY called - Q id: `\(taskViewController.currentStepViewController?.step?.identifier)`\n")
        // print("taskViewController.currentStepViewController?.step: `\(taskViewController.currentStepViewController?.step)`")
        
        // set up the card's UI properties
        // stepViewController.navigationController?.navigationBar.barStyle = UIBarStyle.black  // pretty confident this does nothing
        stepViewController.navigationController?.presentTransparentNavigationBar() // fixes the invisible cancel and back buttons background color
        // stepViewController.navigationController?.hideTransparentNavigationBar()  // makes the buttons actually go away (not desireable)
        // stepViewController.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black] // sets the title text ("1 of 6") color - undesireable, we want the dark-mode-aware version
        // stepViewController.view.backgroundColor = UIColor.clear // makes the entire thing transparent - obviously wrong
        // stepViewController.navigationController // exists UINavigationController
        // stepViewController.navigationController?.navigationBar // exists, UINavigationBar
        
        // set up start screen
        self.currentQuestion = nil
        if stepViewController.continueButtonTitle == NSLocalizedString("get_started", comment: "") {
            stepViewController.continueButtonTitle = NSLocalizedString("continue_button_title", comment: "")
        }
        
        if let identifier = stepViewController.step?.identifier {
            // run the required questions logic first
            self.handleRequiredQuestion(stepViewController, identifier)
            
            switch identifier {
            case "finished":
                // executed when the card with the finished survey button is _loaded_ - not when the done button is pressed
                // ... but this code does not actually clear the survey, even though it submits it.
                self.addTimingsEvent("submitted", question: nil)
                
                self.finalizeSurveyAnswers() // Submit.
                
                // why do we save restorationData right after a submit?
                self.activeSurvey.rkAnswers = taskViewController.restorationData
                self.activeSurvey.isComplete = true
                self.isComplete = true
                StudyManager.sharedInstance.updateActiveSurveys(true)
                
                // We need to disable the back buttton, otherwise the answers can be created more than once.
                // stepViewController.backButtonItem = nil // nope, it is already nil.
                // Have to assign it something and then make that not do anything
                // (On old versions of iOS it cannot be hidden.)
                stepViewController.backButtonItem = stepViewController.cancelButtonItem
                stepViewController.cancelButtonItem = nil  // gets rid of it from the righthand corner
                stepViewController.backButtonItem?.isEnabled = false
                if #available(iOS 16.0, *) {
                    stepViewController.backButtonItem?.isHidden = true // and hide it
                }
            default:
                // load the question
                if let question = questionIdToQuestion[identifier] {
                    // print("loading next question, with identifier \(identifier)")
                    self.currentQuestion = question
                    if self.activeSurvey.bwAnswers[identifier] == nil {
                        self.activeSurvey.bwAnswers[identifier] = ""
                    }
                    
                    // populate any existing question
                    var currentValue = self.activeSurvey.bwAnswers[identifier]
                    self.addTimingsEvent("present", question: question)
                    
                    var delay = 0.0
                    if question.questionType == SurveyQuestionType.Slider {
                        // for untested reasons we have to provide some delay for slider type questions, probably because
                        // it otherwise causes thousands of sliding style input events
                        delay = 0.25
                    }
                    
                    self.valueChangeHandler = Debouncer<String>(delay: delay) { [weak self] (val: String?) in
                        if let strongSelf = self, currentValue != val {
                            currentValue = val
                            strongSelf.addTimingsEvent("changed", question: question, forcedValue: val)
                        }
                    }
                }
                
                // if this is the final question set the button text correctly.
                if let finalQuestionId = self.finalQuestionId, finalQuestionId == identifier {
                    // print("setting end survey text")
                    stepViewController.continueButtonTitle = NSLocalizedString("submit_survey_title", comment: "")
                }
            }
        }
    }
    
    /** Called to tell the delegate that a step will disappear, before it disappears.
     Docs say it is after [native implementation of] saving the result, before navigating away.
     
     Old notes:
     @param taskViewController    The calling `ORKTaskViewController` instance.
     @param stepViewController    The `ORKStepViewController` that has just finished.
     @param direction             The `ORKStepViewControllerNavigationDirection` of navigation.
     */
    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillDisappear stepViewController: ORKStepViewController, navigationDirection: ORKStepViewControllerNavigationDirection) {
        // print("taskViewController STEP WILL DISAPPEAR called...")
        // print("\ntaskViewController STEP WILL DISAPPEAR - Q id: `\(taskViewController.currentStepViewController?.step?.identifier)`\n")
        // print("taskViewController.currentStepViewController?.step: `\(taskViewController.currentStepViewController?.step)`")
        // print("navigationDirection: \(navigationDirection)")
    }
    
    /** Called by super if the cancel action should be confirmed (true) or not (false)
     
     Starting in iOS 26 the End Task menu got super slow, which could cause ia double-tap to force
     an app crash. Tracked this down, gets rid of the stupid menu option.
     */
    func taskViewControllerShouldConfirmCancel(_ taskViewController: ORKTaskViewController) -> Bool{
        return false
    }
    
    //##############################################################################################
    //################################## Defined But Not Used ######################################
    //##############################################################################################
    
    /**Asks the delegate if the state of the current uncompleted task should be saved.
     The original app (was bad and) reimplemented this feature, but it is automatic.
     We always return no (false).
     See overridden function for details.
     
     Old notes:
     - (called when any survey card is displayed)
     - called when back button is pressed, once with the 'current' question, once with the previous question
     - called when next/skip button is pressed, once with the 'current' question, once with the next question
     - called when you hit the cancel button
     */
    func taskViewControllerSupportsSaveAndRestore(_ taskViewController: ORKTaskViewController) -> Bool {
        // print("taskViewController ASK STATE SAVE called")
        // print("\ntaskViewController ASK STATE SAVE - Q id: `\(taskViewController.currentStepViewController?.step?.identifier)`\n")
        // print("taskViewController.currentStepViewController?.step: `\(taskViewController.currentStepViewController?.step)`")
        // if let identifier = taskViewController.currentStepViewController?.step?.identifier {
        //     self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        // }
        return false
    }
    
    
    /** Asks the delegate for a custom view controller for the specified step.
     The original app was bad and this hook was not used. It probably should have been.
     We always return nil.
     See overridden function for details.
     
     - (called when any survey card is displayed - twice! 🙃)
     - called when back button is pressed, once with the 'current' question, BUT TWICE with the previous question
     - called when next/skip button is pressed, once with the 'current' question, BUT TWICE with the next question
     */
    func taskViewController(_ taskViewController: ORKTaskViewController, viewControllerFor step: ORKStep) -> ORKStepViewController? {
        // print("(taskViewController 5 ASK CUSTOM VIEWCONTROLLER called...)")
        // print("\ntaskViewController 5 - Q id: `\(taskViewController.currentStepViewController?.step?.identifier)`\n")
        // print("taskViewController.currentStepViewController?.step: `\(taskViewController.currentStepViewController?.step)`")
        // print("step: \(step)")
        // if let identifier = taskViewController.currentStepViewController?.step?.identifier {
        //     self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        // }
        return nil
    }
    
    /** Asks the delegate if there is Learn More content for this step.
     Our answer is always no (false).  See overwritten function for details.
     
     Old notes:
     - (called when any survey card is displayed)
     - called when back button is pressed, once with the 'current' question, once with the previous question
     - called when next/skip button is pressed, once with the 'current' question, once with the next question
     - called when survey is initially opened, once with nil and once with a question id (possibly differs if you don't have an informational text box question)
     */
    func taskViewController(_ taskViewController: ORKTaskViewController, hasLearnMoreFor step: ORKStep) -> Bool {
        // print("(taskViewController 4 ASK LEARN MORE called...)")
        // print("\ntaskViewController 4 - Q id: `\(taskViewController.currentStepViewController?.step?.identifier)`\n")
        // print("taskViewController.currentStepViewController?.step: `\(taskViewController.currentStepViewController?.step)`")
        // if let identifier = taskViewController.currentStepViewController?.step?.identifier {
        //     self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        // }
        return false
    }
    
    
    deinit {
        self.surveyTimingsFile.reset()
        self.the_continue_button = nil
        self.the_internal_continue_button = nil
    }
}
