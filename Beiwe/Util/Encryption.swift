import Foundation
import IDZSwiftCommonCrypto
import SwiftyRSA

// The data file wire format (llm/contracts-data.md "Encryption"). Pure functions, no file IO or app state, so
// tests/ can run them: run_tests.sh copies this file and Crypto.swift. Moved verbatim out of DataStorage,
// EncryptedStorage and StudyManager; the backend decrypts exactly these bytes, keep them byte-identical.
enum Encryption {

    /// The participant's RSA public key, from the registration payload's `client_public_key`.
    static func publicKey(base64Encoded clientPublicKey: String) -> PublicKey {
        return try! PublicKey(base64Encoded: clientPublicKey)
    }

    ///////////////////////////////////////// Text data files /////////////////////////////////////////

    /// Returns the entire raw string of the first line of a file containing an RSA-encoded decryption key.
    static func get_rsa_line(_ aesKey: Data, publicKey: SecKey) -> Data {
        // for dumb Python 2 legacy reasons we needed to  base64-encode the aes key, and
        // only then encrypt it... and then base64 encode that again.
        let encryption_key_line_as_string = Crypto.sharedInstance.rsaEncryptToBase64URL(
            self.get_that_aeskey(aesKey),
            publicKey: publicKey
        ) + "\n"

        return encryption_key_line_as_string.data(using: String.Encoding.utf8)!
    }

    static func get_that_aeskey(_ aesKey: Data) -> String {
        return Crypto.sharedInstance.base64ToBase64URL(aesKey.base64EncodedString())
    }

    /// One encrypted line of a data file, `iv:ciphertext\n`; a fresh random iv per line unless one is given.
    static func encrypted_line(_ line: String, aesKey: Data, iv: Data = Crypto.sharedInstance.randomBytes(16)) -> Data {
        let encrypted = Crypto.sharedInstance.aesEncrypt(iv, key: aesKey, plainText: line)
        let base64_data = (
            Crypto.sharedInstance.base64ToBase64URL(iv.base64EncodedString(options: []))
                + ":"
                + Crypto.sharedInstance.base64ToBase64URL(encrypted.base64EncodedString(options: []))
                + "\n"
        ).data(using: String.Encoding.utf8)!
        return base64_data
    }

    ///////////////////////////////////////// Audio (EncryptedStorage) /////////////////////////////////////////

    /// second line of an audio file, written right after the key line; the ciphertext follows on the same line
    static func audio_iv_header(_ iv: Data) -> Data {
        let ivHeader = Crypto.sharedInstance.base64ToBase64URL(iv.base64EncodedString()) + ":"
        return ivHeader.data(using: String.Encoding.utf8)!
    }

    static func audio_stream_cryptor(aesKey: Data, iv: Data) -> StreamCryptor {
        let data_for_key = (aesKey as NSData).bytes.bindMemory(to: UInt8.self, capacity: aesKey.count)
        let data_for_iv = (iv as NSData).bytes.bindMemory(to: UInt8.self, capacity: iv.count)
        return StreamCryptor(
            operation: .encrypt,
            algorithm: .aes,
            options: .PKCS7Padding,
            key: Array(UnsafeBufferPointer(start: data_for_key, count: aesKey.count)),
            iv: Array(UnsafeBufferPointer(start: data_for_iv, count: iv.count))
        )
    }

    /// Encrypts one write and finalizes the cryptor, so a stream cryptor takes exactly one write.
    static func audio_encrypt(_ stream_cryptor: StreamCryptor, _ data: NSData?, writeLen: Int) -> NSMutableData {
        let new_data: NSMutableData = NSMutableData()

        // setup to write - this case should be impossible
        if data != nil && writeLen != 0 {
            // log.info("write_actual case 1")
            // Need to encrypt data
            let encryptLen = stream_cryptor.getOutputLength(inputByteCount: writeLen)
            let bufferOut = UnsafeMutableRawPointer.allocate(byteCount: encryptLen, alignment: 1)
            var byteCount: Int = 0
            let bufferIn = UnsafeMutableRawPointer(mutating: data!.bytes)
            stream_cryptor.update(
                bufferIn: bufferIn,
                byteCountIn: writeLen,
                bufferOut: bufferOut,
                byteCapacityOut: encryptLen,
                byteCountOut: &byteCount
            )
            new_data.append(NSData(bytesNoCopy: bufferOut, length: byteCount) as Data)
        }

        // again, this case should be impossible
        let encryptLen = stream_cryptor.getOutputLength(inputByteCount: 0, isFinal: true)
        if encryptLen > 0 {
            // log.info("write_actual case 2")
            // mostly setup of these obscure pointers to an array of data (there must be a better way to do this...)
            let bufferOut = UnsafeMutableRawPointer.allocate(byteCount: encryptLen, alignment: 1)
            var byteCount: Int = 0
            stream_cryptor.final(bufferOut: bufferOut, byteCapacityOut: encryptLen, byteCountOut: &byteCount)
            // setup to write an array of appropriate length
            let finalData = NSData(bytesNoCopy: bufferOut, length: byteCount)
            var array = [UInt8](repeating: 0, count: finalData.length / MemoryLayout<UInt8>.size)
            // copy bytes into array (its an array of bytes, length is just length), append to new_data
            finalData.getBytes(&array, length: finalData.length)
            new_data.append(finalData as Data)
        }
        return new_data
    }

    /// the encrypted bytes of one write as file content (base64url, no newline)
    static func audio_encoded(_ new_data: NSMutableData) -> Data {
        let dataToWriteBuffer = UnsafeMutableRawPointer(mutating: new_data.bytes)
        let dataToWrite = NSData(bytesNoCopy: dataToWriteBuffer, length: new_data.length, freeWhenDone: false)
        let encodedData: String = Crypto.sharedInstance.base64ToBase64URL(dataToWrite.base64EncodedString(options: []))
        return encodedData.data(using: String.Encoding.utf8)!
    }
}
