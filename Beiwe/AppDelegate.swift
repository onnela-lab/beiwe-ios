import BackgroundTasks
import CoreMotion
import Crashlytics
import EmitterKit
import Fabric
import Firebase
import Foundation
import PromiseKit
import ReachabilitySwift
import ResearchKit
import Sentry
import UIKit
import XCGLogger

let log = XCGLogger(identifier: "advancedLogger", includeDefaultDestinations: false)

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate {
    // dev stuff
    var transition_count = 0
    let debugEnabled = false
    var lastAppStart = Date()
    
    // constants
    let gcmMessageIDKey = "gcm.message_id"
    
    // ui stuff
    var window: UIWindow? // this needs to be present according to docs
    var storyboard: UIStoryboard?
    var currentRootView: String? = "launchScreen"
    
    // app capability stuff (why do these need to be here? at all?
    let motionManager = CMMotionManager()
    var reachability: Reachability? // tells us about our network access
    
    var canOpenTel = false
    var locationPermission = false
    let locManager: CLLocationManager = CLLocationManager()
    
    // app state
    var isLoggedIn: Bool = false
    var timeEnteredBackground: Date?
    
    // this is a weird location for an object, its used in powerstatemanager, unclear why this is here.
    let lockEvent = EmitterKit.Event<Bool>()
        
    static func sharedInstance() -> AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    var currentTimestamp: String {
        return timestampString() + " " + TimeZone.current.identifier
    }
    
    var currentStudy: Study? {
        return StudyManager.sharedInstance.currentStudy
    }
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////// APPLICATION SETUP ////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    /// The AppDelegate started function
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.lastAppStart = Date()
        
        // Due to a line of documentation about backgroundtasks that says "do this before didFinishLaunchingWithOptions finishes"
        // we are just going to stick it before everything else.  At least it doesn't crash when you remove background app refresh permissions.
        // register the ios Background task scheduler target for the org.beiwe.heartbeatl task and then call it's scheduler
        self.setupBackgroundAppRefresh()
        self.initialSetup(launchOptions)
        self.setupThatDependsOnDatabase(launchOptions)
        
        // start some background looping for core app functionality
        self.firebaseLoop()
        BACKGROUND_DEVICE_INFO_QUEUE.asyncAfter(deadline: .now() + 60, execute: self.deviceInfoUpdateLoop)
                
        // self.isLoggedIn = true // uncomment to auto log in
        return true
    }
    
    // this is currently literally just being tested because I don't know what it does but apple has documentation about it and the BGTasks are completely unreliable right now.
    func beginBackgroundTask(withName taskName: String?, expirationHandler handler: (() -> Void)? = nil) -> UIBackgroundTaskIdentifier {
        StudyManager.sharedInstance.heartbeat("beginBackgroundTask")
        return UIBackgroundTaskIdentifier(rawValue: 0)
    }

    // setMinimumBackgroundFetchInterval, application(_:performFetchWithCompletionHandler:)
    // func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    //     print("======= performFetchWithCompletionHandler")
    //     completionHandler(.newData)
    // }
    
    func setupLogging() {
        // Create a destination for the system console log (via NSLog), add the destination to the logger
        let systemLogDestination = AppleSystemLogDestination(owner: log, identifier: "advancedLogger.systemLogDestination")
        systemLogDestination.outputLevel = self.debugEnabled ? .debug : .warning
        systemLogDestination.showLogIdentifier = true
        systemLogDestination.showFunctionName = true
        systemLogDestination.showThreadName = true
        systemLogDestination.showLevel = true
        systemLogDestination.showFileName = true
        systemLogDestination.showLineNumber = true
        systemLogDestination.showDate = true
        log.add(destination: systemLogDestination)
    }

    // BY THE WAY background app refresh health tasts simply aren't functional as far as it is possible to tell, so we are just rawdogging at and logging everything
    // up to the server inside the requests to the backend because the app isn't stable enough to be a reliable source of truth.
    func setupBackgroundAppRefresh() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BACKGROUND_TASK_NAME_HEARTBEAT_BGREFRESH, using: HEARTBEAT_QUEUE) { (task: BGTask) in
            print("inside the register closure for \(BACKGROUND_TASK_NAME_HEARTBEAT_BGREFRESH)")
            handleHeartbeatRefresh(task: task as! BGAppRefreshTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BACKGROUND_TASK_NAME_HEARTBEAT_BGPROCESSING, using: HEARTBEAT_QUEUE) { (task: BGTask) in
            print("inside the register closure for \(BACKGROUND_TASK_NAME_HEARTBEAT_BGPROCESSING)")
            handleHeartbeatProcessing(task: task as! BGProcessingTask)
        }
        // this appears to ... Just be broken? it doesn'n register a task, or maybe that task is not visible to getPendingBackgroundTasks in
        if #available(iOS 17.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: BACKGROUND_TASK_NAME_HEARTBEAT_BGHEALTH, using: HEARTBEAT_QUEUE) { (task: BGTask) in
                print("inside the register closure for \(BACKGROUND_TASK_NAME_HEARTBEAT_BGHEALTH)")
                handleHeartbeatHealth(task: task as! BGHealthResearchTask)
            }
        }
    }
    
    func appStartLog() {
        // print("AppUUID: \(PersistentAppUUID.sharedInstance.uuid)")
        let uiDevice = UIDevice.current
        // let modelVersionId = UIDevice.current.model + "/" + UIDevice.current.systemVersion  // this used to be a (completely usused class variable)
        print("name: \(uiDevice.name)")
        print("systemName: \(uiDevice.systemName)")
        print("systemVersion: \(uiDevice.systemVersion)")
        print("model: \(uiDevice.model)")
        print("platform: \(platform())")
    }
    
    /// starts reachability
    func initializeReachability() {
        do {
            self.reachability = Reachability()
            try self.reachability!.startNotifier()
        } catch {
            print("Unable to create or start Reachability")
        }
    }
    
    func printLoadedStudyInfo() {
        print("\n\n\n")
        print("patient id: '\(String(describing: ApiManager.sharedInstance.patientId))'")
        print("fcmToken: '\(String(describing: ApiManager.sharedInstance.fcmToken))'")
        print("patientId: '\(String(describing: ApiManager.sharedInstance.patientId))'")
        print("customApiUrl: '\(String(describing: ApiManager.sharedInstance.customApiUrl))'")
        print("baseApiUrl: '\(String(describing: ApiManager.sharedInstance.baseApiUrl))'")
        print("firebase app: '\(String(describing: FirebaseApp.app()))'")
        print("\n\n\n")
    }
    
    /// These are the basics that we need to be able to Use The App At All (or Debug the app).
    /// If your setup does not require the database it can go in here.
    func initialSetup(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // initialize Sentry IMMEDIATELY
        self.setupSentry()
        self.setupLogging()
        // setupCrashLytics()  // not currently using crashlytics
        AppEventManager.sharedInstance.didLaunch(launchOptions: launchOptions)
        // appStartLog()  // this is too verbose and usually unnecessary, uncomment if you want but don't commit.
        self.initializeReachability()
        self.initializeUI()
        
        // determine whether phone call bump is available - its just a weird flag we should set early
        self.canOpenTel = UIApplication.shared.canOpenURL(URL(string: "tel:6175551212")!) // (should be true ios 10+? or is there a permission you have to ask for?)
    }
    
    /// Some of our setup needs to execute inside of promises because it needs to wait on other tasks, specifically setting up the database.
    /// This is Terrible. Everything in the app depends on the database. App load should block until the database is configured.
    /// Can we rewrite the app to abandon this awful crap? HAHAAHAHAHAH. 🙄
    func setupThatDependsOnDatabase(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // Start the database, eg LOAD STUDY STUFF
        Recline.shared.open().then { (_: Bool) -> Promise<Bool> in
            // print("Database opened")
            StudyManager.sharedInstance.loadDefaultStudy()
        }.done { (_: Bool) in
            // IF A NOTIFICATION WAS RECEIVED while app was in killed state there will be launch options!
            if launchOptions != nil {
                if let informationDictionary = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? Dictionary<AnyHashable, Any> {
                    self.handleSurveyNotification(informationDictionary)
                }
            }
            // get any (delivered) notifications
            UNUserNotificationCenter.current().getDeliveredNotifications { (notifications: [UNNotification]) in
                for notification in notifications {
                    self.handleSurveyNotification(notification.request.content.userInfo)
                }
            }
            
            // okay we currently are blanket removing notifications, not ideal.
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            self.transitionToLoadedAppState() // transition to loaded app state
        }.catch { (_: Error) in
            print("Database open failed, probably should just crash the app tbh")
        }
    }
    
    /// Run this function once at app boot and it will rerun itself every minute, updating some stored values that are in turn reported to the server.
    func deviceInfoUpdateLoop() {
        
        self.currentStudy?.lastAppStart = self.currentTimestamp
        
        // This takes an amount of time to run / must be run ~asynchronously
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
            Ephemerals.notification_permission = switch settings.authorizationStatus {
            case .notDetermined: "not_determined"
            case .denied: "denied"
            case .authorized: "authorized"
            case .provisional: "provisional"
            case .ephemeral: "ephemeral"
            @unknown default: "unknown: '\(settings.authorizationStatus.rawValue)'"
            }
        })

        // locationServicesEnabledDescription and notification_permission are device info datapoints taht need to be checked on periiodically
        // because they require async calls to get their values, and we can't wait on them every time we do a network request.
        Ephemerals.locationServicesEnabledDescription = CLLocationManager.locationServicesEnabled().description
        Ephemerals.significantLocationChangeMonitoringAvailable = CLLocationManager.significantLocationChangeMonitoringAvailable().description
        
        // backgroundRefreshStatus needs to be run on the main thread, but we can do this asynchronously somehow? and that's better? hunh?
        DispatchQueue.main.async {
            Ephemerals.backgroundRefreshStatus = switch UIApplication.shared.backgroundRefreshStatus {
            case .available: "available"
            case .denied: "denied"
            case .restricted: "restricted"
            @unknown default: "unknown: '\(UIApplication.shared.backgroundRefreshStatus.rawValue)'"
            }
        }
        
        _ = countBackgroundTasks()  // this is purely for logging/development purposes
        
        BACKGROUND_DEVICE_INFO_QUEUE.asyncAfter(deadline: .now() + 60, execute: self.deviceInfoUpdateLoop)
    }
    
    /// anything that depends on app state at initialization time needs to go after this has run
    func transitionToLoadedAppState() {
        self.transition_count += 1
        Ephemerals.transition_count = self.transition_count
        print("transitionToLoadedAppState incremented to \(self.transition_count)")

        if let currentStudy = self.currentStudy {
            if currentStudy.participantConsented {
                StudyManager.sharedInstance.startStudyDataServices()
            }
            
            if !self.isLoggedIn {
                // Load up the login view - when the animation is working (it used to not work 🙄) the main screen is
                // visible briefly.  This is fine? we aren't really protecting any data here.
                self.changeRootViewControllerWithIdentifier("login")
            } else {
                // We are logged in, so if we've completed onboarding load main interface, Otherwise continue onboarding.
                if currentStudy.participantConsented {
                    // print("transitionToLoadedAppState - isLoggedIn True, setting to main view")
                    self.changeRootViewControllerWithIdentifier("mainView")
                } else {
                    // print("transitionToLoadedAppState - isLoggedIn True, setting to consent view")
                    self.changeRootViewController(ConsentManager().consentViewController)
                }
            }
            self.initializeFirebase()
            
            // schedule the heartbeats (after the database is ready, apparently, but there were a lot of race condition errors so this might not be necessary)
            scheduleAllHeartbeats()
        } else {
            // If there is no study loaded, then it's obvious.  We need the onboarding flow from the beginning.
            self.changeRootViewController(OnboardingManager().onboardingViewController)
        }
    }

    /// Compares password to the stored password, but also sets password if there is no password due a bug where
    /// the app (or keychain?) up and forgets the password. This app doesn't actually have any data to show the user,
    /// the password is for show/getting the app through the original IRB/participant security theater.
    func checkPasswordAndLogin(_ password: String) -> Bool {
        // uncomment these lines to make login always succeed, useful for debugging patterns.
        // ApiManager.sharedInstance.password = PersistentPasswordManager.sharedInstance.passwordForStudy() ?? ""
        // self.isLoggedIn = true
        // return true
        
        // 2.2.1: there was a bug where access of passwordForStudy using the optional-force operoter (then line 169), e.g.
        //    PersistentPasswordManager.sharedInstance.passwordForStudy()!
        // would error as null. Using the optional coalescing operator should fix it
        var storedPassword: String = PersistentPasswordManager.sharedInstance.passwordForStudy() ?? ""
        // print("incoming password: '\(password)'")
        // print("current password: '\(storedPassword)'")

        // If there is somehow a situation where no stored password is set, take the new password and set it.
        //  THIS EXISTS PURELY TO FIX A THEORETICAL BUG WHERE PASSWORDS WERE SOMEHOW RESET,
        //  BUT THE SOURCE OF THAT BUG WAS PROBABLY A CHANGE OF APP BUILD CREDENTIALS.
        if storedPassword.isEmpty {
            PersistentPasswordManager.sharedInstance.storePassword(password)
            storedPassword = PersistentPasswordManager.sharedInstance.passwordForStudy()!
        }
        
        if password == storedPassword {
            ApiManager.sharedInstance.password = storedPassword
            self.isLoggedIn = true
            if let study = self.currentStudy {
                study.lastSuccessfulLogin = self.currentTimestamp
                _ = Recline.shared.save(study)
            }
            return true
        }
        return false
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////// APPLICATION WILL X ///////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("applicationWillEnterForeground")
        if let study = self.currentStudy {
            study.lastApplicationWillEnterForeground = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        
        // Called as part of the transition from the background to the inactive (Eli does not know who wrote "inactive") state.
        // here you can undo many of the changes made on entering the background.
        UNUserNotificationCenter.current().getDeliveredNotifications { (notifications: [UNNotification]) in
            for notification in notifications {
                self.handleSurveyNotification(notification.request.content.userInfo)
            }
        }
        
        // clear any notification center items.
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        // logout timer check
        if let timeEnteredBackground = timeEnteredBackground, let currentStudy = self.currentStudy, let studySettings = currentStudy.studySettings {
            if self.isLoggedIn {
                let loginExpires = timeEnteredBackground.addingTimeInterval(Double(studySettings.secondsBeforeAutoLogout))
                // old incomprehensible code for identifying if the logout timer has passed. It works, just leave it
                if loginExpires.compare(Date()) == ComparisonResult.orderedAscending {
                    // print("expired.  Log 'em out")
                    self.isLoggedIn = false
                    self.transitionToLoadedAppState()
                }
            }
        } else {
            self.isLoggedIn = false
        }
    }

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("applicationWillFinishLaunchingWithOptions")
        if let study = self.currentStudy {
            study.lastApplicationWillFinishLaunchingWithOptions = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        print("applicationWillTerminate")
        if let study = self.currentStudy {
            study.lastApplicationWillTerminate = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        
        AppEventManager.sharedInstance.logAppEvent(event: "terminate", msg: "Application terminating")
        
        let dispatchGroup = DispatchGroup() // I don't know what this multithreading control tool is
        dispatchGroup.enter()
        // call stop on the study, then... leave the dispatch group, which I think means wait for everything to finish (or crash)
        StudyManager.sharedInstance.stop().done(on: GLOBAL_DEFAULT_QUEUE) { (_: Bool) in
            dispatchGroup.leave()
        }.catch(on: GLOBAL_DEFAULT_QUEUE) { (_: Error) in
            dispatchGroup.leave()
        }
        dispatchGroup.wait() // block until the dispatch group is... finished? until the promise is finished?
        print("applicationWillTerminate exiting")
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        print("applicationWillResignActive")
        if let study = self.currentStudy {
            study.lastApplicationWillResignActive = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////// APPLICATION DID X ////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        print("applicationDidBecomeActive")
        if let study = self.currentStudy {
            study.lastApplicationDidBecomeActive = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        
        AppEventManager.sharedInstance.logAppEvent(event: "foreground", msg: "Application entered foreground")

        // Send FCM Token everytime the app launches
        if ApiManager.sharedInstance.patientId != "" /* && FirebaseApp.app() != nil*/ {
            if let token = Messaging.messaging().fcmToken {
                self.sendFCMToken(fcmToken: token)
            }
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        print("applicationDidEnterBackground")
        if let study = self.currentStudy {
            study.lastApplicationDidEnterBackground = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        self.timeEnteredBackground = Date()
        AppEventManager.sharedInstance.logAppEvent(event: "background", msg: "Application entered background")
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("applicationDidReceiveMemoryWarning")
        if let study = self.currentStudy {
            study.lastApplicationDidReceiveMemoryWarning = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        AppEventManager.sharedInstance.logAppEvent(event: "memory_warn", msg: "Application received memory warning")
    }

    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        print("applicationProtectedDataDidBecomeAvailable")
        if let study = self.currentStudy {
            study.lastApplicationProtectedDataDidBecomeAvailable = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        self.lockEvent.emit(false)
        AppEventManager.sharedInstance.logAppEvent(event: "unlocked", msg: "Phone/keystore unlocked")
    }

    func applicationProtectedDataWillBecomeUnavailable(_ application: UIApplication) {
        print("applicationProtectedDataWillBecomeUnavailable")
        if let study = self.currentStudy {
            study.lastApplicationProtectedDataWillBecomeUnavailable = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        self.lockEvent.emit(true)
        AppEventManager.sharedInstance.logAppEvent(event: "locked", msg: "Phone/keystore locked")
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////// PERMISSIONS //////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// this function gets called when CLAuthorization status changes
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            // If status has not yet been determied, ask for authorization
            manager.requestAlwaysAuthorization()
            break
        case .authorizedWhenInUse:
            // If authorized when in use
            self.locationPermission = false
            break
        case .authorizedAlways:
            // If always authorized
            self.locationPermission = true
            break
        case .restricted:
            // If restricted by e.g. parental controls. User can't enable Location Services
            self.locationPermission = false
            break
        case .denied:
            // If user denied your app access to Location Services, but can grant access from Settings.app
            self.locationPermission = false
            break
        default:
            break
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////// REAL NOTIFICATION CODE ///////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for notifications: \(error.localizedDescription)")
        if let study = self.currentStudy {
            study.lastFailedToRegisterForNotification = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        AppEventManager.sharedInstance.logAppEvent(event: "push_notification", msg: "Failed to register for notifications: \(error.localizedDescription)")
    }

    // eventually called after the participant receives a notification while the participant is in the background
    // this callback will not be fired until the user taps on the notification launching the application.
    func application(_ application: UIApplication, didReceiveRemoteNotification messageInfo: [AnyHashable: Any]) {
        if let study = self.currentStudy {
            study.lastBackgroundPushNotificationReceived = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        
        AppEventManager.sharedInstance.logAppEvent(event: "push_notification", msg: "Background push notification received")
        self.printMessageInfo(messageInfo)

        // if the notification is for a survey
        if messageInfo["survey_ids"] != nil {
            self.handleSurveyNotification(messageInfo)
        }
    }
    
    // called when receiving notification while app is in foreground
    /// If you are receiving a notification message while your app is in the background,
    /// this callback will not be fired until the user taps on the notification launching the application.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification messageInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Foreground push notification received func application")
        if let study = self.currentStudy {
            study.lastForegroundPushNotificationReceived = self.currentTimestamp
            _ = Recline.shared.save(study)
        }
        
        AppEventManager.sharedInstance.logAppEvent(event: "push_notification", msg: "Foreground push notification received")
        self.printMessageInfo(messageInfo)

        // if the notification is for a survey
        if messageInfo["survey_ids"] != nil {
            self.handleSurveyNotification(messageInfo)
        }
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    /// convenience print function when receiving a notification, uncomment body to print this in several useful locations.
    func printMessageInfo(_ messageInfo: [AnyHashable: Any]) {
        print("Push notification message contents:")
        print(messageInfo)
    }

    /// alternate type that handles some casting, it works.
    func printMessageInfo(_ notificationRequest: UNNotificationRequest) {
        let messageInfoDict: [AnyHashable: Any] = notificationRequest.content.userInfo
        self.printMessageInfo(messageInfoDict)
    }
    
    /// the userNotificationCenter functions receive a UNNotification that has to be cast to a UNNotificationRequest and then a dict
    func handleSurveyNotification(_ notificationRequest: UNNotificationRequest) {
        let messageInfo: [AnyHashable: Any] = notificationRequest.content.userInfo
        self.handleSurveyNotification(messageInfo)
    }
    
    /// code to run when receiving a push notification with surveys in it. Called from an AppDelegate extension.
    /// Checks for any new surveys on the server and pops any survey notifications indicated in the push notificattion
    func handleSurveyNotification(_ messageInfo: Dictionary<AnyHashable, Any>) {
        // return if nothing found
        guard let surveyIdsString = messageInfo["survey_ids"] else {
            print("no surveyIds found, checking for new surveys anyway.")
            self.downloadSurveys(surveyIds: [])
            return
        }
        
        // extract survey ids to force-display
        AppEventManager.sharedInstance.logAppEvent(event: "push_notification", msg: "Received notification while app was killed")
        let surveyIds: [String] = self.jsonToSurveyIdArray(json: surveyIdsString as! String)
        
        // downloadSurveys calls setActiveSurveys, even if it errors/fails. We always want to download the most recent survey information.
        // (old versions of the backend don't supply the sent_time key)
        if let sentTimeString = messageInfo["sent_time"] as! String? {
            self.downloadSurveys(surveyIds: surveyIds, sentTime: isoStringToTimeInterval(timeString: sentTimeString))
        } else {
            self.downloadSurveys(surveyIds: surveyIds)
        }
    }
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////// MISC BEIWE STUFF /////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // converts json string to an array of strings
    func jsonToSurveyIdArray(json: String) -> [String] {
        let surveyIds = try! JSONDecoder().decode([String].self, from: Data(json.utf8))
        for surveyId in surveyIds {
            if !(self.currentStudy?.surveyExists(surveyId: surveyId) ?? false) {
                print("Received notification for a NEW survey \(surveyId)")
                AppEventManager.sharedInstance.logAppEvent(event: "push_notification", msg: "Received notification for new survey \(surveyId)")
            } else {
                print("Received notification for survey \(surveyId)")
                AppEventManager.sharedInstance.logAppEvent(event: "push_notification", msg: "Received notification for survey \(surveyId)")
            }
        }
        return surveyIds
    }

    // downloads all of the surveys in the study
    func downloadSurveys(surveyIds: [String], sentTime: TimeInterval = 0) {
        guard let study = self.currentStudy else {
            return
        }
        Recline.shared.save(study).then { (_: Study) -> Promise<([Survey], Int)> in
            let surveyRequest = GetSurveysRequest()
            return ApiManager.sharedInstance.arrayPostRequest(surveyRequest)
        }.then { (surveys: [Survey], _: Int) -> Promise<Void> in
            study.surveys = surveys
            return Recline.shared.save(study).asVoid()
        }.done { (_: Void) in
            self.setActiveSurveys(surveyIds: surveyIds, sentTime: sentTime)
        }.catch { (error: Error) in
            print("Error downloading surveys: \(error)")
            AppEventManager.sharedInstance.logAppEvent(event: "survey_download", msg: "Error downloading surveys: \(error)")
            // try setting the active surveys anyway, even if download failed, can still use previously downloaded surveys
            self.setActiveSurveys(surveyIds: surveyIds, sentTime: sentTime)
        }
    }

    /// sets the active survey on the main app page, force-enables any specified surveys.
    func setActiveSurveys(surveyIds: [String], sentTime: TimeInterval = 0) {
        guard let study = self.currentStudy else {
            return
        }
        
        // force reload all always-available surveys and any passed in surveys
        for survey in study.surveys {
            let surveyId = survey.surveyId!, from_notification = surveyIds.contains(surveyId)
            
            if from_notification || survey.alwaysAvailable {
                let activeSurvey = ActiveSurvey(survey: survey)
                // when we receive a notification we need to record that, this is used to sort surveys on the main screen (I think)
                if from_notification {
                    activeSurvey.received = sentTime
                    // FIXME: study.receivedAudioSurveys and study.receivedTrackingSurveys are junk, they are assigned but never used.
                    if let surveyType = survey.surveyType {
                        switch surveyType {
                        case .AudioSurvey:
                            study.receivedAudioSurveys = (study.receivedAudioSurveys) + 1
                        case .TrackingSurvey:
                            study.receivedTrackingSurveys = (study.receivedTrackingSurveys) + 1
                        }
                    }
                }
                study.activeSurveys[surveyId] = activeSurvey
            }
        }
        
        // if the survey id doesn't exist record a log statement
        for surveyId in surveyIds {
            if !study.surveyExists(surveyId: surveyId) {
                print("Could not get survey \(surveyId)")
                AppEventManager.sharedInstance.logAppEvent(event: "survey_download", msg: "Could not get obtain survey for ActiveSurvey")
            }
        }
        
        // Emits a surveyUpdated event to the listener
        StudyManager.sharedInstance.surveysUpdatedEvent.emit(0)
        Recline.shared.save(study).catch { (_: Error) in
            print("Failed to save study after processing surveys")
        }

        // set badge number
        UIApplication.shared.applicationIconBadgeNumber = study.activeSurveys.count
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////// Firebase Stuff ///////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func firebaseLoop() {
        // The app cannot register with firebase until it gets a token, which only occurs at registration time, and it needs access to the appDelegate.
        // This must be called after FirebaseApp.configure(), so we dispatch it and wait until the app is initialized from RegistrationViewController...
        GLOBAL_BACKGROUND_QUEUE.async {
            while !StudyManager.real_study_loaded {
                sleep(1) // print("waiting for study to load")
            }
            while FirebaseApp.app() == nil { // FirebaseApp.app() emits the firebase spam log
                sleep(1) // print("waiting firbase app to be ready")
            }
            Messaging.messaging().delegate = self
            UNUserNotificationCenter.current().delegate = self
            // App crashes if this isn't called on main thread
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
                if let token = Messaging.messaging().fcmToken {
                    self.sendFCMToken(fcmToken: token)
                }
            }
        }
    }

    func initializeFirebase() {
        // safely checks whether to start firebase.
        if ApiManager.sharedInstance.patientId != "" && FirebaseApp.app() == nil {
            self.checkFirebaseCredentials()
            let token = Messaging.messaging().fcmToken
            self.sendFCMToken(fcmToken: token ?? "")
        }
    }
    
    func configureFirebase(studySettings: StudySettings) {
        let options = FirebaseOptions(googleAppID: studySettings.googleAppID, gcmSenderID: studySettings.gcmSenderID)
        options.apiKey = studySettings.apiKey
        options.projectID = studySettings.projectID
        options.bundleID = studySettings.bundleID
        options.clientID = studySettings.clientID
        options.databaseURL = studySettings.databaseURL
        options.storageBucket = studySettings.storageBucket
        // firebase is pretty noisy, so we can squash the excess. (this does not squash the
        // "The default Firebase app has not yet been configured" error, wish it did.)
        FirebaseConfiguration.shared.setLoggerLevel(.min)

        // initialize Firebase on the main thread
        DispatchQueue.main.async {
            // this used to depend on what version of beiwe (with or without pre-filled server url)
            FirebaseApp.configure(options: options)
        }
    }

    func checkFirebaseCredentials() {
        // case: unregistered - return early
        guard let studySettings = self.currentStudy?.studySettings else {
            AppEventManager.sharedInstance.logAppEvent(
                event: "push_notification", msg: "Unable to configure Firebase App. No study found.")
            return
        }
        // case: the registered server did not have push notification credentials
        if studySettings.googleAppID == "" {
            return
        }
        // Configure firebase
        if FirebaseApp.app() == nil {
            self.configureFirebase(studySettings: studySettings)
            AppEventManager.sharedInstance.logAppEvent(
                event: "push_notification", msg: "Registered for push notifications with Firebase")
        }
    }

    func sendFCMToken(fcmToken: String) {
        if fcmToken != "" {
            let fcmTokenRequest = FCMTokenRequest(fcmToken: fcmToken)
            ApiManager.sharedInstance.makePostRequest(fcmTokenRequest).catch { (error: Error) in
                AppEventManager.sharedInstance.logAppEvent(
                    event: "push_notification", msg: "Error registering FCM token: \(error)")
            }
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////// UI STUFF ///////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func initializeUI() {
        // set up colors for researchkit, set the launch screen view.
        let rkAppearance: UIView = UIView.appearance(whenContainedInInstancesOf: [ORKTaskViewController.self])
        rkAppearance.tintColor = AppColors.tintColor
        // set core ui to load launch screen - this is only called at app-open, don't wrap in DispatchQueue.main.async
        self.storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = UIStoryboard(
            name: "LaunchScreen", bundle: Bundle.main).instantiateViewController(withIdentifier: "launchScreen")
        self.window!.makeKeyAndVisible()
    }

    /// Helper function for setting root view controller by name
    func changeRootViewControllerWithIdentifier(_ identifier: String!) {
        if identifier == self.currentRootView {
            return
        }
        // the parentheses are required for the forced unwrap... why?
        let desiredViewController: UIViewController = (self.storyboard?.instantiateViewController(withIdentifier: identifier))!
        self.changeRootViewController(desiredViewController, identifier: identifier)
    }
    
    /// Encapsulates the rootviewcontroller update operation in a DispatchQueue.main.async, all transitions like this
    /// should be in one, the black screen bug was terrible.
    func changeRootViewController(_ desiredViewController: UIViewController, identifier: String? = nil) {
        // OK. I think we have a race condition somewhere that causes the black screen bug "here" (it might be the other thread).
        // The race condition we encountered was in the call to set the login screen when the login timer expires and the user.
        // This message always got printed when the bug occurred (I think always, could be wrong about that):
        //     This method can cause UI unresponsiveness if invoked on the main thread. Instead, consider waiting for the
        //       `-locationManagerDidChangeAuthorization:` callback and checking `authorizationStatus` first. """
        // (The referenced code is part of the check for location permissions.)
        // The fix is to wrap this rootview controller and animation in DispatchQueue.main.async.
        // This seems so critical and difficult to debug that we will just ALWAYS do it, I guess.
        // UPDATE:
        //   Based on review of my logs of old black screen bugs that I kept around it looks like the authorizationStatus message
        //   did NOT always co-occur.  If true (I definitely purged some lines from those logs) then we still have an unknown
        //   proximate cause / source of the thing I'm going to continue to call a race condition.
        DispatchQueue.main.async {
            self.currentRootView = identifier
            let snapshot: UIView = (self.window?.snapshotView(afterScreenUpdates: true))!
            desiredViewController.view.addSubview(snapshot)
            self.window?.rootViewController = desiredViewController
            // simple zoom animation for transitions
            UIView.animate(withDuration: 0.3, animations: { () in
                snapshot.layer.opacity = 0
                snapshot.layer.transform = CATransform3DMakeScale(1.5, 1.5, 1.5)
            }, completion: { (_: Bool) in
                snapshot.removeFromSuperview()
            })
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////// CRASHLYTICS STUFF ////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // func setupCrashLytics() {
    //     Fabric.with([Crashlytics.self])
    //     let crashlyticsLogDestination = XCGCrashlyticsLogDestination(owner: log, identifier: "advancedlogger.crashlyticsDestination")
    //     crashlyticsLogDestination.outputLevel = .debug
    //     crashlyticsLogDestination.showLogIdentifier = true
    //     crashlyticsLogDestination.showFunctionName = true
    //     crashlyticsLogDestination.showThreadName = true
    //     crashlyticsLogDestination.showLevel = true
    //     crashlyticsLogDestination.showFileName = true
    //     crashlyticsLogDestination.showLineNumber = true
    //     crashlyticsLogDestination.showDate = true
    //     // Add the destination to the logger
    //     log.add(destination: crashlyticsLogDestination)
    //     log.logAppDetails()
    // }
    //
    // // completely disabled, does nothing
    // func setDebuggingUser(_ username: String) {
    //     // TODO: Use the current user's information
    //     // You can call any combination of these three methods
    //     // Crashlytics.sharedInstance().setUserEmail("user@fabric.io")
    //     // Crashlytics.sharedInstance().setUserIdentifier(username)
    //     // Crashlytics.sharedInstance().setUserName("Test User")
    // }
    //
    // func crash() {
    //     Crashlytics.sharedInstance().crash()
    // }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////// SENTRY STUFF ////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func setupSentry() {
        // loads sentry key, prints an error if it doesn't work.
        do {
            let dsn = Configuration.sharedInstance.settings["sentry-dsn"] as? String ?? "dev"
            if dsn == "release" {
                Client.shared = try Client(dsn: SentryKeys.release_dsn)
            } else if dsn == "dev" {
                Client.shared = try Client(dsn: SentryKeys.development_dsn)
            } else {
                throw "Invalid Sentry configuration"
            }
            try Client.shared?.startCrashHandler()
        } catch let error {
            print("\(error)")
        }
    }
}

// ios_10_message_handling
@available(iOS 10, *)
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Receive displayed notifications for iOS 10 devices.
    // THIS ONE is called when RECEIVING a notification while app is in FOREGROUND.
    /// The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely
    /// manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the
    /// notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // print("Foreground push notification received in extension 1")
        AppEventManager.sharedInstance.logAppEvent(event: "push_notification", msg: "Foreground push notification received")
        self.printMessageInfo(notification.request)
        self.handleSurveyNotification(notification.request)
        completionHandler([]) // Change to preferred presentation option
    }

    // THIS ONE is called when TAPPING on notification when app is in BACKGROUND.
    /// The method will be called on the delegate when the user responded to the notification by opening the application,
    /// dismissing the notification, or choosing a UNNotificationAction.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // print("Background push notification received in extension 2")
        AppEventManager.sharedInstance.logAppEvent(event: "push_notification", msg: "Background push notification received")
        self.printMessageInfo(response.notification.request)
        self.handleSurveyNotification(response.notification.request)
        completionHandler()
    }
}

// refresh_token code
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        let dataDict: [String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        // Note: This callback is fired at each app startup and whenever a new token is generated.

        // wait until user is registered to send FCM token, runs on background thread
        GLOBAL_BACKGROUND_QUEUE.async {
            while ApiManager.sharedInstance.patientId == "" {
                sleep(1)
            }
            self.sendFCMToken(fcmToken: fcmToken)
        }
    }

    // ios 10 data message
    // Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
    // To enable direct data messages, you can set Messaging.messaging().shouldEstablishDirectChannel to true.
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        // FIXME: what even is this function
        log.error("Received data message: \(remoteMessage.appData)")
        // remoteMessage.messageID
    }
}
