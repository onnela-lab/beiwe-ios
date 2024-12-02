import Foundation
import ObjectMapper

/* Example JSON:  (uuseful but this is quite old, there are new keys.  you get the idea tho.)
 { client_public_key: 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn4ynh9zr7TZJBDoWx9TB78Mo7mAL4hSoLPEEGoZdEffvpKcXmY6qZOzXU6CzODts/3XXbqFHQrPKY9EnaumifeKpzIJZDRf6jUZD5SOFACLTH6u6+/2KiZKaGJ591GJTH4r/1LxvvIEAr2XxK9qx49RKlBl3dGPYn+7079wzV9mhdrYbqLgJCgZr0TqSiJvVYbGDuESnPZ5/1doAaFWnL8JILHv/Hf6HBTroePZmEsu00r2PQiEURtUWt76auccwKPzG+I6wqKfFR4o4uUovAZjxUledpvucXwOi10jCVK70MEVUTGKYp6/m2LyEdtGrKImMja/sAuoMU9qlaNPsaQIDAQAB',
 device_settings:
 { about_page_text: 'The Beiwe application runs on your phone and helps researchers ...',
 accelerometer: true,
 accelerometer_off_duration_seconds: 300,
 accelerometer_on_duration_seconds: 300,
 bluetooth: true,
 bluetooth_global_offset_seconds: 150,
 bluetooth_on_duration_seconds: 300,
 bluetooth_total_duration_seconds: 0,
 call_clinician_button_text: 'Call My Clinician',
 calls: true,
 check_for_new_surveys_frequency_seconds: 21600,
 consent_form_text: ' I have read and understood ....',
 create_new_data_files_frequency_seconds: 900,
 gps: true,
 gps_off_duration_seconds: 300,
 gps_on_duration_seconds: 300,
 power_state: true,
 seconds_before_auto_logout: 300,
 survey_submit_success_toast_text: 'Thank you for completing the survey....',
 texts: true,
 upload_data_files_frequency_seconds: 3600,
 voice_recording_max_time_length_seconds: 300,
 wifi: true,
 wifi_log_frequency_seconds: 300 } } */

struct ConsentSection: Mappable, Equatable {
    init?(map: Map) {}
    
    var text: String = ""
    var more: String = ""

    // Mappable
    mutating func mapping(map: Map) {
        text <- map["text"]
        more <- map["more"]
    }
    
    /// conform to the Equatable protocol, of type ConsentSection, for use in updating device settings.
    static func ==(lhs: ConsentSection, rhs: ConsentSection) -> Bool {
        return lhs.text == rhs.text && lhs.more == rhs.more
    }
    
}

struct StudySettings: Mappable {
    init?(map: Map) {}

    // Disabled non-ios keys (data streams) htat we don't need to import
    // var calls = false
    // var texts = false

    // DEFAULT VALUES for parameters received from the server at registration
    
    // Participant detail
    var clientPublicKey: String?

    // Study settings
    var checkForNewSurveysFreqSeconds = 21600
    var createNewDataFileFrequencySeconds = 900
    var secondsBeforeAutoLogout = 300
    var uploadDataFileFrequencySeconds = 3600
    var voiceRecordingMaxLengthSeconds = 300
    var uploadOverCellular = false
    var callClinicianButtonEnabled = true
    var callResearchAssistantButtonEnabled = true

    // text strings
    var aboutPageText = ""
    var callClinicianText = "Call My Clinician"
    var consentFormText = "I have read and understood the information about the study and all of my questions about the study have been answered by the study researchers."
    var submitSurveySuccessText = "Thank you for completing the survey.  A clinician will not see your answers immediately, so if you need help or are thinking about harming yourself, please contact your clinician.  You can also press the \"Call My Clinician\" button."
    var consentSections: [String: ConsentSection] = [:]  // this is an encoded json list of strings. (why?)

    // DATA STREAMS
    // Accelerometer
    var accelerometer = false
    var accelerometerOffDurationSeconds = 300
    var accelerometerOnDurationSeconds = 0
    var accelerometerFrequency = 10
    // GPS data
    var gps = false
    var gpsOffDurationSeconds = 300
    var gpsOnDurationSeconds = 0
    var fuzzGps = false
    // Powerstate logging
    var powerState = false
    // wifi scans
    var wifi = false
    var wifiLogFrequencySeconds = 300
    // Proximity
    var proximity = false
    // Magnetometer
    var magnetometer = false
    var magnetometerOffDurationSeconds = 300
    var magnetometerOnDurationSeconds = 0
    // gyroscope
    var gyro = false
    var gyroOffDurationSeconds = 300
    var gyroOnDurationSeconds = 0
    var gyroFrequency = 10
    // Device motion
    var motion = false
    var motionOffDurationSeconds = 300
    var motionOnDurationSeconds = 0
    // Reachability
    var reachability = false
    // Bluetooth
    var bluetooth = false
    var bluetoothOffDurationSeconds = 300
    var bluetoothOnDurationSeconds = 60
    var bluetoothTotalDurationSeconds = 300
    var bluetoothGlobalOffsetSeconds = 0
    // Omniring
    var omniring = false
    var omniringOffDurationSeconds = 300
    var omniringOnDurationSeconds = 0

    // firebase/gcm stuff (most of this is junk we don't use)
    var gcmSenderID = ""
    var isGcmEnabled = true
    var googleAppID = ""
    var clientID = ""
    var reversedClientID = ""
    var apiKey = ""
    var plistVersion = 1
    var bundleID = ""
    var projectID = ""
    var storageBucket = ""
    var isAdsEnabled = false
    var isAnalyticsEnabled = false
    var isAppInviteEnabled = true
    var isSignInEnabled = true
    var databaseURL = ""

    // Mappable
    mutating func mapping(map: Map) {
        // This appears to be the location where we define how to read various data sources, the study settings and the firebase creds.
        self.clientPublicKey                     <- map["client_public_key"]
        self.aboutPageText                       <- map["device_settings.about_page_text"]
        self.accelerometer                       <- map["device_settings.accelerometer"]
        self.accelerometerOffDurationSeconds     <- map["device_settings.accelerometer_off_duration_seconds"]
        self.accelerometerOnDurationSeconds      <- map["device_settings.accelerometer_on_duration_seconds"]
        self.accelerometerFrequency              <- map["device_settings.accelerometer_frequency"]
        self.bluetooth                           <- map["device_settings.bluetooth"]
        self.bluetoothGlobalOffsetSeconds        <- map["device_settings.bluetooth_global_offset_seconds"]
        self.bluetoothOnDurationSeconds          <- map["device_settings.bluetooth_on_duration_seconds"]
        self.bluetoothTotalDurationSeconds       <- map["device_settings.bluetooth_total_duration_seconds"]
        self.omniring                            <- map["device_settings.omniring"]
        self.omniringOffDurationSeconds          <- map["device_settings.omniring_off_duration_seconds"]
        self.omniringOnDurationSeconds           <- map["device_settings.omniring_on_duration_seconds"]
        self.callClinicianText                   <- map["device_settings.call_clinician_button_text"]
        // self.calls                               <- map["device_settings.calls"]
        self.checkForNewSurveysFreqSeconds       <- map["device_settings.check_for_new_surveys_frequency_seconds"]
        self.consentFormText                     <- map["device_settings.consent_form_text"]
        self.createNewDataFileFrequencySeconds   <- map["device_settings.create_new_data_files_frequency_seconds"]
        self.gps                                 <- map["device_settings.gps"]
        self.gpsOffDurationSeconds               <- map["device_settings.gps_off_duration_seconds"]
        self.gpsOnDurationSeconds                <- map["device_settings.gps_on_duration_seconds"]
        self.powerState                          <- map["device_settings.power_state"]
        self.secondsBeforeAutoLogout             <- map["device_settings.seconds_before_auto_logout"]
        self.submitSurveySuccessText             <- map["device_settings.survey_submit_success_toast_text"]
        // self.texts                               <- map["device_settings.texts"]
        self.uploadDataFileFrequencySeconds      <- map["device_settings.upload_data_files_frequency_seconds"]
        self.voiceRecordingMaxLengthSeconds      <- map["device_settings.voice_recording_max_time_length_seconds"]
        self.wifi                                <- map["device_settings.wifi"]
        self.wifiLogFrequencySeconds             <- map["device_settings.wifi_log_frequency_seconds"]
        self.proximity                           <- map["device_settings.proximity"]
        self.magnetometer                        <- map["device_settings.magnetometer"]
        self.magnetometerOffDurationSeconds      <- map["device_settings.magnetometer_off_duration_seconds"]
        self.magnetometerOnDurationSeconds       <- map["device_settings.magnetometer_on_duration_seconds"]
        self.gyro                                <- map["device_settings.gyro"]
        self.gyroOffDurationSeconds              <- map["device_settings.gyro_off_duration_seconds"]
        self.gyroOnDurationSeconds               <- map["device_settings.gyro_on_duration_seconds"]
        self.gyroFrequency                       <- map["device_settings.gyro_frequency"]
        self.motion                              <- map["device_settings.devicemotion"]
        self.motionOffDurationSeconds            <- map["device_settings.devicemotion_off_duration_seconds"]
        self.motionOnDurationSeconds             <- map["device_settings.devicemotion_on_duration_seconds"]
        self.reachability                        <- map["device_settings.reachability"]
        self.consentSections                     <- map["device_settings.consent_sections"]
        self.uploadOverCellular                  <- map["device_settings.allow_upload_over_cellular_data"]
        self.fuzzGps                             <- map["device_settings.use_gps_fuzzing"]
        self.callClinicianButtonEnabled          <- map["device_settings.call_clinician_button_enabled"]
        self.callResearchAssistantButtonEnabled  <- map["device_settings.call_research_assistant_button_enabled"]
        // firebase details
        self.clientID                            <- map["ios_plist.CLIENT_ID"]
        self.reversedClientID                    <- map["ios_plist.REVERSED_CLIENT_ID"]
        self.apiKey                              <- map["ios_plist.API_KEY"]
        self.gcmSenderID                         <- map["ios_plist.GCM_SENDER_ID"]
        self.plistVersion                        <- map["ios_plist.PLIST_VERSION"]
        self.bundleID                            <- map["ios_plist.BUNDLE_ID"]
        self.projectID                           <- map["ios_plist.PROJECT_ID"]
        self.storageBucket                       <- map["ios_plist.STORAGE_BUCKET"]
        self.isAdsEnabled                        <- map["ios_plist.IS_ADS_ENABLED"]
        self.isAnalyticsEnabled                  <- map["ios_plist.IS_ANALYTICS_ENABLED"]
        self.isAppInviteEnabled                  <- map["ios_plist.IS_APPINVITE_ENABLED"]
        self.isGcmEnabled                        <- map["ios_plist.IS_GCM_ENABLED"]
        self.isSignInEnabled                     <- map["ios_plist.IS_SIGNIN_ENABLED"]
        self.googleAppID                         <- map["ios_plist.GOOGLE_APP_ID"]
        self.databaseURL                         <- map["ios_plist.DATABASE_URL"]
    }
}


/// we need a Mappable for UpdateDeviceSettingsRequest, this isn't Quite a copy-paste of StudySettings, we
/// have to remove clientPublicKey and use different keys in the mapping function.
struct JustStudySettings: Mappable {
    init() {}
    init?(map: Map) {}

    // Study settings
    var checkForNewSurveysFreqSeconds = 21600
    var createNewDataFileFrequencySeconds = 900
    var secondsBeforeAutoLogout = 300
    var uploadDataFileFrequencySeconds = 3600
    var voiceRecordingMaxLengthSeconds = 300
    var uploadOverCellular = false
    var callClinicianButtonEnabled = true
    var callResearchAssistantButtonEnabled = true

    // text strings
    var aboutPageText = ""
    var callClinicianText = "Call My Clinician"
    var consentFormText = "I have read and understood the information about the study and all of my questions about the study have been answered by the study researchers."
    var submitSurveySuccessText = "Thank you for completing the survey.  A clinician will not see your answers immediately, so if you need help or are thinking about harming yourself, please contact your clinician.  You can also press the \"Call My Clinician\" button."
    var consentSections: [String: ConsentSection] = [:]  // this is an encoded json list of strings. (why?)

    // DATA STREAMS
    // Accelerometer
    var accelerometer = false
    var accelerometerOffDurationSeconds = 300
    var accelerometerOnDurationSeconds = 0
    var accelerometerFrequency = 10
    // GPS data
    var gps = false
    var gpsOffDurationSeconds = 300
    var gpsOnDurationSeconds = 0
    var fuzzGps = false
    // Powerstate logging
    var powerState = false
    // wifi scans
    var wifi = false
    var wifiLogFrequencySeconds = 300
    // Proximity
    var proximity = false
    // Magnetometer
    var magnetometer = false
    var magnetometerOffDurationSeconds = 300
    var magnetometerOnDurationSeconds = 0
    // gyroscope
    var gyro = false
    var gyroOffDurationSeconds = 300
    var gyroOnDurationSeconds = 0
    var gyroFrequency = 10
    // Device motion
    var motion = false
    var motionOffDurationSeconds = 300
    var motionOnDurationSeconds = 0
    // Reachability
    var reachability = false
    // Bluetooth
    var bluetooth = false
    var bluetoothOffDurationSeconds = 300
    var bluetoothOnDurationSeconds = 60
    var bluetoothTotalDurationSeconds = 300
    var bluetoothGlobalOffsetSeconds = 0
    // Omniring
    var omniring = false
    var omniringOffDurationSeconds = 300
    var omniringOnDurationSeconds = 0

    // Mappable
    mutating func mapping(map: Map) {
        self.aboutPageText                       <- map["about_page_text"]
        self.accelerometer                       <- map["accelerometer"]
        self.accelerometerOffDurationSeconds     <- map["accelerometer_off_duration_seconds"]
        self.accelerometerOnDurationSeconds      <- map["accelerometer_on_duration_seconds"]
        self.accelerometerFrequency              <- map["accelerometer_frequency"]
        self.bluetooth                           <- map["bluetooth"]
        self.bluetoothGlobalOffsetSeconds        <- map["bluetooth_global_offset_seconds"]
        self.bluetoothOnDurationSeconds          <- map["bluetooth_on_duration_seconds"]
        self.bluetoothTotalDurationSeconds       <- map["bluetooth_total_duration_seconds"]
        self.omniring                            <- map["device_settings.omniring"]
        self.omniringOffDurationSeconds          <- map["device_settings.omniring_off_duration_seconds"]
        self.omniringOnDurationSeconds           <- map["device_settings.omniring_on_duration_seconds"]
        self.callClinicianText                   <- map["call_clinician_button_text"]
        // self.calls                               <- map["calls"]
        self.checkForNewSurveysFreqSeconds       <- map["check_for_new_surveys_frequency_seconds"]
        self.consentFormText                     <- map["consent_form_text"]
        self.createNewDataFileFrequencySeconds   <- map["create_new_data_files_frequency_seconds"]
        self.gps                                 <- map["gps"]
        self.gpsOffDurationSeconds               <- map["gps_off_duration_seconds"]
        self.gpsOnDurationSeconds                <- map["gps_on_duration_seconds"]
        self.powerState                          <- map["power_state"]
        self.secondsBeforeAutoLogout             <- map["seconds_before_auto_logout"]
        self.submitSurveySuccessText             <- map["survey_submit_success_toast_text"]
        // self.texts                               <- map["texts"]
        self.uploadDataFileFrequencySeconds      <- map["upload_data_files_frequency_seconds"]
        self.voiceRecordingMaxLengthSeconds      <- map["voice_recording_max_time_length_seconds"]
        self.wifi                                <- map["wifi"]
        self.wifiLogFrequencySeconds             <- map["wifi_log_frequency_seconds"]
        self.proximity                           <- map["proximity"]
        self.magnetometer                        <- map["magnetometer"]
        self.magnetometerOffDurationSeconds      <- map["magnetometer_off_duration_seconds"]
        self.magnetometerOnDurationSeconds       <- map["magnetometer_on_duration_seconds"]
        self.gyro                                <- map["gyro"]
        self.gyroOffDurationSeconds              <- map["gyro_off_duration_seconds"]
        self.gyroOnDurationSeconds               <- map["gyro_on_duration_seconds"]
        self.gyroFrequency                       <- map["gyro_frequency"]
        self.motion                              <- map["devicemotion"]
        self.motionOffDurationSeconds            <- map["devicemotion_off_duration_seconds"]
        self.motionOnDurationSeconds             <- map["devicemotion_on_duration_seconds"]
        self.reachability                        <- map["reachability"]
        self.consentSections                     <- map["consent_sections"]
        self.uploadOverCellular                  <- map["allow_upload_over_cellular_data"]
        self.fuzzGps                             <- map["use_gps_fuzzing"]
        self.callClinicianButtonEnabled          <- map["call_clinician_button_enabled"]
        self.callResearchAssistantButtonEnabled  <- map["call_research_assistant_button_enabled"]
    }
}
