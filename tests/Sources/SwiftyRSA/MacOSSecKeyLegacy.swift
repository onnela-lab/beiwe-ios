import Foundation
import Security

// The app's SwiftyRSA (copied from Pods/ into Pod/ by run_tests.sh) calls SecKeyEncrypt/SecKeyDecrypt, which the
// macOS SDK header hides (iOS only). macOS Security still exports both; these bind to Apple's own implementation
// by name, so `swift test` runs the app's RSA path unchanged.
// swiftlint:disable function_parameter_count

private typealias LegacyCrypt = @convention(c) (
    SecKey, SecPadding, UnsafePointer<UInt8>, Int, UnsafeMutablePointer<UInt8>, UnsafeMutablePointer<Int>
) -> OSStatus

private func legacy(_ name: String) -> LegacyCrypt {
    let security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW)
    guard let symbol = dlsym(security, name) else { fatalError("Security does not export \(name)") }
    return unsafeBitCast(symbol, to: LegacyCrypt.self)
}

private let legacyEncrypt = legacy("SecKeyEncrypt")
private let legacyDecrypt = legacy("SecKeyDecrypt")

func SecKeyEncrypt(_ key: SecKey, _ padding: SecPadding, _ plainText: UnsafePointer<UInt8>, _ plainTextLen: Int,
                   _ cipherText: UnsafeMutablePointer<UInt8>, _ cipherTextLen: UnsafeMutablePointer<Int>) -> OSStatus {
    return legacyEncrypt(key, padding, plainText, plainTextLen, cipherText, cipherTextLen)
}

func SecKeyDecrypt(_ key: SecKey, _ padding: SecPadding, _ cipherText: UnsafePointer<UInt8>, _ cipherTextLen: Int,
                   _ plainText: UnsafeMutablePointer<UInt8>, _ plainTextLen: UnsafeMutablePointer<Int>) -> OSStatus {
    return legacyDecrypt(key, padding, cipherText, cipherTextLen, plainText, plainTextLen)
}

// the app never signs or verifies; these only let SwiftyRSA compile
func SecKeyRawSign(_ key: SecKey, _ padding: SecPadding, _ dataToSign: UnsafePointer<UInt8>, _ dataToSignLen: Int,
                   _ sig: UnsafeMutablePointer<UInt8>, _ sigLen: UnsafeMutablePointer<Int>) -> OSStatus {
    fatalError("SecKeyRawSign is not used by the app")
}

func SecKeyRawVerify(_ key: SecKey, _ padding: SecPadding, _ signedData: UnsafePointer<UInt8>, _ signedDataLen: Int,
                     _ sig: UnsafePointer<UInt8>, _ sigLen: Int) -> OSStatus {
    fatalError("SecKeyRawVerify is not used by the app")
}
// swiftlint:enable function_parameter_count
