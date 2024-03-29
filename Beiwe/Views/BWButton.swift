import Foundation
import UIKit

class BWButton: UIButton {
    let fadeDelay = 0.0
    override var isSelected: Bool {
        didSet {
            updateBorderColor()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            updateBorderColor()
        }
    }

    override var isEnabled: Bool {
        didSet {
            updateBorderColor()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setTitleColor(UIColor.white, for: UIControl.State())
        self.setTitleColor(UIColor.white, for: UIControl.State.selected)
        self.setTitleColor(UIColor.white, for: UIControl.State.highlighted)

        self.setTitleColor(UIColor.darkGray, for: UIControl.State.disabled)
        self.layer.borderWidth = 1
        self.layer.cornerRadius = 5
        self.layer.masksToBounds = true
        self.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        self.updateBorderColor()
    }

    func fadeHighlightOrSelectColor() {
        // Ignore if it's a race condition
        if self.isEnabled && !(self.isHighlighted || self.isSelected) {
            self.backgroundColor = UIColor.clear
            self.layer.borderColor = UIColor.white.cgColor
        }
    }

    func updateBorderColor() {
        if self.isEnabled && (self.isHighlighted || self.isSelected) {
            self.backgroundColor = AppColors.highlightColor
            self.layer.borderColor = AppColors.highlightColor.cgColor
        } else if self.isEnabled && !(self.isHighlighted || self.isSelected) {
            if self.fadeDelay > 0 {
                let delayTime = DispatchTime.now() + Double(Int64(self.fadeDelay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: delayTime) {
                    self.fadeHighlightOrSelectColor()
                }
            } else {
                self.fadeHighlightOrSelectColor()
            }
        } else {
            self.backgroundColor = UIColor.clear
            self.layer.borderColor = UIColor.darkGray.cgColor
        }
    }
}
