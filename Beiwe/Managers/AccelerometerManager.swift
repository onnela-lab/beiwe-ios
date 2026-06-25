import CoreMotion
import Foundation

let accelerometer_headers = [
    "timestamp",
    "accuracy",
    "x",
    "y",
    "z",
]

struct AccelerometerDataPoint {
    var timestamp: TimeInterval
    var accuracy: Int
    var x: Double
    var y: Double
    var z: Double
}

class AccelerometerManager: DataServiceProtocol {
    let motionManager = AppDelegate.sharedInstance().motionManager // weird singleton instance attached to appdelegate - ah, shares with gyro
    // the base
    let storeType = "accel"
    let dataStorage: DataStorage
    var datapoints = [AccelerometerDataPoint]()
    
    // we need an offset for timestamp calculations, that's just how it works.
    // this has to be updated periodically as the program runs, otherwise it drifts
    var offset_since_1970: Double = 0
    
    // accelerometer's callback has a non-optional queue, we want exactly one queue.
    // We need a lock because arrays are not atomic and flush can be called mid-update.
    let queue = OperationQueue()
    let cacheLock = NSLock()
    
    init() {
        self.dataStorage = DataStorageManager.sharedInstance.createStore(self.storeType, headers: accelerometer_headers)
    }
    
    /// protocol function - sets up frequency
    func initCollecting() -> Bool {
        guard self.motionManager.isAccelerometerAvailable else {
            log.error("Accel not available.  Not initializing collection")
            return false
        }
        // TimeInterval of uptime, boottime as unix timestamp
        self.offset_since_1970 = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        let frequency_base = StudyManager.sharedInstance.currentStudy?.studySettings?.accelerometerFrequency ?? 10
        self.motionManager.accelerometerUpdateInterval = 1.0 / Double(frequency_base)
        // print("accelerometerUpdateInterval: \(motionManager.accelerometerUpdateInterval)")
        return true
    }

    /// protocol function
    func startCollecting() {
        // This value drifts based on device sleep, reset it at the start of every recording cycle.
        self.offset_since_1970 = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        
        // print("Turning \(self.storeType) collection on")
        // print("accelerometerUpdateInterval: \(motionManager.accelerometerUpdateInterval)")
        // set the closure function as the delegate for updates
        self.motionManager.startAccelerometerUpdates(to: self.queue) { (accelData: CMAccelerometerData?, _: Error?) in
            if let accelData = accelData {
                // we store this data in a struct for speed and compactness
                let data = AccelerometerDataPoint(
                    timestamp: accelData.timestamp,
                    accuracy: 0,
                    x: accelData.acceleration.x,
                    y: accelData.acceleration.y,
                    z: accelData.acceleration.z
                )
                
                // testing indicates we get contention when flush is called, which makes sense.
                self.cacheLock.lock()
                self.datapoints.append(data)
                self.cacheLock.unlock()
                
                if self.datapoints.count > ACCELEROMETER_CACHE_SIZE {
                    self.flush()
                }
            }
        }
        AppEventManager.sharedInstance.logAppEvent(event: "accel_on", msg: "Accel collection on")
    }

    /// protocol function
    func pauseCollecting() {
        // print("Pausing \(self.storeType) collection")
        self.motionManager.stopAccelerometerUpdates()
        AppEventManager.sharedInstance.logAppEvent(event: "accel_off", msg: "Accel collection off")
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
        let data_to_write = self.datapoints
        self.datapoints = []
        self.cacheLock.unlock()
        
        for data in data_to_write {
            self.dataStorage.store(
                [
                    String(Int64((data.timestamp + self.offset_since_1970) * 1000.0)),
                    "unknown", // ios does not provide an accuracy value
                    String(data.x),
                    String(data.y),
                    String(data.z)
                ]
            )
        }
    }
}
