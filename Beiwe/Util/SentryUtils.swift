import Foundation

// loads the sentry configuration from Config.plist or Config-Default.plist?
// This appears to correctly determine whether the app is a development build or a release build.
class SentryConfiguration {
    static let sharedInstance = SentryConfiguration();
    var settings: Dictionary<String, AnyObject> = [:];

    init() {
        if let path = Bundle.main.path(forResource: "Config-Default", ofType: "plist"), let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            for (key,value) in dict {
                settings[key] = value;
            }
        }
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"), let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            for (key,value) in dict {
                settings[key] = value;
            }
        }

    }
}
