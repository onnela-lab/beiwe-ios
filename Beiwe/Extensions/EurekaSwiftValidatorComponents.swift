//
//  EurekaSwiftValidatorComponents.swift
//  Examples
//
//  Created by Demetrio Filocamo on 12/03/2016.
//  Copyright © 2016 Novaware Ltd. All rights reserved.
//
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// Fixes & Modifications by Keary Griffin, RocketFarmStudios

import Eureka
import ObjectiveC
import SwiftValidator

open class _SVFieldCell<T>: _FieldCell<T> where T: Equatable, T: InputTypeInitiable {
    public required init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

//    required public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
//        fatalError("init(style:reuseIdentifier:) has not been implemented")
//    }

    open lazy var validationLabel: UILabel = {
        [unowned self] in
        let validationLabel = UILabel()
        validationLabel.translatesAutoresizingMaskIntoConstraints = false
        validationLabel.font = validationLabel.font.withSize(10.0)
        return validationLabel
    }()

    override open func setup() {
        super.setup()
        textField.autocorrectionType = .default
        textField.autocapitalizationType = .sentences
        textField.keyboardType = .default

        self.height = {
            60
        }
        contentView.addSubview(self.validationLabel)

        let sameLeading: NSLayoutConstraint = NSLayoutConstraint(item: self.contentView, attribute: .leading, relatedBy: .equal, toItem: self.validationLabel, attribute: .leading, multiplier: 1, constant: -20)
        let sameTrailing: NSLayoutConstraint = NSLayoutConstraint(item: self.textField, attribute: .trailing, relatedBy: .equal, toItem: self.validationLabel, attribute: .trailing, multiplier: 1, constant: 0)
        let sameBottom: NSLayoutConstraint = NSLayoutConstraint(item: self.contentView, attribute: .bottom, relatedBy: .equal, toItem: self.validationLabel, attribute: .bottom, multiplier: 1, constant: 4)
        let all: [NSLayoutConstraint] = [sameLeading, sameTrailing, sameBottom]

        contentView.addConstraints(all)

        self.validationLabel.textAlignment = NSTextAlignment.right
        self.validationLabel.adjustsFontSizeToFitWidth = true
        self.resetField()
    }

    func setRules(_ rules: [Rule]?) {
        self.rules = rules
    }

    override open func textFieldDidChange(_ textField: UITextField) {
        super.textFieldDidChange(textField)

        if self.autoValidation {
            self.validate()
        }
    }

    // MARK: - Validation management

    func validate() {
        if let v = self.validator {
            // Registering the rules
            if !self.rulesRegistered {
                v.unregisterField(textField) //  in case the method has already been called
                if let r = rules {
                    v.registerField(textField, errorLabel: self.validationLabel, rules: r)
                }
                self.rulesRegistered = true
            }

            self.valid = true

            v.validate({
                errors in
                self.resetField()
                for (field, error) in errors {
                    self.valid = false
                    self.showError(field as! UITextField, error: error)
                }
            })
        } else {
            self.valid = false
        }
    }

    func resetField() {
        self.validationLabel.isHidden = true
        textField.textColor = UIColor.black
        // textLabel?.textColor = UIColor.blackColor();
    }

    func showError(_ field: UITextField, error: SwiftValidator.ValidationError) {
        // turn the field to red
        field.textColor = self.errorColor
        /*
         if let ph = field.placeholder {
             let str = NSAttributedString(string: ph, attributes: [NSForegroundColorAttributeName: errorColor])
             field.attributedPlaceholder = str
         }
         */
        // self.textLabel?.textColor = errorColor
        self.validationLabel.textColor = self.errorColor
        error.errorLabel?.text = error.errorMessage // works if you added labels
        error.errorLabel?.isHidden = false
    }

    var validator: Validator? {
        if let fvc = formViewController() {
            return fvc.form.validator
        }
        return nil
    }

    var errorColor: UIColor = UIColor.red
    var autoValidation = true
    var rules: [Rule]?

    fileprivate var rulesRegistered = false
    var valid = false
}

public protocol SVRow {
    var errorColor: UIColor { get set }

    var customRules: [Rule]? { get set }

    var autoValidation: Bool { get set }

    var valid: Bool { get }

    func validate()
}

open class _SVTextRow<Cell: _SVFieldCell<String>>: FieldRow<Cell>, SVRow where Cell: BaseCell, Cell: CellType, Cell: TextFieldCell, Cell.Value == String {
    public required init(tag: String?) {
        super.init(tag: tag)
    }

    open var errorColor: UIColor {
        get {
            return self.cell.errorColor
        }
        set {
            self.cell.errorColor = newValue
        }
    }

    open var customRules: [Rule]? {
        get {
            return self.cell.rules
        }
        set {
            self.cell.setRules(newValue)
        }
    }

    open var autoValidation: Bool {
        get {
            return self.cell.autoValidation
        }
        set {
            self.cell.autoValidation = newValue
        }
    }

    open var valid: Bool {
        return self.cell.valid
    }

    open func validate() {
        self.cell.validate()
    }
}

open class SVTextCell: _SVFieldCell<String>, CellType {
    public required init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override open func setup() {
        super.setup()
        textField.autocorrectionType = .default
        textField.autocapitalizationType = .sentences
        textField.keyboardType = .default
    }
}

open class SVAccountCell: SVTextCell {
    override open func setup() {
        super.setup()
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .asciiCapable
    }
}

open class SVPhoneCell: SVTextCell {
    override open func setup() {
        super.setup()
        textField.keyboardType = .phonePad
    }
}

open class SVSimplePhoneCell: SVTextCell {
    override open func setup() {
        super.setup()
        textField.keyboardType = .numberPad
    }
}

open class SVNameCell: SVTextCell {
    override open func setup() {
        super.setup()
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .words
        textField.keyboardType = .asciiCapable
    }
}

open class SVEmailCell: SVTextCell {
    override open func setup() {
        super.setup()
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .emailAddress
    }
}

open class SVPasswordCell: SVTextCell {
    override open func setup() {
        super.setup()
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .asciiCapable
        textField.isSecureTextEntry = true
    }
}

open class SVURLCell: SVTextCell {
    override open func setup() {
        super.setup()
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = .URL
    }
}

open class SVZipCodeCell: SVTextCell {
    override open func setup() {
        super.setup()
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .allCharacters
        textField.keyboardType = .numbersAndPunctuation
    }
}

extension Form {
    fileprivate struct AssociatedKey {
        static var validator: UInt8 = 0
        static var dataValid: UInt8 = 0
    }

    var validator: Validator {
        get {
            if let validator = objc_getAssociatedObject(self, &AssociatedKey.validator) {
                return validator as! Validator
            } else {
                let v = Validator()
                self.validator = v
                return v
            }
        }

        set {
            objc_setAssociatedObject(self, &AssociatedKey.validator, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var dataValid: Bool {
        get {
            if let dv = objc_getAssociatedObject(self, &AssociatedKey.dataValid) {
                return dv as! Bool
            } else {
                let dv = false
                self.dataValid = dv
                return dv
            }
        }

        set {
            objc_setAssociatedObject(self, &AssociatedKey.dataValid, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func validateAll() -> Bool {
        self.dataValid = true

        let rows = allRows
        for row in rows {
            if row is SVRow {
                var svRow = (row as! SVRow)
                svRow.validate()
                let rowValid = svRow.valid
                svRow.autoValidation = true // from now on autovalidation is enabled
                if !rowValid && self.dataValid {
                    self.dataValid = false
                }
            }
        }
        return self.dataValid
    }
}

/// A String valued row where the user can enter arbitrary text.

public final class SVTextRow: _SVTextRow<SVTextCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVAccountRow: _SVTextRow<SVAccountCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVPhoneRow: _SVTextRow<SVPhoneCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVSimplePhoneRow: _SVTextRow<SVSimplePhoneCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVNameRow: _SVTextRow<SVNameCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVEmailRow: _SVTextRow<SVEmailCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVPasswordRow: _SVTextRow<SVPasswordCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVURLRow: _SVTextRow<SVURLCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

public final class SVZipCodeRow: _SVTextRow<SVZipCodeCell>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

// TODO: add more
