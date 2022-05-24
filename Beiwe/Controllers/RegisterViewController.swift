//
//  RegisterViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/23/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import Eureka
import SwiftValidator
import PKHUD
import PromiseKit
import Sentry
import Firebase

class RegisterViewController: FormViewController {

    enum RegistrationError: Error {
        case incorrectServer
    }
    
    static let commErrDelay = 7.0
    static let commErr = NSLocalizedString("http_message_server_not_found", comment: "")
    let autoValidation = false;
    let db = Recline.shared;
    var dismiss: ((_ didRegister: Bool) -> Void)?;

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        let font = UIFont.systemFont(ofSize: 13.0);
        SVURLRow.defaultCellSetup = { cell, row in
            cell.textLabel?.font = font
            cell.detailTextLabel?.font = font;
        }
        SVTextRow.defaultCellSetup = { cell, row in
            cell.textLabel?.font = font
            cell.detailTextLabel?.font = font;
        }
        SVPasswordRow.defaultCellSetup = { cell, row in
            cell.textLabel?.font = font
            cell.detailTextLabel?.font = font;
        }
        SVSimplePhoneRow.defaultCellSetup = { cell, row in
            cell.textLabel?.font = font
            cell.detailTextLabel?.font = font;
        }
        let configServer = Configuration.sharedInstance.settings["config-server"] as? Bool ?? false;
        var section = Section(NSLocalizedString("registration_screen_title", comment: ""))
        if (configServer) {
            section = section <<< SVURLRow("server") {
                $0.title = NSLocalizedString("registration_server_url_label", comment: "")
                $0.placeholder = NSLocalizedString("registration_server_url_hint", comment: "")
                $0.customRules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
        }
        section = section <<< SVAccountRow("patientId") {
                $0.title = NSLocalizedString("registration_user_id_label", comment: "")
                $0.placeholder = NSLocalizedString("registration_user_id_hint", comment: "")
                $0.customRules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
            <<< SVPasswordRow("tempPassword") {
                $0.title = NSLocalizedString("registration_temp_password_label", comment: "")
                $0.placeholder = NSLocalizedString("registration_temp_password_hint", comment: "")
                $0.customRules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
            <<< SVPasswordRow("password") {
                $0.title = NSLocalizedString("registration_new_password_label", comment: "")
                $0.placeholder = NSLocalizedString("registration_new_password_hint", comment: "")
                $0.customRules = [RequiredRule(), RegexRule(regex: Constants.passwordRequirementRegex, message: Constants.passwordRequirementDescription)]
                $0.autoValidation = autoValidation
            }
            <<< SVPasswordRow("confirmPassword") {
                $0.title = NSLocalizedString("registration_confirm_new_password_label", comment: "")
                $0.placeholder = NSLocalizedString("registration_confirm_new_password_hint", comment: "")
                $0.customRules = [RequiredRule(), MinLengthRule(length: 1)]
                $0.autoValidation = autoValidation
            }
            <<< SVSimplePhoneRow("clinicianPhone") {
                $0.title = NSLocalizedString("phone_number_entry_your_clinician_label", comment: "")
                $0.placeholder = NSLocalizedString("phone_number_entry_your_clinician_hint", comment: "")
                $0.customRules = [RequiredRule(), MinLengthRule(length: 8), MaxLengthRule(length: 15), FloatRule()]
                $0.autoValidation = autoValidation

            }
            <<< SVSimplePhoneRow("raPhone") {
                $0.title = NSLocalizedString("phone_number_entry_research_assistant_label", comment: "")
                $0.placeholder = NSLocalizedString("phone_number_entry_research_assistant_hint", comment: "")
                $0.customRules = [RequiredRule(), MinLengthRule(length: 8), MaxLengthRule(length: 15), FloatRule()]
                $0.autoValidation = autoValidation

            }
            <<< ButtonRow() {
                $0.title = NSLocalizedString("registration_submit", comment: "")
                }
                .onCellSelection {
                    [unowned self] cell, row in
                    if (self.form.validateAll()) {
                        PKHUD.sharedHUD.dimsBackground = true;
                        PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false;
                        HUD.show(.progress);
                        let formValues = self.form.values();
                        let patientId: String? = formValues["patientId"] as! String?;
                        //let phoneNumber: String? = formValues["phone"] as! String?;
                        let phoneNumber: String? = "NOT_SUPPLIED"
                        let newPassword: String? = formValues["password"] as! String?;
                        let tempPassword: String? = formValues["tempPassword"] as! String?;
                        let clinicianPhone: String? = formValues["clinicianPhone"] as! String?;
                        let raPhone: String? = formValues["raPhone"] as! String?;
                        var customApiUrl: String?;
                        var server: String?
                        if (configServer) {
                            server = formValues["server"] as! String?;
                        }
                        if let server = server {
                            customApiUrl = "https://" + server
                        }
                        if let patientId = patientId, let phoneNumber = phoneNumber, let newPassword = newPassword, let clinicianPhone = clinicianPhone, let raPhone = raPhone {
                            let registerStudyRequest = RegisterStudyRequest(patientId: patientId, phoneNumber: phoneNumber, newPassword: newPassword)
                            
                            // sets tags for Sentry
                            Client.shared?.tags = ["user_id": patientId, "server_url": customApiUrl ?? "Not Registered"]
                            ApiManager.sharedInstance.password = tempPassword ?? "";
                            ApiManager.sharedInstance.patientId = patientId;
                            ApiManager.sharedInstance.customApiUrl = customApiUrl;
                            
                            
                            ApiManager.sharedInstance.makePostRequest(registerStudyRequest).then {
                                (studySettings, _) -> Promise<Study> in
                                // testing three arbitrary response body values to ensure we hit the correct server and not some random server
                                // that happened to return a 200
                                guard studySettings.clientPublicKey != nil, studySettings.wifiLogFrequencySeconds != nil, studySettings.callClinicianButtonEnabled != nil else {
                                    throw RegistrationError.incorrectServer
                                }
                                if (FirebaseApp.app() == nil && studySettings.googleAppID != "") {
                                    AppDelegate.sharedInstance().configureFirebase(studySettings: studySettings)
                                }
                                
                                PersistentPasswordManager.sharedInstance.storePassword(newPassword);
                                ApiManager.sharedInstance.password = newPassword
                                let study = Study(patientPhone: phoneNumber, patientId: patientId, studySettings: studySettings, apiUrl: customApiUrl);
                                study.clinicianPhoneNumber = clinicianPhone
                                study.raPhoneNumber = raPhone
                                if studySettings.fuzzGps {
                                    study.fuzzGpsLatitudeOffset = self._generateLatitudeOffset()
                                    study.fuzzGpsLongitudeOffset = self._generateLongitudeOffset()
                                }
                                return StudyManager.sharedInstance.purgeStudies().then {_ in
                                    return self.db.save(study)
                                }
                            }.then { _ -> Promise<Bool> in
                                let token = Messaging.messaging().fcmToken
                                AppDelegate.sharedInstance().sendFCMToken(fcmToken: token ?? "")
                                HUD.flash(.success, delay: 1);
                                return StudyManager.sharedInstance.loadDefaultStudy();
                            }.done { _ -> Void in
                                AppDelegate.sharedInstance().isLoggedIn = true;
                                if let dismiss = self.dismiss {
                                    dismiss(true);
                                } else {
                                    self.presentingViewController?.dismiss(animated: true, completion: nil);
                                }
                            }.catch { error -> Void in
                                print("error received from register: \(error)");
                                var delay = 2.0;
                                var err: HUDContentType;
                                switch error {
                                case ApiErrors.failedStatus(let code):
                                    switch code {
                                    case 403, 401:
                                        err = .labeledError(title: NSLocalizedString("couldnt_register", comment: ""), subtitle: NSLocalizedString("http_message_403_during_registration", comment: ""));
                                    case 405:
                                        err = .label(NSLocalizedString("http_message_405", comment: ""));
                                        delay = 10.0;
                                    case 400:
                                        err = .label(NSLocalizedString("http_message_400", comment: ""));
                                        delay = 10.0;
                                    default:
                                        err = .label(RegisterViewController.commErr);
                                        delay = RegisterViewController.commErrDelay
                                    }
                                default:
                                    err = .label(RegisterViewController.commErr);
                                    delay = RegisterViewController.commErrDelay
                                }
                                HUD.flash(err, delay: delay)
                            }
                        }
                    } else {
                        print("Bad validation.");
                    }
                }
            <<< ButtonRow() {
                $0.title = NSLocalizedString("cancel_button_text", comment: "");
                }.onCellSelection { [unowned self] cell, row in
                    if let dismiss = self.dismiss {
                        dismiss(false);
                    } else {
                        self.presentingViewController?.dismiss(animated: true, completion: nil);
                    }
        }

        form +++ section

        let passwordRow: SVPasswordRow? = form.rowBy(tag: "password");
        let confirmRow: SVPasswordRow? = form.rowBy(tag: "confirmPassword");
        confirmRow!.customRules = [ConfirmationRule(confirmField: passwordRow!.cell.textField)]



    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    /*
     Generates a random offset between -1 and 1 (thats not between -0.2 and 0.2)
    */
    func _generateLatitudeOffset() -> Double {
        var ran = Double.random(in: -1...1)
        while(ran <= 0.2 && ran >= -0.2) {
            ran = Double.random(in: -1...1)
        }
        return ran
    }
    
    /*
     Generates a random offset between -180 and 180 (thats not between -10 and 10)
    */
    func _generateLongitudeOffset() -> Double {
        var ran = Double.random(in: -180...180)
        while(ran <= 10 && ran >= -10) {
            ran = Double.random(in: -180...180)
        }
        return ran
    }
}
