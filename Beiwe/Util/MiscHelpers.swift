import Foundation
import ObjectMapper

enum BWErrors: Error {
    case ioError
}

func delay(_ delay: Double, closure: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

func platform() -> String {
    var size: Int = 0 // as Ben Stahl noticed in his answer
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var machine = [CChar](repeating: 0, count: Int(size))
    sysctlbyname("hw.machine", &machine, &size, nil, 0)
    return String(cString: machine)
}

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
let transformNotification = TransformOf<UILocalNotification, String>(fromJSON: { encoded -> UILocalNotification? in
    // transform value from String? to Int?
    if let str = encoded {
        let data = Data(base64Encoded: str, options: [])
        if let data = data {
            return NSKeyedUnarchiver.unarchiveObject(with: data) as! UILocalNotification?
        }
    }
    return nil
}, toJSON: { value -> String? in
    // transform value from Int? to String?
    if let value = value {
        let data = NSKeyedArchiver.archivedData(withRootObject: value)
        return data.base64EncodedString(options: [])
    }
    return nil
})

let transformJsonStringInt = TransformOf<Int, Any>(fromJSON: { (value: Any?) -> Int? in
    // transform value from String? to Int?
    if let value = value as? Int {
        return value
    }
    if let value = value as? String {
        return Int(value)
    }
    return nil
}, toJSON: { (value: Int?) -> Int? in
    // transform value from Int? to String?
    value
})

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
