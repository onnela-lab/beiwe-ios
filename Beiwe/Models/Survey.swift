import Foundation
import ObjectMapper

enum SurveyTypes: String {
    case AudioSurvey = "audio_survey"
    case TrackingSurvey = "tracking_survey"
}

struct Survey: Mappable, Equatable {
    var surveyId: String?
    var surveyType: SurveyTypes?
    var name = ""
    var timings: [[Int]] = []
    var triggerOnFirstDownload: Bool = false
    var randomize: Bool = false
    var numberOfRandomQuestions: Int?
    var randomizeWithMemory: Bool = false
    var questions: [GenericSurveyQuestion] = []
    var audioSurveyType: String = "compressed"
    var audioSampleRate = 44100
    var audioBitrate = 64000
    var alwaysAvailable = false

    init?(map: Map) {}

    // Mappable
    mutating func mapping(map: Map) {
        self.surveyId <- map["_id"]
        self.surveyType <- map["survey_type"]
        self.name <- map["name"]
        self.timings <- map["timings"]
        self.triggerOnFirstDownload <- map["settings.trigger_on_first_download"]
        self.randomize <- map["settings.randomize"]
        self.numberOfRandomQuestions <- map["settings.number_of_random_questions"]
        self.randomizeWithMemory <- map["settings.randomize_with_memory"]
        self.audioSurveyType <- map["settings.audio_survey_type"]
        self.audioSampleRate <- map["settings.sample_rate"]
        self.audioBitrate <- map["settings.bit_rate"]
        self.questions <- map["content"]
        self.alwaysAvailable <- map["settings.always_available"]
    }
    
    static func == (lhs: Survey, rhs: Survey) -> Bool {
        let surveyId_unchanged = lhs.surveyId == rhs.surveyId
        let surveyType_unchanged = lhs.surveyType == rhs.surveyType
        let name_unchanged = lhs.name == rhs.name
        let timings_unchanged = lhs.timings == rhs.timings
        let triggerOnFirstDownload_unchanged = lhs.triggerOnFirstDownload == rhs.triggerOnFirstDownload
        let randomize_unchanged = lhs.randomize == rhs.randomize
        let numberOfRandomQuestions_unchanged = lhs.numberOfRandomQuestions == rhs.numberOfRandomQuestions
        let randomizeWithMemory_unchanged = lhs.randomizeWithMemory == rhs.randomizeWithMemory
        let questions_unchanged = lhs.questions == rhs.questions
        let audioSurveyType_unchanged = lhs.audioSurveyType == rhs.audioSurveyType
        let audioSampleRate_unchanged = lhs.audioSampleRate == rhs.audioSampleRate
        let audioBitrate_unchanged = lhs.audioBitrate == rhs.audioBitrate
        let alwaysAvailable_unchanged = lhs.alwaysAvailable == rhs.alwaysAvailable
        
        if !surveyId_unchanged { print(lhs.surveyId, "!=", rhs.surveyId) }
        if !surveyType_unchanged { print(lhs.surveyType, "!=", rhs.surveyType) }
        if !name_unchanged { print(lhs.name, "!=", rhs.name) }
        if !timings_unchanged { print(lhs.timings, "!=", rhs.timings) }
        if !triggerOnFirstDownload_unchanged { print(lhs.triggerOnFirstDownload, "!=", rhs.triggerOnFirstDownload) }
        if !randomize_unchanged { print(lhs.randomize, "!=", rhs.randomize) }
        if !numberOfRandomQuestions_unchanged { print(lhs.numberOfRandomQuestions, "!=", rhs.numberOfRandomQuestions) }
        if !randomizeWithMemory_unchanged { print(lhs.randomizeWithMemory, "!=", rhs.randomizeWithMemory) }
        if !questions_unchanged { print(lhs.questions, "!=", rhs.questions) }
        if !audioSurveyType_unchanged { print(lhs.audioSurveyType, "!=", rhs.audioSurveyType) }
        if !audioSampleRate_unchanged { print(lhs.audioSampleRate, "!=", rhs.audioSampleRate) }
        if !audioBitrate_unchanged { print(lhs.audioBitrate, "!=", rhs.audioBitrate) }
        if !alwaysAvailable_unchanged { print(lhs.alwaysAvailable, "!=", rhs.alwaysAvailable) }
        
        return surveyId_unchanged &&
            surveyType_unchanged &&
            name_unchanged &&
            timings_unchanged &&
            triggerOnFirstDownload_unchanged &&
            randomize_unchanged &&
            numberOfRandomQuestions_unchanged &&
            randomizeWithMemory_unchanged &&
            questions_unchanged &&
            audioSurveyType_unchanged &&
            audioSampleRate_unchanged &&
            audioBitrate_unchanged &&
            alwaysAvailable_unchanged
    }
}
