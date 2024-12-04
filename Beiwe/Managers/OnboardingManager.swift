import Foundation
import ResearchKit

class OnboardingManager: NSObject, ORKTaskViewControllerDelegate {
    var retainSelf: AnyObject?
    var onboardingViewController: ORKTaskViewController!

    // the welcome step has white text when the phone is in dark mode (which looks good) and black text in light mode (which is fine but meh)
    var WelcomeStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: "WelcomeStep")
        // image is commented out since the new ResearchKit distorts the image dimensions
        // it also has a gray background, probably some issue with the alpha
        // instructionStep.image = UIImage(named: "welcome-image")
        instructionStep.title = NSLocalizedString("welcome_screen_title", comment: "")
        instructionStep.text = NSLocalizedString("welcome_screen_body_text", comment: "")
        return instructionStep
    }

    override init() {
        super.init()
        
        // setup steps for registration
        var steps = [ORKStep]()
        steps += [self.WelcomeStep] // defines the first thing to come up to be the welcome screen
        
        // this is the registration step, why it is called WaitForRegister is lost to the mists of time (and it is poorly named)
        steps += [ORKWaitStep(identifier: "WaitForRegister")] // behavior of pressing register is defined here (bumps to register card)
        
        let task = ORKOrderedTask(identifier: "OnboardingTask", steps: steps)
        self.onboardingViewController = ORKTaskViewController(task: task, taskRun: nil)
        self.onboardingViewController.showsProgressInNavigationBar = false
        self.onboardingViewController.delegate = self
        self.retainSelf = self
        
        // THIS IS A UI HACK, IT AFFECTS RegisterViewActivity
        // READ THIS IF YOU ARE GOING TO TRY TO CHANGE THE UI.
        //  This ui is actually a card view, not a full screen view.
        //  We set the parent view's background color to be the same as this card's color
        //    so it looks full screen, and the status bar remains visible.
        
        // "stepViewController.view.backgroundColor = AppColors.Beiwe1" has to go somewhere else
        self.onboardingViewController.view.backgroundColor = AppColors.Beiwe1
        
        // this is the bar that has the cancel button - when we updated to ResearchKit 2.1.0
        // it became white/black depending on dark mode, so now we need to set it explicitly.
        self.onboardingViewController.navigationBar.backgroundColor = AppColors.Beiwe1
        
        // We can't trivially get rid of the cancel button on the card behind the registration card,
        // because if you dismiss it the user has no way to get back to registration....
        // (can't currently work out how to block dismissing it, its not very important but this
        // does make the app feel a little cheap when you fat-finger and dismiss it.  🫠)
        
        // self.onboardingViewController.view.tintColor = UIColor.white // nope doesn't force text to be white
        // self.onboardingViewController.discardable = false  // doesn't appear to do anything with true or false
    }

    // called when the onboarding view is done.
    func closeOnboarding() {
        AppDelegate.sharedInstance().transitionToLoadedAppState()
        self.retainSelf = nil
    }
    
    /* ORK Delegates */
    /// these 4 taskViewController functions are called in this order on application load when there is no study registration,
    /// and when the registration views update (like when the welcome screen's register button is pressed or when the registration page cancel button is pressed)
    // 1
    func taskViewController(_ taskViewController: ORKTaskViewController, shouldPresent step: ORKStep) -> Bool {
        return true
    }

    // 2
    func taskViewController(_ taskViewController: ORKTaskViewController, viewControllerFor step: ORKStep) -> ORKStepViewController? {
        return nil
    }

    // 3
    func taskViewController(_ taskViewController: ORKTaskViewController, hasLearnMoreFor step: ORKStep) -> Bool {
        switch step.identifier {
        case "SecondStep":
            return true
        default: return false
        }
    }

    // 4
    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        // the other half of the ui hack to make it appear to be a full screen singular color
        stepViewController.view.backgroundColor = AppColors.Beiwe1
        
        // determines which page to display, welcome or registration. (I don't understand the high-level pattern here, this is weird and overly complex)
        if let identifier = stepViewController.step?.identifier {
            switch identifier {
            case "WelcomeStep":
                stepViewController.cancelButtonItem = nil
                // the text of the register button (it says "Register")
                stepViewController.continueButtonTitle = NSLocalizedString("welcome_screen_go_to_registration_button_text", comment: "")
            case "WaitForRegister":
                let registerViewController = RegisterViewController()
                registerViewController.dismiss = { [unowned self] didRegister in
                    self.onboardingViewController.dismiss(animated: true, completion: nil)
                    if !didRegister {
                        self.onboardingViewController.goBackward()
                    } else {
                        // They did register, so if we close this onboarding, it should restart up
                        // with the consent form.
                        self.closeOnboarding()
                    }
                }
                self.onboardingViewController.present(registerViewController, animated: true, completion: nil)
            default: break
            }
        }
        
        // this has no effect on the welcome view
        // if (stepViewController.step?.identifier == "login") {
        //      stepViewController.cancelButtonItem = nil
        // }
        
        // set the text of the register button (it already says "Register")
        // stepViewController.continueButtonTitle = "Go!"
    }
    
    // unknown functions, don't seem to be called
    func taskViewController(_ taskViewController: ORKTaskViewController, didChange result: ORKTaskResult) {
        // print("func taskViewController unused 1")
    }
    
    func taskViewController(_ taskViewController: ORKTaskViewController, learnMoreForStep stepViewController: ORKStepViewController) {
        // print("func taskViewController unused 2")
        // this appears to be entirely junk with no effect, its repeated elsewhere in the codebase. maybe its some template code from somewhere?
        // Present modal...
        // let refreshAlert = UIAlertController(title: "Learning more!", message: "You're smart now", preferredStyle: UIAlertController.Style.alert)
        // refreshAlert.addAction(UIAlertAction(title: NSLocalizedString("ok_button_text", comment: ""), style: .default, handler: { (_: UIAlertAction!) in }))
        // self.onboardingViewController.present(refreshAlert, animated: true, completion: nil)
    }
    
    // does not appear to be called
    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        // print("func taskViewController 0")
        // Handle results with taskViewController.result
        // taskViewController.dismissViewControllerAnimated(true, completion: nil)
        self.closeOnboarding()
        log.info("Onboarding closed")
    }
}
