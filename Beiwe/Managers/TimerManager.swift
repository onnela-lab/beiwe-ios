import Darwin
import Foundation

/// For some unfathomable, incomprehensible reason, this logic was attached to the GpsManager
// It may be the case that the GPS updates are how the app stays open (there is disabled logic to record when the app vas opened that checks
// for the presense of some location service *stuff* over in AppEventManager), in which case my best guess for that old, _terrible_ factoring
// is that Keary thought he would need to hook everything into those GPS details.

let DEVICE_SETTINGS_INTERVAL: Int64 = 30 * 60 // hardcoded thirty minutes

let DEFAULT_NEXT_STATE_CHECK_INTERVAL: TimeInterval = 5 * 60

func default_interval_from_now() -> Date {
    return Date(timeIntervalSince1970: Date().timeIntervalSince1970 + DEFAULT_NEXT_STATE_CHECK_INTERVAL)
}

/// this class is not a data recording class, it is a manager for the timers that run on the app as a whole.
class TimerManager {
    // state
    var dataCollectionServices: [DataServiceStatus] = []
    var areServicesRunning = false
    
    // timer stuff () the app ~only keeps track of the next timer event to occur, and updates it accordingly.  (I don't know why it is spread across 2 variables.)
    var timer: Timer = Timer()
    var expected_wakeup: Date = Date(timeIntervalSince1970: 0)
    var nextSurveyDisplayUpdate: Date = Date(timeIntervalSince1970: 0)
    var nextDataServicesCheck: Date = Date(timeIntervalSince1970: 0)
    // var nextHeartbeat: Date = Date(timeIntervalSince1970: 0)
    var nextNewFiles: Date = Date(timeIntervalSince1970: 0)
    var nextPersistentTasks: Date = Date(timeIntervalSince1970: 0)
    
    /// a core function that enables many sensor managers (DataServiceProtocols)
    func addDataService(on_duration: Int, off_duration: Int, dataService: DataServiceProtocol) {
        let dataServiceStatus = DataServiceStatus(
            onDurationSeconds: on_duration, offDurationSeconds: off_duration, dataService: dataService
        )
        if dataService.initCollecting() {
            self.dataCollectionServices.append(dataServiceStatus)
        }
    }
    
    /// a core function that enables the other half of the data services (data streams with no timers)
    func addDataService(_ dataService: DataServiceProtocol) {
        self.addDataService(on_duration: 1, off_duration: 0, dataService: dataService)
    }
    
    ///
    /// Timer control
    ///
    
    /// enables the timer
    func start() {
        // print("TimerManager.start()")
        self.areServicesRunning = true
        self.startPollTimer(1.5) // this value is purely to differentiate from a +1.0 seconds value for clarity when debugging.
    }
    
    /// stops timers for everything
    func stop_all_services() {
        self.areServicesRunning = false
        self.clearPollTimer()
        // call finishCollecting on every collection service in dataCollectionServices
        for dataStatus in self.dataCollectionServices {
            // print("global timer stop, calling finishCollecting on \(dataStatus.dataService.self)")
            dataStatus.dataService.finishCollecting()
        }
        self.dataCollectionServices.removeAll() // clear out the registered services entirely
    }
    
    // hit the new files function on all running services
    func all_services_new_files() {
        for dataStatus in self.dataCollectionServices {
            // print("calling new files on \(dataStatus.dataService.self)")
            dataStatus.dataService.createNewFile() // should call flush if necessary
        }
    }
    
    /// used in unregistering
    func clear() {
        self.dataCollectionServices = []
    }
    
    /// clear a poll timer safely
    func clearPollTimer() {
        self.timer.invalidate()
        self.timer = Timer() // clear out the old timer object, make a new one
    }
    
    // func heartbeatTimerCheck(_ now: Date) -> Date {
    //     if now > self.nextHeartbeat {
    //         StudyManager.sharedInstance.heartbeat("Timer logic")
    //         return Date(timeIntervalSince1970: now.timeIntervalSince1970 + Constants.HEARTBEAT_INTERVAL)
    //     }
    //     return self.nextHeartbeat
    // }
    
    func nextNewFilesCheck(_ now: Date) -> Date {
        // reset files periodically - exact behavior varies by data stream.
        if now > self.nextNewFiles {
            // (900 is also the hardcoded default on createNewDataFileFrequencySeconds)
            var next_time = StudyManager.sharedInstance.currentStudy?.studySettings?.createNewDataFileFrequencySeconds ?? 900
            self.all_services_new_files()
            return Date(timeIntervalSince1970: now.timeIntervalSince1970 + Double(next_time))
        }
        return self.nextNewFiles
    }
    
    // TODO: if we ever get weekly survey logic implemented put it here. Currently this just
    // checks if the current displayed surveys are correct, returns the 5 minute timer.
    func nextSurveyAvailabilityCheck(_ now: Date) -> Date {
        if now > self.nextSurveyDisplayUpdate {
            StudyManager.sharedInstance.updateActiveSurveys()
        }
        return default_interval_from_now()
    }
    
    /// Starts or stops every data service, returns the time interval until the next event.
    /// called in self.pollServices, which assigns to self
    func runDataCollectionServicesToggleLogic(_ now: TimeInterval) -> Date {
        // print("ToggleLogic")
        var next_toggle_check = now + (10 * 60) // default is a ten minute timer
        
        // for every data service get its nextToggleTime, turn it on or off as appropriate,
        // set state as appropriate, update nextToggleTime.
        for dataStatus in self.dataCollectionServices {
            // 1 - get the toggle time from the DataServiceStatus - this value is set to current time at initialization, e.g. it always starts "in the past".
            // print("ToggleLogic - timer check for \(dataStatus.dataService)")
            if var toggleTime = dataStatus.nextToggleTime?.timeIntervalSince1970 {
                // 2 - if that time is in the past, toggle.
                // print("ToggleLogic - \(dataStatus.dataService) - toggletime: \(smartformat(toggleTime))")
                if toggleTime <= now {
                    // 2a - toggle off if on, update .nextToggleTime
                    // print("ToggleLogic - \(dataStatus.dataService) - was in the past, time to toggle.")
                    if dataStatus.currentlyOn {
                        // print("ToggleLogic - \(dataStatus.dataService) - it was on, toggling off.")
                        dataStatus.dataService.pauseCollecting()
                        dataStatus.currentlyOn = false
                        dataStatus.nextToggleTime = Date(timeIntervalSince1970: now + dataStatus.offDurationSeconds)
                        // print("ToggleLogic - \(dataStatus.dataService) - next toggle time: \(smartformat(dataStatus.nextToggleTime!.timeIntervalSince1970))")
                        
                        // 2b - toggle on if off, update .nextToggleTime
                    } else {
                        // print("ToggleLogic - \(dataStatus.dataService) - it was off, toggling on.")
                        dataStatus.dataService.startCollecting()
                        dataStatus.currentlyOn = true
                        
                        // If there is no off time, we run forever... (some things don't need to be turned off?)
                        if dataStatus.offDurationSeconds == 0 {
                            dataStatus.nextToggleTime = nil
                            // print("ToggleLogic - \(dataStatus.dataService) - no off time, runs forever.")
                        } else {
                            dataStatus.nextToggleTime = Date(timeIntervalSince1970: now + dataStatus.onDurationSeconds)
                            // print("ToggleLogic - \(dataStatus.dataService) - next toggle time: \(smartformat(dataStatus.nextToggleTime!.timeIntervalSince1970))")
                        }
                    }
                    
                    // update local variable from nextToggleTime because it may have changed
                    toggleTime = dataStatus.nextToggleTime?.timeIntervalSince1970 ?? Double.greatestFiniteMagnitude
                }
                
                // As we iterate over all the DataServiceStatuses we look for the soonest event time to trigger
                if toggleTime < next_toggle_check {
                    next_toggle_check = toggleTime
                    // print("ToggleLogic - next_toggle_check set to \(smartformat(next_toggle_check))")
                }
            }
            // print("") // you will need a new line for legibility
        }
        
        // print("=========== next_toggle_check determined to be \(smartformat(next_toggle_check)) (in \(next_toggle_check - now) seconds) ==========")
        return Date(timeIntervalSince1970: next_toggle_check)
    }
    
    ///
    /// Timers
    ///
    
    /// Runs StudyManaager.periodicNetworkTransfers, sets next survey update, starts another timer.
    /// When this function doesn't find anything to do it takes miniscule fractions of a second,
    /// When it does find stuff to do, like dispatch 30 file uploads, it takes a half second.
    /// (profiled on an iphone 15 pro max).
    @objc func pollServices() {
        // handy print statemunt, buuuuut timers are perfect when attached to the debugger so it's not actually very useful??
        var t1 = Date()
        // if t1 > self.nextDataServicesCheck {
        //     print("pollservices was late by \(String(format: "%.3f", t1.timeIntervalSince1970 - self.expected_wakeup.timeIntervalSince1970)) seconds")
        // } else {
        //     print("pollservices was early by \(String(format: "%.3f", self.expected_wakeup.timeIntervalSince1970 - t1.timeIntervalSince1970)) seconds")
        // }
        
        self.clearPollTimer()
        AppEventManager.sharedInstance.logAppEvent(event: "poll_service", msg: "Polling service") // probably pointless
        
        // return early if services are not running (should not be running)
        if !self.areServicesRunning {
            return
        }
        
        let now = Date() // from before the network tasks execute
        let now_interval = now.timeIntervalSince1970
        
        /// set the next service date (its a timeInterval object) to the next event time
        self.nextDataServicesCheck = self.runDataCollectionServicesToggleLogic(now_interval)
        // self.nextHeartbeat = self.heartbeatTimerCheck(now)
        self.nextNewFiles = self.nextNewFilesCheck(now)
        self.nextSurveyDisplayUpdate = self.nextSurveyAvailabilityCheck(now)
        
        // Determines which persistent actions (actions that have some state persisting across
        // app launches) to run and runs them,
        // bug (its either int truncation or it returns the Previous time) - this sometimes returns a value before now.
        // self.nextPersistentTasks = StudyManager.sharedInstance.persistentTimerActions(now)
        StudyManager.sharedInstance.persistentTimerActions(now)
        // update timer
        self.setTheNextPollTimer(now) // it's literally the next function, keeping function clean.
        
        // var t2 = Date()
        // print("pollServices took \(String(format: "%.3f", t2.timeIntervalSince(t1))) seconds")
    }
    
    /// This logic is currently disabled, we are going to try a 10 second timer - having difficulty
    /// getting the nextPersistentTasks to not return a value before now, but I think that's actually
    /// normal because those can be skipped and it uses a "missed" flag, which is meh. It also has
    /// integer-based time where everytihng else has Float or Date() time.
    func setTheNextPollTimer(_ now: Date) {
        // if self.nextDataServicesCheck < now {
        //     fatalError("self.nextDataServicesCheck (\(nextDataServicesCheck)) was set to a time before now (\(now))")
        // }
        // if self.nextHeartbeat < now {
        //     fatalError("self.nextHeartbeat (\(nextHeartbeat)) was set to a time before now (\(now))")
        // }
        // if self.nextNewFiles < now {
        //     fatalError("self.nextNewFiles (\(nextNewFiles)) was set to a time before now (\(now))")
        // }
        // BUG: this logic trips, I didn't undestand this situation when trying to debug, I think it might be
        // normal for persistent tasks to return the timer value of a missed ~upload event.
        // if self.nextPersistentTasks < now {
        //     fatalError("self.nextPersistentTasks (\(nextPersistentTasks)) was set to a time before now (\(now))")
        // }
        // if self.nextSurveyDisplayUpdate < now {
        //     fatalError("self.nextSurveyDisplayUpdate (\(nextSurveyDisplayUpdate)) was set to a time before now (\(now))")
        // }
        
        // earliest next time
        // let next_check: Date = min(
        //     self.nextDataServicesCheck,
        //     self.nextHeartbeat,
        //     self.nextNewFiles,
        //     self.nextPersistentTasks,
        //     self.nextSurveyDisplayUpdate
        // )
        
        // print("self.nextDataServicesCheck:", self.nextDataServicesCheck.timeIntervalSince1970 - now.timeIntervalSince1970)
        // print("self.nextHeartbeat:", self.nextHeartbeat.timeIntervalSince1970 - now.timeIntervalSince1970)
        // print("self.nextNewFiles:", self.nextNewFiles.timeIntervalSince1970 - now.timeIntervalSince1970)
        // print("self.nextPersistentTasks:", self.nextPersistentTasks.timeIntervalSince1970 - now.timeIntervalSince1970)
        // print("self.nextSurveyDisplayUpdate:", self.nextSurveyDisplayUpdate.timeIntervalSince1970 - now.timeIntervalSince1970)
        
        // self.expected_wakeup = next_check
        // self.startPollTimer(next_check.timeIntervalSince1970 - now.timeIntervalSince1970)
        
        // get whichever is soonest, get the number of seconds between then and now.
        // let next_seconds = min(nextSurveyUpdate_seconds, nextDataServicesCheck_seconds) - now_seconds
        // print("now: \(smartformat(now_seconds))")
        // print("nextSurveyUpdate: \(smartformat(self.nextSurveyUpdate)), (\(nextSurveyUpdate_seconds - now_seconds) seconds)")
        // print("nextServicesCheck: \(smartformat(self.nextDataServicesCheck)), (\(nextDataServicesCheck_seconds - now_seconds) seconds)")
        // print("self.nextSettingsUpdate: \(self.nextSettingsUpdate), \(now - self.nextSettingsUpdate)")
        
        self.expected_wakeup = Date(timeIntervalSinceNow: 10.0)
        self.startPollTimer(10.0)
    }

    /// start the poll timer - called in start (1.5 seconds), and in setTheNextPolltimer.
    func startPollTimer(_ seconds: Double) {
        self.clearPollTimer()
        self.timer = Timer.scheduledTimer(
            timeInterval: seconds, target: self, selector: #selector(self.pollServices), userInfo: nil, repeats: false
        )
        // print("The Timer was set for: \(seconds) seconds")
        AppEventManager.sharedInstance.logAppEvent(event: "set_timer", msg: "Set timer for \(seconds) seconds", d1: String(seconds))
    }
}
