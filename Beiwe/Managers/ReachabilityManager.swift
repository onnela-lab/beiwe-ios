import Foundation
import Network
import SystemConfiguration.CaptiveNetwork

let EXPLICIT_NETWORK_CHECK_INTERVAL: TimeInterval = 60.0 * 5

let reachability_headers = [
    "timestamp",
    "event",
]

/// Uses NWPathMonitor to provide a network-available status monitor - kinda.
///
/// Integrates with (the most recently instantiated) ReachabilityManager to provide a hook
/// for recording that data stream.
class NetworkAccessMonitor {
    static let monitor = NWPathMonitor()
    static var reachabilityManager: ReachabilityManager?
    
    // this is always returned as true by NWPathMonitor? attribute is currently unused.
    static var network_active = true
    
    // network_cellular is intended to be used across the app whenever there in operation
    // that needs to know when the device is on a cellular data connection.
    static var network_cellular = false // true when wifi is off

    // tracking for writes
    static var first_run = true
    static var prior_cellular_status = false

    /// our static init function (I believe this has to be called from on the main thread.)
    static func start_monitor() {
        NetworkAccessMonitor.monitor.pathUpdateHandler = { (update: NWPath) in
            NetworkAccessMonitor.pathUpdateHandler(update)
        }
        
        // this gets calls pathUpdateHandler basically immediately.
        self.monitor.start(queue: BACKGROUND_DEVICE_INFO_FAST_QUEUE)
    }
    
    // the callback for the NWPathMonitor
    static func pathUpdateHandler(_ update: NWPath) {
        // update status, write to reachability
        NetworkAccessMonitor.network_active = update.status == .satisfied ? true : false
        NetworkAccessMonitor.network_cellular = update.isExpensive ? true : false
        NetworkAccessMonitor.conditional_record_reachability()
        NetworkAccessMonitor.prior_cellular_status = NetworkAccessMonitor.network_cellular
    }
    
    static func conditional_record_reachability() {
        // write the current status if it just changed or on first run.
        if first_run || network_cellular != prior_cellular_status {
            if let reachabilityManager = reachabilityManager {
                // we used to have the abilite to identify no network connectivity, "unreachable"
                // but that is gone now because it is incredibly difficult unless you make a network
                // connection to test it.
                let state = if network_cellular { "cellular" } else { "wifi" }
                let data: [String] = [
                    String(Int64(Date().timeIntervalSince1970 * 1000)),
                    state,
                ]
                reachabilityManager.dataStorage.store(data)
            }
            first_run = false
        }
    }
}


/// Reachability - uses a delegate pattern
class ReachabilityManager: DataServiceProtocol {
    // tHe basics
    let storeType = "reachability"
    var dataStorage: DataStorage
    
    init() {
        self.dataStorage = DataStorageManager.sharedInstance.createStore(self.storeType, headers: reachability_headers)
    }
    
    /// protocol function
    func initCollecting() -> Bool {
        // reachability doesn't use timers, just turn it on.
        NetworkAccessMonitor.reachabilityManager = self
        return true
    }

    /// protocol function
    func startCollecting() {
        // print("Turning \(self.storeType) collection on")
        NetworkAccessMonitor.reachabilityManager = self
        AppEventManager.sharedInstance.logAppEvent(event: "reachability_on", msg: "Reachability collection on")
    }

    /// protocol function
    func pauseCollecting() {
        // print("Pausing \(self.storeType) collection")
        NetworkAccessMonitor.reachabilityManager = nil
        AppEventManager.sharedInstance.logAppEvent(event: "reachability_off", msg: "Reachability collection off")
    }

    /// protocol function
    func finishCollecting() {
        // print("Finishing \(self.storeType) collection")
        self.pauseCollecting()
        self.dataStorage.reset()
    }
    
    func createNewFile() {
        self.dataStorage.reset()
    }
    
    func flush() {
        // ReachabilityManager does not have potentially intensive write operations, it
        // writes it's data immediately.
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////// Mechanisms of Determining Wifi vs Cellular Network Status ////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

/// NWPathMonitor - we went with this because it is native.
/// (I think the distinction of "expensive" is because a wifi connection
/// can be marked as "expensive" in the use case of a cellular hotspot. It's still strange.)
// this appears to be the/a ~new (ios 12+) mechanism to check network status.
// its one of the lesser answers on
// https://stackoverflow.com/questions/30743408/check-for-internet-connection-with-swift
// Unfortunately it seems to have the same problem as every other mechanism, e.g. while
// it is easy to identify that you are on wifi it is extremely difficult to tell
// when you have an active internet connection other than by making a network request.
// import Network
// struct Internet {
//     private static let monitor = NWPathMonitor()
// 
//     static var active = false  // this always returns true
//     static var expensive = false  // true when wifi is off
// 
//     /// Monitors internet connectivity changes. Updates with every change in connectivity.
//     /// Updates variables for availability and if it's expensive (cellular).
//     static func start() {
//         guard self.monitor.pathUpdateHandler == nil else { return }
// 
//         self.monitor.pathUpdateHandler = { (update: NWPath) in
//             Internet.active = update.status == .satisfied ? true : false
//             print("Internet.active:", Internet.active)
//             Internet.expensive = update.isExpensive ? true : false
//             print("Internet.expensive:", Internet.expensive)
//         }
//         self.monitor.start(queue: BACKGROUND_DEVICE_INFO_FAST_QUEUE)
//     }
// }

/// AlamoFire
// AlamoFire provides a mechanism to check network status. It is quite convenient, but yet again
// doesn't correctly determine "do I have an internet connection."
// On a code level.... why on earth is NetworkReachabilityManager() optional?
// (uses SystemConfiguration under the covers)
// import Alamofire
// func a_func() {
//     let network_reachability_manager = NetworkReachabilityManager()!
//     // always returns true:
//     print("alamofire isReachable:", network_reachability_manager.isReachable)
//     // false wthen on wifi
//     print("alamofire isReachableOnWWAN:", network_reachability_manager.isReachableOnWWAN)
//     // true when on wifi
//     print("alamofire isReachableOnEthernetOrWiFi:",
//           network_reachability_manager.isReachableOnEthernetOrWiFi)
// }

/// Use SystemConfiguration Raw to get the wifi address
// This does get us the datapoint we need - it returns Nil when there is no wifi.
// Literally this code is not about having an internet connection, it is just about being on wifi.
// Must execute on the main thread.
// import SystemConfiguration.CaptiveNetwork
// func a_func() -> String? {
//     var ssid: String?
//     if let interfaces = CNCopySupportedInterfaces() as NSArray? {
//         for interface in interfaces {
//             if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
//                 ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
//                 break
//             }
//         }
//     }
//     return ssid
// }
