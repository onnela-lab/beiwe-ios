import Foundation
import ResearchKit

class BWORKTaskViewController: ORKTaskViewController {
    var displayDiscard = true
    
    // Doesn't exist on this class despite being a UIViewController? maybe?
    // @objc override func preferredStatusBarStyle() -> UIStatusBarStyle {
    //     return UIStatusBarStyle.LightContent
    // }

    @objc override func presentCancelOptions(_ saveable: Bool, sender: UIBarButtonItem?) {
        // print("inside BWORKTaskViewController.presentCancelOptions()")
        super.presentCancelOptions(self.displayDiscard ? saveable : false, sender: sender)
    }
}
