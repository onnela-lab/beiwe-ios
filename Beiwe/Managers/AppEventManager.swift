import EmitterKit
import Foundation

let app_event_headers = [
    "timestamp",
    "launchId",
    "memory",
    "battery",
    "event",
    "msg",
    "d1",
    "d2",
    "d3",
    "d4",
]

/// The iOS Log Datamanager
class AppEventManager: DataServiceProtocol {
    static let sharedInstance = AppEventManager()  // singleton reference
    
    // iOS Log stuff
    let storeType = "ios_log"
    var dataStorage: DataStorage?
    
    // basics
    var isCollecting: Bool = false
    
    // manager state
    var launchTimestamp: Date = Date()  // briefly wrong at application start? before AppDelegate.application() is called
    var launchOptions: String = ""  // these appear to be the App's launch options but it is never actually populated other than an empty string or "location". sure. whatever.
    var eventCount = 0  // incremented whenever an event is logged
    var didLogLaunch: Bool = false
    
    // an identifier value that is unique to whenever AppDelegate started - only used locally?
    var launchId: String {
        return String(Int64(self.launchTimestamp.timeIntervalSince1970 * 1000))
    }
    
    /// Called on app launch, sets the launch timestamp()
    func didLaunch(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        self.launchOptions = ""
        self.launchTimestamp = Date()
        // do nothing for... 18 lines of code
        if (launchOptions?.index(forKey: UIApplication.LaunchOptionsKey.location)) != nil {
            self.launchOptions = "location"
            // it looks like this indicates whether the app started in the background, apparently by a location event of some kind
            /* let localNotif = UILocalNotification()
             // localNotif.fireDate = currentDate
             let body: String = "Beiwe was Launched in the background"
             localNotif.alertBody = body
             localNotif.soundName = UILocalNotificationDefaultSoundName
             UIApplication.shared.scheduleLocalNotification(localNotif)*/
        }
        //record launch options - on wait no we don't do that for some reason?
        /* if let launchOptions = launchOptions {
             for (kind, _) in launchOptions {
                 if (self.launchOptions != "") {
                     self.launchOptions = self.launchOptions + ":"
                 }
                 self.launchOptions = self.launchOptions + String(describing: kind)
             }
         }*/
        // log.verbose("AppEvent didLaunch, launchId: \(self.launchId) (launch options are ignored) (launch options are ignored) (launch options are ignored), options: \(self.launchOptions) (launch options are ignored) (launch options are ignored) (launch options are ignored)")
    }
    
    /// writes an app event to the iOS Log
    func logAppEvent(event: String, msg: String = "", d1: String = "", d2: String = "", d3: String = "") {
        guard let dataStorage = self.dataStorage else {
            return
        }
        
        let date = Date()
        let log_content: [String] = [
            event,
            msg,
            d1,
            d2,
            d3,
            String(self.eventCount),
        ]
        
        // uncomment to print the app log
        // print("==App Log== `\(dateFormatLocalWithMs(date)) - `\(log_content.joined(separator: "` - `"))")
        
        // metadata
        var full_statement: [String] = [
            String(Int64(date.timeIntervalSince1970 * 1000)),
            self.launchId,
            self.getMemoryUsage(),
            String(UIDevice.current.batteryLevel)
        ]
        full_statement.append(contentsOf: log_content)
        dataStorage.store(full_statement)
        
        self.eventCount += 1  // update state
    }

    /// protocol function - iniitalize data, always returns true. Logs only on first call
    func initCollecting() -> Bool {
        self.dataStorage = DataStorageManager.sharedInstance.createStore(self.storeType, headers: app_event_headers)
        // log that a recording session has started - why? legacy I guess.
        if !self.didLogLaunch {
            self.didLogLaunch = true
            let appVersion: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)!
            self.logAppEvent(event: "launch", msg: "Application launch", d1: self.launchOptions, d2: appVersion)
        }
        return true
    }

    /// protocol function - does not directly start collecting - sets isCollecting to true and logs,
    func startCollecting() {
        // print("Turning \(self.storeType) collection on")
        self.logAppEvent(event: "collecting", msg: "Collecting Data")
        self.isCollecting = true
    }

    /// protocol function - sets is collection to false
    func pauseCollecting() {
        // print("Pausing \(self.storeType) collection but that is meaningless?")
        self.isCollecting = false
    }

    /// protocol function - completely stops the iOS Log data stream
    func finishCollecting() {
        // print("Finishing \(self.storeType) collection")
        self.logAppEvent(event: "stop_collecting", msg: "Stop Collecting Data")
        self.pauseCollecting()
        self.createNewFile() // we have lazy file creation
    }
    
    func createNewFile() {
        self.dataStorage?.reset()
    }
    
    func flush() {
        // AppEventManager does not have potentially intensive write operations, it
        // writes it's data immediately.
    }
    
    /// Gets a String like "used megabytes: 5" (ts an int) of the current app usage, uses an incorrect value to define megabyte.
    func getMemoryUsage() -> String {
        var taskInfo = mach_task_basic_info()  // Darwin.mach.mach_task_basic_info, thread information
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        // kerr a cstring
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            let usedMegabytes: UInt64 = taskInfo.resident_size / 1000000  // Its an apple device so binary values are defined incorrectly using base 10. 🙄
            // print("used megabytes: \(usedMegabytes)")
            return String(usedMegabytes)
        } else {
            print("Error with task_info(): " +
                (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
            return ""
        }
    }
    
    /* /// detects the unlock screen, apparently. Not used, shifting it out of the way
     func didLockUnlock(_ isLocked: Bool) {
         log.info("Lock state data changed: \(isLocked)")
         var data: [String] = []
         data.append(String(Int64(Date().timeIntervalSince1970 * 1000)))
         let state: String = isLocked ? "Locked" : "Unlocked"
         data.append(state)
         data.append(String(UIDevice.current.batteryLevel))
         self.store?.store(data)
         self.store?.flush()
     }*/
}

// looks like a(n old) copy of the ios log manager that is a dev log file or something
// class DevLogManager: DataServiceProtocol {
//     static let sharedInstance = AppEventManager()
//     var isCollecting: Bool
//     let storeType = "dev_log"
//     let headers = ["timestamp", "ET"]
//     var store: DataStorage?
//     var listeners: [Listener] = []
//
//     var isStoreOpen: Bool {  // this was removed?
//         return self.store != nil
//     }
//
//     func logAppEvent(_ statement: String) {
//         // literally the timestamp followed by the statement:
//         let date = Date()
//         self.store?.store(String(Int64(date.timeIntervalSince1970 * 1000)) + "," + date.ISO8601Format() + "," + statement)
//     }
//
//     func initCollecting() -> Bool {
//         if self.store != nil {
//             return true
//         }
//         self.store = DataStorageManager.sharedInstance.createStore(self.storeType, headers: self.headers)
//         return true
//     }
//
//     func startCollecting() {
//         // print("Turning \(self.storeType) collection on")
//         self.logAppEvent("dev log start")
//         self.isCollecting = true
//     }
//
//     func pauseCollecting() {
//         self.isCollecting = false
//         log.info("Pausing \(self.storeType) collection")
//         self.logAppEvent("dev log pause")
//         self.listeners = []
//         self.store!.flush()
//     }
//
//     func finishCollecting() -> Promise<Void> {
//         log.info("Finish \(self.storeType) collection")
//         self.pauseCollecting()
//         self.logAppEvent("dev log end")
//         self.store = nil
//         return DataStorageManager.sharedInstance.closeStore(self.storeType)
//     }
// }
