import EmitterKit
import Hakuba
import ResearchKit
import Sentry
import UIKit
import XLActionController

class MainViewController: UIViewController {
    // infrastructure
    var listeners: [Listener] = [] // Listeners are part of EmitterKit
    var hakuba: Hakuba!
    
    // a selected survey
    var selectedSurvey: ActiveSurvey?
    
    // labels and buttons
    @IBOutlet weak var haveAQuestionLabel: UILabel!
    @IBOutlet weak var callClinicianButton: UIButton!
    @IBOutlet weak var footerSeperator: UIView!
    @IBOutlet weak var surveyTableView: UITableView!
    @IBOutlet var activeSurveyHeader: UIView!
    @IBOutlet var emptySurveyHeader: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.presentTransparentNavigationBar()
        
        // ic-user is the outline of a person in the upper left corner.
        let leftImage: UIImage? = UIImage(named: "user-settings")!.withRenderingMode(.alwaysOriginal)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: leftImage, style: UIBarButtonItem.Style.plain, target: self, action: #selector(self.userButton)
        )
        let rightImage: UIImage? = UIImage(named: "ic-info")!.withRenderingMode(.alwaysOriginal)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: rightImage, style: UIBarButtonItem.Style.plain, target: self, action: #selector(self.infoButton)
        )
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationItem.rightBarButtonItem = nil

        // Do any additional setup after loading the view.
        // set up the survey table view
        self.hakuba = Hakuba(tableView: self.surveyTableView)
        self.surveyTableView.backgroundView = nil
        self.surveyTableView.backgroundColor = UIColor.clear
        // hakuba.registerCell(SurveyCell)

        var clinicianText: String = (
            StudyManager.sharedInstance.currentStudy?.studySettings?.callClinicianText ?? NSLocalizedString("default_call_clinician_text", comment: "")
        )
        self.callClinicianButton.setTitle(clinicianText, for: UIControl.State())
        self.callClinicianButton.setTitle(clinicianText, for: UIControl.State.highlighted)
        self.callClinicianButton.setTitle(clinicianText, for: UIControl.State.focused)

        // Hide call button if it's disabled in the study settings
        if !(StudyManager.sharedInstance.currentStudy?.studySettings?.callClinicianButtonEnabled)! {
            self.haveAQuestionLabel.isHidden = true
            self.callClinicianButton.isHidden = true
        }
        
        // add the surveysUpdatedEvent to the listeners
        self.listeners += StudyManager.sharedInstance.surveysUpdatedEvent.on { [weak self] data in
            self?.refreshSurveys()
        }
        
        // if AppDelegate.sharedInstance().debugEnabled {
        //     self.addDebugMenu()
        // }
        // refresh surveys as last step of view load
        self.refreshSurveys()
    }

    /// updates the ui list of surveys
    func refreshSurveys() {
        // clean out the current list, add a new empty section at the beginning
        self.hakuba.removeAll()
        self.hakuba.insert(Section(), atIndex: 0).bump()

        var active_survey_count = 0
        if let activeSurveys = StudyManager.sharedInstance.currentStudy?.activeSurveys {
            // sort surveys by the time that they were received by the app (I think)
            let sortedSurveys = activeSurveys.sorted { s1, s2 -> Bool in
                s1.1.received > s2.1.received
            }
            
            // because surveys do not have their state cleared when the done button is pressed, the buttons retain
            // the incomplete label and tapping on a finished always available survey results in loading to the "done" buttton on that survey.
            // (and creating a new file. see comments in StudyManager.swift for ~explination of this behavior.)
            for (_, active_survey) in sortedSurveys {
                // get every incomplete or always available survey to, att it as a SurveyCellModel to the hakuba table view.
                if !active_survey.isComplete || active_survey.survey?.alwaysAvailable ?? false {
                    let cellmodel = SurveyCellModel(activeSurvey: active_survey) { [weak self] (cell: Cell) in
                        cell.isSelected = false
                        if let strongSelf = self, let surveyCell = cell as? SurveyCell, let surveyId = surveyCell.cellmodel?.activeSurvey.survey?.surveyId {
                            strongSelf.presentSurvey(surveyId)
                        }
                    }
                    self.hakuba[0].append(cellmodel)
                    active_survey_count += 1
                }
            }
            // animation to updates display of list of surveys (of the cell element)
            // self.hakuba[0].bump(.fade) // this causes ui glitches
        }
        
        self.hakuba.bump(.fade) // this applies the animation to the list (hakuba section?) as a whole
        
        // set the scrollability based on active_survey_count of surveys, set header.
        // emptySurveyHeader is the box with the string "there are no active surveys to take at this time"
        if active_survey_count > 0 {
            self.footerSeperator.isHidden = false
            self.surveyTableView.tableHeaderView = self.activeSurveyHeader
            self.surveyTableView.isScrollEnabled = true
        } else {
            self.footerSeperator.isHidden = true
            self.surveyTableView.tableHeaderView = self.emptySurveyHeader
            self.surveyTableView.isScrollEnabled = false
        }
    }
    
    func presentSurvey(_ surveyId: String) {
        // confirm everything necessary is present for the survey button to work
        guard let activeSurvey = StudyManager.sharedInstance.currentStudy?.activeSurveys[surveyId],
              let survey = activeSurvey.survey,
              let surveyType = survey.surveyType
        else {
            return
        }

        switch surveyType {
        case .TrackingSurvey:
            TrackingSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey).present(self)
        case .AudioSurvey:
            self.selectedSurvey = activeSurvey
            performSegue(withIdentifier: "audioQuestionSegue", sender: self)
            // AudioSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey).present(self);
        }
    }

    /// This is the menu in the upper left of the main screen
    @objc func userButton() {
        // create the primary action controller
        let actionController = BWXLActionController()
        actionController.settings.cancelView.backgroundColor = AppColors.Beiwe3
        actionController.headerData = nil // no obvious effect
        actionController.addAction(
            Action(ActionData(title: NSLocalizedString("change_password_button", comment: "")), style: .default) { _action in
                DispatchQueue.main.async {
                    self.changePassword(self)
                }
            }
        )

        // Only add Call button if it's enabled by the study
        if (StudyManager.sharedInstance.currentStudy?.studySettings?.callResearchAssistantButtonEnabled)! {
            actionController.addAction(Action(ActionData(title: NSLocalizedString("call_research_assistant_button", comment: "")), style: .default) { _action in
                DispatchQueue.main.async {
                    confirmAndCallClinician(self, callAssistant: true)
                }
            })
        }
        // logout
        actionController.addAction(Action(ActionData(title: NSLocalizedString("logout_button", comment: "")), style: .default) { _action in
            DispatchQueue.main.async {
                self.logout(self)
            }
        })
        // leave study - disabled as of 2024-1-24
        // actionController.addAction(Action(ActionData(title: NSLocalizedString("unregister_button", comment: "")), style: .destructive) { _action in
        //     DispatchQueue.main.async {
        //         self.leaveStudy(self)
        //     }
        // })
        present(actionController, animated: true)
    }

    ///
    /// User Menu actions
    ///
    
    @IBAction func callClinician(_ sender: AnyObject) {
        confirmAndCallClinician(self) // Present modal...
    }

    @IBAction func changePassword(_ sender: AnyObject) {
        // this shares code with the forgot password action on the login screen.
        let changePasswordController = ChangePasswordViewController()
        changePasswordController.isForgotPassword = false
        present(changePasswordController, animated: true, completion: nil)
    }

    @IBAction func logout(_ sender: AnyObject) {
        AppDelegate.sharedInstance().isLoggedIn = false
        AppDelegate.sharedInstance().transitionToLoadedAppState()
    }

    // Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "audioQuestionSegue" {
            let questionController: AudioQuestionViewController = segue.destination as! AudioQuestionViewController
            questionController.activeSurvey = self.selectedSurvey
        }
    }
    
    ///
    /// Literally junk
    ///
    
    @objc func infoButton() {}
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////// Debug Menu ////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // func addDebugMenu() {
    //     // adds a debug command? (Keary never told us about this.)
    //     print("adding debugtap")
    //     let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.debugTap))
    //     tapRecognizer.numberOfTapsRequired = 2
    //     tapRecognizer.numberOfTouchesRequired = 2
    //     view.addGestureRecognizer(tapRecognizer)
    // }
    //
    // // hey the debug button! I don't think its bound to anything.
    // @objc func debugTap(_ gestureRecognizer: UIGestureRecognizer) {
    //     print("debugtap!")
    //     if gestureRecognizer.state != .ended {
    //         print("return debug tap doing nothing")
    //         return
    //     }
    //
    //     self.refreshSurveys()
    //
    //     let actionController = BWXLActionController()
    //     actionController.settings.cancelView.backgroundColor = AppColors.highlightColor
    //
    //     actionController.headerData = nil
    //
    //     actionController.addAction(Action(ActionData(title: NSLocalizedString("upload_data_button", comment: "")), style: .default) { _action in
    //         DispatchQueue.main.async {
    //             self.Upload(self)
    //         }
    //     })
    //     actionController.addAction(Action(ActionData(title: NSLocalizedString("check_for_surveys_button", comment: "")), style: .default) { _action in
    //         DispatchQueue.main.async {
    //             self.checkSurveys(self)
    //         }
    //     })
    //
    //     present(actionController, animated: true) {}
    // }
    //
    // @IBAction func Upload(_ sender: AnyObject) {
    //     StudyManager.sharedInstance.upload(false)
    // }
    //
    // @IBAction func checkSurveys(_ sender: AnyObject) {
    //     StudyManager.sharedInstance.checkSurveys()
    // }
    
    ///
    /// Leave study funcitonality - disabled as of 2024-1-24
    ///
    // leave study menu option
    // @IBAction func leaveStudy(_ sender: AnyObject) {
    //     let alertController = UIAlertController(
    //         title: NSLocalizedString("unregister_alert_title", comment: ""),
    //         message: NSLocalizedString("unregister_alert_text", comment: ""),
    //         preferredStyle: .alert
    //     )
    //
    //     let cancelAction = UIAlertAction(title: NSLocalizedString("cancel_button_text", comment: ""), style: .cancel) { _ in }
    //     alertController.addAction(cancelAction)
    //
    //     let OKAction = UIAlertAction(title: NSLocalizedString("ok_button_text", comment: ""), style: .default) { _ in
    //         StudyManager.sharedInstance.leaveStudy().done { _ in
    //             AppDelegate.sharedInstance().isLoggedIn = false
    //             AppDelegate.sharedInstance().transitionToLoadedAppState()
    //         }
    //     }
    //     alertController.addAction(OKAction)
    //
    //     present(alertController, animated: true) {}
    // }
}
