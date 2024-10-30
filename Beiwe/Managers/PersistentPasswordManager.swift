import Foundation
import KeychainSwift

/// standardized name format that we can never change despite being very stupid
fileprivate func keyForStudy(prefix: String) -> String {
    return prefix + "default"
}

struct PersistentPasswordManager {
    static let sharedInstance = PersistentPasswordManager() // static singleton reference
    static let bundlePrefix = Bundle.main.bundleIdentifier ?? "com.rocketarmstudios.beiwe"

    // Apple Keychain connection for secure storage
    fileprivate let keychain: KeychainSwift

    // file name prefixes
    fileprivate let passwordKeyPrefix = "password:"
    fileprivate let rsaKeyPrefix = PersistentPasswordManager.bundlePrefix + ".rsapk."

    init() {
        // instantiate the keychain depending on development environment (TODO: why do we do this?)
        #if targetEnvironment(simulator)
            self.keychain = KeychainSwift(keyPrefix: PersistentPasswordManager.bundlePrefix + ".")
        #else
            self.keychain = KeychainSwift()
        #endif
    }

    /// Gets the password for the current study, but is optional
    func passwordForStudy() -> String? {
        // passwords are stored on a per-study basis, so in principle someone could have
        // multiple instances of study information present.
        return self.keychain.get(keyForStudy(prefix: self.passwordKeyPrefix))
    }

    /// Sets the password string for the participant on a particular study in the
    /// keychain for secure storage, device-only (not icloud shared?)
    func storePassword(_ password: String) {
        self.keychain.set(
            password, forKey: keyForStudy(prefix: self.passwordKeyPrefix), withAccess: .accessibleAfterFirstUnlockThisDeviceOnly
        )
    }
}
