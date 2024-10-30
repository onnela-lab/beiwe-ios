import Foundation
import ObjectMapper

class Study: ReclineObject {
    // StudySettings is (probably?) saved recursively as it is a mappable - if that's how Recline works
    var studySettings: StudySettings?
    
    // constants (these should not change after registration)
    var participantConsented: Bool = false
    var patientId: String?
    var patientPhoneNumber: String = "" // uh, I don't think this is used?
    var clinicianPhoneNumber: String?
    var raPhoneNumber: String?
    var customApiUrl: String?
    var fuzzGpsLongitudeOffset: Double = 0.0
    var fuzzGpsLatitudeOffset: Double = 0.0
    var registerDate: Int64?
    
    // app state
    var nextUploadCheck: Int64?
    var nextSurveyCheck: Int64?
    var nextDeviceSettingsCheck: Int64?
    var lastBadgeCnt = 0
    var submittedAudioSurveys: Int = 0 // TODO: what is this and is it breaking uploads
    var submittedTrackingSurveys: Int = 0 // TODO: what is this and is it breaking uploads
    var surveyPushNotificationUUIDs: [String]?
    
    // app state tracking - default value is "never_populated"
    var lastBackgroundPushNotificationReceived = Constants.DEFAULT_UNPOPULATED_APPINFO
    var lastForegroundPushNotificationReceived = Constants.DEFAULT_UNPOPULATED_APPINFO
    var lastApplicationWillTerminate = Constants.DEFAULT_UNPOPULATED_APPINFO
    
    // Survey app state
    var surveys: [Survey] = []
    var activeSurveys: [String: ActiveSurvey] = [:]

    init(patientPhone: String, patientId: String, studySettings: StudySettings, apiUrl: String?) {
        super.init()
        self.patientPhoneNumber = patientPhone
        self.studySettings = studySettings
        self.patientId = patientId
        self.registerDate = Int64(Date().timeIntervalSince1970)
        self.customApiUrl = apiUrl
    }

    required init?(map: Map) {
        super.init(map: map)
    }

    // Mappable
    override func mapping(map: Map) {
        super.mapping(map: map)
        self.patientPhoneNumber <- map["phoneNumber"]
        self.studySettings <- map["studySettings"]
        self.patientId <- map["patientId"]
        self.participantConsented <- map["participantConsented"]
        self.clinicianPhoneNumber <- map["clinicianPhoneNumber"]
        self.raPhoneNumber <- map["raPhoneNumber"]
        self.nextSurveyCheck <- (map["nextSurveyCheck"], TransformOf<Int64, NSNumber>(fromJSON: { $0?.int64Value }, toJSON: { $0.map { NSNumber(value: $0) } }))
        self.nextUploadCheck <- (map["nextUploadCheck"], TransformOf<Int64, NSNumber>(fromJSON: { $0?.int64Value }, toJSON: { $0.map { NSNumber(value: $0) } }))
        self.surveys <- map["surveys"]
        self.activeSurveys <- map["active_surveys"]
        self.registerDate <- (map["registerDate"], TransformOf<Int64, NSNumber>(fromJSON: { $0?.int64Value }, toJSON: { $0.map { NSNumber(value: $0) } }))
        self.submittedAudioSurveys <- map["submittedAudioSurveys"]
        self.submittedTrackingSurveys <- map["submittedTrackingSurveys"]
        self.customApiUrl <- map["customApiUrl"]
        self.fuzzGpsLongitudeOffset <- map["fuzzGpsLongitudeOffset"]
        self.fuzzGpsLatitudeOffset <- map["fuzzGpsLatitudeOffset"]
        
        // this is so stupid. The way this works and What On Earth Recline is and how this mapping function I define could even possibly
        // magically be a 2-way binding for data simply isn't documented anywhere.  It just magically exists and is saved without explanaition.
        self.lastBackgroundPushNotificationReceived <- map["lastBackgroundPushNotificationReceived"]
        self.lastForegroundPushNotificationReceived <- map["lastForegroundPushNotificationReceived"]
        self.lastApplicationWillTerminate <- map["lastApplicationWillTerminate"]
        self.surveyPushNotificationUUIDs <- map["lastApplicationWillTerminate"]
    }

    func surveyExists(surveyId: String?) -> Bool {
        for survey in self.surveys {
            if survey.surveyId == surveyId {
                return true
            }
        }
        return false
    }

    func getSurvey(surveyId: String?) -> Survey? {
        for survey in self.surveys {
            if survey.surveyId == surveyId {
                return survey
            }
        }
        return nil
    }
}
