import Foundation
import ObjectMapper
import XCGLogger

/// unused, appears to be an alternate to the upload data file post request
struct ParamUploadRequest: Mappable, ApiRequest {
    static let apiEndpoint = "/upload/ios/"
    typealias ApiReturnType = BodyResponse

    var fileName: String?
    var fileData: String?

    init?(map: Map) {}
    init(fileName: String, filePath: String) {
        self.fileName = fileName
        do {
            self.fileData = try NSString(contentsOfFile: filePath, encoding: String.Encoding.utf8.rawValue) as String
        } catch {
            log.error("Error reading file for upload: \(error)")
            self.fileData = ""
        }
    }

    // Mappable
    mutating func mapping(map: Map) {
        self.fileName <- map["file_name"]
        self.fileData <- map["file"]
    }
}
