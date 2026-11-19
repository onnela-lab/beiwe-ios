import Alamofire
import Eureka
import PKHUD
import SwiftValidator
import UIKit

/// This class is used in two places, the forgot password menu (on the login page), and the logged in change password (user menu option)
class ChangePasswordViewController: FormViewController {
    let autoValidation = false
    var isForgotPassword = false // flag determines whether this is the forgot password or change password use-case
    
    let error_label_invalid_old_password: HUDContentType = .labeledError(
        title: NSLocalizedString("reset_password_error_alert_title", comment: ""),
        subtitle: NSLocalizedString("invalid_old_password", comment: "")
    )
    let error_label_reset_password_communication_error: HUDContentType = .labeledError(
        title: NSLocalizedString("reset_password_error_alert_title", comment: ""),
        subtitle: NSLocalizedString("reset_password_communication_error", comment: "")
    )
    let fake_hud_error: HUDContentType = .labeledError(title: "", subtitle: "")
    
    // I literally have no idea what this is or was intended to be, its usage makes no sense.
    // TODO: test thoroughly, there is some dismiss behavior that it gates? I guess?
    var finished: ((_ changed: Bool) -> Void)?
    
    var the_proposed_password: String? // this is not used
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // self.view = GradientView() // This doesn't work at all
        tableView?.backgroundColor = AppColors.Beiwe1
        
        // create the "form" (menu option) elements
        form +++ Section { section in
            if self.isForgotPassword {
                // populate
                var header = HeaderFooterView<ForgotPasswordHeaderView>(.nibFile(name: "ForgotPasswordHeaderView", bundle: nil))
                header.onSetupView = { (headerView: ForgotPasswordHeaderView, _: Section) in
                    // headerView.patientId - is offset vertically (down) by about 2/3rds of a line
                    // height and and I can't work out how to fix it
                    // headerView.patientId.text = StudyManager.sharedInstance.currentStudy?.patientId ?? ""
                    headerView.patientId2.text = "Patient ID: " +
                        (StudyManager.sharedInstance.currentStudy?.patientId ?? "")

                    // add the call button, but hide it if it's disabled in the study settings
                    headerView.callButton.addTarget(self, action: #selector(ChangePasswordViewController.callAssistant(_:)), for: UIControl.Event.touchUpInside)
                    if !(StudyManager.sharedInstance.currentStudy?.studySettings?.callResearchAssistantButtonEnabled)! {
                        headerView.descriptionLabel.text = NSLocalizedString("forgot_password_title", comment: "")
                        headerView.callButton.isHidden = true
                    }
                }
                section.header = header
            } else {
                // sets the ~title to "CHANGE PASSWOORD" for the logged-in change password, but its like gray
                section.header = HeaderFooterView(stringLiteral: NSLocalizedString("title_activity_reset_password", comment: ""))
            }
        }
        
            // these are the cells (buttons) in the menu
            // temporary / current password field
            <<< SVPasswordRow("currentPassword") {
                $0.title = isForgotPassword ? NSLocalizedString("forgot_password_temporary_password_caption", comment: "") : NSLocalizedString("reset_password_current_password_caption", comment: "")
                let placeholder: String = String($0.title!.lowercased().dropLast())
                $0.placeholder = placeholder
                $0.customRules = [RequiredRule()]
                $0.autoValidation = autoValidation
                $0.cell.backgroundColor = AppColors.Beiwe1
                $0.cell.tintColor = UIColor.white // sets the text color
            }
            // new password field
            <<< SVPasswordRow("password") {
                $0.title = NSLocalizedString("reset_password_new_password_caption", comment: "")
                $0.placeholder = NSLocalizedString("reset_password_new_password_hint", comment: "")
                $0.customRules = [RequiredRule(), RegexRule(regex: Constants.passwordRequirementRegex, message: Constants.passwordRequirementDescription)]
                $0.autoValidation = autoValidation
                $0.cell.backgroundColor = AppColors.Beiwe1
                $0.cell.tintColor = UIColor.white
            }
            // new password again field
            <<< SVPasswordRow("confirmPassword") {
                $0.title = NSLocalizedString("reset_password_confirm_new_password_caption", comment: "")
                $0.placeholder = NSLocalizedString("reset_password_confirm_new_password_hint", comment: "")
                $0.customRules = [RequiredRule(), MinLengthRule(length: 1)]
                $0.autoValidation = autoValidation
                $0.cell.backgroundColor = AppColors.Beiwe1
                $0.cell.tintColor = UIColor.white
            }
            // submit button
            <<< ButtonRow {
                $0.title = NSLocalizedString("reset_password_submit", comment: "")
                $0.cell.backgroundColor = AppColors.Beiwe2 // set a darker color on the submit and cancel buttons
                $0.cell.tintColor = UIColor.cyan // and a different text color for distinction
            }
            // the code for doing a password reset, contacting the server etc., calls do_password_reset_request
            .onCellSelection { [unowned self] (cell: ButtonCellOf<String>, row: ButtonRow) in
                if self.form.validateAll() {
                    // ui lock etc
                    PKHUD.sharedHUD.dimsBackground = true
                    PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false
                    HUD.show(.progress)
                    
                    // get the values
                    let formValues = self.form.values()
                    let newPassword: String? = formValues["password"] as! String?
                    let currentPassword: String? = formValues["currentPassword"] as! String?
                    
                    // do the request
                    if let newPassword = newPassword, let currentPassword = currentPassword {
                        do_password_reset_request(newPassword: newPassword, currentPassword: currentPassword)
                    }
                } else {
                    // print("Bad validation.")
                }
            } // end submit button (have I mentioned this is terrible factoring?)
            
            // The Cancel button
            <<< ButtonRow {
                $0.title = NSLocalizedString("cancel_button_text", comment: "")
                $0.cell.backgroundColor = AppColors.Beiwe2
                $0.cell.tintColor = UIColor.cyan
            }.onCellSelection { [unowned self] (cell: ButtonCellOf<String>, row: ButtonRow) in
                self.presentingViewController?.dismiss(animated: true, completion: nil)
            }
        
        // I guess this is some kind of configuration of the confirmation field that has to be assigned/set up outside the active code.
        let passwordRow: SVPasswordRow? = form.rowBy(tag: "password")
        let confirmRow: SVPasswordRow? = form.rowBy(tag: "confirmPassword")
        confirmRow!.customRules = [ConfirmationRule(confirmField: passwordRow!.cell.textField)]
    }

    func do_password_reset_request(newPassword: String, currentPassword: String) {
        self.the_proposed_password = newPassword
        let changePasswordRequest = ChangePasswordRequest(newPassword: newPassword)
        ApiManager.sharedInstance.makePostRequest(changePasswordRequest, password: currentPassword, completion_handler: self.reset_password_callback)
    }
    
    func reset_password_callback(response: DataResponse<String>) {
        guard let the_proposed_password = self.the_proposed_password else {
            log.error("self.the_proposed_password is nil")
            fatalError("self.the_proposed_password is nil")
        }
        self.the_proposed_password = nil // immediately clear
        
        // populate these
        var error_message = "" // for a debug print statement
        var hud_error_message: HUDContentType // for ui display

        switch response.result {
        case .success:
            if let statusCode = response.response?.statusCode {
                // real success, 200 class status codes
                if statusCode >= 200 && statusCode < 300 {
                    hud_error_message = self.fake_hud_error
                }
                // rejected errors (400 class)
                else if statusCode == 403 || statusCode == 401 {
                    hud_error_message = self.error_label_invalid_old_password
                }
                // all other status codes
                else {
                    hud_error_message = self.error_label_reset_password_communication_error
                    error_message = "password reset: \(response) , statuscode: \(statusCode), value/body: \(String(describing: response.result.value))"
                }
            } else {
                // no status code
                hud_error_message = self.error_label_reset_password_communication_error
                error_message = "password reset: \(response) - no status code?"
            }
        case .failure:
            // general failure
            hud_error_message = self.error_label_reset_password_communication_error
            error_message = "password reset: \(response) - error: \(String(describing: response.error))"
        }
        
        // error message will be an empty string if there were no errors.
        if error_message == "" {
            PersistentPasswordManager.sharedInstance.storePassword(the_proposed_password)
            
            // ui runs on main thread
            DispatchQueue.main.async {
                HUD.flash(.success, delay: 2)
                self.presentingViewController?.dismiss(animated: true, completion: nil)
            }
        } else {
            log.error(error_message)
            DispatchQueue.main.async {
                // xcode/swift will yell at you if you've missed cases and hud_error_message is null.
                // (comment out `hud_error_message = fake_hud_error` to test)
                HUD.flash(hud_error_message, delay: 2.0)
            }
        }
    }
    
    // waring
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning() // Dispose of any resources that can be recreated.
    }

    @objc func callAssistant(_ sender: UIButton!) {
        confirmAndCallClinician(self, callAssistant: true)
    }
    
    /* MARK: - Navigation
     In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
         Get the new view controller using segue.destinationViewController.
         Pass the selected object to the new view controller.
     }*/
}
