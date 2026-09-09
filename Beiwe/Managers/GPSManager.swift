import CoreLocation
import Darwin
import Foundation


let gps_headers = [
    "timestamp",
    "latitude",
    "longitude",
    "altitude",
    "accuracy",
]


// accuracy options:
// kCLLocationAccuracyBestForNavigation
// kCLLocationAccuracyBest
// kCLLocationAccuracyNearestTenMeters
// kCLLocationAccuracyHundredMeters
// kCLLocationAccuracyKilometer
// kCLLocationAccuracyThreeKilometers

// self.locationManager.distanceFilter:
// Specifies the minimum update distance in meters. Client will not be notified of movements of less
// than the stated value, unless the accuracy has improved. Pass in kCLDistanceFilterNone to be
// notified of all movements. By default, kCLDistanceFilterNone is used.

// Worst accuracy (off but still connected to gps)
// self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers // loose accuracy?
// self.locationManager.distanceFilter = 99999 // value in meters - "Pass in kCLDistanceFilterNone to be notified of all movements"

// probably still not viable
// self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
// self.locationManager.distanceFilter = 50  // ?

// reasonable accuracy - we will test this
// self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
// self.locationManager.distanceFilter = 10

// best accuracy
// self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
// self.locationManager.distanceFilter = kCLDistanceFilterNone

// set the desired
// let THE_DESIRED_ACTIVE_ACCURACY = kCLLocationAccuracyKilometer
let THE_DESIRED_ACTIVE_ACCURACY = kCLLocationAccuracyHundredMeters
// let THE_DESIRED_ACTIVE_ACCURACY = kCLLocationAccuracyNearestTenMeters
// let THE_DESIRED_ACTIVE_ACCURACY = kCLLocationAccuracyBest
let THE_DESIRED_ACTIVE_DISTANCE_FILTER = kCLDistanceFilterNone

// let THE_DESIRED_INACTIVE_ACCURACY = kCLLocationAccuracyKilometer
let THE_DESIRED_INACTIVE_ACCURACY = kCLLocationAccuracyHundredMeters  // 2024.21 -- less frequent than best
// let THE_DESIRED_INACTIVE_ACCURACY = kCLLocationAccuracyNearestTenMeters  // seems identical to best
// let THE_DESIRED_INACTIVE_ACCURACY = kCLLocationAccuracyBest
let THE_DESIRED_INACTIVE_DISTANCE_FILTER = kCLDistanceFilterNone


// testing with kCLDistanceFilterNone while stationary
// kCLLocationAccuracyBest: 1 update per second
// kCLLocationAccuracyNearestTenMeters: also one update per second.
// kCLLocationAccuracyHundredMeters: one update every 15 seconds.
//   WOW ok my personal tests indicate this is a battery life improvement over Best by about 1/3 - eg
//   battery drain is about 2/3 overall compared to Best.  sweet.
// kCLLocationAccuracyKilometer: started as one update every 15 seconds to start, but then esp if the app is backgrounded
//   it becomes whenever the user gets updates, which can be when they turn on the screen...  Next try did not start with
//   data points every 15 seconds to start despite remaining in the app.

/// The GPS Manager.
/// The GPSManager is a critical component of app persistence, it is instantiated even if the study
/// is not using the GPS data stream, it just doesn't do anything with the data.
class GPSManager: NSObject, CLLocationManagerDelegate, DataServiceProtocol {
    // Location
    let locationManager = CLLocationManager()
    var lastLocations: [CLLocation]?
    
    // settings
    var enableGpsFuzzing: Bool = false
    var fuzzGpsLatitudeOffset: Double = 0.0
    var fuzzGpsLongitudeOffset: Double = 0.0
    
    // State
    var isCollectingGps: Bool = false
    
    // gps storage
    var datapoints = [[String]]()
    let cacheLock = NSLock()
    
    // ok this is a little dumb but we need to do it to conform to the DataServiceProtocol
    static let static_storeType = "gps"
    let storeType = "gps"
    var dataStorage: DataStorage?
    
    /// checks gps permission - IDE warning about UI unresponsiveness appears to never be an issue.
    func gpsAllowed() -> Bool {
        return CLLocationManager.locationServicesEnabled()
            && CLLocationManager.authorizationStatus() == .authorizedAlways
    }
    
    /// starts GPS - enrolls app (rather, this class) in the LocationManager updates loop.
    func startGps() {
        self.locationManager.delegate = self // assigns this instance of the class as the gps delegate class
        self.locationManager.activityType = CLActivityType.other // most permissive I think
        self.locationManager.allowsBackgroundLocationUpdates = true // do not require app be in foreground
        
        self.locationManager.desiredAccuracy = THE_DESIRED_INACTIVE_ACCURACY
        self.locationManager.distanceFilter = THE_DESIRED_INACTIVE_DISTANCE_FILTER
        
        // permission check
        self.locationManager.requestAlwaysAuthorization()
        
        // never stop
        self.locationManager.pausesLocationUpdatesAutomatically = false
        
        // start!
        self.locationManager.startUpdatingLocation()
        self.locationManager.startMonitoringSignificantLocationChanges()
    }
    
    /// Stops the location manager from receiving updates
    /// This is only called from special locations within the app, like when the app is terminated,
    /// it is not part of general usage.
    func stopGps() {
        self.locationManager.stopUpdatingLocation()
        AppEventManager.sharedInstance.logAppEvent(event: "gps stopped due to app termination")
    }
 
    ////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Location Manager Functons ///////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////
    
    /// records a single location datapoint (though in principal it could provide more)
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // we don't record data when a recording session is not active
        // print("hey a location: \(locations)")
        if self.isCollectingGps && StudyManager.sharedInstance.timerManager.areServicesRunning {
            self.recordGpsData(manager, locations: locations)
        }
    }

    /// gps paused
    //Invoked when location updates are automatically paused.
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        print("gps paused message received")
        AppEventManager.sharedInstance.logAppEvent(event: "gps paused message received")
    }

    /// gps resumed
    // Invoked when location updates are automatically resumed. In the event that your
    // application is terminated while suspended, you will not receive this notification. */
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        print("gps resumed message received")
        AppEventManager.sharedInstance.logAppEvent(event: "gps resumed message received")
    }
    
    // Invoked when deferred updates will no longer be delivered. Stopping location, disallowing deferred
    // updates, and meeting a specified criterion are all possible reasons for finishing deferred updates.
    // An error will be returned if deferred updates end before the specified
    // criteria are met (see CLError), otherwise error will be nil.
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?){
        let error_message: String
        if let error = error { error_message = error.localizedDescription } else { error_message = "no error"}
        print("gps \"FinishDeferredUpdatesWithError\" error message received '\(error_message)")
        AppEventManager.sharedInstance.logAppEvent(event: "gps \"FinishDeferredUpdatesWithError\" error message received", d1: error_message)
    }
    
    /// Invoked when either the authorizationStatus or accuracyAuthorization properties change (iOS 14+),
    /// also fires once when the delegate is assigned. Defers to the AppDelegate's permission tracking, which
    /// writes a permission_changed app log event only when the value actually differs from the last known one.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        AppDelegate.sharedInstance().updatePermissionStates()
    }
    
    /*  locationManager:didFailWithError:
    Invoked when an error has occurred. Error types are defined in "CLError.h". */
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let error_message = error.localizedDescription
        print("gps \"didFailWithError\" error message received '\(error_message)")
        AppEventManager.sharedInstance.logAppEvent(event: "gps \"didFailWithError\" error message received", d1: error_message)
    }

    /// records a single line of data to the gps csv, implements gps fuzzing
    func recordGpsData(_ manager: CLLocationManager, locations: [CLLocation]) {
        for loc in locations {
            var data: [String] = []
            var lat = loc.coordinate.latitude
            var lng = loc.coordinate.longitude
            if self.enableGpsFuzzing {
                lat = lat + self.fuzzGpsLatitudeOffset
                // the range for highly negative numbers (up to -360.0) creates out-of-range output, the fix is to add
                // multiple of 360 + 180 so that the truncating remainder is always a positive value -  and then at
                // the end account for the negative range by subtracting 180. (1260 = 360*3 + 180)
                lng = ((lng + self.fuzzGpsLongitudeOffset + 1260.0).truncatingRemainder(dividingBy: 360.0)) - 180.0
            }
            // header order is timestamp, latitude, longitude, altitude, accuracy, vert_accuracy
            data.append(String(Int64(loc.timestamp.timeIntervalSince1970 * 1000)))
            data.append(String(lat))
            data.append(String(lng))
            data.append(String(loc.altitude))
            data.append(String(loc.horizontalAccuracy))
            
            self.cacheLock.lock()
            datapoints.append(data)
            self.cacheLock.unlock()
            
            if self.datapoints.count > GPS_CACHE_SIZE {
                self.flush()
            }
        }
    }

    /* Data service protocol */

    /// init collecting
    func initCollecting() -> Bool {
        guard self.gpsAllowed() else {
            log.error("GPS not enabled.  Not initializing collection")
            return false
        }
        self.dataStorage = DataStorageManager.sharedInstance.createStore("gps", headers: gps_headers)
        self.isCollectingGps = false
        return true
    }

    /// start collecting
    func startCollecting() {
        // print("Turning \(self.storeType) collection on")
        AppEventManager.sharedInstance.logAppEvent(event: "gps_on", msg: "GPS collection on")
        self.isCollectingGps = true
        // disable changing this at all
        self.locationManager.desiredAccuracy = THE_DESIRED_ACTIVE_ACCURACY
        self.locationManager.distanceFilter = THE_DESIRED_ACTIVE_DISTANCE_FILTER
    }

    /// stop collecting
    func pauseCollecting() {
        // print("Pausing \(self.storeType) collection")
        AppEventManager.sharedInstance.logAppEvent(event: "gps_off", msg: "GPS collection off")
        self.isCollectingGps = false
        self.locationManager.desiredAccuracy = THE_DESIRED_INACTIVE_ACCURACY
        self.locationManager.distanceFilter = THE_DESIRED_INACTIVE_DISTANCE_FILTER
    }

    /// only called in self.stopAndClear
    func finishCollecting() {
        // print("Finishing \(self.storeType) collection")
        self.pauseCollecting()
        self.isCollectingGps = false
        self.dataStorage = nil
        self.createNewFile() // we have lazy new file creation
    }
    
    func createNewFile() {
        self.flush()
        self.dataStorage?.reset()
    }
    
    func flush() {
        // todo - bulk write?
        self.cacheLock.lock()
        let data_to_write = self.datapoints
        self.datapoints = []
        self.cacheLock.unlock()
        for data in data_to_write {
            self.dataStorage?.store(data)
        }
    }
}


/// These are the other GPS hooks and their documentation

/// deferred updates - why on earth are these called "deferred"? These are just gps updates! wtf
/// receive deferred
/*  locationManager:didUpdateLocations:
Invoked when new locations are available.  Required for delivery of deferred locations.
If implemented, updates will not be delivered to locationManager:didUpdateToLocation:fromLocation:
locations is an array of CLLocation objects in chronological order. */
// optional func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
/// deferred error
/*  locationManager:didFinishDeferredUpdatesWithError:
Invoked when deferred updates will no longer be delivered. Stopping location, disallowing deferred
updates, and meeting a specified criterion are all possible reasons for finishing deferred updates.
An error will be returned if deferred updates end before the specified
criteria are met (see CLError), otherwise error will be nil. */
// optional func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?)


/// Heading? probably part of navigation apps.

/// part of driving mode? not useful.
/*  locationManager:didUpdateHeading: Invoked when a new heading is available. */
// optional func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading)

/// part of driving? not useful
/*  locationManagerShouldDisplayHeadingCalibration:
Invoked when a new heading is available. Return YES to display heading calibration info. The display
will remain until heading is calibrated, unless dismissed early via dismissHeadingCalibrationDisplay. */
// optional func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool


/// "important" location updates?

/// part of important location updates? not useful
/*  locationManager:didVisit:
Invoked when the CLLocationManager determines that the device has visited a
location, if visit monitoring is currently started (possibly from a prior launch). */
// optional func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit)



/// Regions?

/// "DetermineState"??
/*  locationManager:didDetermineState:forRegion:
Invoked when there's a state transition for a monitored region or in response to a request for state via a
a call to requestStateForRegion:. */
// optional func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion)
/// Enter
/*  locationManager:didEnterRegion:
Invoked when the user enters a monitored region.  This callback will be invoked for every allocated
CLLocationManager instance with a non-nil delegate that implements this method. */
// optional func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion)
/// Exit
/*  locationManager:didExitRegion:
Invoked when the user exits a monitored region.  This callback will be invoked for every allocated
CLLocationManager instance with a non-nil delegate that implements this method. */
// optional func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion)
/// Region errors
/*  locationManager:monitoringDidFailForRegion:withError:
Invoked when a region monitoring error has occurred. Error types are defined in "CLError.h". */
// optional func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error)
/// start monitoring regions
/*  locationManager:didStartMonitoringForRegion:
      Invoked when a monitoring for a region started successfully. */
// optional func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion)


///Beacons?

/// what are beacons...
/*  locationManager:didRangeBeacons:inRegion:
Invoked when a new set of beacons are available in the specified region. beacons is an array of CLBeacon objects.
If beacons is empty, it may be assumed no beacons that match the specified region are nearby.
Similarly if a specific beacon no longer appears in beacons, it may be assumed the beacon is no longer received
by the device. */
// optional func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion)
/// more beacons
/*  locationManager:rangingBeaconsDidFailForRegion:withError:
Invoked when an error has occurred ranging beacons in a region. Error types are defined in "CLError.h". */
// optional func locationManager(_ manager: CLLocationManager, rangingBeaconsDidFailFor region: CLBeaconRegion, withError error: Error)
/// even more beacons
// optional func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint)
// optional func locationManager(_ manager: CLLocationManager, didFailRangingFor beaconConstraint: CLBeaconIdentityConstraint, error: Error)


/// errors....
/*  locationManager:didFailWithError:
Invoked when an error has occurred. Error types are defined in "CLError.h". */
// optional func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)

/// Authorization changed
/// auth change 1
/*  locationManager:didChangeAuthorizationStatus:
Invoked when the authorization status changes for this application. */
// optional func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
/// auth change 2
/*  locationManagerDidChangeAuthorization:
Invoked when either the authorizationStatus or accuracyAuthorization properties change */
// optional func locationManagerDidChangeAuthorization(_ manager: CLLocationManager)
