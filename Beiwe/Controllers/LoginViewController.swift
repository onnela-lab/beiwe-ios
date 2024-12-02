import PKHUD
import ResearchKit
import UIKit
import FirebaseMessaging

class LoginViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var callClinicianButton: UIButton!
    @IBOutlet weak var loginButton: BWBorderedButton!
    @IBOutlet weak var password: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.presentTransparentNavigationBar()

        var clinicianText: String
        clinicianText = StudyManager.sharedInstance.currentStudy?.studySettings?.callClinicianText ?? NSLocalizedString("default_call_clinician_text", comment: "")
        self.callClinicianButton.setTitle(clinicianText, for: UIControl.State())
        self.callClinicianButton.setTitle(clinicianText, for: UIControl.State.highlighted)
        if #available(iOS 9.0, *) {
            callClinicianButton.setTitle(clinicianText, for: UIControl.State.focused)
        }
        // Hide call button if it's disabled in the study settings
        if !(StudyManager.sharedInstance.currentStudy?.studySettings?.callClinicianButtonEnabled)! {
            self.callClinicianButton.isHidden = true
        }

        self.password.delegate = self
        self.loginButton.isEnabled = false
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.tap))
        view.addGestureRecognizer(tapGesture)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        log.warning("didReceiveMemoryWarning")
    }
    
    /// the login button
    @IBAction func loginPressed(_ sender: AnyObject) {
        password.resignFirstResponder()
        PKHUD.sharedHUD.dimsBackground = true
        PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false

        if let password = password.text, password.count > 0 {
            // register for notifications (for some reason) and log in
            if AppDelegate.sharedInstance().checkPasswordAndLogin(password) {
                // This animation has to go after transitionToLoadedAppState and put in a DispatchQueue.main.async otherwise it gets cut off.
                // This cutting off appears to be caused by adding the DispatchQueue.main.async in changeRootViewController.
                // These combined might cause the animation to be delayed slightly, it is hard to tell.
                AppDelegate.sharedInstance().transitionToLoadedAppState()
                DispatchQueue.main.async {
                    HUD.flash(.success, delay: 0) // this is the checkbox thingy that flashes on the screen
                }
                
                // includes a network call and used to block login? what? moved this after the animation and transition code
                AppDelegate.sharedInstance().checkFirebaseCredentials()
                if let token: String = Messaging.messaging().fcmToken {
                    AppDelegate.sharedInstance().sendFCMToken(fcmToken: token)
                }
            } else {
                HUD.flash(.error, delay: 1) // the X box thingy. Don't know what the delay does.
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.loginPressed(self)
        textField.resignFirstResponder()
        return true
    }

    @objc func tap(_ gesture: UITapGestureRecognizer) {
        self.password.resignFirstResponder()
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Find out what the text field will be after adding the current edit
        if let text = (password.text as NSString?)?.replacingCharacters(in: range, with: string) {
            if !text.isEmpty { // Checking if the input field is not empty
                self.loginButton.isEnabled = true // Enabling the button
            } else {
                self.loginButton.isEnabled = false // Disabling the button
            }
        }

        // Return true so the text field will be changed
        return true
    }
    
    /// some overridden class method afaik
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    /// reset password button
    @IBAction func forgotPassword(_ sender: AnyObject) {
        let vc = ChangePasswordViewController()
        vc.isForgotPassword = true
        vc.finished = { (_: Bool) in
            self.dismiss(animated: true, completion: nil)
        }
        present(vc, animated: true, completion: nil)
    }

    /// call clinician button
    @IBAction func callClinician(_ sender: AnyObject) {
        confirmAndCallClinician(self)
    }
}
