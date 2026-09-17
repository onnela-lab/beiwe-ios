import BackgroundTasks
import Sentry

/// This file is under active development and is not documented. Once we work better code for this
/// background process management we can document.

/// Tests results of tests of background tasks :
/// - BGHealthResearchTask is not hitting at all - we know this is configured incorrectly, we need to
///   work out what that is.
/// - The DispatchQueue mechanisme of sending a heartbeat is 1 or 2 _orders of magnitude_ more frequent
///   than any of teh background tasks
/// - Timer - dispatch queue is 43 times more frequent
/// - bgprocessing task - dispatch queue is 87 times more frequent
/// - bgapprefresh task - dispatch queue is 107 times more frequent
/// Over time this drifted towards 50x cumulative based on data sourced from production

//
// The Scheduler Functions - one for each BGTask-like entity
//

func scheduleRefreshHeartbeat() {
    // print("background - scheduling refresh heartbeat")
    let request = BGAppRefreshTaskRequest(identifier: BG_TASK_NAME_BGREFRESH)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30)
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        // capture and report this error to sentry.
        SentrySDK.capture(message: "not a crash - scheduling refresh heartbeat: \(error)") { (scope: Scope) in
            scope.setEnvironment(Constants.APP_INFO_TAG)
            scope.setLevel(.error)
        }
    }
}

func scheduleProcessingHeartbeat() {
    // print("background - scheduling processing heartbeat")
    let request = BGProcessingTaskRequest(identifier: BG_TASK_NAME_BGPROCESSING)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30)
    request.requiresExternalPower = false
    request.requiresNetworkConnectivity = true
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        // capture and report this error to sentry.
        SentrySDK.capture(message: "not a crash - scheduling processing heartbeat: \(error)") { (scope: Scope) in
            scope.setEnvironment(Constants.APP_INFO_TAG)
            scope.setLevel(.error)
        }
    }
}

// @available(iOS 17.0, *)
// func scheduleHealthHeartbeat() {
//     // print("background - scheduling health heartbeat")
//     let request = BGHealthResearchTaskRequest(identifier: BG_TASK_NAME_BGHEALTH)
//     request.earliestBeginDate = Date(timeIntervalSinceNow: 30)
//     request.requiresExternalPower = false
//     request.requiresNetworkConnectivity = true
//     request.protectionTypeOfRequiredData = "junk"
//     do {
//         try BGTaskScheduler.shared.submit(request)
//     } catch {
//         // capture and report this error to sentry.
//         SentrySDK.capture(message: "not a crash - scheduling health heartbeat: \(error)") { (scope: Scope) in
//             scope.setEnvironment(Constants.APP_INFO_TAG)
//             scope.setLevel(.error)
//         }
//     }
// }

func scheduleAllHeartbeats() {
    print("background - scheduling all heartbeats")
    scheduleRefreshHeartbeat()
    scheduleProcessingHeartbeat()
    // if #available(iOS 17.0, *) {
    //     scheduleHealthHeartbeat()
    // }
    // continued processing tasks can only be submitted from the foreground
    // if #available(iOS 26.0, *) {
    //     submitContinuedProcessingHeartbeat()
    // }
}

// Counts the outstanding background tasks (unclear if this includes any currently running background tasks.)
func updateBackgroundTasksCount() {
    var info: [String] = []
    
    BGTaskScheduler.shared.getPendingTaskRequests { (taskRequests: [BGTaskRequest]) in
        printTimer("There are \(taskRequests.count) BGTaskRequests outstanding right now:")
        for request in taskRequests {
            if let refresh_task_request = request as? BGAppRefreshTaskRequest {
                // print("background - \t BGAppRefreshTaskRequest - ", request.identifier, request.earliestBeginDate!)
                info.append("BGAppRefreshTaskRequest \(request.identifier):\(request.earliestBeginDate!)")
            }
            if let processing_task_request = request as? BGProcessingTaskRequest {
                // print("background - \t BGProcessingTaskRequest - ", request.identifier, request.earliestBeginDate!,
                //       "external power:", processing_task_request.requiresExternalPower,
                //       "requires network:", processing_task_request.requiresNetworkConnectivity)
                info.append("BGProcessingTaskRequest \(request.identifier):\(request.earliestBeginDate!)")
            }
            // the background health tasks DO NOT SHOW UP. This is not a version-gating bug, I tested it THOROUGHLY,
            // it's either another bug or they are hidden and are not visible to the getPendingTaskRequests function.
            // if #available(iOS 17.0, *) {
            //     if let health_task_request = request as? BGHealthResearchTaskRequest {
            //         // print("background - \t BGHealthResearchTaskRequest - ", request.identifier, request.earliestBeginDate!)
            //         info.append("BGHealthResearchTaskRequest \(request.identifier):\(request.earliestBeginDate!)")
            //     }
            // }
        }
        Ephemerals.background_task_count = info.joined(separator: ",")
        // print(Ephemerals.background_task_count)
    }
}

/// Claude (Fable 5.1):
/// Tasks don't call setTaskCompleted are counted as expired runs, and iOS aggressively
/// deprioritizes future launches for apps whose tasks routinely expire - so each handler
/// sets an expiration handler and reports completion when its (fast, synchronous) work is done.

/// These are the callbacks that run code in our BGTasks, they always reschedule themselves.
/// BGTasks _DO NOT RUN WHEN THE DEBUGGER IS ATTACHED TO THE APP_.
func handleBGRefresh(task: BGAppRefreshTask) {
    scheduleRefreshHeartbeat()
    var expired = false
    task.expirationHandler = {
        expired = true
    }
    StudyManager.sharedInstance.heartbeat("BGAppRefreshTask")
    runAllBackgroundTasks()
    task.setTaskCompleted(success: !expired)
}

func handleBGPRefresh(task: BGProcessingTask) {
    scheduleProcessingHeartbeat()
    var expired = false
    task.expirationHandler = {
        expired = true
    }
    StudyManager.sharedInstance.heartbeat("BGProcessingTask")
    runAllBackgroundTasks()
    task.setTaskCompleted(success: !expired)
}

// Claude (Fable 5.1):
// iOS 26+ Continued Processing Task - this one differs from the two above.
// It does not launch the app in the background on a schedule; it must be submitted while the
// app is in the FOREGROUND (Apple says submission should stem from a user action), and then
// keeps running after the participant backgrounds the app. The system shows it in a Live
// Activity with our title/subtitle and progress, and the participant can cancel it there.
// Value for us: one more sanctioned window of background runtime right after app use.

// NOT YET ENABLED - also requires uncommenting the registration in AppDelegate.setupBackgroundAppRefresh
// and adding "$(PRODUCT_BUNDLE_IDENTIFIER).heartbeat_continued" to BGTaskSchedulerPermittedIdentifiers
// in Info.plist (continued processing identifiers must be prefixed with the bundle id).
// @available(iOS 26.0, *)
// func submitContinuedProcessingHeartbeat() {
//     // print("background - submitting continued processing heartbeat")
//     let request = BGContinuedProcessingTaskRequest(
//         identifier: BG_TASK_NAME_CONTINUED,
//         title: "Beiwe",
//         subtitle: NSLocalizedString("continued_processing_subtitle", value: "Syncing study data", comment: "")
//     )
//     // .fail = error immediately if the system can't run it now, rather than queueing a stale one.
//     request.strategy = .fail
//     do {
//         try BGTaskScheduler.shared.submit(request)
//     } catch {
//         // capture and report this error to sentry.
//         SentrySDK.capture(message: "not a crash - submitting continued processing heartbeat: \(error)") { (scope: Scope) in
//             scope.setEnvironment(Constants.APP_INFO_TAG)
//             scope.setLevel(.error)
//         }
//     }
// }

// @available(iOS 26.0, *)
// func handleBGCRefresh(task: BGContinuedProcessingTask) {
//     print("background - handle continued processing...")
//     var expired = false
//     task.expirationHandler = {
//         expired = true
//         print("background - BGContinuedProcessingTask expired/cancelled before completing")
//     }
//     // progress is displayed in the system Live Activity; stalled progress gets terminated first.
//     task.progress.totalUnitCount = 2
//     StudyManager.sharedInstance.heartbeat("BGContinuedProcessingTask")
//     task.progress.completedUnitCount = 1
//     runAllBackgroundTasks()
//     task.progress.completedUnitCount = 2
//     task.setTaskCompleted(success: !expired)
// }

// @available(iOS 17.0, *)
// func handleBGHRefresh(task: BGHealthResearchTask) {
//     print("background - handle health...")
//     scheduleHealthHeartbeat()
//     // print("background - BGHealthResearchTask - the handler is getting called \(dateFormatLocal(Date()))")
//     StudyManager.sharedInstance.heartbeat("BGHealthResearchTask")
//     runAllBackgroundTasks()
// }

func runAllBackgroundTasks() {
    // return without anything if study is not started
    guard let _ = StudyManager.sharedInstance.currentStudy else {
        print("background - runAllBackgroundTasks failed because there was no study.")
        return
    }
    // all runtime safety checks should be inside runTimerServices
    StudyManager.sharedInstance.timerManager.runTimerServices()
    StudyManager.sharedInstance.persistentTimerActions(Date())
}
