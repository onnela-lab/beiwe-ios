import CommonCrypto
import Foundation
import Security

// Swift mirror of the backend's DeviceDataDecryptor (beiwe-backend libs/encryption.py, the real consumer of app
// data files): same checks, same order, so a file it rejects the backend rejects too. Nothing is imported from the
// backend repo. Not mirrored: null-byte checks and the padding repair in decode_base64 (the app always pads).

enum BackendDecryptError: Error, Equatable {
    case noData                    // RemoteDeleteFileScenario
    case keyNotBase64              // DecryptionKeyInvalidError "Key not base64 encoded"
    case invalidDecryptionKey      // DecryptionKeyInvalidError on a base64 failure or an empty key
    case keyNot128Bits(Int)        // DecryptionKeyInvalidError "Decryption key not 128 bits"
    case lineFormat                // `iv, data = line.split(b":")` raising
    case invalidData               // InvalidData
    case invalidIV                 // InvalidIV
}

/// URLSAFE_BASE64_CHARACTERS (constants/security_constants.py)
private let urlsafeBase64Characters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-=".utf8)

/// base64.urlsafe_b64decode
func backendDecodeBase64(_ bytes: Data) -> Data? {
    guard let text = String(bytes: bytes, encoding: .utf8) else { return nil }
    let std = text
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    return Data(base64Encoded: std)
}

/// rsa_decrypt: textbook RSA (pow(c, d, n)), leading zero bytes stripped
private func backendRsaDecrypt(_ cipher: Data, privateKey: SecKey) -> Data? {
    guard let raw = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionRaw, cipher as CFData, nil) as Data? else {
        return nil
    }
    return Data(raw.drop(while: { $0 == 0 }))
}

/// extract_aes_key
private func backendExtractAesKey(_ keyLine: Data, privateKey: SecKey) throws -> Data {
    guard keyLine.allSatisfy({ urlsafeBase64Characters.contains($0) }) else { throw BackendDecryptError.keyNotBase64 }
    guard let decoded = backendDecodeBase64(keyLine),
          let base64Key = backendRsaDecrypt(decoded, privateKey: privateKey),
          let key = backendDecodeBase64(base64Key), !key.isEmpty else {
        throw BackendDecryptError.invalidDecryptionKey
    }
    guard key.count == 16 else { throw BackendDecryptError.keyNot128Bits(key.count) }
    return key
}

/// decrypt_device_line: raw CBC decrypt, bytes past a 16 multiple dropped, padding stripped by the last byte's value
private func backendDecryptLine(_ line: Data, aesKey: Data) throws -> Data {
    let parts = line.split(separator: UInt8(ascii: ":"), omittingEmptySubsequences: false)
    guard parts.count == 2 else { throw BackendDecryptError.lineFormat }
    guard let iv = backendDecodeBase64(Data(parts[0])), var raw = backendDecodeBase64(Data(parts[1])) else {
        throw BackendDecryptError.invalidData
    }
    if raw.count < 16 { throw BackendDecryptError.invalidData }
    if iv.count < 16 { throw BackendDecryptError.invalidIV }
    raw = raw.prefix(raw.count - raw.count % 16)

    var out = Data(count: raw.count)
    var moved = 0
    let status = out.withUnsafeMutableBytes { outPtr in
        raw.withUnsafeBytes { rawPtr in
            aesKey.withUnsafeBytes { keyPtr in
                iv.withUnsafeBytes { ivPtr in
                    CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(0),  // no unpadding
                            keyPtr.baseAddress, aesKey.count, ivPtr.baseAddress,
                            rawPtr.baseAddress, raw.count, outPtr.baseAddress, raw.count, &moved)
                }
            }
        }
    }
    precondition(status == kCCSuccess, "CCCrypt failed: \(status)")
    let padding = Int(out[out.count - 1])
    return padding == 0 ? out : out.prefix(max(0, out.count - padding))
}

/// run_decryption: the decrypted file, lines joined with "\n"; throws on the first bad line (the backend records
/// line errors and goes on, but any line error here is a test failure)
func backendDecryptFile(_ file: Data, privateKey: SecKey) throws -> Data {
    let lines = file.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true).map { Data($0) }
    guard let keyLine = lines.first else { throw BackendDecryptError.noData }
    let aesKey = try backendExtractAesKey(keyLine, privateKey: privateKey)
    let good = try lines.dropFirst().map { try backendDecryptLine($0, aesKey: aesKey) }
    return Data(good.joined(separator: Data("\n".utf8)))
}

/// the AES key the backend would read from a file's first line
func backendAesKey(fromKeyLine keyLine: Data, privateKey: SecKey) throws -> Data {
    let line = keyLine.split(separator: UInt8(ascii: "\n")).first.map { Data($0) } ?? Data()
    return try backendExtractAesKey(line, privateKey: privateKey)
}
