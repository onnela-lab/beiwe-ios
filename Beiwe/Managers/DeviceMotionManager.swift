import CoreMotion
import Foundation

let device_motion_headers = [
    "timestamp",
    "roll",
    "pitch",
    "yaw",
    "rotation_rate_x",
    "rotation_rate_y",
    "rotation_rate_z",
    "gravity_x",
    "gravity_y",
    "gravity_z",
    "user_accel_x",
    "user_accel_y",
    "user_accel_z",
    "magnetic_field_calibration_accuracy",
    "magnetic_field_x",
    "magnetic_field_y",
    "magnetic_field_z",
]

struct DeviceMotionDatapoint {
    var timestamp: TimeInterval
    var roll: Double
    var pitch: Double
    var yaw: Double
    var rotation_rate_x: Double
    var rotation_rate_y: Double
    var rotation_rate_z: Double
    var gravity_x: Double
    var gravity_y: Double
    var gravity_z: Double
    var user_accel_x: Double
    var user_accel_y: Double
    var user_accel_z: Double
    var magnetic_field_calibration_accuracy: CMMagneticFieldCalibrationAccuracy
    var magnetic_field_x: Double
    var magnetic_field_y: Double
    var magnetic_field_z: Double
}

class DeviceMotionManager: DataServiceProtocol {
    let motionManager = AppDelegate.sharedInstance().motionManager // weird singleton reference attached to AppDelegate

    // the basics
    let storeType = "devicemotion"
    let dataStorage: DataStorage
    var datapoints = [DeviceMotionDatapoint]()
    
    // DeviceMotion requires a queue, and we need a lock because arrays are not atomic and flush can be called mid-update.
    let cacheLock = NSLock()
    let queue = OperationQueue()
    
    // we need an offset timestamp for timecode calculations
    // this has to be updated periodically as the program runs, otherwise it drifts
    var offset_since_1970: Double = 0
    
    init() {
        self.dataStorage = DataStorageManager.sharedInstance.createStore(self.storeType, headers: device_motion_headers)
    }
    
    /// protocol funciton
    func initCollecting() -> Bool {
        // give up early logic
        guard self.motionManager.isDeviceMotionAvailable else {
            log.info("DeviceMotion not available.  Not initializing collection")
            return false
        }
        // Get TimeInterval of uptime i.e. the delta: now - bootTime
        self.offset_since_1970 = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime // Now since 1970
        self.motionManager.deviceMotionUpdateInterval = 0.1
        return true
    }
    
    /// protocol function
    func startCollecting() {
        // This value drifts based on device sleep, reset it at the start of every recording cycle.
        self.offset_since_1970 = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        
        // print("Turning \(self.storeType) collection on")
        
        self.motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xArbitraryZVertical, to: self.queue) {
            (motionData: CMDeviceMotion?, _: Error?) in
            // assemble our struct, safely append to list, flush after enough data points
            if let motionData = motionData {
                let data = DeviceMotionDatapoint(
                    timestamp: motionData.timestamp,
                    roll: motionData.attitude.roll,
                    pitch: motionData.attitude.pitch,
                    yaw: motionData.attitude.yaw,
                    rotation_rate_x: motionData.rotationRate.x,
                    rotation_rate_y: motionData.rotationRate.y,
                    rotation_rate_z: motionData.rotationRate.z,
                    gravity_x: motionData.gravity.x,
                    gravity_y: motionData.gravity.y,
                    gravity_z: motionData.gravity.z,
                    user_accel_x: motionData.userAcceleration.x,
                    user_accel_y: motionData.userAcceleration.y,
                    user_accel_z: motionData.userAcceleration.z,
                    magnetic_field_calibration_accuracy: motionData.magneticField.accuracy,
                    magnetic_field_x: motionData.magneticField.field.x,
                    magnetic_field_y: motionData.magneticField.field.y,
                    magnetic_field_z: motionData.magneticField.field.z
                )
                
                self.cacheLock.lock()
                self.datapoints.append(data)
                self.cacheLock.unlock()
                
                if self.datapoints.count > DEVICE_MOTION_CACHE_SIZE {
                    self.flush()
                }
            }
        }
        AppEventManager.sharedInstance.logAppEvent(event: "devicemotion_on", msg: "DeviceMotion collection on")
    }

    func pauseCollecting() {
        // print("Pausing \(self.storeType) collection")
        self.motionManager.stopDeviceMotionUpdates()
        AppEventManager.sharedInstance.logAppEvent(event: "devicemotion_off", msg: "DeviceMotion collection off")
    }

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
        
        // maximize compiler optimization and cpu loop unrolling with an array literal in a loop?
        for motionData in data_to_write {
            let fieldAccuracy: String
            switch motionData.magnetic_field_calibration_accuracy {
            case .uncalibrated:
                fieldAccuracy = "uncalibrated"
            case .low:
                fieldAccuracy = "low"
            case .medium:
                fieldAccuracy = "medium"
            case .high:
                fieldAccuracy = "high"
            default:
                fieldAccuracy = "unknown"
            }
            
            self.dataStorage.store(
                [
                    String(Int64((motionData.timestamp + self.offset_since_1970) * 1000)),
                    String(motionData.roll),
                    String(motionData.pitch),
                    String(motionData.yaw),
                    String(motionData.rotation_rate_x),
                    String(motionData.rotation_rate_y),
                    String(motionData.rotation_rate_z),
                    String(motionData.gravity_x),
                    String(motionData.gravity_y),
                    String(motionData.gravity_z),
                    String(motionData.user_accel_x),
                    String(motionData.user_accel_y),
                    String(motionData.user_accel_z),
                    fieldAccuracy,
                    String(motionData.magnetic_field_x),
                    String(motionData.magnetic_field_y),
                    String(motionData.magnetic_field_z),
                ]
            )
        }
    }
}
