import CoreMotion
import Foundation

let magnetometer_headers = [
    "timestamp",
    "x",
    "y",
    "z",
]

struct MagnetometerDataPoint {
    var timestamp: TimeInterval
    var x: Double
    var y: Double
    var z: Double
}

class MagnetometerManager: DataServiceProtocol {
    let motionManager = AppDelegate.sharedInstance().motionManager // weird singleton reference attached to AppDelegate
    
    // the basics
    let storeType = "magnetometer"
    var dataStorage: DataStorage
    var datapoints = [MagnetometerDataPoint]()
    
    // magnetometer's callback has a non-optional queue, we want exactly one queue.
    // We need a lock because arrays are not atomic and flush can be called mid-update.
    let queue = OperationQueue()
    let cacheLock = NSLock()
    
    // the offset - required for timestamp calculations
    // this has to be updated periodically as the program runs, otherwise it drifts
    var offset_since_1970: Double = 0

    init() {
        self.dataStorage = DataStorageManager.sharedInstance.createStore(self.storeType, headers: magnetometer_headers)
    }
    
    /// protocol function
    func initCollecting() -> Bool {
        // give up early logic
        guard self.motionManager.isMagnetometerAvailable else {
            log.info("Magnetometer not available.  Not initializing collection")
            return false
        }

        // we need an offset for time calculations
        self.offset_since_1970 = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        self.motionManager.magnetometerUpdateInterval = 0.1
        return true
    }
    
    /// protocol function
    func startCollecting() {
        // This value drifts based on device sleep, reset it at the start of every recording cycle.
        self.offset_since_1970 = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        
        // print("Turning \(self.storeType) collection on")
        // this closure is the function that records data
        self.motionManager.startMagnetometerUpdates(to: self.queue) { (magData: CMMagnetometerData?, _: Error?) in
            
            // assemble our struct, safely append to list, flush after enough data points
            if let magData = magData {
                let data = MagnetometerDataPoint(
                    timestamp: magData.timestamp,
                    x: magData.magneticField.x,
                    y: magData.magneticField.y,
                    z: magData.magneticField.z
                )
                
                self.cacheLock.lock()
                self.datapoints.append(data)
                self.cacheLock.unlock()
                
                if self.datapoints.count > MAGNETOMETER_CACHE_SIZE {
                    self.flush()
                }
            }
        }
        AppEventManager.sharedInstance.logAppEvent(event: "magnetometer_on", msg: "Magnetometer collection on")
    }

    /// protocol function
    func pauseCollecting() {
        // print("Pausing \(self.storeType) collection")
        self.motionManager.stopMagnetometerUpdates()
        AppEventManager.sharedInstance.logAppEvent(event: "magnetometer_off", msg: "Magnetometer collection off")
    }

    /// protocol function
    func finishCollecting() {
        // print("Finishing \(self.storeType) collection")
        self.pauseCollecting()
        self.createNewFile() // file creation is lazy
    }
    
    func createNewFile() {
        self.flush()
        self.dataStorage.reset()
    }
    
    func flush() {
        // todo - bulk write?
        self.cacheLock.lock()
        let data_to_write: [MagnetometerDataPoint] = self.datapoints
        self.datapoints = []
        self.cacheLock.unlock()
        // maximize compiler optimization and cpu loop unrolling with an array literal in a loop?
        for magDataPoint in data_to_write {
            self.dataStorage.store(
                [
                    String(Int64((magDataPoint.timestamp + self.offset_since_1970) * 1000)),
                    String(magDataPoint.x),
                    String(magDataPoint.y),
                    String(magDataPoint.z),
                ]
            )
        }
    }
}
