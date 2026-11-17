import Foundation
import ObjectMapper

// stand-ins for app types the copied Beiwe/Models/*.swift need; ReclineObject minus Couchbase
class ReclineObject: Mappable {
    var _id: String?
    init() {}
    required init?(map: Map) {}
    func mapping(map: Map) {}
}

enum Constants {
    static let DEFAULT_UNPOPULATED_APPINFO = "never_populated"
}
