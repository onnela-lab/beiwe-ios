import Alamofire
import Foundation
import ObjectMapper

/// a type used in the api endpoint classes
protocol ApiRequest {
    associatedtype ApiReturnType: Mappable
    static var apiEndpoint: String { get }
}

/// error types for api requests
enum ApiErrors: Error {
    case failedStatus(code: Int)
    case fileNotFound
}

/// This is what we ended up using for our post requests after the promisekit purge, I thought it
/// was part of Alamofire. It isn't. It just takes the output of the request and sticks it on a
/// .body property. Complete garbage intermidiate object.
/// Fixme: kill this class, why are we even using a mappable that's insane. Call the correct
/// Mappable that you need on the body output of the api requests explicitly.
struct BodyResponse: Mappable {
    var body: String?

    init?(map: Map) {}
    init(body: String?) {
        self.body = body
    }

    // I don't know what this function does, it clearly sets body too the contents of the map at key "body"
    mutating func mapping(map: Map) {
        self.body <- map["body"]
    }
}

/// Our general purpose api endpoint hitting code.
class ApiManager {
    static let sharedInstance = ApiManager()
    fileprivate var deviceId = PersistentAppUUID.sharedInstance.uuid

    fileprivate var hashedPassword = ""

    // setter hashes the password
    var password: String {
        set {
            self.hashedPassword = Crypto.sharedInstance.sha256Base64URL(newValue)
        }
        get {
            return ""
        }
    }

    // some dumb default values
    var fcmToken: String?
    var patientId: String = ""
    var customApiUrl: String?
    
    // get the url
    var baseApiUrl: String {
        return self.customApiUrl ?? ""
    }
    
    func setDefaultParameters(_ parameters: inout [String: Any], skip_password: Bool = false) {
        // credential parameters
        if !skip_password {
            parameters["password"] = self.hashedPassword
        }
        parameters["patient_id"] = self.patientId
        
        parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid // deprecated?
        
        // basic device info, will be displayed on the participant page
        parameters["version_code"] = Constants.APP_VERSION
        parameters["version_name"] = Constants.APP_BUILD
        parameters["os_version"] = UIDevice.current.systemVersion
        parameters["timezone"] = TimeZone.current.identifier
        
        // testing for the presence of these strings is much MUCH better than comparing version numbers.
        parameters["supported_features"] = easyJSON(Constants.ENABLED_FEATURES)

        // various device metrics to be improved on over time, meant for developer use to debug issues.
        var device_status_report = [String: String]()
        device_status_report["app_commit"] = Constants.APP_COMMIT
        device_status_report["timestamp"] = timestampString() + " " + TimeZone.current.identifier
        device_status_report["transition_count"] = Ephemerals.transition_count.description
        
        // UIDevice provides some helpful details
        device_status_report["battery_level"] = String(UIDevice.current.batteryLevel)
        device_status_report["battery_state"] = String(UIDevice.current.batteryState.rawValue)
        device_status_report["device_model"] = UIDevice.current.model
        device_status_report["proximity_monitoring_enabled"] = UIDevice.current.isProximityMonitoringEnabled.description
        device_status_report["on_wifi"] = "\(!NetworkAccessMonitor.network_cellular)"
        
        // Location services configuration
        device_status_report["location_services_enabled"] = Ephemerals.locationServicesEnabledDescription
        device_status_report["location_significant_change_monitoring_enabled"] = Ephemerals.significantLocationChangeMonitoringAvailable
        device_status_report["location_permission"] = switch CLLocationManager.authorizationStatus() {
        case .notDetermined: "not_determined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorizedAlways: "authorized_always"
        case .authorizedWhenInUse: "authorized_when_in_use"
        @unknown default: "unknown: '\(CLLocationManager.authorizationStatus().rawValue)'"
        }
        
        // Ephemerals are items that for one reason or another are stored on and not perisistent.
        
        // notification permissions, can be one of not_determined, denied, authorized, provisional, or ephemeral.
        device_status_report["notification_permission"] = Ephemerals.notification_permission
        // background refresh
        device_status_report["background_refresh_status"] = Ephemerals.backgroundRefreshStatus
        // uploads info
        device_status_report["last_upload_start"] = Ephemerals.start_last_upload
        device_status_report["last_upload_end"] = Ephemerals.end_last_upload
        
        // is there a possible database threading error here on accessing files_in_flight?
        device_status_report["number_uploads_queued"] = String(StudyManager.sharedInstance.files_in_flight.count)
        
        
        // app state that can't exist until you register for a study
        if let study = StudyManager.sharedInstance.currentStudy {
            device_status_report["last_application_will_terminate"] = study.lastApplicationWillTerminate
            device_status_report["last_application_did_become_active"] = Ephemerals.lastApplicationDidBecomeActive
            device_status_report["last_application_did_enter_background"] = Ephemerals.lastApplicationDidEnterBackground
            device_status_report["last_application_did_receive_memory_warning"] = Ephemerals.lastApplicationDidReceiveMemoryWarning
            device_status_report["last_app_start"] = Ephemerals.lastAppStart
            device_status_report["last_successful_login"] = Ephemerals.lastSuccessfulLogin
            device_status_report["last_background_push_notification_received"] = study.lastBackgroundPushNotificationReceived
            device_status_report["last_foreground_push_notification_received"] = study.lastForegroundPushNotificationReceived
            
            // This could be extremely verbose... let's do a count?
            // device_status_report["list_current_data_files"] = easyJSON(get_current_data_files_list())
            // device_status_report["list_upload_files"] = easyJSON(get_upload_files_list())
            device_status_report["count_current_data_files"] = String(count_current_data_files())
            device_status_report["count_upload_files_count"] = String(count_upload_files())
            
            // neither of these can fail
            parameters["notification_uuids"] = easyJSON(study.surveyPushNotificationUUIDs)
            parameters["active_survey_ids"] = easyJSON(StudyManager.sharedInstance.getActuallyActiveSurveyIds())
        }
        
        // object cannot fail to be serialized, data types are valid....
        // stupid. We need to convert a [String:String] to a json object, which is a Data
        // (bytes) and then we need to convert THAT to a string.
        parameters["device_status_report"] = easyJSON(device_status_report)
    }
    
    /// This looks like it does literally nothing?
    static func serialErr() -> NSError {
        return NSError(domain: "com.beiwe.studies", code: 2, userInfo: nil)
    }

    /// hits the endpoint once, doesn't do anything with the request object, literally just returns.
    // assumes endpoint starts with a slash
    func extremelySimplePostRequest(_ endpoint: String, extra_parameters: [String: Any]) {
        var parameters: [String: Any] = [:]
        self.setDefaultParameters(&parameters)
        // add to parameters
        for (key, value) in extra_parameters {
            parameters[key] = value
        }
        Alamofire.request(self.baseApiUrl + endpoint, method: .post, parameters: parameters)
        
        // if we want to extend it here's some code to do so - note that this executes asynchronously, so we would need a completion handler pattern
        // var return_code = 0
        // let x = request.responseString { (response: DataResponse<String>) in
        //     switch response.result {
        //
        //     case let .failure(error):
        //         print("failure in simpleGetRequest, Error: '\(error)', Response: '\(response)', Response.response: '\(String(describing: response.response))'")
        //         return_code = -1
        //
        //     case .success:
        //         return_code = response.response!.statusCode
        //         print("response code:", response.response!.statusCode)
        //     }
        // }
        // print("request.responseString?:", x)
        // return return_code
    }
    
    /// way WAY less complex api request that doesn't bypass the entire point of Alamofire. Requires a completionhandler.
    /// If we need the non-DataResponse<String> type.... make such a function.
    /// (request runs on the default alamofire queue, the convenience session constructor in the docs
    /// might require version 5+. This is version 4.9.1. )
    func makePostRequest<T: ApiRequest>(
        _ requestObject: T,
        password: String? = nil,
        completion_queue: DispatchQueue? = nil,
        completion_handler: ((DataResponse<String>) -> Void)? = nil
    ) where T: Mappable {
        var parameters = requestObject.toJSON()
        parameters["password"] = (password == nil) ? self.hashedPassword : Crypto.sharedInstance.sha256Base64URL(password!) // I don't know what this line does
        self.setDefaultParameters(&parameters, skip_password: true)
        
        // this is asynchronous, it ~immediately fires, and somehow we can attach the completion handler
        // afterwards and it all just works. cool.
        let request = Alamofire.request(self.baseApiUrl + T.apiEndpoint, method: .post, parameters: parameters)
        // pass the completion handler to the responseString method on the queue
        
        if let completion_handler = completion_handler {
            request.responseString(queue: completion_queue, completionHandler: completion_handler)
        }
    }
    
    func makeMultipartUploadRequest<T: ApiRequest>(
        _ requestObject: T,
        file: URL,
        completionQueue: DispatchQueue,
        httpSuccessCompletionHandler: @escaping (DataResponse<String>) -> Void,
        encodingErrorHandler: @escaping (Error) -> Void
    ) where T: Mappable {
        var parameters: [String: Any] = requestObject.toJSON()
        self.setDefaultParameters(&parameters)
        let url = self.baseApiUrl + T.apiEndpoint

        Alamofire.upload(
            // for some reason we need to do the multipart form elements first, otherwise
            // swift complains that it has to precede the `to` and `method` parameters.
            multipartFormData: { (multipartFormData: MultipartFormData) in
                // all the parameters as multipart form data, and the file
                for (k, v) in parameters {
                    multipartFormData.append(String(describing: v).data(using: .utf8)!, withName: k)
                }
                multipartFormData.append(file, withName: "file")
            },
            
            // target url and specify post. (why we have to specify that? seems implied? whatever.)
            to: url,
            method: .post,
            
            // the completion stuff
            encodingCompletion: { (encodingResult: SessionManager.MultipartFormDataEncodingResult) in
                // it looks like encoding data in the muiltipart upload section can fail
                switch encodingResult {
                // this failure is probably specific to local system stuff, but I guess it might
                // be bad network requests too maybe? deleted files? unknown.
                case let .failure(encodingError):
                    completionQueue.async {
                        encodingErrorHandler(encodingError)
                    }
                // and for the success case... we use the same architecture as makePostRequest,
                // Provide A Completion Handler That Takes a DataResponse<String> object.
                case let .success(uploadRequest, _streamingFromDisk, _streamFileURL): // UploadRequest, Bool, URL?
                    uploadRequest.responseString(
                        queue: completionQueue,
                        completionHandler: httpSuccessCompletionHandler
                    )
                }
            }
        )
    }
}
