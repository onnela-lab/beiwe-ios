import Foundation
import ObjectMapper

// enum BWErrors: Error {
//     case ioError
// }

// func delay(_ delay: Double, closure: @escaping () -> Void) {
//     DispatchQueue.main.asyncAfter(
//         deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
// }

func platform() -> String {
    var size: Int = 0 // as Ben Stahl noticed in his answer
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var machine = [CChar](repeating: 0, count: Int(size))
    sysctlbyname("hw.machine", &machine, &size, nil, 0)
    return String(cString: machine)
}

// BEGIN modelTransforms (copied into tests/, keep Foundation+ObjectMapper only)
// used to shuffle questions in a survey for randomized questions
func shuffle<C: MutableCollection>(_ list: inout C) -> C where C.Index == Int {
    if list.count < 2 { return list }
    for i in list.startIndex ..< list.endIndex - 1 {
        let j = Int(arc4random_uniform(UInt32(list.endIndex - i))) + i
        if i != j {
            list.swapAt(i, j)
        }
    }
    return list
}

// used to transform the "rkanswers" object to json, presumably this is a researchkit answer format
let transformNSData = TransformOf<Data, String>(fromJSON: { encoded in
    // transform value from String? to Int?
    if let str = encoded {
        return Data(base64Encoded: str, options: [])
    } else {
        return nil
    }
}, toJSON: { value -> String? in
    // transform value from Int? to String?
    if let value = value {
        return value.base64EncodedString(options: [])
    }
    return nil
})

// not used, but appears to be a transform for notification information to json.
// let transformNotification = TransformOf<UILocalNotification, String>(fromJSON: { encoded -> UILocalNotification? in
//     // transform value from String? to Int?
//     if let str = encoded {
//         let data = Data(base64Encoded: str, options: [])
//         if let data = data {
//             return NSKeyedUnarchiver.unarchiveObject(with: data) as! UILocalNotification?
//         }
//     }
//     return nil
// }, toJSON: { value -> String? in
//     // transform value from Int? to String?
//     if let value = value {
//         let data = NSKeyedArchiver.archivedData(withRootObject: value)
//         return data.base64EncodedString(options: [])
//     }
//     return nil
// })

let transformJsonStringInt = TransformOf<Int, Any>(fromJSON: { (value: Any?) -> Int? in
    // transform value from String? to Int?
    if let value = value as? Int {
        return value
    }
    // Android getInt truncates ("1.5" and 1.5 -> 1)
    func truncated(_ d: Double) -> Int? {
        d.isFinite && abs(d) < 1e15 ? Int(d) : nil
    }
    if let value = value as? Double {
        return truncated(value)
    }
    if let value = value as? String {
        if let i = Int(value) { return i }
        // quote characters left by double-encoded survey content are stripped too (Android rejects these)
        let quotesAndWhitespace = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"'"))
        return Double(value.trimmingCharacters(in: quotesAndWhitespace)).flatMap(truncated)
    }
    return nil
}, toJSON: { (value: Int?) -> Int? in
    // transform value from Int? to String?
    value
})
// END modelTransforms

/// This is horrendously named.
/// Bounce refers to user-input "bouncing", the name comes from keyboard keys "bouncing" and triggering multiple inputs even though
/// they only hit a key once. (on keyboards the electrical impulse is never perfect, so low-level code has to impose a rate limit or delay.)
class Debouncer<T>: NSObject {
    var arg: T?
    var callback: (_ arg: T?) -> Void
    var delay: Double // defines the fastest input "bounce" periodicity
    weak var timer: Timer?

    init(delay: Double, callback: @escaping ((_ arg: T?) -> Void)) {
        self.delay = delay
        self.callback = callback
    }

    func call(_ arg: T?) {
        self.arg = arg
        if self.delay == 0 {
            self.fireNow() // no timer on a zero delay - code was always like this, don't change without testing
        } else {
            self.timer?.invalidate()
            // set up a timer for the output event
            let nextTimer = Timer.scheduledTimer(timeInterval: self.delay, target: self, selector: #selector(self.fireNow), userInfo: nil, repeats: false)
            self.timer = nextTimer
        }
    }

    func flush() {
        if let timer = timer {
            timer.invalidate() // cancel the existing timer (output event) so that we don't double-input
            self.fireNow()
        }
    }

    /// do the output event
    @objc func fireNow() {
        self.timer = nil
        self.callback(self.arg)
    }
}

func confirmAndCallClinician(_ presenter: UIViewController, callAssistant: Bool = false) {
    let msg = NSLocalizedString("call_clinician_confirmation_text", comment: "")
    var number = StudyManager.sharedInstance.currentStudy?.clinicianPhoneNumber
    if callAssistant {
        // msg = "Call your study's research assistant now?"
        number = StudyManager.sharedInstance.currentStudy?.raPhoneNumber
    }
    if let phoneNumber = number, AppDelegate.sharedInstance().canOpenTel {
        if let phoneUrl = URL(string: "tel:" + phoneNumber) {
            let callAlert = UIAlertController(title: NSLocalizedString("call_clinician_confirmation_title", comment: ""), message: msg, preferredStyle: UIAlertController.Style.alert)
            callAlert.addAction(UIAlertAction(title: NSLocalizedString("ok_button_text", comment: ""), style: .default) { (action: UIAlertAction!) in
                UIApplication.shared.open(phoneUrl)
            })
            callAlert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button_text", comment: ""), style: .default) { (action: UIAlertAction!) in
                print("Call cancelled.")
            })
            presenter.present(callAlert, animated: true) { /* ... */ }
        }
    }
}

// BEGIN gpsFuzz (copied into tests/, keep Foundation-only)
/// Random source is injectable so tests can seed it.
typealias GpsFuzzRandom = (ClosedRange<Double>) -> Double
let systemGpsFuzzRandom: GpsFuzzRandom = { Double.random(in: $0) }

/// Random offset in -1...1, never in -0.2...0.2 (a near-zero offset would barely hide anything).
func generateGpsLatitudeOffset(random: GpsFuzzRandom = systemGpsFuzzRandom) -> Double {
    var ran = random(-1 ... 1)
    while ran <= 0.2 && ran >= -0.2 {
        ran = random(-1 ... 1)
    }
    return ran
}

/// Random offset in -180...180, never in -10...10.
func generateGpsLongitudeOffset(random: GpsFuzzRandom = systemGpsFuzzRandom) -> Double {
    var ran = random(-180 ... 180)
    while ran <= 10 && ran >= -10 {
        ran = random(-180 ... 180)
    }
    return ran
}

/// Generated offsets are never 0, so 0.0 means "unset". Fills unset offsets when fuzzing is on (matches Android's lazy
/// generation); set offsets are kept, including across fuzzing being turned off and on again.
struct GpsFuzzOffsets {
    var lat: Double
    var lng: Double
    var generated: Bool
}

func ensureGpsFuzzOffsets(lat: Double, lng: Double, fuzzOn: Bool, random: GpsFuzzRandom = systemGpsFuzzRandom) -> GpsFuzzOffsets {
    guard fuzzOn else { return GpsFuzzOffsets(lat: lat, lng: lng, generated: false) }
    let newLat = lat == 0.0 ? generateGpsLatitudeOffset(random: random) : lat
    let newLng = lng == 0.0 ? generateGpsLongitudeOffset(random: random) : lng
    return GpsFuzzOffsets(lat: newLat, lng: newLng, generated: newLat != lat || newLng != lng)
}

/// Output is always a valid coordinate. Latitude past a pole is reflected (180 - lat) and the longitude turned half a
/// circle, as a point going over the pole comes down on the far side; clamping would pile points on the pole line.
/// One reflection is enough as |latOffset| <= 1. The longitude wrap adds multiples of 360 + 180 so the truncating
/// remainder is never negative (offsets reach -180, input -180: lng + off >= -360), then subtracts 180 -> [-180, 180).
/// (1260 = 360*3 + 180)
func applyGpsFuzz(lat: Double, lng: Double, latOffset: Double, lngOffset: Double) -> (lat: Double, lng: Double) {
    var newLat = lat + latOffset
    var newLng = lng + lngOffset
    if newLat > 90.0 {
        newLat = 180.0 - newLat
        newLng += 180.0
    } else if newLat < -90.0 {
        newLat = -180.0 - newLat
        newLng += 180.0
    }
    return (newLat, (newLng + 1260.0).truncatingRemainder(dividingBy: 360.0) - 180.0)
}
// END gpsFuzz
