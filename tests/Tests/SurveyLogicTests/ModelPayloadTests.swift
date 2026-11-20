import XCTest
import ObjectMapper
@testable import SurveyQuestionDisplayLogic

private func loadSurveys() -> [Survey] {
    Mapper<Survey>().mapArray(JSONObject: loadFixture("survey_download_payload"))!
}

private func loadSettings() -> StudySettings {
    Mapper<StudySettings>().map(JSON: loadFixture("device_settings_payload") as! [String: Any])!
}

/// a slider bound (`min`/`max`) as the survey model parses it
private func transformedInt(_ value: Any?) -> Int? {
    transformJsonStringInt.transformFromJSON(value)
}

// MARK: - Survey payload (shape: llm/contracts-surveys.md)

class SurveyPayloadTests: UnbufferedTestCase {

    func testTrackingSurveyFields() {
        let s = loadSurveys()
        XCTAssertEqual(s.count, 3)
        let t = s[0]
        XCTAssertEqual(t.surveyId, "aaaaaaaaaaaaaaaaaaaaaaa1")
        XCTAssertEqual(t.surveyType, .TrackingSurvey)
        XCTAssertEqual(t.name, "Invented daily mood")
        XCTAssertEqual(t.timings, [[], [32400], [32400], [], [], [], [3600, 7200]])
        XCTAssertTrue(t.triggerOnFirstDownload)
        XCTAssertFalse(t.alwaysAvailable)
        XCTAssertTrue(t.randomize)
        XCTAssertEqual(t.numberOfRandomQuestions, 2)
        XCTAssertTrue(t.randomizeWithMemory)
        // audio defaults when absent
        XCTAssertEqual(t.audioSurveyType, "compressed")
        XCTAssertEqual(t.audioSampleRate, 44100)
        XCTAssertEqual(t.audioBitrate, 64000)
    }

    func testTrackingQuestions() {
        let q = loadSurveys()[0].questions
        XCTAssertEqual(q.count, 3)
        XCTAssertEqual(q[0].questionType, .Slider)
        XCTAssertEqual(q[0].prompt, "How do you feel?")
        XCTAssertEqual(q[0].minValue, 1)   // server sends ints as strings
        XCTAssertEqual(q[0].maxValue, 10)
        XCTAssertTrue(q[0].required)
        XCTAssertEqual(q[1].questionType, .RadioButton)
        XCTAssertEqual(q[1].selectionValues.map { $0.text }, ["red", "blue"])
        XCTAssertFalse(q[1].required)
        XCTAssertEqual(q[2].textFieldType, .Numeric)
        XCTAssertNil(q[2].minValue)  // "" -> nil
        XCTAssertNil(q[2].maxValue)
        XCTAssertNotNil(q[2].displayIf?["and"])
        XCTAssertNil(q[0].displayIf)
    }

    func testAudioSurveyFields() {
        let a = loadSurveys()[1]
        XCTAssertEqual(a.surveyType, .AudioSurvey)
        XCTAssertEqual(a.audioSurveyType, "raw")
        XCTAssertEqual(a.audioSampleRate, 22050)
        XCTAssertEqual(a.audioBitrate, 32000)
        XCTAssertEqual(a.questions.count, 1)
        XCTAssertEqual(a.questions[0].prompt, "Say something.")
        XCTAssertNil(a.numberOfRandomQuestions)
        XCTAssertFalse(a.randomize)
    }

    // pins BS16: negative number_of_random_questions isn't validated, flip when fixed
    func testNegativeRandomQuestionCount_currentBehavior_BS16() {
        let s = loadSurveys()[2]
        XCTAssertTrue(s.randomize)
        XCTAssertEqual(s.numberOfRandomQuestions, -3)
        XCTAssertTrue(s.alwaysAvailable)
    }
}

// MARK: - Device settings payload (shape: llm/contracts-storage.md)

class StudySettingsPayloadTests: UnbufferedTestCase {

    func testDeviceSettingsFields() {
        let s = loadSettings()
        XCTAssertEqual(s.clientPublicKey, "INVENTED-PUBLIC-KEY-BASE64")
        XCTAssertEqual(s.aboutPageText, "About this invented study.")
        XCTAssertTrue(s.accelerometer)
        XCTAssertEqual(s.accelerometerOffDurationSeconds, 120)
        XCTAssertEqual(s.accelerometerOnDurationSeconds, 60)
        XCTAssertEqual(s.accelerometerFrequency, 5)
        XCTAssertEqual(s.callClinicianText, "Call Invented Clinician")
        XCTAssertEqual(s.checkForNewSurveysFreqSeconds, 1800)
        XCTAssertEqual(s.consentFormText, "Invented consent text.")
        XCTAssertEqual(s.createNewDataFileFrequencySeconds, 600)
        XCTAssertTrue(s.gps)
        XCTAssertEqual(s.gpsOffDurationSeconds, 30)
        XCTAssertEqual(s.gpsOnDurationSeconds, 15)
        XCTAssertTrue(s.powerState)
        XCTAssertEqual(s.secondsBeforeAutoLogout, 900)
        XCTAssertEqual(s.submitSurveySuccessText, "Thanks (invented).")
        XCTAssertEqual(s.uploadDataFileFrequencySeconds, 7200)
        XCTAssertEqual(s.voiceRecordingMaxLengthSeconds, 90)
        XCTAssertTrue(s.wifi)
        XCTAssertEqual(s.wifiLogFrequencySeconds, 450)
        XCTAssertTrue(s.proximity)
        XCTAssertTrue(s.magnetometer)
        XCTAssertEqual(s.magnetometerOffDurationSeconds, 11)
        XCTAssertEqual(s.magnetometerOnDurationSeconds, 12)
        XCTAssertTrue(s.gyro)
        XCTAssertEqual(s.gyroOffDurationSeconds, 13)
        XCTAssertEqual(s.gyroOnDurationSeconds, 14)
        XCTAssertEqual(s.gyroFrequency, 6)
        XCTAssertTrue(s.motion)  // server key is "devicemotion"
        XCTAssertEqual(s.motionOffDurationSeconds, 15)
        XCTAssertEqual(s.motionOnDurationSeconds, 16)
        XCTAssertTrue(s.reachability)
        XCTAssertEqual(s.consentSections.count, 1)
        XCTAssertEqual(s.consentSections["overview"]?.text, "Invented overview")
        XCTAssertEqual(s.consentSections["overview"]?.more, "Invented more")
        XCTAssertTrue(s.uploadOverCellular)
        XCTAssertTrue(s.fuzzGps)
        XCTAssertFalse(s.callClinicianButtonEnabled)
        XCTAssertFalse(s.callResearchAssistantButtonEnabled)
    }

    func testFirebasePlistFields() {
        let s = loadSettings()
        XCTAssertEqual(s.clientID, "invented-client-id")
        XCTAssertEqual(s.reversedClientID, "invented-reversed")
        XCTAssertEqual(s.apiKey, "invented-api-key")
        XCTAssertEqual(s.gcmSenderID, "123456789")
        XCTAssertEqual(s.plistVersion, 1)
        XCTAssertEqual(s.bundleID, "invented.bundle.id")
        XCTAssertEqual(s.projectID, "invented-project")
        XCTAssertEqual(s.storageBucket, "invented.appspot.com")
        XCTAssertFalse(s.isAdsEnabled)
        XCTAssertTrue(s.isAnalyticsEnabled)
        XCTAssertFalse(s.isAppInviteEnabled)
        XCTAssertFalse(s.isGcmEnabled)
        XCTAssertFalse(s.isSignInEnabled)
        XCTAssertEqual(s.googleAppID, "1:123:ios:abc")
        XCTAssertEqual(s.databaseURL, "https://invented.firebaseio.com")
    }

    func testMissingKeysKeepDefaults() {
        let s = Mapper<StudySettings>().map(JSON: ["device_settings": ["gps": true]])!
        XCTAssertTrue(s.gps)
        XCTAssertEqual(s.gpsOnDurationSeconds, 0)
        XCTAssertEqual(s.gpsOffDurationSeconds, 300)
        XCTAssertEqual(s.uploadDataFileFrequencySeconds, 3600)
        XCTAssertNil(s.clientPublicKey)
        XCTAssertTrue(s.isGcmEnabled)
        XCTAssertEqual(s.googleAppID, "")
    }
}

// MARK: - Study persistence round trip

class StudyRoundTripTests: UnbufferedTestCase {

    private func makeStudy() -> Study {
        let study = Study(patientPhone: "5550100", patientId: "abc123", studySettings: loadSettings(), apiUrl: "https://example.invalid")
        study.participantConsented = true
        study.nextSurveyCheck = 111
        study.nextUploadCheck = 222
        study.submittedAudioSurveys = 3
        study.surveys = loadSurveys()
        return study
    }

    func testRoundTripPreservesOrdinaryFields() {
        let study = makeStudy()
        let back = Mapper<Study>().map(JSON: Mapper<Study>().toJSON(study))!
        XCTAssertEqual(back.patientPhoneNumber, "5550100")
        XCTAssertEqual(back.patientId, "abc123")
        XCTAssertEqual(back.customApiUrl, "https://example.invalid")
        XCTAssertTrue(back.participantConsented)
        XCTAssertEqual(back.nextSurveyCheck, 111)
        XCTAssertEqual(back.nextUploadCheck, 222)
        XCTAssertEqual(back.submittedAudioSurveys, 3)
        XCTAssertEqual(back.surveys.count, 3)
        XCTAssertEqual(back.surveys[0].questions.count, 3)
        XCTAssertEqual(back.studySettings?.gpsOnDurationSeconds, 15)
        XCTAssertEqual(back.studySettings?.clientPublicKey, "INVENTED-PUBLIC-KEY-BASE64")
        XCTAssertEqual(back.studySettings?.googleAppID, "1:123:ios:abc")
    }

    // pins BS10: surveyPushNotificationUUIDs is mapped to the "lastApplicationWillTerminate" key (Study.swift:74-75), flip when fixed
    func testKeySlip_currentBehavior_BS10() {
        let study = makeStudy()
        study.surveyPushNotificationUUIDs = ["u1", "u2"]
        study.lastApplicationWillTerminate = "2026-01-01 terminated"
        let json = Mapper<Study>().toJSON(study)
        // later mapping wins, the key holds the uuid array
        XCTAssertEqual(json["lastApplicationWillTerminate"] as? [String], ["u1", "u2"])
        XCTAssertNil(json["surveyPushNotificationUUIDs"])
        let back = Mapper<Study>().map(JSON: json)!
        XCTAssertEqual(back.surveyPushNotificationUUIDs, ["u1", "u2"])
        // the string is lost on reload
        XCTAssertEqual(back.lastApplicationWillTerminate, "never_populated")
    }

    // pins BS10: with no uuids the string under the slipped key survives, flip when fixed
    func testKeySlipStringValueIsNotAUuidList_currentBehavior_BS10() {
        let study = makeStudy()
        study.lastApplicationWillTerminate = "some string"
        let json = Mapper<Study>().toJSON(study)
        XCTAssertEqual(json["lastApplicationWillTerminate"] as? String, "some string")  // nil uuids emit no key
        let back = Mapper<Study>().map(JSON: json)!
        XCTAssertEqual(back.lastApplicationWillTerminate, "some string")
        XCTAssertNil(back.surveyPushNotificationUUIDs)
    }

    // pins BS10: nextDeviceSettingsCheck isn't in the mapping, flip when fixed
    func testNextDeviceSettingsCheckNotPersisted_currentBehavior_BS10() {
        let study = makeStudy()
        study.nextDeviceSettingsCheck = 99999
        let json = Mapper<Study>().toJSON(study)
        XCTAssertNil(json["nextDeviceSettingsCheck"])
        XCTAssertNil(Mapper<Study>().map(JSON: json)!.nextDeviceSettingsCheck)
    }

    // pins BS10: nil optionals are omitted from toJSON instead of written as null, flip when fixed
    func testNilFieldOmittedFromJson_currentBehavior_BS10() {
        let study = makeStudy()
        study.customApiUrl = nil
        study.nextSurveyCheck = nil
        let json = Mapper<Study>().toJSON(study)
        XCTAssertFalse(json.keys.contains("customApiUrl"))
        XCTAssertFalse(json.keys.contains("nextSurveyCheck"))
        let back = Mapper<Study>().map(JSON: json)!
        XCTAssertNil(back.customApiUrl)
        XCTAssertNil(back.nextSurveyCheck)
    }

    func testRemappingOverExistingObjectKeepsStaleValueWhenKeyAbsent() {
        // follows from omit-nil: an absent key doesn't clear the live value
        let study = makeStudy()
        let json = ["patientId": "abc123"] as [String: Any]
        _ = Mapper<Study>().map(JSON: json, toObject: study)
        XCTAssertEqual(study.customApiUrl, "https://example.invalid")
        XCTAssertEqual(study.nextSurveyCheck, 111)
    }
}

/// Android getInt truncates decimals and coerces numeric strings; slider bounds depend on it.
class JsonStringIntTransformTests: UnbufferedTestCase {

    // BS24: a slider with bounds "1.5" to "5.5" showed 1 to 10; Android's getInt truncates them to 1 to 5
    func testDecimalBoundsTruncateTowardZero() {
        AssertEqual(transformedInt("1.5"), 1)
        AssertEqual(transformedInt("5.5"), 5)
        AssertEqual(transformedInt(5.5), 5)
        AssertEqual(transformedInt(-1.5), -1)
    }

    // whole-number bounds, sent as numbers or strings, must still parse after the decimal handling was added
    func testWholeNumberBoundsParse() {
        AssertEqual(transformedInt(5), 5)
        AssertEqual(transformedInt("5"), 5)
    }

    // double-encoded survey content can leave quote characters in a bound; stripped like display-logic values (BS23)
    func testQuotedBoundsParseLikeUnquoted() {
        AssertEqual(transformedInt("\"5\""), 5)
        AssertEqual(transformedInt("'5'"), 5)
        AssertEqual(transformedInt(" \" 1.5 \" "), 1)
        AssertNil(transformedInt("\"abc\""))
        AssertNil(transformedInt("\"\""))
    }

    // "nan" and "1e400" parse as Double but would crash Int(); they and other junk must be nil (slider default range)
    func testUnparseableBoundsAreNil() {
        AssertNil(transformedInt(""))
        AssertNil(transformedInt("abc"))
        AssertNil(transformedInt("nan"))
        AssertNil(transformedInt("1e400"))
        AssertNil(transformedInt(nil))
    }
}
