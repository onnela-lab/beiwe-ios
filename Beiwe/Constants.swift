struct Constants {
    
    static let FIRST_PARTY_SERVER_DOMAIN_FOR_ERROR_REPORTING = "beiwe.org"
    
    static let ENABLED_FEATURES = [
        "survey_resend",
    ]
    
    static let passwordRequirementRegex = "^.{6,}$"
    static let passwordRequirementDescription = NSLocalizedString("password_length_requirement", comment: "")
    
    static let DELIMITER = "," // csv separator character, named for legible code reasons
    static let KEYLENGTH = 128 // encryption key length for any given line of encrypted data.
    
    // settings for functions that have retry logic
    static let RECUR_SLEEP_DURATION = 0.05 // 50 milliseconds
    static let RECUR_DEPTH = 10
    
    static let DEFAULT_UNPOPULATED_APPINFO = "never_populated"
    
    
    static var APP_VERSION: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    static var APP_BUILD: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    static var APP_COMMIT: String {
        return Bundle.main.infoDictionary?["GitCommitHash"] as? String ?? "Unknown"
    }
    
    static let APP_INFO_TAG = "iOS Version: \(Constants.APP_VERSION) Build: \(Constants.APP_BUILD) Commit: \(Constants.APP_COMMIT)"
    static let APP_INFO_SHORT = "\(Constants.APP_VERSION) \(Constants.APP_BUILD) (\(Constants.APP_COMMIT))"


    static let HEARTBEAT_INTERVAL = 300.0 // 5 minutes
}

let DEV_TIMEZONE = "America/New_York"

let BG_TASK_NAME_BGREFRESH = "org.beiwe.heartbeat_bgrefresh"
let BG_TASK_NAME_BGPROCESSING = "org.beiwe.heartbeat_bgprocessing"
let BG_TASK_NAME_BGHEALTH = "org.beiwe.heartbeat_bghealth"
// iOS 26+ continued processing task identifiers are required to be prefixed with the app's bundle id.
let BG_TASK_NAME_CONTINUED = "\(Bundle.main.bundleIdentifier!).heartbeat_continued"

let DEVICE_INFO_UPDATE_PERIOD: TimeInterval = 60
let FCM_REFRESH_REQUEST_PERIOD: TimeInterval = 60 * 30
let DEVICE_SETTINGS_INTERVAL: Int64 = 30 * 60 // hardcoded thirty minutes
let DEFAULT_NEXT_STATE_CHECK_INTERVAL: TimeInterval = 5 * 60
let DATA_COLLECTION_TIMER_INVERVAL: TimeInterval = 10 //= 10 * 60  // why on earth was this set to 10 minutes that's terrible, 10 seconds is reasonable
let EXPLICIT_NETWORK_CHECK_INTERVAL: TimeInterval = 60.0 * 5  // unused?

// Dispatch Queue qos options are: default, background, utility, userInitiated, userInteractive, and unspecified.
// TODO: document the difference between these.
// TODO: research, document the attributes parameter
let GLOBAL_DEFAULT_QUEUE = DispatchQueue.global(qos: .default)
let GLOBAL_BACKGROUND_QUEUE = DispatchQueue.global(qos: .background)
let GLOBAL_UTILITY_QUEUE = DispatchQueue.global(qos: .utility)

let HEARTBEAT_QUEUE = DispatchQueue(label: "org.beiwe.heartbeat_queue", qos: .userInitiated, attributes: [])
let BACKGROUND_DEVICE_INFO_QUEUE = DispatchQueue(label: "org.beiwe.background_device_info_queue", qos: .background, attributes: [])
let BACKGROUND_DEVICE_INFO_FAST_QUEUE = DispatchQueue(label: "org.beiwe.background_device_info_queue", qos: .userInteractive, attributes: [])
let TIMER_QUEUE = DispatchQueue(label: "org.beiwe.timer_queue", attributes: [])
let INNER_RECLINE_QUEUE = DispatchQueue(label: "org.beiwe.recline_queue_1", qos: .userInteractive, attributes: []) // setting high on this queue because it is the database.
let OUTER_RECLINE_QUEUE = DispatchQueue(label: "org.beiwe.recline_queue_2", qos: .userInteractive, attributes: []) // setting high on this queue because it is the database.
let POST_UPLOAD_QUEUE = DispatchQueue(label: "org.beiwe.postupload_queue", qos: .default, attributes: [])
let UPLOAD_DISPATCH_QUEUE = DispatchQueue(label: "org.beiwe.run_upload_queue", qos: .background, attributes: [])

let ACCELEROMETER_CACHE_SIZE = 100
let DEVICE_MOTION_CACHE_SIZE = 100
let GPS_CACHE_SIZE = 100
let GYRO_CACHE_SIZE = 100
let MAGNETOMETER_CACHE_SIZE = 100

struct Ephemerals {
    // device info statuses
    static var notification_permission = "not populated, this is an app bug"
    static var locationServicesEnabledDescription = "not populated, this is an app bug"
    static var significantLocationChangeMonitoringAvailable = "not populated, this is an app bug"
    static var backgroundRefreshStatus = "not populated, this is an app bug"
    static var transition_count = 0
    static var background_task_count = "(not populated yet?)"
    static var start_last_upload = "not populated"
    static var end_last_upload = "not populated"
    
    static var lastAppStart = Constants.DEFAULT_UNPOPULATED_APPINFO
    static var lastApplicationDidBecomeActive = Constants.DEFAULT_UNPOPULATED_APPINFO
    static var lastApplicationDidEnterBackground = Constants.DEFAULT_UNPOPULATED_APPINFO
    static var lastApplicationDidReceiveMemoryWarning = Constants.DEFAULT_UNPOPULATED_APPINFO
    static var lastSuccessfulLogin = Constants.DEFAULT_UNPOPULATED_APPINFO
    
    static var lastHeartbeat = 0.0
}
