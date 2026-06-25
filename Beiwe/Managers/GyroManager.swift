import CoreMotion
import Foundation


let headers = [
    "timestamp",
    "x",
    "y",
    "z",
]

struct GyroDataPoint {
    var timestamp: TimeInterval
    var x: Double
    var y: Double
    var z: Double
}

class GyroManager: DataServiceProtocol {
    let motionManager = AppDelegate.sharedInstance().motionManager  // weird singleton instance attached to appdelegate - ah, shares with accelerometer

    // the basics
    let storeType = "gyro"
    let dataStorage: DataStorage
    var datapoints = [GyroDataPoint]()
    
    // Gyro's callback has a non-optional queue, we want exactly one queue.
    // We need a lock because arrays are not atomic and flush can be called mid-update.
    let cachelock = NSLock()
    let queue = OperationQueue()
    
    // we need an offset for time calculations
    // this has to be updated periodically as the program runs, otherwise it drifts
    var offset_since_1970: Double = 0

    init () {
        self.dataStorage = DataStorageManager.sharedInstance.createStore(self.storeType, headers: headers)
    }
    
    /// protocol instruction - sets up custom interval
    func initCollecting() -> Bool {
        guard self.motionManager.isGyroAvailable else {
            log.info("Gyro not available.  Not initializing collection")
            return false
        }
        // TimeInterval of uptime, boottime as unix timestamp
        self.offset_since_1970 = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime

        // ug, currentstudy and study settings are optional so can't rely on the default gyroFrequency, have to hardcode it
        let frequency_base = StudyManager.sharedInstance.currentStudy?.studySettings?.gyroFrequency ?? 10
        self.motionManager.gyroUpdateInterval = 1.0 / Double(frequency_base)
        // print("gyroUpdateInterval: \(motionManager.gyroUpdateInterval)")
        return true
    }

    /// protocol instruction - sets the delegate(?) function
    func startCollecting() {
        // This value drifts based on device sleep, reset it at the start of every recording cycle.
        self.offset_since_1970 = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        
        // print("Turning \(self.storeType) collection on")
        // print("gyroUpdateInterval: \(motionManager.gyroUpdateInterval)")
        // set the closure as the delegate function
        self.motionManager.startGyroUpdates(to: self.queue) { (gyroData: CMGyroData?, _: Error?) in
            if let gyroData = gyroData {
                
                // assemble our struct, safely append to list, flush after enough data points
                let data = GyroDataPoint(
                    timestamp: gyroData.timestamp,
                    x: gyroData.rotationRate.x,
                    y: gyroData.rotationRate.y,
                    z: gyroData.rotationRate.z
                )
                
                self.cachelock.lock()
                self.datapoints.append(data)
                self.cachelock.unlock()
                
                if self.datapoints.count > GYRO_CACHE_SIZE {
                    self.flush()
                }
            }
        }
        AppEventManager.sharedInstance.logAppEvent(event: "gyro_on", msg: "Gyro collection on")
    }

    /// protocol instruction
    func pauseCollecting() {
        // print("Pausing \(self.storeType) collection")
        self.motionManager.stopGyroUpdates()
        AppEventManager.sharedInstance.logAppEvent(event: "gyro_off", msg: "Gyro collection off")
    }

    /// protocol instruction
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
        self.cachelock.lock()
        let data_to_write: [GyroDataPoint] = self.datapoints
        self.datapoints = []
        self.cachelock.unlock()
        
        // maximize compiler optimization and cpu loop unrolling with an array literal in a loop?
        for gyroData in data_to_write {
            self.dataStorage.store(
                [
                    String(Int64((gyroData.timestamp + self.offset_since_1970) * 1000)),
                    String(gyroData.x),
                    String(gyroData.y),
                    String(gyroData.z)
                ]
            )
        }
    }
}
