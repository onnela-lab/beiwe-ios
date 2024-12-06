import Sentry
import XCGLogger

/// This file contains collections of useful items, when something is specific
/// enough it should go into a file in utils

//////////////////////////// LOG GOTTA GET CONFIGURED SOMEWHERE /////////////////////////////
//////////////////////////// LOG GOTTA GET CONFIGURED SOMEWHERE ////////////////////////////
//////////////////////////// LOG GOTTA GET CONFIGURED SOMEWHERE ///////////////////////////

let log = XCGLogger(identifier: "advancedLogger", includeDefaultDestinations: false)

/////////////////////////////////// Class Extensions ////////////////////////////////
/////////////////////////////////// Class Extensions ///////////////////////////////
/////////////////////////////////// Class Extensions //////////////////////////////

/// Extend the DispatchQueue to have a function called Background
extension DispatchQueue {
    // more or less from https://stackoverflow.com/questions/24056205/how-to-use-background-thread-in-swift
    // the original names were not super descriptive
    func background(_ background_task: @escaping (() -> Void), completion_task: (() -> Void)? = nil, completeion_delay: Double = 0.0) {
        self.async {
            // run the background task
            background_task()
            
            // run completion task
            if let completion_task = completion_task {
                self.asyncAfter(deadline: .now() + completeion_delay, execute: { completion_task() })
            }
        }
    }
    
    // in simplifying background_completion above I eventually worked out that you dispatch on background thread with a delay like this:
    // queue.asyncAfter(deadline: .now() + delay, execute: { background_task() })
}

/// Do not have the expertise to actually identify what the warning means
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

/// mostly these additions are useful in encryption code, and printing a Data is unhelpful.
extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return self.map { String(format: format, $0) }.joined()
    }
    
    // TODO: replace uses of Crypto.base64ToBase64URL with this
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }
}

// mastly useful in encryption, printing [UInt8] is unhelpful
extension [UInt8] {
    /// simple, unoptimized
    func toHexString() -> String {
        let HexLookup: [Character] = [
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F",
        ]
        var ret = ""
        for oneByte in self {
            let asInt = Int(oneByte)
            ret.append(HexLookup[asInt >> 4])
            ret.append(HexLookup[asInt & 0x0F])
        }
        return ret
    }
}

//////////////////////// Date and Time formatting functions ////////////////////////
//////////////////////// Date and Time formatting functions ////////////////////////
//////////////////////// Date and Time formatting functions ////////////////////////

func dateFormat(_ date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "y-MM-dd HH:mm:ss"
    return dateFormatter.string(from: date)
}

func dateFormatLocal(_ date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: DEV_TIMEZONE)
    dateFormatter.dateFormat = "y-MM-dd HH:mm:ss"
    return dateFormatter.string(from: date) + "(ET)"
}

func dateFormatLocalWithMs(_ date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: DEV_TIMEZONE)
    dateFormatter.dateFormat = "y-MM-dd HH:mm:ss.ms"
    return dateFormatter.string(from: date) + "(ET)"
}

func timeFormat(_ date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm:ss"
    return dateFormatter.string(from: date)
}

func timeFormatLocal(_ date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm:ss"
    return dateFormatter.string(from: date) + "(ET)"
}

// Swift can't work out how to call the Date-typed version of the call from inside the TimeInterval-typed version of the call.
func _swift_sucks_explicit_function_type_dateFormat(_ date: Date) -> String {
    return dateFormat(date)
}

func _swift_sucks_explicit_function_type_timeFormat(_ date: Date) -> String {
    return timeFormat(date)
}

func dateformat(_ unix_timestamp: TimeInterval) -> String {
    return _swift_sucks_explicit_function_type_dateFormat(Date(timeIntervalSince1970: unix_timestamp))
}

func timeformat(_ unix_timestamp: TimeInterval) -> String {
    return _swift_sucks_explicit_function_type_timeFormat(Date(timeIntervalSince1970: unix_timestamp))
}

func smartformat(_ d: Date) -> String {
    if Calendar.current.isDateInToday(d) {
        return timeFormat(d)
    } else {
        return dateFormat(d)
    }
}

func smartformat(_ unix_timestamp: TimeInterval) -> String {
    let d = Date(timeIntervalSince1970: unix_timestamp)
    if Calendar.current.isDateInToday(d) {
        return timeFormat(d)
    } else {
        return dateFormat(d)
    }
}

func timestampString() -> String {
    return dateFormat(Date())
}

/// converts the iso time string format to a TimeInterval (integer)
func isoStringToTimeInterval(timeString: String?) -> TimeInterval {
    guard  let timeString = timeString  else {
        return 0
    }
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    let sentTime = dateFormatter.date(from: timeString)!
    return sentTime.timeIntervalSince1970
}

//////////////////////////////// CONVENIENCE JSON FUNCTIONS ///////////////////////////////////
//////////////////////////////// CONVENIENCE JSON FUNCTIONS ///////////////////////////////////
//////////////////////////////// CONVENIENCE JSON FUNCTIONS ///////////////////////////////////

func easyJSON(_ str_list: [String]?) -> String {
    guard let str_list = str_list else {
        return "[]"
    }
    
    return String(
        data: try! JSONSerialization.data(
            withJSONObject: str_list,
            options: []
        ),
        encoding: .utf8
    )!
}

func easyJSON(_ str_str_dict: [String: String]?) -> String {
    guard let str_str_dict = str_str_dict else {
        return "{}"
    }
    return String(
        data: try! JSONSerialization.data(
            withJSONObject: str_str_dict,
            options: []
        ),
        encoding: .utf8
    )!
}

func easyJSON(_ str_any_dict: [String: Any]?) throws -> String {
    // json encoding has to be handled
    guard let str_any_dict = str_any_dict else {
        return "{}"
    }
    return String(
        data: try JSONSerialization.data(
            withJSONObject: str_any_dict,
            options: []
        ),
        encoding: .utf8
    )!
}

/////////////////////////////////// THE PRINT FUNCTION ////////////////////////////////////////
/////////////////////////////////// THE PRINT FUNCTION ////////////////////////////////////////
/////////////////////////////////// THE PRINT FUNCTION ////////////////////////////////////////

/// Override the swift print function to make all dates in reasonable timezone and reasonable text format
public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    // print everything, converting dates to dev time.
    // we can't build a list and pass it through, that causes it to _print a list_,
    // so we do 2 print statements of the separator and then the terminator at the very end.
    for item in items {
        if item is Date || item is Date? {
            let d = item as! Date
            // convert Date object to be in America/New_York time
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "y-MM-dd HH:mm:ss.SS" // its a custom format specifically for printing
            dateFormatter.timeZone = TimeZone(identifier: DEV_TIMEZONE)
            Swift.print(dateFormatter.string(from: d) + "(ET)", separator: "", terminator: "")
            Swift.print(separator, separator: "", terminator: "")
        } else {
            Swift.print(item, separator: "", terminator: "")
            Swift.print(separator, separator: "", terminator: "")
        }
    }
    Swift.print(terminator, separator: "", terminator: "")
}

////////////////////////////////////// SENTRY //////////////////////////////////////////
////////////////////////////////////// SENTRY //////////////////////////////////////////
////////////////////////////////////// SENTRY //////////////////////////////////////////

func sentry_warning(
    _ title: String, _ extra1: String? = nil, _ extra2: String? = nil, _ extra3: String? = nil, crash: Bool
) {
    var extras = [String: Any]()
    if let extra = extra1 {
        extras["extra1"] = extra
    }
    if let extra = extra2 {
        extras["extra2"] = extra
    }
    if let extra = extra3 {
        extras["extra3"] = extra
    }
    if let patient_id = StudyManager.sharedInstance.currentStudy?.patientId {
        extras["user_id"] = patient_id
    }
    
    SentrySDK.capture(message: "not a crash - Error moving file 1") { (scope: Scope) in
        scope.setEnvironment(Constants.APP_INFO_TAG)
        scope.setExtras(extras)
        scope.setLevel(.warning)
    }
}

///////////////////////////// RAW BYTE Operations //////////////////////////
///////////////////////////// RAW BYTE Operations //////////////////////////
///////////////////////////// RAW BYTE Operations //////////////////////////

// Utility function that will unambiguously (slowlyish) copy bytes directly from an array of bytes.
// Use this only if you cannot otherwise get rid of unsafe pointers to buffers (arrays of bytes)
func copy_bytearray(_ byte_array: [CUnsignedChar]) -> [UInt8] {
    // print("inner_array.count: \(byte_array.count)")
    var ret = [UInt8](repeating: 0, count: byte_array.count)
    
    byte_array.withUnsafeBufferPointer({ unsafe_byte_array in
        for i in 0 ... (byte_array.count - 1) {
            // print("i: \(i)")
            ret[i] = unsafe_byte_array[i]
            // print("ret[i]: \(ret[i])")
        }
    })
    return ret
}

// probably broken
// func copy_bytearray_subslice(_ byteArray: [CUnsignedChar], start: Int, end: Int) -> [UInt8] {
//     var end = end
//     if end >= byteArray.count {
//         end = byteArray.count - 1 // just make it work I don't care
//     }
//
//     let inner_array = byteArray[start ... end]
//     print("inner_array.count: \(inner_array.count)")
//
//     var test = [UInt8](repeating: 0, count: inner_array.count)
//
//     inner_array.withUnsafeBufferPointer({ unsafe_buffer in
//         for i in 0 ... (inner_array.count - 2) {
//             print("i: \(i)")
//             test[i] = unsafe_buffer[i]
//             print("test[i]: \(test[i])")
//         }
//     })
//     return test
// }
