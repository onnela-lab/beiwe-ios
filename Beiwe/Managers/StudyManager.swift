import Alamofire
import EmitterKit
import Foundation
import ObjectMapper
import Sentry
import FirebaseCore
import FirebaseMessaging
import FirebaseInstallations
import Reachability

/// Contains all sorts of miiscellaneous study related functionality - this is badly factored and should be refactored into classes that contain their own well-defirned things
class StudyManager {
    static let sharedInstance = StudyManager() // singleton reference
    
    // General code assets
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let calendar = Calendar.current
    
    // Really critical app components
    var currentStudy: Study?
    var timerManager: TimerManager = TimerManager()
    var gpsManager: GPSManager? // gps manager is slightly special because we use it to keep the app open in the background
    var keyRef: SecKey? // the study's security key
    
    // State tracking variables
    var sensorsStartedEver = false
    let surveysUpdatedEvent: EmitterKit.Event<Int> = EmitterKit.Event<Int>() // I don't know what this is. sometimes we emit events, like when closing a survey
    static var real_study_loaded = false
    
    var isStudyLoaded: Bool { // returns true if self.currentStudy is populated
        return self.currentStudy != nil
    }
    
    // Common getters
    
    /// getters, mutators all the ids of active surveys - not used (anymore?
    func getActiveSurveyIds() -> [String] {
        guard let study = self.currentStudy else {
            return []
        }
        return Array(study.activeSurveys.keys)
    }
    
    /// iterates over all the surveys IN THE DATABASE, gives you survey ids
    func getAllSurveyIds() -> [String] {
        guard let study = self.currentStudy else {
            return []
        }
        var allSurveyIds: [String] = []
        for survey in study.surveys where survey.surveyId != nil { // this comes from a mappable in RecLine
            allSurveyIds.append(survey.surveyId!)
        }
        return allSurveyIds
    }
    
    /// saves study data....?
    /// FIXME: I need to work out what these emmitters are
    func emit_survey_updates_save_study_data() {
        guard let study = self.currentStudy else {
            return
        }
        // print("emit_survey_updates_save_study_data got called")
        self.surveysUpdatedEvent.emit(0) // what is this?
        Recline.shared.save(study)
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////// Setup and UnSetup ////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////
    
    func loadDefaultStudy() {
        self.currentStudy = nil
        self.gpsManager = nil // this seems like a bug waiting to happen
        let studies: [Study] = Recline.shared.queryAll() // its a list of studies
        if studies.count > 1 {
            log.warning("Multiple Studies: \(studies)") // should we now error on this??
        }
        if studies.count < 1 {
            return // participant not registered.
        }
        self.currentStudy = studies[0]
        StudyManager.real_study_loaded = true
        self.updateActiveSurveys()
    }
    
    /// pretty much an initializer for data services, for some reason gpsManager is the test if we are already initialized
    func startStudyDataServices() {
        // if there is no study return immediately (this should probably throw an error, such an app state is too invalid to support)
        if !self.isStudyLoaded {
            return
        }
        self.setApiCredentials()
        DataStorageManager.sharedInstance.dataStorageManagerInit(self.currentStudy!, secKeyRef: self.keyRef)
        self.prepareDataServices() // prepareDataServices was 90% of the function body
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged), name: .reachabilityChanged, object: nil)
        
        self.heartbeat_on_dispatch_queue()
    }
    
    /// ACTUAL initialization - initializes the weirdly complex self.gpsManager and everything else
    private func prepareDataServices() {
        // current study and study settings are null of course
        guard let studySettings: StudySettings = self.currentStudy?.studySettings else {
            return // this should probably be a crash...
        }
        
        if self.sensorsStartedEver {
            self.timerManager.clearPollTimer()
            self.timerManager.stop_all_services() // it's a little weird but the Timers actually holds the list of data services
            self.timerManager.clear()
        }
        
        DataStorageManager.sharedInstance.ensureDirectoriesExist() // required on first run
        
        // legacy case - we were using a bad location, the CACHE directory, and we may
        // still have files there. adding this on 2024-2-20.
        DataStorageManager.sharedInstance.moveOldUnknownJunkToUpload()
        
        // There may be files in the current data directory, this should only happen if the app crashed,
        // move those files to the upload directory where the backend can identify if they have any data
        // and will tell the app to delete them.
        DataStorageManager.sharedInstance.moveUnknownJunkToUpload()
        
        // GPS, Check if gps fuzzing is enabled for currentStudy
        self.gpsManager = GPSManager()
        self.gpsManager?.enableGpsFuzzing = studySettings.fuzzGps ? true : false
        self.gpsManager?.fuzzGpsLatitudeOffset = (self.currentStudy?.fuzzGpsLatitudeOffset)!
        self.gpsManager?.fuzzGpsLongitudeOffset = (self.currentStudy?.fuzzGpsLongitudeOffset)!
        
        // iOS Log (app events)
        self.timerManager.addDataService(AppEventManager.sharedInstance)
        
        // every sensor, which for unfathomable reasons are contained inside the gps manager, activate them
        if studySettings.gps && studySettings.gpsOnDurationSeconds > 0 {
            self.timerManager.addDataService(on_duration: studySettings.gpsOnDurationSeconds, off_duration: studySettings.gpsOffDurationSeconds, dataService: self.gpsManager!)
        }
        if studySettings.accelerometer && studySettings.gpsOnDurationSeconds > 0 {
            self.timerManager.addDataService(on_duration: studySettings.accelerometerOnDurationSeconds, off_duration: studySettings.accelerometerOffDurationSeconds, dataService: AccelerometerManager())
        }
        if studySettings.powerState {
            self.timerManager.addDataService(PowerStateManager())
        }
        if studySettings.proximity {
            self.timerManager.addDataService(ProximityManager())
        }
        if studySettings.reachability {
            self.timerManager.addDataService(ReachabilityManager())
        }
        if studySettings.gyro {
            self.timerManager.addDataService(on_duration: studySettings.gyroOnDurationSeconds, off_duration: studySettings.gyroOffDurationSeconds, dataService: GyroManager())
        }
        if studySettings.magnetometer && studySettings.magnetometerOnDurationSeconds > 0 {
            self.timerManager.addDataService(on_duration: studySettings.magnetometerOnDurationSeconds, off_duration: studySettings.magnetometerOffDurationSeconds, dataService: MagnetometerManager())
        }
        if studySettings.motion && studySettings.motionOnDurationSeconds > 0 {
            self.timerManager.addDataService(on_duration: studySettings.motionOnDurationSeconds, off_duration: studySettings.motionOffDurationSeconds, dataService: DeviceMotionManager())
        }
        
        self.gpsManager!.startGps()
        self.timerManager.start()
        self.sensorsStartedEver = true
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Survey Submission ///////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////
    // TODO: this location for this code makes no sense, why is it here?
    
    /// takes a(n active) survey and creates the survey answers file
    func submitSurvey(_ activeSurvey: ActiveSurvey, surveyPresenter: TrackingSurveyPresenter? = nil) {
        // only run if this stuff exists and it is a TrackingSurvey, but then later there is checking of the survey type so maybe not.
        if let survey = activeSurvey.survey, let surveyId = survey.surveyId, let surveyType = survey.surveyType, surveyType == .TrackingSurvey {
            // get the survey data and write it out
            var trackingSurvey: TrackingSurveyPresenter
            if surveyPresenter == nil {
                // print("hitting case where we were 'expiring' the survey timings?")
                // expiration logic? what is "expired?"
                trackingSurvey = TrackingSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey)
                trackingSurvey.addTimingsEvent("expired", question: nil)
            } else {
                trackingSurvey = surveyPresenter! // current survey I think?
            }
            trackingSurvey.finalizeSurveyAnswers() // its done, do the its-done thing (writes file)
            
            // increment number of submitted surveys
            if activeSurvey.bwAnswers.count > 0 {
                if let surveyType = survey.surveyType { // ... isn't this already instantiated?
                    switch surveyType {
                    case .AudioSurvey:
                        self.currentStudy?.submittedAudioSurveys = (self.currentStudy?.submittedAudioSurveys ?? 0) + 1
                    case .TrackingSurvey:
                        self.currentStudy?.submittedTrackingSurveys = (self.currentStudy?.submittedTrackingSurveys ?? 0) + 1
                    }
                }
            }
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////// Active Survey State Logic //////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////
    
    /// updates the list of surveys in the app ui based on the study timers,
    /// updates the badge count, submits completed surveys, and updates the relevant survey timer.
    /// Called from, AudioQuestionsViewController.saveButtonPressed, StudyManager.checkSurveys,
    ///  and inside TrackingSurveyPresenter when the survey is completed.
    func updateActiveSurveys(_ forceSave: Bool = false) {
        guard let study = currentStudy else {
            return
        }
        print("updateActiveSurveys, forceSave: \(forceSave)")
        // logic that refreshes survey list
        let activeSurveysModified_1 = self.clear_out_completed_surveys()
        let activeSurveysModified_2 = self.ensure_always_and_trigger_surveys()
        let activeSurveysModified_3 = self.remove_deleted_surveys()
        let activeSurveysModified_4 = self.update_any_changed_active_surveys() // should go last
        self.updateBadgerCount()
        
        // save survey data?
        if activeSurveysModified_1 || activeSurveysModified_2 || activeSurveysModified_3 || forceSave {
            self.emit_survey_updates_save_study_data()
        }
    }
    
    /// Removes completed surveys from study.activeSurveys, resets completed always-available
    /// surveys, implements magic (OBSCURE, it's not great) logic for trigger-on-download surveys.
    func clear_out_completed_surveys() -> Bool {
        guard let study = currentStudy else {
            return false
        }
        print("clear_out_completed_surveys")
        // For all active surveys that aren't complete, but have expired, submit them. (id is a string)
        var surveyDataModified = false
        var surveys_to_remove = [String]()
        // the reason for this != nill case has been lost to time.
        for activeSurvey in study.activeSurveys.values where activeSurvey.survey != nil {
            // case: always available survey
            // reset the survey, behavior if we don't is the survey stays in the "done" stage
            // you can't retake it. (It loads the survey to the done page, which will resave a
            // new version of the data in a file.)
            // THIS IS ALSO THE OBSCURE LOCATION WHERE WE HANDLE A CRITICAL DETAIL OF TRIGGER
            // ON FIRST DOWNLOAD SURVEYS.
            if activeSurvey.isComplete {
                if activeSurvey.survey!.alwaysAvailable {
                    print("clear_out_completed_surveys - resetting always available survey \(activeSurvey.survey!.surveyId!)")
                    activeSurvey.reset(activeSurvey.survey!)
                    surveyDataModified = true
                } else if !activeSurvey.survey!.triggerOnFirstDownload {
                    // case: a non-trigger, non-always-avaiilable survey, is complete, remove entirely.
                    // To make trigger on first download surveys not identical in behavior to always-
                    // available surveys we ... never remove them from the active surveys list.
                    // Yup, that's how we implement them. It's Terrible.
                    print("clear_out_completed_surveys - found non-AlwaysAvailable, non-triggered completed survey \(activeSurvey.survey!.surveyId!)")
                    surveys_to_remove.append(activeSurvey.survey!.surveyId!)
                    surveyDataModified = true
                }
            }
        }
        
        // delete them (don't mutate the list you are iterating over)
        for surveyId in surveys_to_remove {
            study.activeSurveys.removeValue(forKey: surveyId)
        }
        return surveyDataModified
    }
    
    /// Checks the database for surveys that should exist, removes active surveys that
    /// are not in that list.
    // FIXME: This does not do anything if surveys are not removed from the database
    // when the app checks for new surveys. NEED TO TEST.
    func remove_deleted_surveys() -> Bool {
        guard let study = self.currentStudy else {
            return false
        }
        print("remove_deleted_surveys")
        var surveyDataModified = false
        let allSurveyIds = self.getAllSurveyIds()  // from the database
        for (surveyId, activeSurvey) in study.activeSurveys {
            // if the survey no longer exists in the database, remove it
            if !allSurveyIds.contains(surveyId) {
                print("remove_deleted_surveys - removing survey \(surveyId)")
                study.activeSurveys.removeValue(forKey: surveyId)
                surveyDataModified = true
            }
        }
        return surveyDataModified
    }
    
    /// 1) These ActiveSurveys in study.activeSurveys are _persistent objects_, they are restored
    ///     when the app is reopened. They are ~never removed.
    /// 2) AlwaysAvailable surveys _do not get disabled_ over in `clear_out_completed_surveys`.
    /// 3) triggerOnFirstDownload surveys don't get unloaded, they just don't get reactivated.
    ///     over in over in `clear_out_completed_surveys`
    func ensure_always_and_trigger_surveys() -> Bool {
        guard let study = self.currentStudy else {
            return false
        }
        print("ensure_always_and_trigger_surveys")
        
        var surveyDataModified = false
        // for each survey, check on its availability, insert (and forcibly overwrite data)
        for survey in study.surveys {
            // If a survey does not have a surveyId... I don't even know, but kill it
            if let survey_id = survey.surveyId {
                // we only care about trigger and always available surveys here
                if !(survey.triggerOnFirstDownload || survey.alwaysAvailable) {
                    print("ensure_always_and_trigger_surveys - skipping survey '\(survey.name)', it is not trigger or always available.")
                    continue
                }
                
                // study.activeSurveys has non-optional keys, nil means the key is not present.
                // If it is in the list then it _might but may not be_ visible (I think).
                let on_the_main_screen = study.activeSurveys[survey_id] != nil
                
                if !on_the_main_screen {
                    // case: new trigger or always available survey, add it.
                    print("ensure_always_and_trigger_surveys - adding survey '\(survey.name)'")
                    study.activeSurveys[survey_id] = ActiveSurvey(survey: survey)
                    surveyDataModified = true
                } else {
                    // case: Survey is already loaded
                    if study.activeSurveys[survey_id]!.survey == survey {
                        // case: old survey was _not_ updated and was already present.
                        // Nothin to be done here, move on.
                        print("ensure_always_and_trigger_surveys - survey '\(survey.name)' is unchanged, skipping.")
                        continue
                    }
                    
                    // case: old survey was updated. (for future debugging clarity retin these two cases)
                    // This will cause any partially completed surveys to have state cleared. If the
                    // surveys are identical. A final else clause should be unreachable because we test
                    // for that at the top of the loop.
                    if survey.alwaysAvailable {
                        print("ensure_always_and_trigger_surveys - alwaysAvailable survey changed '\(survey.name)'.")
                        study.activeSurveys[survey_id] = ActiveSurvey(survey: survey)
                        surveyDataModified = true
                    } else if survey.triggerOnFirstDownload {
                        print("ensure_always_and_trigger_surveys - trigger survey changed, '\(survey.name)'.")
                        study.activeSurveys[survey_id] = ActiveSurvey(survey: survey)
                        surveyDataModified = true
                    }
                }
            }
        }
        return surveyDataModified
    }
    
    /// Finds surveys that have changed and replaces them. Has obscure handling for trigger
    /// on first download surveys.
    func update_any_changed_active_surveys() -> Bool {
        guard let study = self.currentStudy else {
            return false
        }
        var any_surveys_updated = false
        print("update_any_changed_active_surveys")
        // the dumb loop again
        // If a survey does not have a surveyId... skip? buh? it's stupid that its optional
        for target_possibly_updated_survey in study.surveys {
            if let survey_id = target_possibly_updated_survey.surveyId {
                if (study.activeSurveys[survey_id] == nil) {
                    continue // survey not an active survey
                }
                
                // get the corresponding active survey
                let the_activesurvey = study.activeSurveys[survey_id]!
                let activesurvey_survey = the_activesurvey.survey!
                
                // Special case of triggerOnFirstDownload surveys - these are retained in the
                // active survey list (like an always-available survey) but instead of getting
                // automatically reset is just... stays there forever. We don't want to update
                // that survey because that will cause it to become visible again. 
                // We just skip it here. This works because the only way for a completed trigger
                // survey to be reloaded is for it to be activated via push notification
                // in activate_surveys, which will reload it from scratch.
                // Surveys that are trigger AND always available should be treated as normal.
                if the_activesurvey.isComplete && activesurvey_survey.triggerOnFirstDownload && !activesurvey_survey.alwaysAvailable {
                    print("update_any_changed_active_surveys - survey '\(target_possibly_updated_survey.name)' is a trigger survey and is complete, skipping.")
                    continue
                }
                
                // run the full survey comparison woo!
                if activesurvey_survey != target_possibly_updated_survey {
                    print("update_any_changed_active_surveys - survey '\(target_possibly_updated_survey.name)' changed.")
                    study.activeSurveys[survey_id] = ActiveSurvey(survey: target_possibly_updated_survey)
                    any_surveys_updated = true
                } else {
                    print("update_any_changed_active_surveys - survey '\(target_possibly_updated_survey.name)' did not change.")
                }
            }
        }
        return any_surveys_updated
    }
    
    /// loads a list of surveys into active surveys so that they will be displayed.
    func activate_surveys(surveyIds: [String], sentTime: TimeInterval) -> Bool {
        guard let study = self.currentStudy else {
            return false
        }
        if surveyIds.count == 0 {
            return false  // if there are no surveys don't do anything
        }
        
        // check every survey we have stored in the database against the passed in surveyIds
        // (this function runs after the surveys have been updated in most cases, and the case
        // of not having a survey but receiving that notification is virtually zero.)
        // (this loop is weird, whatever.)
        var updated_survey_state = false
        for survey in study.surveys {
            if surveyIds.contains(survey.surveyId!) {
                let activeSurvey = ActiveSurvey(survey: survey)
                activeSurvey.received = sentTime  // used to sort surveys on the main screen.
                // this action clears out the prior state of the survey.
                study.activeSurveys[survey.surveyId!] = activeSurvey
                updated_survey_state = true
            }
        }
        
        StudyManager.sharedInstance.surveysUpdatedEvent.emit(0)
        Recline.shared.save(study)
        return updated_survey_state
    }
    
    /// Set the badger count - a count of untaken surveys, excluding always-available surveys.
    func updateBadgerCount() {
        guard let study = self.currentStudy else {
            return
        }
        
        var bdgrCnt = 0
        for activeSurvey in study.activeSurveys.values where activeSurvey.survey != nil {
            // if survey is not complete and the survey is not an always available survey
            if !activeSurvey.isComplete && !activeSurvey.survey!.alwaysAvailable {
                bdgrCnt += 1
            }
        }
        // print("updateBadgerCount - Setting badge count to: \(bdgrCnt)")
        UIApplication.shared.applicationIconBadgeNumber = bdgrCnt
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////// Timer Checks //////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////
    
    /// TODO: move this over to TimerManager
    /// TODO: convert to store as doubles and use Dates in logic.
    /// These operations all happen to be network operations, and we want them to run
    /// as soon as a network connection is available, which means we need to handle
    /// the case of the app closing.
    /// (currently reverted to easier strategy would return a date with a reasonable next time for timer logic to check.)
    func persistentTimerActions(_ now_date: Date) {
        // fail early logic, get study settings and study.
        guard let currentStudy = currentStudy, let studySettings = currentStudy.studySettings else {
            return
        }
        
        let now_int: Int64 = Int64(now_date.timeIntervalSince1970)
        
        // Todo - make these TimeIntervals (doubles)
        let nextSurvey = currentStudy.nextSurveyCheck ?? 0
        let nextUpload = currentStudy.nextUploadCheck ?? 0
        let nextDeviceSettings = currentStudy.nextDeviceSettingsCheck ?? 0
        
        // print("now: \(now), nextSurvey: \(nextSurvey), nextUpload: \(nextUpload), nextDeviceSettings: \(nextDeviceSettings)")
        
        // logic for checking for surveys
        if now_int > nextSurvey {
            self.setNextSurveyTime()
            self.checkForNewSurveys() // asynchronous, returns ~immediately
        }
        
        // logic for running uploads code
        if now_int > nextUpload {
            self.setNextUploadTime()
            if studySettings.uploadOverCellular {
                // case: we are allowed to upload over, so we upload.
                UPLOAD_DISPATCH_QUEUE.async {
                    self.upload() // long running operation
                }
            } else if !NetworkAccessMonitor.network_cellular {
                // case: we are not allowed to upload over cellular, and we are not on cellular. upload.
                UPLOAD_DISPATCH_QUEUE.async {
                    self.upload() // long running operation
                }
            }
        }
        
        // logic for updating the study's device settings.
        if now_int > nextDeviceSettings {
            // print("Checking for updated device settings...")
            self.setNextDeviceSettingsTime()
            self.updateDeviceSettings() // asynchronous, returns ~immediately
        }
        
        Recline.shared.save(currentStudy)
    }
    
    // to reduce calls to save there is a single save call in persistentTimerActions
    // instead of one in each of these setnext functions.
    
    /// The Persistant timers, these get set and are checked even across app termination.
    func setNextUploadTime() {
        guard let study = currentStudy, let studySettings = study.studySettings else {
            return
        }
        // if let t = study.nextUploadCheck { print("previous study.nextUploadCheck:", study.nextUploadCheck!, Date(timeIntervalSince1970: Double(t))) }
        study.nextUploadCheck = Int64(Date().timeIntervalSince1970) + Int64(studySettings.uploadDataFileFrequencySeconds)
        // if let t = study.nextUploadCheck { print("updated study.nextUploadCheck:", study.nextUploadCheck!, Date(timeIntervalSince1970: Double(t))) }
    }
    
    func setNextSurveyTime() {
        guard let study = currentStudy, let studySettings = study.studySettings else {
            return
        }
        // if let t = study.nextSurveyCheck { print("previous study.nextSurveyCheck:", study.nextSurveyCheck!, Date(timeIntervalSince1970: Double(t))) }
        study.nextSurveyCheck = Int64(Date().timeIntervalSince1970) + Int64(studySettings.checkForNewSurveysFreqSeconds)
        // if let t = study.nextSurveyCheck { print("updated study.nextSurveyCheck:", study.nextSurveyCheck!, Date(timeIntervalSince1970: Double(t))) }
    }
    
    func setNextDeviceSettingsTime() {
        guard let study = currentStudy else {
            return
        }
        // if let t = study.nextDeviceSettingsCheck { print("previous study.nextDeviceSettingsCheck:", study.nextDeviceSettingsCheck!, Date(timeIntervalSince1970: Double(t))) }
        study.nextDeviceSettingsCheck = Int64(Date().timeIntervalSince1970) + DEVICE_SETTINGS_INTERVAL
        // if let t = study.nextDeviceSettingsCheck { print("updated study.nextDeviceSettingsCheck:", study.nextDeviceSettingsCheck!, Date(timeIntervalSince1970: Double(t))) }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////// Network Operations Kinda //////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////
    
    /// some kind of reachability thing, calls periodicNetworkTransfers
    @objc func reachabilityChanged(_ notification: Notification) {
        // print("Reachability changed, running periodic network transfers.")
        self.timerManager.pollServices()
    }
    
    func heartbeat_on_dispatch_queue() {
        print("Scheduling dispatchqueue heartbeat...")
        HEARTBEAT_QUEUE.asyncAfter(deadline: .now() + Constants.HEARTBEAT_INTERVAL, execute: {
            print("running heartbeat on dispatch queue \(Date())")
            self.heartbeat("DispatchQueue \(Constants.HEARTBEAT_INTERVAL) secondly - \(Ephemerals.background_task_count)")
            self.heartbeat_on_dispatch_queue()
        })
    }
    
    /// dispatches the heartbeat signal to the server
    func heartbeat(_ message: String) {
        print("Sending heartbeat...")
        ApiManager.sharedInstance.extremelySimplePostRequest(
            "/mobile-heartbeat/",
            extra_parameters: ["message": "(" + message + ")"]
        )
    }
    
    /// Runs the api call for downloading survey data, and _then_ adds any provided surveys to
    /// to self.activeSurveys. (Adding the new active surveys is guaranteed to run even if the
    /// network request fails.)
    /// This implementation is desireable because it isn't uncommon (especially when testing)
    /// to update a survey and send the survey notification via the button on the Beiwe website.
    /// Also it is just safer to 99% of the time have all the relevant survey info.)
    func checkForNewSurveys(surveyIds: [String] = [], sentTime: TimeInterval = 0) {
        guard let study = currentStudy else {
            return
        }
        print("checkForNewSurveys")
               
        ApiManager.sharedInstance.makePostRequest(
            GetSurveysRequest(), completion_handler: { (response: DataResponse<String>) in
                var error_message = ""
                switch response.result {
                case .success:
                    if let statusCode = response.response?.statusCode {
                        // valid 200 range response
                        if statusCode >= 200 && statusCode < 300 {
                            let body_response = BodyResponse(body: response.result.value)
                            if let body_string = body_response.body {
                                if let newSurveys: [Survey] = Mapper<Survey>().mapArray(JSONString: body_string) {
                                    // we have survey data!
                                    study.surveys = newSurveys
                                    Recline.shared.save(study)
                                } else {
                                    error_message = "download surveys: \(response) - but body was nil"
                                }
                            }
                        } else { // all non-200 error codes
                            error_message = "download surveys: statuscode: \(statusCode), value/body: \(String(describing: response.result.value))"
                        }
                    } else { // no error code?
                        error_message = "download surveys: no status code?"
                    }
                case .failure: // general failure?
                    error_message = "download surveys - error: \(String(describing: response.error))"
                }
                
                if error_message != "" {
                    log.error(error_message)
                    AppEventManager.sharedInstance.logAppEvent(event: "survey_download", msg: error_message)
                }
                
                // if received any surveys to this call
                if !surveyIds.isEmpty {
                    self.activate_surveys(surveyIds: surveyIds, sentTime: sentTime)
                }
                
                // even if we didn't get new surveys we need to call setActiveSurveys with the survey ids
                self.updateActiveSurveys()
            }
        )
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////// UPDATE DEVICE SETTINGS /////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////
    
    /// Queries the server for new study settings, hand off to completion handler
    func updateDeviceSettings() {
        // assert that these are instantiated
        guard let _ = self.currentStudy, let _ = self.currentStudy?.studySettings else {
            return
        }
        // make the post request, convert to json, convert to a JustStudySettings mapper
        ApiManager.sharedInstance.makePostRequest(
            UpdateDeviceSettingsRequest(), completion_handler: self.updateSettingsCompletionHandler)
    }

    /// callback for the updateDeviceSettings function, handles output of the post request, determines if we have any input data.
    func updateSettingsCompletionHandler(response: DataResponse<String>) {
        var error_message = ""
        
        // this could be cleaned up, but don't bother? it is tested and works.
        // All the error cases are "fine", we just try again later regardless of current success,
        // so we only print the error type.
        switch response.result {
        case .success:
            if let statusCode = response.response?.statusCode {
                if statusCode >= 200 && statusCode < 300 {
                    // 200 codes
                    let body_response = BodyResponse(body: response.result.value)
                    if let body_string = body_response.body {
                        // use the custom-purpose JustStudySettings class
                        if let newSettings: JustStudySettings = Mapper<JustStudySettings>().map(JSONString: body_string) {
                            self.updateSettings(newSettings: newSettings)
                        } else {
                            error_message = "update settings response: \(response) - but body was nil"
                        }
                    }
                } else {
                    // all other status codes
                    error_message = "update settings response: \(response) , statuscode: \(statusCode), value/body: \(String(describing: response.result.value))"
                }
            } else {
                // no status code
                error_message = "update settings response: \(response) - no status code?"
            }
        case .failure:
            // general failure
            error_message = "update settings response: \(response) - error: \(String(describing: response.error))"
        }
        
        if error_message != "" {
            log.error(error_message)
        }
    }
    
    /// This abomination of a function updates study settings if they have changed
    func updateSettings(newSettings: JustStudySettings) {
        // Check EVERY SETTING, record if anything changed, assign any new values
        var anything_changed: Bool = false
        
        // TODO: find a way to make this introspective (BUT SAFE) and less verbose.
        // I encountered problems using anything other than "self.currentStudy?.studySettings?.accelerometer"
        // to access and update the study settings for the device
        if self.currentStudy?.studySettings?.accelerometer != newSettings.accelerometer {
            anything_changed = true
            self.currentStudy?.studySettings?.accelerometer = newSettings.accelerometer
            // print("accelerometer changed to: \(newSettings.accelerometer)")
        }
        if self.currentStudy?.studySettings?.accelerometerOffDurationSeconds != newSettings.accelerometerOffDurationSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.accelerometerOffDurationSeconds = newSettings.accelerometerOffDurationSeconds
            // print("accelerometerOffDurationSeconds changed to: \(newSettings.accelerometerOffDurationSeconds)")
        }
        if self.currentStudy?.studySettings?.accelerometerOnDurationSeconds != newSettings.accelerometerOnDurationSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.accelerometerOnDurationSeconds = newSettings.accelerometerOnDurationSeconds
            // print("accelerometerOnDurationSeconds changed to: \(newSettings.accelerometerOnDurationSeconds)")
        }
        if self.currentStudy?.studySettings?.accelerometerFrequency != newSettings.accelerometerFrequency {
            anything_changed = true
            self.currentStudy?.studySettings?.accelerometerFrequency = newSettings.accelerometerFrequency
            // print("accelerometerFrequency changed to: \(newSettings.accelerometerFrequency)")
        }
        if self.currentStudy?.studySettings?.aboutPageText != newSettings.aboutPageText {
            anything_changed = true
            self.currentStudy?.studySettings?.aboutPageText = newSettings.aboutPageText
            // print("aboutPageText changed to: \(newSettings.aboutPageText)")
        }
        if self.currentStudy?.studySettings?.callClinicianText != newSettings.callClinicianText {
            anything_changed = true
            self.currentStudy?.studySettings?.callClinicianText = newSettings.callClinicianText
            // print("callClinicianText changed to: \(newSettings.callClinicianText)")
        }
        if self.currentStudy?.studySettings?.consentFormText != newSettings.consentFormText {
            anything_changed = true
            self.currentStudy?.studySettings?.consentFormText = newSettings.consentFormText
            // print("consentFormText changed to: \(newSettings.consentFormText)")
        }
        if self.currentStudy?.studySettings?.checkForNewSurveysFreqSeconds != newSettings.checkForNewSurveysFreqSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.checkForNewSurveysFreqSeconds = newSettings.checkForNewSurveysFreqSeconds
            // print("checkForNewSurveysFreqSeconds changed to: \(newSettings.checkForNewSurveysFreqSeconds)")
        }
        if self.currentStudy?.studySettings?.createNewDataFileFrequencySeconds != newSettings.createNewDataFileFrequencySeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.createNewDataFileFrequencySeconds = newSettings.createNewDataFileFrequencySeconds
            // print("createNewDataFileFrequencySeconds changed to: \(newSettings.createNewDataFileFrequencySeconds)")
        }
        if self.currentStudy?.studySettings?.gps != newSettings.gps {
            anything_changed = true
            self.currentStudy?.studySettings?.gps = newSettings.gps
            // print("gps changed to: \(newSettings.gps)")
        }
        if self.currentStudy?.studySettings?.gpsOffDurationSeconds != newSettings.gpsOffDurationSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.gpsOffDurationSeconds = newSettings.gpsOffDurationSeconds
            // print("gpsOffDurationSeconds changed to: \(newSettings.gpsOffDurationSeconds)")
        }
        if self.currentStudy?.studySettings?.gpsOnDurationSeconds != newSettings.gpsOnDurationSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.gpsOnDurationSeconds = newSettings.gpsOnDurationSeconds
            // print("gpsOnDurationSeconds changed to: \(newSettings.gpsOnDurationSeconds)")
        }
        if self.currentStudy?.studySettings?.powerState != newSettings.powerState {
            anything_changed = true
            self.currentStudy?.studySettings?.powerState = newSettings.powerState
            // print("powerState changed to: \(newSettings.powerState)")
        }
        if self.currentStudy?.studySettings?.secondsBeforeAutoLogout != newSettings.secondsBeforeAutoLogout {
            anything_changed = true
            self.currentStudy?.studySettings?.secondsBeforeAutoLogout = newSettings.secondsBeforeAutoLogout
            // print("secondsBeforeAutoLogout changed to: \(newSettings.secondsBeforeAutoLogout)")
        }
        if self.currentStudy?.studySettings?.submitSurveySuccessText != newSettings.submitSurveySuccessText {
            anything_changed = true
            self.currentStudy?.studySettings?.submitSurveySuccessText = newSettings.submitSurveySuccessText
            // print("submitSurveySuccessText changed to: \(newSettings.submitSurveySuccessText)")
        }
        if self.currentStudy?.studySettings?.uploadDataFileFrequencySeconds != newSettings.uploadDataFileFrequencySeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.uploadDataFileFrequencySeconds = newSettings.uploadDataFileFrequencySeconds
            // print("uploadDataFileFrequencySeconds changed to: \(newSettings.uploadDataFileFrequencySeconds)")
        }
        if self.currentStudy?.studySettings?.voiceRecordingMaxLengthSeconds != newSettings.voiceRecordingMaxLengthSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.voiceRecordingMaxLengthSeconds = newSettings.voiceRecordingMaxLengthSeconds
            // print("voiceRecordingMaxLengthSeconds changed to: \(newSettings.voiceRecordingMaxLengthSeconds)")
        }
        if self.currentStudy?.studySettings?.wifi != newSettings.wifi {
            anything_changed = true
            self.currentStudy?.studySettings?.wifi = newSettings.wifi
            // print("wifi changed to: \(newSettings.wifi)")
        }
        if self.currentStudy?.studySettings?.wifiLogFrequencySeconds != newSettings.wifiLogFrequencySeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.wifiLogFrequencySeconds = newSettings.wifiLogFrequencySeconds
            // print("wifiLogFrequencySeconds changed to: \(newSettings.wifiLogFrequencySeconds)")
        }
        if self.currentStudy?.studySettings?.proximity != newSettings.proximity {
            anything_changed = true
            self.currentStudy?.studySettings?.proximity = newSettings.proximity
            // print("proximity changed to: \(newSettings.proximity)")
        }
        if self.currentStudy?.studySettings?.magnetometer != newSettings.magnetometer {
            anything_changed = true
            self.currentStudy?.studySettings?.magnetometer = newSettings.magnetometer
            // print("magnetometer changed to: \(newSettings.magnetometer)")
        }
        if self.currentStudy?.studySettings?.magnetometerOffDurationSeconds != newSettings.magnetometerOffDurationSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.magnetometerOffDurationSeconds = newSettings.magnetometerOffDurationSeconds
            // print("magnetometerOffDurationSeconds changed to: \(newSettings.magnetometerOffDurationSeconds)")
        }
        if self.currentStudy?.studySettings?.magnetometerOnDurationSeconds != newSettings.magnetometerOnDurationSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.magnetometerOnDurationSeconds = newSettings.magnetometerOnDurationSeconds
            // print("magnetometerOnDurationSeconds changed to: \(newSettings.magnetometerOnDurationSeconds)")
        }
        if self.currentStudy?.studySettings?.gyro != newSettings.gyro {
            anything_changed = true
            self.currentStudy?.studySettings?.gyro = newSettings.gyro
            // print("gyro changed to: \(newSettings.gyro)")
        }
        if self.currentStudy?.studySettings?.gyroOffDurationSeconds != newSettings.gyroOffDurationSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.gyroOffDurationSeconds = newSettings.gyroOffDurationSeconds
            // print("gyroOffDurationSeconds changed to: \(newSettings.gyroOffDurationSeconds)")
        }
        if self.currentStudy?.studySettings?.gyroOnDurationSeconds != newSettings.gyroOnDurationSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.gyroOnDurationSeconds = newSettings.gyroOnDurationSeconds
            // print("gyroOnDurationSeconds changed to: \(newSettings.gyroOnDurationSeconds)")
        }
        if self.currentStudy?.studySettings?.gyroFrequency != newSettings.gyroFrequency {
            anything_changed = true
            self.currentStudy?.studySettings?.gyroFrequency = newSettings.gyroFrequency
            // print("gyroFrequency changed to: \(newSettings.gyroFrequency)")
        }
        if self.currentStudy?.studySettings?.motion != newSettings.motion {
            anything_changed = true
            self.currentStudy?.studySettings?.motion = newSettings.motion
            // print("motion changed to: \(newSettings.motion)")
        }
        if self.currentStudy?.studySettings?.motionOffDurationSeconds != newSettings.motionOffDurationSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.motionOffDurationSeconds = newSettings.motionOffDurationSeconds
            // print("motionOffDurationSeconds changed to: \(newSettings.motionOffDurationSeconds)")
        }
        if self.currentStudy?.studySettings?.motionOnDurationSeconds != newSettings.motionOnDurationSeconds {
            anything_changed = true
            self.currentStudy?.studySettings?.motionOnDurationSeconds = newSettings.motionOnDurationSeconds
            // print("motionOnDurationSeconds changed to: \(newSettings.motionOnDurationSeconds)")
        }
        if self.currentStudy?.studySettings?.reachability != newSettings.reachability {
            anything_changed = true
            self.currentStudy?.studySettings?.reachability = newSettings.reachability
            // print("reachability changed to: \(newSettings.reachability)")
        }
        if self.currentStudy?.studySettings?.consentSections != newSettings.consentSections {
            anything_changed = true
            self.currentStudy?.studySettings?.consentSections = newSettings.consentSections
            // print("consentSections changed to: \(newSettings.consentSections)")
        }
        if self.currentStudy?.studySettings?.uploadOverCellular != newSettings.uploadOverCellular {
            anything_changed = true
            self.currentStudy?.studySettings?.uploadOverCellular = newSettings.uploadOverCellular
            // print("uploadOverCellular changed to: \(newSettings.uploadOverCellular)")
        }
        if self.currentStudy?.studySettings?.fuzzGps != newSettings.fuzzGps {
            anything_changed = true
            self.currentStudy?.studySettings?.fuzzGps = newSettings.fuzzGps
            // print("fuzzGps changed to: \(newSettings.fuzzGps)")
        }
        if self.currentStudy?.studySettings?.callClinicianButtonEnabled != newSettings.callClinicianButtonEnabled {
            anything_changed = true
            self.currentStudy?.studySettings?.callClinicianButtonEnabled = newSettings.callClinicianButtonEnabled
            // print("callClinicianButtonEnabled changed to: \(newSettings.callClinicianButtonEnabled)")
        }
        if self.currentStudy?.studySettings?.callResearchAssistantButtonEnabled != newSettings.callResearchAssistantButtonEnabled {
            anything_changed = true
            self.currentStudy?.studySettings?.callResearchAssistantButtonEnabled = newSettings.callResearchAssistantButtonEnabled
            // print("callResearchAssistantButtonEnabled changed to: \(newSettings.callResearchAssistantButtonEnabled)")
        }
        
        // accedentally tested it like this outside of if anything_changed, it's fine.
        Recline.shared.save(self.currentStudy!)
        
        // if anything changed, reset all data services.
        if anything_changed {
            self.prepareDataServices()
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////// Data Upload ///////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///
    /// Notes:
    ///
    /// It is possible for AlamoFire to say that an upload failed due to a timeout, but the server
    /// still somehow fully accepts the file - here is an example of what the data looks like for
    /// a random test participant that had this occur - this code gets the uploaded file
    /// and compares it to the other instance of it, the files were the same:
    ///
    /// In [30]: list(p.upload_trackers.filter(file_path__icontains="f37twhxm/devicemotion/1708719536932").values())
    /// Out[30]:
    /// [{'id': 7913053,
    ///   'file_path': 'f37twhxm/devicemotion/1708719536932.csv',
    ///   'file_size': 41907,
    ///   'timestamp': datetime.datetime(2024, 2, 23, 21, 42, 56, 147142, tzinfo=<UTC>),
    ///   'participant_id': 1557},
    ///  {'id': 7913088,
    ///   'file_path': 'f37twhxm/devicemotion/1708719536932.csv-duplicate-7wglblddmt',
    ///   'file_size': 41907,
    ///   'timestamp': datetime.datetime(2024, 2, 23, 21, 48, 46, 335498, tzinfo=<UTC>),
    ///   'participant_id': 1557}]
    ///
    /// In [31]: a,b = p.upload_trackers.filter(file_path__icontains="f37twhxm/devicemotion/1708719536932")
    ///
    /// In [32]: a.s3_retrieve() == b.s3_retrieve()
    /// Out[32]: True
    ///
    /// It would be _nice_ if we could fix this, but it shouldn't be a huge issue.
    
    // after sticking upload dispatch on a queue (with a file-in-flight count maximum) we no longer
    // need this list to block overlapping runs by caching the names, could use a counter. But,
    // then we have no info?
    var files_in_flight = [String]() // the files we are currently trying to upload.
    var files_with_encoding_errors = [String]()
    let files_in_flight_lock = NSLock()
    
    /// This function always runs on the POST_UPLOAD_QUEUE
    /// Beiwe servers only respond with statuscodes on data upload. 200 means it was uploaded
    /// and we should delete the file, everything else means it didn't work and we should try again.
    func uploadAttemptResponseHandler(
        _ dataResponse: DataResponse<String>, filename: String, filePath: URL
    ) {
        var error_message = ""
        switch dataResponse.result {
        case .success:
            if let statusCode = dataResponse.response?.statusCode {
                var body_response_string = BodyResponse(body: dataResponse.result.value).body ?? "(no message)"
                if body_response_string == "" { body_response_string = "(no message)" }
                
                if statusCode >= 200 && statusCode < 300 {
                    if !body_response_string.contains("upload successful") {
                        print("Success uploading: \(filename) with message '\(body_response_string)'.")
                    }
                    AppEventManager.sharedInstance.logAppEvent(
                        event: "uploaded", msg: "Uploaded data file", d1: filename, d2: body_response_string)
                    AppEventManager.sharedInstance.logAppEvent(
                        event: "upload_complete", msg: "Upload Complete")
                    
                    do {
                        try FileManager.default.removeItem(at: filePath) // ok I guess this can fail...?
                    } catch {
                        let minipath = filePath.path.split(separator: "/").last!
                        
                        // this seems to happen whenever we have overlapping runs of uploading the same file.
                        print("Error deleting file '\(minipath)': \(error)")
                        // fatalError("could not delete a file??")
                    }
                } else {
                    // non-200 status codes
                    error_message = "bad statuscode: \(statusCode) for file \(filename) with message '\(body_response_string)'"
                }
            } else {
                error_message = "upload failed - not a status code or other .failure case? for file \(filename)"
            }
        case .failure:
            // this case triggers when there are normal kinds of errors like a timeout.
            error_message = "upload ERROR: \(String(describing: dataResponse.error)) for file \(filename)"
        }
        
        if error_message != "" {
            print("Upload error message: ", error_message)
            AppEventManager.sharedInstance.logAppEvent(
                event: "upload error", msg: error_message, d1: filename)
        }
        
        self.files_in_flight_lock.lock()
        // there should REALLY only be one of these but just in case we will do all of them
        self.files_in_flight.removeAll(where: { $0 == filename })
        self.files_in_flight_lock.unlock()
    }
    
    /// business logic of the upload.
    /// processOnly means don't upload (it's based on reachability)
    func upload() {
        print("Checking for uploads...")

        Ephemerals.start_last_upload = dateFormat(Date())
        DataStorageManager.sharedInstance.moveLeftBehindFilesToUpload()
        
        // if we can't enumerate files, that's insane, crash.
        let fileEnumerator: FileManager.DirectoryEnumerator =
            FileManager.default.enumerator(atPath: DataStorageManager.uploadDataDirectory().path)!
        var filesToProcess: [String] = []
        
        // loop over all and check if each file can be uploaded, assemble the list.
        while let filename = fileEnumerator.nextObject() as? String {
            if DataStorageManager.sharedInstance.isUploadFile(filename) {
                // don't actually know if this can cause a thread confict, don't care, wrapping.
                self.files_in_flight_lock.lock()
                let skip = self.files_in_flight.contains(filename)
                self.files_in_flight_lock.unlock()
                
                // this skip check should never fire because we are on a queue.
                if skip {
                    let just_the_filename = filename.split(separator: "/").last!
                    print("skipping \(just_the_filename) because its already being uploaded right now")
                    continue
                } else {
                    self.dispatch_upload(filename)
                }
                
                self.files_in_flight_lock.lock()
                filesToProcess.append(filename)
                self.files_in_flight_lock.unlock()
                
                // rate limit dispatching any more upload attempts (which will die inside Alamofire
                // with a _timeout_ error for some reason... and also some files that
                // time out _actually_ _upload_ _which_ _is_ _insane_) by waiting for one second
                // until there are fewer than... 11.
                while self.files_in_flight.count > 10 {
                    // print("self.files_in_flight.count:", self.files_in_flight.count)
                    sleep(1)
                }
            }
        }
        Ephemerals.end_last_upload = dateFormat(Date())
        print("Done with uploads.")
    }
    
    func dispatch_upload(_ filename: String) {
        let filePath: URL = DataStorageManager.uploadDataDirectory().appendingPathComponent(filename)
        let uploadRequest = UploadRequest(fileName: filename, filePath: filePath.path)
        
        // do an upload - this does not block. it dispatches the upload operation onto the
        // AlamoFire root queue, and then eventually our callbacks get called.
        ApiManager.sharedInstance.makeMultipartUploadRequest(
            uploadRequest,
            file: filePath,
            completionQueue: POST_UPLOAD_QUEUE,
            httpSuccessCompletionHandler: { (dataResponse: DataResponse<String>) in
                self.uploadAttemptResponseHandler(dataResponse, filename: filename, filePath: filePath)
            },
            encodingErrorHandler: { (error: Error) in
                AppEventManager.sharedInstance.logAppEvent(
                    event: "upload_file_failed", msg: "Failed Uploaded data file", d1: filename)
                log.error("Encoding error?: \(error)")
                
                // we don't know when this error happens, but the upload has failed, remove from list
                self.files_in_flight_lock.lock()
                self.files_in_flight.removeAll(where: { $0 == filename })
                self.files_in_flight_lock.unlock()
                
                // report this error to Sentry (but only once per app launch, by checking/appending
                // file name to a list)
                if !self.files_with_encoding_errors.contains(filename) {
//                    if let sentry_client = Client.shared {
//                        sentry_client.snapshotStacktrace {
//                            let event = Sentry.Event(level: .error)
//                            event.message = "Encountered encoding error while uploading file"
//                            event.environment = Constants.APP_INFO_TAG
//                            
//                            // todo does this always exist?
//                            if event.extra == nil {
//                                event.extra = [:]
//                            }
//                            if var extras = event.extra {
//                                extras["error"] = "\(error)"
//                                extras["filename"] = filename
//                                extras["user_id"] = self.currentStudy!.patientId
//                            }
//                            sentry_client.appendStacktrace(to: event)
//                            sentry_client.send(event: event)
//                        }
//                    }
                    self.files_with_encoding_errors.append(filename)
                }
            }
        )
        self.files_in_flight_lock.lock()
        self.files_in_flight.append(filename)
        self.files_in_flight_lock.unlock()
        // print("upload for \(filename) dispatched")
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////// Registration ////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////
    
    /// sets the study as consented, sets api credentials
    func setConsented() {
        // fail if current study or study settings are null
        guard let study = currentStudy, let studySettings = study.studySettings else {
            return
        }
        // api setup
        self.setApiCredentials()
        let currentTime: Int64 = Int64(Date().timeIntervalSince1970)
        // kick off survey timers
        study.nextUploadCheck = currentTime + Int64(studySettings.uploadDataFileFrequencySeconds)
        study.nextSurveyCheck = currentTime + Int64(studySettings.checkForNewSurveysFreqSeconds)
        // set consented to true (checked over in AppDelegate)
        study.participantConsented = true
        // some io stuff
        DataStorageManager.sharedInstance.dataStorageManagerInit(study, secKeyRef: self.keyRef)
        DataStorageManager.sharedInstance.ensureDirectoriesExist()
        // update study stuff?
        Recline.shared.save(study)
        self.checkForNewSurveys()
    }
    
    // FIXME: This function has 4 unacceptable failure modes -- called only from setConsented (study registration) and startStudyDataServices
    /// Sets up the password (api) credential for backend calls
    func setApiCredentials() {
        // if there is no study.... don't do this.
        guard let currentStudy: Study = self.currentStudy else {
            return
        }
        // Setup APIManager's security
        // Why is this EVER allowed to be the empty string? that's silent failure FOREVER
        ApiManager.sharedInstance.password = PersistentPasswordManager.sharedInstance.passwordForStudy() ?? ""
        ApiManager.sharedInstance.customApiUrl = currentStudy.customApiUrl
        if let patientId = currentStudy.patientId { // again WHY is this even allowed to happen on a null participant id
            ApiManager.sharedInstance.patientId = patientId
            if let clientPublicKey = currentStudy.studySettings?.clientPublicKey {
                do {
                    // failure means a null key
                    self.keyRef = try PersistentPasswordManager.sharedInstance.storePublicKeyForStudy(clientPublicKey, patientId: patientId)
                } catch {
                    log.error("Failed to store RSA key in keychain.") // why are we not crashing...
                }
            } else {
                log.error("No public key found.  Can't store") // why are we not crashing...
            }
        }
    }
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////// The Leave Study Code //////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // The reason this code is still present is because we need to handle the case of a user dismissing or exiting the
    // app during the registration or consent sections stage of registration.  We would probably be fine without it,
    // but this is some free safety so until it becomes a maintenance burden we will keep it.
    
    /// the bulk of the leave study feature.
    func leaveStudy() {
        // disable gps - gps is special because it interacts with app persistence
        if self.gpsManager != nil {
            self.gpsManager!.stopGps()
        }
        // stop all timers
        self.timerManager.stop_all_services()
        self.timerManager.clear()
        
        // kill notifications
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: nil)
        UIApplication.shared.cancelAllLocalNotifications()
        
        // clear out remaining active study objects
        self.gpsManager = nil
        self.timerManager.clear() // this may deallocate all sensors.  I think.
        self.purgeStudies()
        
        // delete upload diirectory using ugly code
        var enumerator = FileManager.default.enumerator(atPath: DataStorageManager.uploadDataDirectory().path)
        if let enumerator = enumerator {
            while let filename = enumerator.nextObject() as? String {
                if true /* filename.hasSuffix(DataStorageManager.dataFileSuffix) */ {
                    let filePath = DataStorageManager.uploadDataDirectory().appendingPathComponent(filename)
                    do {
                        try FileManager.default.removeItem(at: filePath)
                    } catch {
                        log.error("(1) Failed to delete file: \(filename) with error \(error)")
                    }
                }
            }
        }
        
        // delete data directory using ugly code
        enumerator = FileManager.default.enumerator(atPath: DataStorageManager.currentDataDirectory().path)
        if let enumerator = enumerator {
            while let filename = enumerator.nextObject() as? String {
                let filePath = DataStorageManager.currentDataDirectory().appendingPathComponent(filename)
                do {
                    try FileManager.default.removeItem(at: filePath)
                } catch {
                    log.error("(2) Failed to delete file: \(filename) with error \(error)")
                }
            }
        }
        
        // clear the study, patient id
        self.currentStudy = nil // self.isStudyLoaded will now fail
        ApiManager.sharedInstance.patientId = ""
    }
    
    /// deletes all studies - used in registration for some reason
    func purgeStudies() {
        let studies = Recline.shared.queryAll() // this returns a list of studies, ignore the templated type
        for study in studies {
            Recline.shared.purge(study)
        }
    }
    
    ///
    /// Miscellaneous utility functions
    ///
    
    /// only called from AppDelegate.applicationWillTerminate
    func stop() {
        // this is the reference to the object attached to StudyManager, need to dereference
        if self.gpsManager != nil {
            self.gpsManager!.stopGps()
            self.gpsManager = nil
        }
        
        // stop all recording, clear registered timer events
        self.timerManager.stop_all_services()
        self.timerManager.clear()
        
        // clear currentStudy - this originally ran on the default background queue inside a promisekit promise,
        // but it was only called in applicationWillTerminate, so we can just run it on the main thread?
        self.currentStudy = nil
        StudyManager.real_study_loaded = false
    }
}
