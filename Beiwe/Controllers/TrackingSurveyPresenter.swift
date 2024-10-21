import Foundation
import ObjectMapper
import ResearchKit

// example json
// let contentJson = "{\"content\":[{\"answers\":[{\"text\":\"Never\"},{\"text\":\"Rarely\"},{\"text\":\"Occasionally\"},{\"text\":\"Frequently\"},{\"text\":\"Almost Constantly\"}],\"question_id\":\"6695d6c4-916b-4225-8688-89b6089a24d1\",\"question_text\":\"In the last 7 days, how OFTEN did you EAT BROCCOLI?\",\"question_type\":\"radio_button\"},{\"answers\":[{\"text\":\"None\"},{\"text\":\"Mild\"},{\"text\":\"Moderate\"},{\"text\":\"Severe\"},{\"text\":\"Very Severe\"}],\"display_if\":{\">\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",0]},\"question_id\":\"41d54793-dc4d-48d9-f370-4329a7bc6960\",\"question_text\":\"In the last 7 days, what was the SEVERITY of your CRAVING FOR BROCCOLI?\",\"question_type\":\"radio_button\"},{\"answers\":[{\"text\":\"Not at all\"},{\"text\":\"A little bit\"},{\"text\":\"Somewhat\"},{\"text\":\"Quite a bit\"},{\"text\":\"Very much\"}],\"display_if\":{\"and\":[{\">\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",0]},{\">\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",0]}]},\"question_id\":\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",\"question_text\":\"In the last 7 days, how much did your CRAVING FOR BROCCOLI INTERFERE with your usual or daily activities, (e.g. eating cauliflower)?\",\"question_type\":\"radio_button\"},{\"display_if\":{\"or\":[{\"and\":[{\"<=\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",3]},{\"==\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",2]},{\"<\":[\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",3]}]},{\"and\":[{\"<=\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",3]},{\"<\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",3]},{\"==\":[\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",2]}]},{\"and\":[{\"==\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",4]},{\"<=\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",1]},{\"<=\":[\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",1]}]}]},\"question_id\":\"9d7f737d-ef55-4231-e901-b3b68ca74190\",\"question_text\":\"While broccoli is a nutritious and healthful food, it's important to recognize that craving too much broccoli can have adverse consequences on your health.  If in a single day you find yourself eating broccoli steamed, stir-fried, and raw with a 'vegetable dip', you may be a broccoli addict.\\u000a\\u000aThis is an additional paragraph (following a double newline) warning you about the dangers of broccoli consumption.\",\"question_type\":\"info_text_box\"},{\"display_if\":{\"or\":[{\"and\":[{\"==\":[\"6695d6c4-916b-4225-8688-89b6089a24d1\",4]},{\"or\":[{\">=\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",2]},{\">=\":[\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",2]}]}]},{\"or\":[{\">=\":[\"41d54793-dc4d-48d9-f370-4329a7bc6960\",3]},{\">=\":[\"5cfa06ad-d907-4ba7-a66a-d68ea3c89fba\",3]}]}]},\"question_id\":\"59f05c45-df67-40ed-a299-8796118ad173\",\"question_text\":\"OK, it sounds like your broccoli habit is getting out of hand.  Please call your clinician immediately.\",\"question_type\":\"info_text_box\"},{\"question_id\":\"9745551b-a0f8-4eec-9205-9e0154637513\",\"question_text\":\"How many pounds of broccoli per day could a woodchuck chuck if a woodchuck could chuck broccoli?\",\"question_type\":\"free_response\",\"text_field_type\":\"NUMERIC\"},{\"display_if\":{\"<\":[\"9745551b-a0f8-4eec-9205-9e0154637513\",10]},\"question_id\":\"cedef218-e1ec-46d3-d8be-e30cb0b2d3aa\",\"question_text\":\"That seems a little low.\",\"question_type\":\"info_text_box\"},{\"display_if\":{\"==\":[\"9745551b-a0f8-4eec-9205-9e0154637513\",10]},\"question_id\":\"64a2a19b-c3d0-4d6e-9c0d-06089fd00424\",\"question_text\":\"That sounds about right.\",\"question_type\":\"info_text_box\"},{\"display_if\":{\">\":[\"9745551b-a0f8-4eec-9205-9e0154637513\",10]},\"question_id\":\"166d74ea-af32-487c-96d6-da8d63cfd368\",\"question_text\":\"What?! No way- that's way too high!\",\"question_type\":\"info_text_box\"},{\"max\":\"5\",\"min\":\"1\",\"question_id\":\"059e2f4a-562a-498e-d5f3-f59a2b2a5a5b\",\"question_text\":\"On a scale of 1 (awful) to 5 (delicious) stars, how would you rate your dinner at Chez Broccoli Restaurant?\",\"question_type\":\"slider\"},{\"display_if\":{\">=\":[\"059e2f4a-562a-498e-d5f3-f59a2b2a5a5b\",4]},\"question_id\":\"6dd9b20b-9dfc-4ec9-cd29-1b82b330b463\",\"question_text\":\"Wow, you are a true broccoli fan.\",\"question_type\":\"info_text_box\"},{\"question_id\":\"ec0173c9-ac8d-449d-d11d-1d8e596b4ec9\",\"question_text\":\"THE END. This survey is over.\",\"question_type\":\"info_text_box\"}],\"settings\":{\"number_of_random_questions\":null,\"randomize\":false,\"randomize_with_memory\":false,\"trigger_on_first_download\":false},\"survey_type\":\"tracking_survey\",\"timings\":[[],[67500],[],[],[],[],[]]}"

let NO_ANSWER_SELECTED = "NO_ANSWER_SELECTED"

class TrackingSurveyPresenter: NSObject, ORKTaskViewControllerDelegate {
    // generates 2 csv files, the survey answers, and the survey timings. Answers is obvious, timings is human interaction with the buttons of the app.
    static let headers = ["question id", "question type", "question text", "question answer options", "answer"]
    static let timingsHeaders = ["timestamp", "question id", "question type", "question text", "question answer options", "answer", "event"]
    static let surveyDataType = "surveyAnswers"
    static let timingDataType = "surveyTimings"
    
    // no clue - probably a memory retention thing?
    var retainSelf: AnyObject?
    
    // info
    var surveyId: String?
    
    // survey pointers?
    var activeSurvey: ActiveSurvey? // live information for this survey
    var survey: Survey? // points to the json information for the survey
    
    // UI stuff
    var parent: UIViewController?
    var surveyViewController: BWORKTaskViewController?
    
    // its a user input slow-downer, only functionally necessary for slider questions afaik.
    var valueChangeHandler: Debouncer<String>?
    
    // state
    var isComplete = false
    var questionIdToQuestion: [String: GenericSurveyQuestion] = [:] // questions have IDs, map of IDs to question objects
    var questionTypes = [String: SurveyQuestionType]() // we aren't using this anymore, but if anything is ever changed for logic it coulde be helpful
    var finalQuestionId: String?
    
    // well its the researchkit task...
    var task: ORKTask?
    
    // survey timings information
    let timingsName: String // unnecessary now?
    var surveyTimingsFile: DataStorage?
    
    // the current question (do display?)
    var currentQuestion: GenericSurveyQuestion?
    
    // we need to stash continue buttons when set to nil on required questions.
    var the_continue_button: UIBarButtonItem?
    var the_internal_continue_button: UIBarButtonItem?
    
    /// This executes at app load Twice (whyyy?) and on survey load
    init(surveyId: String, activeSurvey: ActiveSurvey, survey: Survey) {
        self.timingsName = TrackingSurveyPresenter.timingDataType + "_" + surveyId // any reason we are setting this up early?
        
        // let tempSurvey = Mapper<Survey>().map(contentJson) // very old debugging code from keary
        // let questions = tempSurvey!.questions
        let questions: [GenericSurveyQuestion] = survey.questions
        
        super.init()
        self.surveyId = surveyId
        self.activeSurvey = activeSurvey
        self.survey = survey
        
        // timings file setup begins immediately
        self.surveyTimingsFile = DataStorageManager.sharedInstance.createStore(
            self.timingsName, headers: TrackingSurveyPresenter.timingsHeaders
        )
        self.surveyTimingsFile!.sanitize = true // ok, dumb factoring but here's where we set the sanitize flag
        
        // this TODO is ancient, its from Keary
        // TODO: handle if stepOrder is null, throw error if it is not valid if it is valid, figure out why and under what conditions
        guard let stepOrder = activeSurvey.stepOrder /* where questions.count > 0 */ else {
            log.error("Active survey has no stepOrder")
            return
        }
        
        // question count may be less than number of questions
        let numQuestions = survey.randomize ? min(questions.count, survey.numberOfRandomQuestions ?? 999) : questions.count
        var questionSteps = [ORKStep]()
        
        // make a question id lookup dict of question types, we need it for question logic
        for question in questions {
            self.questionTypes[question.questionId] = question.questionType
            self.questionIdToQuestion[question.questionId] = question
        }
        
        // setup the questions
        let hasOptionalSteps = self.setupQuestionSteps(survey, numQuestions, stepOrder, &questionSteps)
        self.setupSkipLogic(survey: survey, hasOptionalSteps: hasOptionalSteps, questionSteps: questionSteps)
    }
    
    /// create all the ORKSteps for the survey
    func setupQuestionSteps(_ survey: Survey, _ numQuestions: Int, _ stepOrder: [Int], _ questionSteps: inout [ORKStep]) -> Bool {
        let questions = survey.questions
        var hasOptionalSteps = false // flag for whether there is logic to display this question
        
        // iterate over questions in step order
        for i in 0 ..< numQuestions {
            let question: GenericSurveyQuestion = questions[stepOrder[i]]
            if let _ = question.displayIf {
                hasOptionalSteps = true
            }
            
            // different logic for every question type (for some reason question type is optional)
            if let questionType = question.questionType {
                // Weird typing problem - we need a list of [subclasses of] ORKSteps, but you cannot do the following
                //   step = ORKQuestionStep(identifier: question.questionId)
                // when step is defiined as an ORK step.  Instead we need to create an explicit "questionStep" variable
                // and then do `step = questionStep` in order to update the ORKStep pointer... except you can do it
                // for the ORKInstructionStep class.  This is annoying.
                var step: ORKStep
                
                switch questionType {
                case .Checkbox, .RadioButton:
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
                
                // set to true if this question is the last item, based on numQuestions - which is the number of questions to display.
                // (which is rarely the last item in the list when randomizing)
                if i == (numQuestions - 1) {
                    self.finalQuestionId = question.questionId
                }
                step.text = question.prompt
                questionSteps.append(step)
            }
        }
        
        // set up the finish-survey step
        let finishStep = ORKInstructionStep(identifier: "finished")
        finishStep.title = NSLocalizedString("survey_completed", comment: "")
        finishStep.text = StudyManager.sharedInstance.currentStudy?.studySettings?.submitSurveySuccessText
        questionSteps.append(finishStep)
                
        return hasOptionalSteps
    }
    
    /// Add question skip logic to each question
    func setupSkipLogic(survey: Survey, hasOptionalSteps: Bool, questionSteps: [ORKStep]) {
        // (only if its not randomized and if there are no optional steps, e.g. you cannot randomize surveys with logic)
        if !survey.randomize && hasOptionalSteps {
            // Create a BWNavigatableTask, hand it the steps (ORKSteps), and attach a skip rule if the the question has skip logic.
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
    
    /// function is called when the survey card is initially brought up.
    func present(_ parent: UIViewController) {
        self.parent = parent
        
        // restore data for the active survey or start a new one.
        if let activeSurvey = activeSurvey, let restorationData = activeSurvey.rkAnswers {
            self.surveyViewController = BWORKTaskViewController(
                task: self.task!, restorationData: restorationData, delegate: self, error: nil
            )
        } else {
            self.surveyViewController = BWORKTaskViewController(task: self.task, taskRun: nil)
            self.surveyViewController!.delegate = self
        }
        
        self.retainSelf = self // so I guess this is a strong reference to itself?
        self.surveyViewController!.displayDiscard = false
        parent.present(self.surveyViewController!, animated: true, completion: nil)
    }
    
    // almost unreadable function that handles unpacking answers and saving them to a file
    func storeAnswer(_ identifier: String, result: ORKTaskResult) {
        guard let question = questionIdToQuestion[identifier], let stepResult = result.stepResult(forStepIdentifier: identifier) else {
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
        self.activeSurvey?.bwAnswers[identifier] = answersString
    }

    // extracts the answer out of a question object, returns a tuple of objects required for use in writing to a csv
    // the question type, the options for multiple choice questions, and the contents of the answer in string form.
    func questionResponse(_ question: GenericSurveyQuestion) -> (String, String, String) {
        var typeString = ""
        var optionsString = ""
        var answersString = ""

        // get the answers and the question type
        guard let questionType = question.questionType else {
            return (typeString, optionsString, answersString)
        }
        
        typeString = questionType.rawValue
        if let answer: String = activeSurvey?.bwAnswers[question.questionId] {
            answersString = answer
        } else {
            answersString = "NOT_PRESENTED"
        }
        
        // special cases for the various question types - these can all go into store answer?
        switch questionType {
        case .Checkbox, .RadioButton:
            optionsString = self.arrayAnswer(question.selectionValues.map { $0.text })
        case .FreeResponse:
            optionsString = "Text-field input type = " + (question.textFieldType?.rawValue ?? "")
        case .InformationText:
            answersString = ""
        case .Slider:
            if let minValue = question.minValue, let maxValue = question.maxValue {
                optionsString = "min = " + String(minValue) + "; max = " + String(maxValue)
                // this first comparison here expects the answer value from storeAnswer for slider questiions,
                // but it looks like it doesn't work? The second appears to be the functional logic.
                // If you ever work out why comparison 1 is wrong please document it or correct it.
                if Int(answersString) == (minValue - 1) || Int(answersString) == nil {
                    answersString = "NO_ANSWER_SELECTED"
                }
            }
        case .Date, .Time, .DateTime:
            break // fully formatted in storeAnswer
        }
        return (typeString, optionsString, answersString)
    }

    // stores survey answers on a new DataStorage
    func finalizeSurveyAnswers() {
        guard let activeSurvey = activeSurvey,
              let survey = activeSurvey.survey,
              let surveyId = surveyId,
              let patientId = StudyManager.sharedInstance.currentStudy?.patientId,
              let publicKey = StudyManager.sharedInstance.currentStudy?.studySettings?.clientPublicKey else {
            return
        }
        guard let stepOrder = activeSurvey.stepOrder, survey.questions.count > 0 else {
            return
        }
        
        // starting in build 2024.6 we will disable this specific case-handling to see if this has any effect.
        // if we start getting empty survey files that means we reinvestigate.
        // guard activeSurvey.bwAnswers.count > 0 else {
        //     // print("No questions answered, not submitting.")
        //     return
        // }
        
        // set up data file
        let name = TrackingSurveyPresenter.surveyDataType + "_" + surveyId
        let dataFile = DataStorage(
            type: name,
            headers: TrackingSurveyPresenter.headers,
            patientId: patientId,
            publicKey: publicKey,
            keyRef: StudyManager.sharedInstance.getSecKey()
        )
        dataFile.sanitize = true
        
        // no questions
        let numQuestions = survey.randomize ? min(survey.questions.count, survey.numberOfRandomQuestions ?? 999) : survey.questions.count
        if numQuestions == 0 {
            return
        }
        
        // store the questions line by line
        for i in 0 ..< numQuestions {
            let question: GenericSurveyQuestion = survey.questions[stepOrder[i]]
            var data: [String] = [question.questionId]
            let (questionType, optionsString, answersString) = self.questionResponse(question)
            data.append(questionType)
            data.append(question.prompt ?? "")
            data.append(optionsString)
            data.append(answersString)
            dataFile.store(data)
        }
        dataFile.reset() // retires the file
    }
    
    // writes a timing event for the provided question (and value)
    func addTimingsEvent(_ event: String, question: GenericSurveyQuestion?, forcedValue: String? = nil) {
        // get the current time, then set up the timings event using the question
        var data: [String] = [String(Int64(Date().timeIntervalSince1970 * 1000))]
        if let question = question {
            data.append(question.questionId)
            let (questionType, optionsString, answersString) = self.questionResponse(question)
            data.append(questionType)
            data.append(question.prompt ?? "")
            data.append(optionsString)
            data.append(forcedValue != nil ? forcedValue! : answersString)
        } else {
            // probably unreachable? populates empty values if the question isn't present.
            data.append("") // pad commas
            data.append("")
            data.append("")
            data.append("")
            data.append(forcedValue != nil ? forcedValue! : "")
        }
        data.append(event)
        // print("TimingsEvent: \(data.joined(separator: ","))")  // we don't need to see every timings event
        self.surveyTimingsFile?.store(data)
    }
    
    // very poorly named, records survey dismissal I think.
    func possiblyAddUnpresent() {
        self.valueChangeHandler?.flush() // force the debouncer to fire
        self.valueChangeHandler = nil
        if let currentQuestion = currentQuestion {
            // write a timings event that card has been dismissed?
            self.addTimingsEvent("unpresent", question: currentQuestion)
            self.currentQuestion = nil
        }
    }
    
    // TODO: test if this is our only exit point from having a survey open and visible, we need to
    // now add the data storage reset calls
    func closeSurvey() {
        self.retainSelf = nil // clear the reference to self...
        self.surveyTimingsFile?.reset()
        StudyManager.sharedInstance.surveysUpdatedEvent.emit(0) // also unknown
        self.parent?.dismiss(animated: true, completion: nil) // dismiss the researchkit survey
    }
    
    // very simple pseudo json array
    func arrayAnswer(_ array: [String]) -> String {
        return "[" + array.joined(separator: ";") + "]"
    }
    
    /////////////////////////////////////////////////////////////// ORK Delegates ///////////////////////////////////////////////////////////////////
    
    // function that sets up necessary state for implementing required questions
    func handleRequiredQuestion(_ stepViewController: ORKStepViewController, _ identifier: String) {
        // the isEnabled and isHidden properties for the continue and skip buttons are both os version blocked
        // (16 and 15, respectively) .... and isenabled doesn't do anything?
        if identifier != "finished", let question = questionIdToQuestion[identifier] {
            // InformationText questions cannot be required and do not have skip buttons.
            if question.required && question.questionType != SurveyQuestionType.InformationText {
                // TODO: fix this bug, maybe it is specific to
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
                if let some_answer = self.activeSurvey?.bwAnswers[identifier], some_answer != "", some_answer != NO_ANSWER_SELECTED {
                    stepViewController.continueButtonItem = self.the_continue_button
                    stepViewController.internalContinueButtonItem = self.the_internal_continue_button
                } else {
                    stepViewController.continueButtonItem = nil
                    stepViewController.internalContinueButtonItem = nil
                }
            }
        }
    }
    
    // called when the card is dismissed (including cancel button - end task menu item)
    // called when survey done button is pressed
    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        // print("\ntaskViewController 1 \(taskViewController.currentStepViewController?.step?.identifier)\n")
        if let identifier = taskViewController.currentStepViewController?.step?.identifier {
            self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        }
        
        self.possiblyAddUnpresent()
        if !self.isComplete {
            self.activeSurvey?.rkAnswers = taskViewController.restorationData
            if let study = StudyManager.sharedInstance.currentStudy {
                Recline.shared.save(study)
                log.info("Tracking survey Saved.")
            }
        }
        self.closeSurvey()
    }
    
    // called when done, back, or next button is pressed
    // called when input occurs - but
    // NOT called when skip is pressed
    func taskViewController(_ taskViewController: ORKTaskViewController, didChange result: ORKTaskResult) {
        // print("\ntaskViewController 2 \(taskViewController.currentStepViewController?.step?.identifier)\n")
        // update the answer data for this question
        if let identifier = taskViewController.currentStepViewController!.step?.identifier {
            self.storeAnswer(identifier, result: result)
            let currentValue = self.activeSurvey!.bwAnswers[identifier]
            self.valueChangeHandler?.call(currentValue)
            // needs to be called after the question answer has been updated
            self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        }
    }
    
    // called once when any survey card is displayed - actually I think it is when it is closed/left
    // called when back button is pressed
    func taskViewController(_ taskViewController: ORKTaskViewController, shouldPresent step: ORKStep) -> Bool {
        // print("\ntaskViewController 3 \(taskViewController.currentStepViewController?.step?.identifier)\n")
        if let identifier = taskViewController.currentStepViewController?.step?.identifier {
            self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        }
        self.possiblyAddUnpresent()
        return true
    }
    
    // (called when any survey card is displayed)
    // called when back button is pressed, once with the 'current' question, once with the previous question
    // called when next/skip button is pressed, once with the 'current' question, once with the next question
    // called when survey is initially opened, once with nil and once with a question id (possibly differs if you don't have an informational text box question)
    func taskViewController(_ taskViewController: ORKTaskViewController, hasLearnMoreFor step: ORKStep) -> Bool {
        // print("\ntaskViewController 4 \(taskViewController.currentStepViewController?.step?.identifier)\n")
        if let identifier = taskViewController.currentStepViewController?.step?.identifier {
            self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        }
        return false
    }

    // (called when any survey card is displayed - twice. 🙃)
    // called when back button is pressed, once with the 'current' question, BUT TWICE with the previous question
    // called when next/skip button is pressed, once with the 'current' question, BUT TWICE with the next question
    func taskViewController(_ taskViewController: ORKTaskViewController, viewControllerFor step: ORKStep) -> ORKStepViewController? {
        // print("\ntaskViewController 5 \(taskViewController.currentStepViewController?.step?.identifier)\n")
        if let identifier = taskViewController.currentStepViewController?.step?.identifier {
            self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        }
        return nil
    }
    
    // (called when any survey card is displayed)
    // called when back button is pressed, once with the 'current' question, once with the previous question
    // called when next/skip button is pressed, once with the 'current' question, once with the next question
    // called when you hit the cancel button
    func taskViewControllerSupportsSaveAndRestore(_ taskViewController: ORKTaskViewController) -> Bool {
        // print("\ntaskViewController 6 \(taskViewController.currentStepViewController?.step?.identifier)\n")
        if let identifier = taskViewController.currentStepViewController?.step?.identifier {
            self.handleRequiredQuestion(taskViewController.currentStepViewController!, identifier)
        }
        return false
    }

    // (called when any survey card is displayed)
    // called when back button is pressed, once with the 'current' question, once with the previous question
    // called when next/skip button is pressed, once with the 'current' question, once with the next question
    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        // print("\ntaskViewController 7 \(taskViewController.currentStepViewController?.step?.identifier)\n")
        
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
        
        if let identifier = stepViewController.step?.identifier { // question identifier is all we need
            // run the required questions logic first
            self.handleRequiredQuestion(stepViewController, identifier)
            
            switch identifier {
            case "finished":
                // executed when the card with the finished survey button is _loaded_ - not when the done button is pressed
                // ... but this code does not actually clear the survey, even though it submits it.
                self.addTimingsEvent("submitted", question: nil)
                StudyManager.sharedInstance.submitSurvey(self.activeSurvey!, surveyPresenter: self)
                self.activeSurvey?.rkAnswers = taskViewController.restorationData
                self.activeSurvey?.isComplete = true
                self.isComplete = true
                StudyManager.sharedInstance.updateActiveSurveys(true)
                stepViewController.cancelButtonItem = nil
                // stepViewController.backButtonItem = nil // this doesn't do anything
            
            default:
                // load the question
                if let question = questionIdToQuestion[identifier] {
                    self.currentQuestion = question
                    if self.activeSurvey?.bwAnswers[identifier] == nil {
                        self.activeSurvey?.bwAnswers[identifier] = ""
                    }
                    
                    var currentValue = self.activeSurvey!.bwAnswers[identifier]
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
                    stepViewController.continueButtonTitle = NSLocalizedString("submit_survey_title", comment: "")
                }
            }
        }
    }
    
    deinit {
        self.surveyTimingsFile?.reset()
        self.the_continue_button = nil
        self.the_internal_continue_button = nil
    }
}
