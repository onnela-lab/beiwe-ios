import ObjectMapper

// all the question types for a survey
enum SurveyQuestionType: String {
    case InformationText = "info_text_box"
    case Slider = "slider"
    case RadioButton = "radio_button"
    case Checkbox = "checkbox"
    case FreeResponse = "free_response"
    case Date = "date"
    case Time = "time"
    case DateTime = "date_time"
}

// all the entry field types for a survey
enum TextFieldType: String {
    case SingleLine = "SINGLE_LINE_TEXT"
    case MultiLine = "MULTI_LINE_TEXT"
    case Numeric = "NUMERIC"
}

// mappable (json-backed database object) of a question
struct GenericSurveyQuestion: Mappable, Equatable {
    
    var questionId = ""
    var prompt: String?
    var questionType: SurveyQuestionType? // unclear why this is optional...
    var maxValue: Int?
    var minValue: Int?
    var selectionValues: [OneSelection] = []
    var textFieldType: TextFieldType?
    var displayIf: [String: AnyObject]? // AnyObject looks like it can be a string, int, or nsarray
    var required = false
    
    init?(map: Map) {}

    // Mappable
    mutating func mapping(map: Map) {
        self.questionId <- map["question_id"]
        self.prompt <- map["prompt"]
        self.prompt <- map["question_text"]
        self.questionType <- map["question_type"]
        self.maxValue <- (map["max"], transformJsonStringInt)
        self.minValue <- (map["min"], transformJsonStringInt)
        self.textFieldType <- map["text_field_type"]
        self.selectionValues <- map["answers"]
        self.displayIf <- map["display_if"]
        self.required <- map["required"] // well that's interesting, when a key is missing it Doesn't Crash AND the default value is respected
    }
    
    static func == (lhs: GenericSurveyQuestion, rhs: GenericSurveyQuestion) -> Bool {
        let questionId = lhs.questionId == rhs.questionId
        let prompt = lhs.prompt == rhs.prompt
        let questionType = lhs.questionType == rhs.questionType
        let maxValue = lhs.maxValue == rhs.maxValue
        let minValue = lhs.minValue == rhs.minValue
        let selectionValues = lhs.selectionValues == rhs.selectionValues
        let textFieldType = lhs.textFieldType == rhs.textFieldType
        let displayIf = compare_dict_of_string_to_anyobject(lhs: lhs.displayIf, rhs: rhs.displayIf)
        let required = lhs.required == rhs.required
        
        if !questionId { print(lhs.questionId, "!=", rhs.questionId) }
        if !prompt { print(lhs.prompt, "!=", rhs.prompt) }
        if !questionType { print(lhs.questionType, "!=", rhs.questionType) }
        if !maxValue { print(lhs.maxValue, "!=", rhs.maxValue) }
        if !minValue { print(lhs.minValue, "!=", rhs.minValue) }
        if !selectionValues { print(lhs.selectionValues, "!=", rhs.selectionValues) }
        if !textFieldType { print(lhs.textFieldType, "!=", rhs.textFieldType) }
        if !displayIf { print(lhs.displayIf, "!=", rhs.displayIf) }
        if !required { print(lhs.required, "!=", rhs.required) }
        
        return questionId &&
            prompt &&
            questionType &&
            maxValue &&
            minValue &&
            selectionValues &&
            textFieldType &&
            displayIf &&
            required
    }
}


/// The next two functions appear to be sufficient for handling comparison of two [String: AnyObject]?
/// objects in the context of comparing logic on whether a question should be displayed.
func compare_dict_of_string_to_anyobject(lhs: [String: AnyObject]?, rhs: [String: AnyObject]?) -> Bool {
    if lhs == nil && rhs == nil {
        return true
    }
    if lhs == nil || rhs == nil {
        return false
    }
    return _compare_dict_of_string_to_anyobject(lhs: lhs!, rhs: rhs!)
}
    
func _compare_dict_of_string_to_anyobject(lhs: [String: AnyObject], rhs: [String: AnyObject]) -> Bool {
    // immediately return false if they are of different sizes.
    if lhs.count != rhs.count {
        // print("different sizes")
        return false
    }
    
    // the value for both cannot be nil, these are AnyObjects, not "AnyObject?"s
    for (lhsKey, lhsValue) in lhs {
        // check key is present in rhs, if not they are different, return false
        if let _ = rhs[lhsKey] {} else {
            // print("key '\(lhsKey)' not present in rhs")
            return false
        }
        let rhsValue = rhs[lhsKey]!
        
        // if the values are not the same type, fail.
        if type(of: lhsValue) != type(of: rhsValue) {
            // print("lhsValue was a \(type(of: lhsValue)) and rhsValue was a \(type(of: rhsValue))")
            return false
        }
        
        // so now we know they are the same type but the swift compiler doesn't know that
        // we only actually need to support strings and ints, I think
        
        if lhsValue is String && rhsValue is String {
            if lhsValue as! String != rhsValue as! String {
                // print("strings were different - '\(lhsValue)' != '\(rhsValue)'")
                return false
            }
            continue
        }
        
        if lhsValue is Int && rhsValue is Int {
            if lhsValue as! Int != rhsValue as! Int {
                // print("ints were different - '\(lhsValue)' != '\(rhsValue)'")
                return false
            }
            continue
        }
        
        if lhsValue is NSArray && rhsValue is NSArray {
            if lhsValue as! NSArray != rhsValue as! NSArray {
                // print("arrays were different - '\(lhsValue)' != '\(rhsValue)'")
                return false
            }
            continue
        }
        
        if lhsValue is NSDictionary && rhsValue is NSDictionary {
            if !_compare_dict_of_string_to_anyobject(
                lhs: lhsValue as! [String: AnyObject], rhs: rhsValue as! [String: AnyObject]) {
                // print("recursive dictionary - they compared and returned false.")
                return false
            }
            continue
        }
        fatalError("unhandled type in compare_dict_of_string_to_anyobject: lhsValue: \(type(of: lhsValue)) rhsValue: \(type(of: rhsValue))")
    }
    return true
}
