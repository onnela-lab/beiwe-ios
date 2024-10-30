import Foundation
import KeychainSwift

struct PersistentAppUUID {
    static let sharedInstance = PersistentAppUUID()

    fileprivate let keychain = KeychainSwift()
    fileprivate let uuidKey = "privateAppUuid"

    let uuid: String

    fileprivate init() {
        if let u = keychain.get(uuidKey) {
            self.uuid = u
        } else {
            self.uuid = UUID().uuidString
            self.keychain.set(self.uuid, forKey: self.uuidKey, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        }
    }
}
