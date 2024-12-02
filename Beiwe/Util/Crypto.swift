import Foundation
import IDZSwiftCommonCrypto
import SwiftyRSA

class Crypto {
    static let sharedInstance = Crypto() // why is this instantiated At All? there's no state!

    /// generates a URL-safe-base64 string containing the SHA256 hash of the input string
    /// (used on the password parameter sent to the server)
    func sha256Base64URL(_ str: String) -> String {
        let sha256: Digest = Digest(algorithm: .sha256)
        _ = sha256.update(string: str) // returns self
        let digest = sha256.final()
        let data = Data(digest)
        let base64Str = data.base64EncodedString()
        return self.base64ToBase64URL(base64Str)
    }

    // takes a string containing base64 data and returns the string but containing URL-safe base64 data
    func base64ToBase64URL(_ base64str: String) -> String {
        // replaceAll('/', '_').replaceAll('+', '-');
        return base64str.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }

    // generates random data for whatever purpose we desire (e.g. generating the aes encryption key).
    func randomBytes(_ length: Int) -> Data {
        // not being able to generate random bytes is unnacceptable, so we crash the app.
        let byte_array = try! Random.generateBytes(byteCount: length)
        return Data(bytes: byte_array, count: byte_array.count)
    }
    
    // generates a new 128-bit AES key - should only ever be called with 128, for now.
    func newAesKey(_ keyLength: Int = 128) -> Data {
        // this is an integer divide, it rounds any value of bits that is not divisible by 8 up to
        // the nearest multiple of 8. (e.g. it normalizes bits to bytes.... sure ok whatever)
        let length = (keyLength + 7) / 8
        return self.randomBytes(length)
    }
    
    // using the RSA key (provided by the beiwe server for this participant) to encrypt a string,
    // output is a base64 encoded string containing raw bytes.
    func rsaEncryptToBase64URL(_ str: String, publicKey: SecKey) -> String {
        let publicKey = try! PublicKey(reference: publicKey)
        // print("str: \(str)")
        let clear = try! ClearMessage(string: str, using: .utf8)
        let encrypted = try! clear.encrypted(with: publicKey, padding: []) // [] is no padding
        // print("encrypted data: \(tohex(encrypted.data))")
        // print("base64String: \(encrypted.base64String)")
        return self.base64ToBase64URL(encrypted.base64String)
    }

    // encrypts a string using AES 128 - I think it is CBC mode? - using the provided key and iv.
    func aesEncrypt(_ iv: Data, key: Data, plainText: String) -> Data {
        let arrayKey = Array(
            UnsafeBufferPointer(start: (key as NSData)
                .bytes.bindMemory(to: UInt8.self, capacity: key.count), count: key.count)
        )
        let arrayIv = Array(
            UnsafeBufferPointer(start: (iv as NSData)
                .bytes.bindMemory(to: UInt8.self, capacity: iv.count), count: iv.count)
        )
        let cryptor = Cryptor(
            operation: .encrypt, algorithm: .aes, options: .PKCS7Padding, key: arrayKey, iv: arrayIv
        )
        let cipherText = cryptor.update(string: plainText)?.final()
        if let cipherText = cipherText {
            return Data(cipherText)
        }
        // failing here is insane. Just crash.
        fatalError("could not encrypt string with AES")
    }
}
