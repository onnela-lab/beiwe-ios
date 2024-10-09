import Sentry

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
func isoStringToTimeInterval(timeString: String) -> TimeInterval {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    let sentTime = dateFormatter.date(from: timeString)!
    return sentTime.timeIntervalSince1970
}

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

func sentry_warning(_ title: String, _ extra1: String? = nil, _ extra2: String? = nil, _ extra3: String? = nil, crash: Bool) {
//    if let sentry_client = Client.shared {
//        sentry_client.snapshotStacktrace {
//            let event = Event(level: .warning)
//            event.message = title
//            event.environment = Constants.APP_INFO_TAG
//            
//            // todo does this always exist?
//            if event.extra == nil {
//                event.extra = [:]
//            }
//            if var extras = event.extra {
//                if let extra = extra1 {
//                    extras["extra1"] = extra
//                }
//                if let extra = extra2 {
//                    extras["extra2"] = extra
//                }
//                if let extra = extra3 {
//                    extras["extra3"] = extra
//                }
//                if let patient_id = StudyManager.sharedInstance.currentStudy?.patientId {
//                    extras["user_id"] = StudyManager.sharedInstance.currentStudy?.patientId
//                }
//            }
//            sentry_client.appendStacktrace(to: event)
//            sentry_client.send(event: event)
//        }
//    }
}


