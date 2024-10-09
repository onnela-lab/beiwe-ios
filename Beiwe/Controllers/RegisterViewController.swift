import Eureka
import ObjectMapper
import Alamofire
import PKHUD
import Sentry
import SwiftValidator
import UIKit
import FirebaseCore
import FirebaseMessaging


class RegisterViewController: FormViewController {
    // static assets - communication erro is our generic couldn't-find-it error, it also covers
    // the case inside the callback function where there was no or bad json/no encryption key.
    // The message includes "or you have entered an incorrect server address"
    static let commErrDelay = 7.0
    static let commErr = NSLocalizedString("http_message_server_not_found", comment: "")
    
    // validation behavior? always false?
    let autoValidation = false
    // I guess this property is assigned somewhere, but its not assigned in this file...
    var dismiss: ((_ didRegister: Bool) -> Void)?
    
    // various text colors
    let font = UIFont.systemFont(ofSize: 16.0)
    let small_font = UIFont.systemFont(ofSize: 13.0, weight: UIFont.Weight.bold)
    let less_dark_gray = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1) // darkGray is 0.333, this is much more legible
    let legible_red = UIColor(red: 0.8, green: 0, blue: 0, alpha: 1)
    
    // set the font sizes, colors. Note that the label text is black in light mode and white in dark mode and it seems stuck that way.
    func apply_cell_defaults(_ cell: SVTextCell) {
        cell.backgroundColor = AppColors.Beiwe1 // the lightes "beiwe color'
        cell.textLabel?.font = self.font // the normal label
        cell.detailTextLabel?.font = self.font // text when there is nothing present in the form
        cell.validationLabel.font = self.small_font // the red validation text one
        cell.errorColor = self.legible_red // (also works with row.errorColor)
        
        // these don't work. It appears to be impossible to set this element's color.
        // cell.titleLabel?.textColor = UIColor.white
        // cell.accessibilityIgnoresInvertColors = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.backgroundColor = AppColors.Beiwe2 // one step darker than the light coloring
        
        // set the font sizes, colors.  Note that the label text is black in light mode and white in dark mode and it seems stuck that way.
        // (can't work out how to make a generic type function  to handle different rows)
        SVURLRow.defaultCellSetup = { (cell: SVURLCell, row: SVURLRow) in
            self.apply_cell_defaults(cell)
            row.placeholderColor = self.less_dark_gray
            row.onCellHighlightChanged { cell, row in
                cell.titleLabel?.textColor = UIColor.white
            }
        }
        SVTextRow.defaultCellSetup = { (cell: SVTextCell, row: SVTextRow) in
            self.apply_cell_defaults(cell)
            row.placeholderColor = self.less_dark_gray
            row.onCellHighlightChanged { cell, row in
                cell.titleLabel?.textColor = UIColor.white
            }
        }
        SVPasswordRow.defaultCellSetup = { (cell: SVPasswordCell, row: SVPasswordRow) in
            self.apply_cell_defaults(cell)
            row.placeholderColor = self.less_dark_gray
            row.onCellHighlightChanged { cell, row in
                cell.titleLabel?.textColor = UIColor.white
            }
        }
        SVSimplePhoneRow.defaultCellSetup = { (cell: SVSimplePhoneCell, row: SVSimplePhoneRow) in
            self.apply_cell_defaults(cell)
            row.placeholderColor = self.less_dark_gray
            row.onCellHighlightChanged { cell, row in
                cell.titleLabel?.textColor = UIColor.white
            }
        }
        SVAccountRow.defaultCellSetup = { (cell: SVAccountCell, row: SVAccountRow) in
            self.apply_cell_defaults(cell)
            row.placeholderColor = self.less_dark_gray
            row.onCellHighlightChanged { cell, row in
                cell.titleLabel?.textColor = UIColor.white
            }
        }
        
        var section = Section(NSLocalizedString("registration_screen_title", comment: ""))
        section = section
            // server url field (shows the url field, no validation)
            <<< SVURLRow("server") {
                // $0 is the ro object
                // $0.value = "staging.beiwe.org" // speed up your life in debugging by setting a default value
                $0.title = NSLocalizedString("registration_server_url_label", comment: "")
                $0.placeholder = NSLocalizedString("registration_server_url_hint", comment: "")
                $0.customRules = [RequiredRule()] // indicates required field
                $0.autoValidation = autoValidation
                $0.cell.tintColor = UIColor.white
                
                // $0.baseCell.titleLabel?.textColor = UIColor.white
                // the default highlightcolor is blue, we want it to stay white in dark mode, and in light mode it highlights the selected cell...
            }
            // participant id (aka patient id for... no reason)
            <<< SVTextRow("patientId") {
                // $0.value = "susix3kt"
                $0.title = NSLocalizedString("registration_user_id_label", comment: "")
                $0.placeholder = NSLocalizedString("registration_user_id_hint", comment: "")
                $0.customRules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
            // temporary password - has reduced validation
            <<< SVPasswordRow("tempPassword") {
                // $0.value = "a"
                $0.title = NSLocalizedString("registration_temp_password_label", comment: "")
                $0.placeholder = NSLocalizedString("registration_temp_password_hint", comment: "")
                $0.customRules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
            // password - has full validation
            <<< SVPasswordRow("password") {
                // $0.value = "      "
                $0.title = NSLocalizedString("registration_new_password_label", comment: "")
                $0.placeholder = NSLocalizedString("registration_new_password_hint", comment: "")
                $0.customRules = [RequiredRule(), RegexRule(regex: Constants.passwordRequirementRegex, message: Constants.passwordRequirementDescription)]
                $0.autoValidation = autoValidation
            }
            // confirm the password
            <<< SVPasswordRow("confirmPassword") {
                // $0.value = "      "
                $0.title = NSLocalizedString("registration_confirm_new_password_label", comment: "")
                $0.placeholder = NSLocalizedString("registration_confirm_new_password_hint", comment: "")
                $0.customRules = [RequiredRule(), MinLengthRule(length: 1)]
                $0.autoValidation = true // will show up as red until in matches, dope
            }
            // clinic phone number for general help
            <<< SVSimplePhoneRow("clinicianPhone") {
                // $0.value = "5555555555"
                $0.title = NSLocalizedString("phone_number_entry_your_clinician_label", comment: "")
                $0.placeholder = NSLocalizedString("phone_number_entry_your_clinician_hint", comment: "")
                $0.customRules = [RequiredRule(), MinLengthRule(length: 8), MaxLengthRule(length: 15), FloatRule()]
                $0.autoValidation = autoValidation
            }
            // research assistant phone numeber (more specific help)
            <<< SVSimplePhoneRow("raPhone") {
                // $0.value = "5555555555"
                $0.title = NSLocalizedString("phone_number_entry_research_assistant_label", comment: "")
                $0.placeholder = NSLocalizedString("phone_number_entry_research_assistant_hint", comment: "")
                $0.customRules = [RequiredRule(), MinLengthRule(length: 8), MaxLengthRule(length: 15), FloatRule()]
                $0.autoValidation = autoValidation
            }
            // the submit button
            <<< ButtonRow {
                $0.title = NSLocalizedString("registration_submit", comment: "")
                $0.baseCell.backgroundColor = AppColors.Beiwe2point5
                $0.cell.tintColor = UIColor.white // button text is ~blue, set it to white, looks nice....
            }
            // this is the validation code when you tap the register button
            .onCellSelection { [unowned self] (cell: ButtonCellOf<String>, row: ButtonRow) in
                runValidationAndRegister()
            }
            
        // the cancel button - why was there a cancel button.  Dismissing this view Never Worked and still doesn't work.
        // <<< ButtonRow {
        //     $0.title = NSLocalizedString("cancel_button_text", comment: "")
        // }.onCellSelection { [unowned self] (cell: ButtonCellOf<String>, row: ButtonRow) in
        //     if let dismiss = self.dismiss {
        //         dismiss(false)
        //     } else {
        //         self.presentingViewController?.dismiss(animated: true, completion: nil)
        //     }
        // }

        form +++ section // stick the sections in the form to allow form validation - I think
        
        // set up the matching values rule, I think?
        let passwordRow: SVPasswordRow? = form.rowBy(tag: "password")
        let confirmRow: SVPasswordRow? = form.rowBy(tag: "confirmPassword")
        confirmRow!.customRules = [ConfirmationRule(confirmField: passwordRow!.cell.textField)]
    }

    /// runs all validation code and the registration request.
    // This used to be an inline function stuck directly in the .onCellSelection code inside the viewDidLoad function above. No. Not okay.
    // Consequently this could and probably should be refactored further ("detangled" may be more accurate), but ... time.
    func runValidationAndRegister() {
        PKHUD.sharedHUD.dimsBackground = true // make it look nice while doing its thing
        
        if self.form.validateAll() {
            PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false // probably disables ui taps etc
            HUD.show(.progress) // pop up spinner
            
            // extract form values
            let formValues = self.form.values()
            let patientId: String? = formValues["patientId"] as! String?
            let phoneNumber: String? = "NOT_SUPPLIED"
            let newPassword: String? = formValues["password"] as! String?
            let tempPassword: String? = formValues["tempPassword"] as! String?
            let clinicianPhone: String? = formValues["clinicianPhone"] as! String?
            let raPhone: String? = formValues["raPhone"] as! String?
            
            // url fix
            var server = formValues["server"] as! String // this force conversion is safe even when value is empty
            if !server.starts(with: "https://") { // might as well _safely_ prepend https://
                server = "https://" + server
            }
            
            if let patientId = patientId, let phoneNumber = phoneNumber, let newPassword = newPassword, let clinicianPhone = clinicianPhone, let raPhone = raPhone {
                let registerStudyRequest = RegisterStudyRequest(patientId: patientId, phoneNumber: phoneNumber, newPassword: newPassword)
                
                // sets tags for Sentry
//                Client.shared?.tags = ["user_id": patientId, "server_url": server]
                ApiManager.sharedInstance.password = tempPassword ?? ""
                ApiManager.sharedInstance.patientId = patientId
                ApiManager.sharedInstance.customApiUrl = server
                
                ApiManager.sharedInstance.makePostRequest(
                    registerStudyRequest, completion_handler: { (dataResponse: DataResponse<String>) in
                        var error_message = ""
                        switch dataResponse.result {
                        case .success:
                            if let statusCode = dataResponse.response?.statusCode {
                                if statusCode >= 200 && statusCode < 300 {
                                    // body response also "throws errors" (ui elements)
                                    let body_response = BodyResponse(body: dataResponse.result.value)
                                    if let body_string = body_response.body {
                                        self.registrationCompletionHandler(
                                            body_response,
                                            new_password: newPassword,
                                            phone_number: phoneNumber,
                                            patient_id: patientId,
                                            clinician_phone: clinicianPhone,
                                            ra_phone: raPhone,
                                            server: server
                                        )
                                    }
                                } else {
                                    error_message = "registration request, but statuscode: \(statusCode), value/body: \(String(describing: dataResponse.result.value))"
                                    self.display_errors(statusCode, url: server)
                                }
                            } else {
                                error_message = "registration request - no status code?"
                                self.display_errors(0, url: server)
                            }
                        case .failure:
                            error_message = "registration request - error: \(String(describing: dataResponse.error))"
                            self.display_errors(0, url: server)
                        }
                        
                        if error_message != "" {
                            log.error(error_message)
                        }
                    }
                )
            }
        }
    }
    
    /// displays user readable errors in an overlay
    /// This function should not be called with 200-299 status codes.
    func display_errors(_ statusCode: Int, url: String) {
        print("bad status code during registration: \(statusCode)")
        var duration = 2.0
        var err: HUDContentType
        
        // determine message based on status code
        if statusCode == 403 || statusCode == 401 {
            // throwing on the url so that the person is presented with extra information if
            // they are hitting the wrong url that happens to throw a 403 or 401.
            err = .labeledError(
                title: NSLocalizedString("couldnt_register", comment: ""),
                subtitle: NSLocalizedString("http_message_403_during_registration", comment: "") + " " + url
            )
            duration = 4.0
        // we used to have this 405 code for participants already registered on another
        // device, it was removed
        // } else if statusCode == 405 {
        //     err = .label(NSLocalizedString("http_message_405", comment: ""))
        //     duration = 10.0 // long message, long duration (ui is still locked)
        } else if statusCode == 400 {
            err = .label(NSLocalizedString("http_message_400", comment: ""))
            duration = 10.0 // long message, long duration (ui is still locked)
        } else {
            err = .label(RegisterViewController.commErr)
            duration = RegisterViewController.commErrDelay
        }
        // display the error message
        HUD.flash(err, delay: duration) // delay is duration
    }
    
    /// We have to do something real stupid, see comments
    func extractStudySettings(_ bodyResponse: BodyResponse) -> StudySettings? {
        // the json string we are handed may not have data for `ios_plist`, which is the
        // firebase push notification ~certificate from which this app get's access to the
        // service and can generate the app-side tokens.  IF THERE IS NO VALUE then we have
        // to insert some defaults because this is a critical and optional part of Beiwe.
        // But.
        // We use ObjectMapper objects for our critical classes, like StudySettings, and the database
        // expects them too. We can only instantiate these classes using `Mapper<StudySettings>().map`,
        // which takes a String of json text.  In order to do this we need to:
        // - deserialize the incoming string from the server
        // - check if it has the ios_plist content
        // - if it doesn't then we have to insert safe defaults
        // - then reserialize the json to a string - but actually we can't it has to be a Data
        // - so we serialize to Data and then to utf8 encoded string
        // - and then we pass it to the `Mapper<StudySettings>().map`
        // Yes, this is Very Very stupid.
        // But:
        // DON'T REFACTOR TO HAVE A SIMPLER PASSTHROUGH FOR THE CASE WHERE ios_plist IS PRESENT.
        // If you do that then you will not be testing this case bydefault and some poor future soul
        // will be forced to detangle this stupidity again.
        
        // (And if you think this is bad, it used to be inside a promise, inside a
        // conditional, inside the makePostRequest MapperObject-templated function call used
        // by all post requests over in ApiManager because, due to the awful use of PromiseKit
        // this serialization functionality was otherwise completely inaccessible. If you, you
        // poor future soul, find a way to get rid of this crap it is because you are
        // standing on the shoulders of giants. Still, I salute you. |(￣^￣)ゞ - Eli)
        
        // bodyResponse.body is confirmed not nil inside the closure on the registration request.
        do {
            // the ios plist default values may need to be injected
            var converted_original_json: [String: Any] =
                try JSONSerialization.jsonObject(with: Data(bodyResponse.body!.utf8)) as! [String: Any]
            if converted_original_json["ios_plist"] is NSNull || converted_original_json["ios_plist"] == nil {
                converted_original_json["ios_plist"] = [
                    "CLIENT_ID": "",
                    "REVERSED_CLIENT_ID": "",
                    "API_KEY": "",
                    "GCM_SENDER_ID": "",
                    "PLIST_VERSION": "1",
                    "BUNDLE_ID": "",
                    "PROJECT_ID": "",
                    "STORAGE_BUCKET": "",
                    "IS_ADS_ENABLED": false,
                    "IS_ANALYTICS_ENABLED": false,
                    "IS_APPINVITE_ENABLED": true,
                    "IS_GCM_ENABLED": true,
                    "IS_SIGNIN_ENABLED": true,
                    "GOOGLE_APP_ID": "",
                    "DATABASE_URL": "",
                ]
            }
            
            // Do the stupid double serialization.
            // (The String() constructor is optional, can't change that.)
            let back_to_bytes: Data = try JSONSerialization.data(withJSONObject: converted_original_json, options: [])
            if let and_now_its_a_string = String(data: back_to_bytes, encoding: .utf8) {
                // omg a StudySettings object emerges from the mists of stupid.
                return Mapper<StudySettings>().map(JSONString: and_now_its_a_string)
            }
        } catch {
            log.error("Unable to create default firebase credentials plist")
        }
        // case: and_now_its_a_string somehow was null, or the catch logic happened
        return nil
    }
    
    func registrationCompletionHandler(
        _ bodyResponse: BodyResponse,
        new_password: String, 
        phone_number: String,
        patient_id: String,
        clinician_phone: String,
        ra_phone: String,
        server: String
    ) {
        // if the json was not parseable than we probably have the wrong url.
        // Everything is broken if the settings or public key are nil.
        // (the latter  can theoretically happen if there is a valid json in the response body
        // from a rando website, unlikely but possible).  commErr is the appropriate message.
        guard let studySettings = extractStudySettings(bodyResponse), studySettings.clientPublicKey != nil else {
            HUD.flash(.label(RegisterViewController.commErr), delay: RegisterViewController.commErrDelay)
            return
        }
        
        // set password, network ops require the password, there could potentially be network requests happening?
        PersistentPasswordManager.sharedInstance.storePassword(new_password)
        ApiManager.sharedInstance.password = new_password
        
        // firebase - is one of the network requests
        if FirebaseApp.app() == nil && studySettings.googleAppID != "" {
            AppDelegate.sharedInstance().configureFirebase(studySettings: studySettings)
        }
        
        // OK here we go - instantiate the study
        let study = Study(
            patientPhone: phone_number,
            patientId: patient_id,
            studySettings: studySettings,
            apiUrl: server
        )
        study.clinicianPhoneNumber = clinician_phone
        study.raPhoneNumber = ra_phone
        
        // fuzzgps
        if studySettings.fuzzGps {
            study.fuzzGpsLatitudeOffset = self.generateLatitudeOffset()
            study.fuzzGpsLongitudeOffset = self.generateLongitudeOffset()
        }
        
        // Call purge studies to ensure there is no weird data present from possible partial study registrations.
        // (sure, odd that we call the studymanager before creating the study but whatever)
        // TODO: if we are literally emptying the database do we even need the leave study logic AT ALL??
        StudyManager.sharedInstance.purgeStudies()
        Recline.shared.save(study)
        
        // sendFCMToken only sends on non empty string case
        AppDelegate.sharedInstance().sendFCMToken(fcmToken: Messaging.messaging().fcmToken ?? "")
        
        // load the study
        StudyManager.sharedInstance.loadDefaultStudy()
        AppDelegate.sharedInstance().isLoggedIn = true
        HUD.flash(.success, delay: 2) // delay is duration
        
        // UI operations must come from the main thread
        DispatchQueue.main.async {
            if let dismiss = self.dismiss {
                dismiss(true) // it calls dismiss which is a weird assignable function variable.
            } else {
                self.presentingViewController?.dismiss(animated: true, completion: nil) // dismisses the view?
            }
        }
    }
    
    /// this doesn't do anything....
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning() // Dispose of any resources that can be recreated.
    }
    
    /// Generates a random offset between -1 and 1 (thats not between -0.2 and 0.2)
    func generateLatitudeOffset() -> Double {
        var ran = Double.random(in: -1 ... 1)
        while ran <= 0.2 && ran >= -0.2 {
            ran = Double.random(in: -1 ... 1)
        }
        return ran
    }
    
    /// Generates a random offset between -180 and 180 (thats not between -10 and 10)
    func generateLongitudeOffset() -> Double {
        var ran = Double.random(in: -180 ... 180)
        while ran <= 10 && ran >= -10 {
            ran = Double.random(in: -180 ... 180)
        }
        return ran
    }
}
