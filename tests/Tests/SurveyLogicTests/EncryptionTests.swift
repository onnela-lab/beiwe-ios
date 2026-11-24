import Foundation
import Security
import XCTest
@testable import AppEncryption

// source: Beiwe/Util/Encryption.swift + Crypto.swift, copied by run_tests.sh. Wire format: llm/contracts-data.md
// "Encryption". Expected values come from openssl + Python (tests/scripts/make_encryption_vectors.py), and whole
// files go through BackendDecryptor.swift, the mirror of the backend's decryptor.

private struct Vectors: Decodable {
    struct Rsa: Decodable { let public_key_base64: String; let private_key_pkcs1_der_base64: String }
    struct Base64URL: Decodable { let bytes_hex: String; let expected: String }
    struct KeyLine: Decodable { let aes_key_hex: String; let expected: String }
    struct DataLine: Decodable { let name: String; let aes_key_hex: String; let iv_hex: String; let plaintext: String; let expected: String }
    struct Audio: Decodable {
        let aes_key_hex: String; let iv_hex: String; let plaintext_hex: String
        let expected_iv_header: String; let expected_body: String
    }
    struct Password: Decodable { let password: String; let expected: String }
    let rsa: Rsa
    let base64url: [Base64URL]
    let key_lines: [KeyLine]
    let data_lines: [DataLine]
    let audio: [Audio]
    let password_sha256: [Password]
}

private let vectors = try! JSONDecoder().decode(Vectors.self, from: Fixtures.encryptionVectors)  // swiftlint:disable:this force_try

private func hex(_ s: String) -> Data {
    var data = Data()
    var i = s.startIndex
    while i < s.endIndex {
        let j = s.index(i, offsetBy: 2)
        data.append(UInt8(s[i..<j], radix: 16)!)
        i = j
    }
    return data
}

/// strict: bytes that are not valid UTF-8 fail the comparison instead of being repaired
private func utf8(_ data: Data) -> String {
    return String(bytes: data, encoding: .utf8) ?? "<not utf8: \(data.count) bytes>"
}

/// the app's view of the test key, imported the way StudyManager.setApiCredentials does it
private let publicKey: SecKey = Encryption.publicKey(base64Encoded: vectors.rsa.public_key_base64).reference

private let privateKey: SecKey = {
    let attrs: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPrivate]
    return SecKeyCreateWithData(Data(base64Encoded: vectors.rsa.private_key_pkcs1_der_base64)! as CFData,
                                attrs as CFDictionary, nil)!
}()

/// a data file laid out as DataStorage.lazy_new_file_setup + store write it: key line, header, rows
private func dataFile(aesKey: Data, lines: [String]) -> Data {
    var file = Encryption.get_rsa_line(aesKey, publicKey: publicKey)
    for line in lines { file.append(Encryption.encrypted_line(line, aesKey: aesKey)) }
    return file
}

/// an audio file laid out as EncryptedStorage writes it: key line, iv header, one encrypted write
private func audioFile(aesKey: Data, iv: Data, audio: Data) -> Data {
    let cryptor = Encryption.audio_stream_cryptor(aesKey: aesKey, iv: iv)
    var file = Encryption.get_rsa_line(aesKey, publicKey: publicKey)
    file.append(Encryption.audio_iv_header(iv))
    file.append(Encryption.audio_encoded(Encryption.audio_encrypt(cryptor, audio as NSData, writeLen: audio.count)))
    return file
}

private let urlsafeCharacters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-=")

class EncryptionTests: XCTestCase {
    // MARK: encodings

    // every encoded field is base64url with `=` kept; the backend's key-line check rejects `+` and `/`
    func testBase64URLSwapsSlashAndPlusAndKeepsPadding() {
        for v in vectors.base64url {
            AssertEqual(Crypto.sharedInstance.base64ToBase64URL(hex(v.bytes_hex).base64EncodedString()), v.expected)
        }
    }

    // the RSA plaintext is the base64url text of the key, not the raw key: the backend base64-decodes it again
    func testAesKeyIsEncodedAs24Base64URLCharactersBeforeRSA() {
        let key = hex(vectors.key_lines[1].aes_key_hex)
        let encoded = Encryption.get_that_aeskey(key)
        AssertEqual(encoded.count, 24)
        AssertTrue(encoded.hasSuffix("=="), encoded)
        AssertEqual(Data(base64Encoded: encoded.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")), key)
    }

    // the server sends client_public_key as the PEM body of an X.509 key; it must import as a 2048-bit key
    func testBackendPublicKeyFormatImportsAs2048BitKey() {
        AssertEqual(SecKeyGetBlockSize(publicKey), 256)
    }

    // MARK: key line

    // raw RSA without padding is deterministic, so the key line must match textbook RSA computed outside the app
    func testKeyLineMatchesTextbookRSAVector() {
        for v in vectors.key_lines {
            AssertEqual(utf8(Encryption.get_rsa_line(hex(v.aes_key_hex), publicKey: publicKey)),
                        v.expected)
        }
    }

    // the backend must recover every possible key, including ones whose ciphertext starts with zero bytes
    func testKeyLineGivesTheBackendTheAesKeyForManyRandomKeys() throws {
        for _ in 0..<300 {
            let key = Crypto.sharedInstance.newAesKey(128)
            AssertEqual(try backendAesKey(fromKeyLine: Encryption.get_rsa_line(key, publicKey: publicKey),
                                          privateKey: privateKey), key)
        }
    }

    // a file for another participant's key must fail at the backend, else the round-trip tests prove nothing
    func testBackendMirrorRejectsAKeyLineForAnotherKey() throws {
        let attrs: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048]
        let otherPrivateKey = try XCTUnwrap(SecKeyCreateRandomKey(attrs as CFDictionary, nil))
        let keyLine = Encryption.get_rsa_line(Crypto.sharedInstance.newAesKey(128), publicKey: publicKey)
        AssertThrowsError(try backendAesKey(fromKeyLine: keyLine, privateKey: otherPrivateKey))
    }

    // MARK: data lines

    // AES-128-CBC-PKCS7 lines must match openssl byte for byte (empty, one full block, unicode, long, newline)
    func testDataLinesMatchOpensslVectors() {
        for v in vectors.data_lines {
            let line = Encryption.encrypted_line(v.plaintext, aesKey: hex(v.aes_key_hex), iv: hex(v.iv_hex))
            AssertEqual(utf8(line), v.expected, v.name)
        }
    }

    // reusing an IV with one key leaks equal line prefixes; each line must draw a fresh one
    func testEachLineGetsAFreshIV() {
        let key = Crypto.sharedInstance.newAesKey(128)
        let ivs = (0..<50).map { _ in
            utf8(Encryption.encrypted_line("same row", aesKey: key)).split(separator: ":")[0]
        }
        AssertEqual(Set(ivs).count, 50)
        AssertTrue(ivs.allSatisfy { $0.count == 24 }, "\(ivs)")
    }

    // the backend splits files on "\n" and lines on ":", so a line must be one `iv:data` of base64url, "\n"-ended
    func testDataLineIsOneNewlineTerminatedIvColonData() {
        for v in vectors.data_lines {
            let line = utf8(Encryption.encrypted_line(v.plaintext, aesKey: hex(v.aes_key_hex)))
            AssertTrue(line.hasSuffix("\n"), v.name)
            let body = line.dropLast()
            AssertEqual(body.split(separator: ":", omittingEmptySubsequences: false).count, 2, v.name)
            AssertTrue(body.allSatisfy { $0 == ":" || urlsafeCharacters.contains($0) }, v.name)
        }
    }

    // MARK: whole files through the backend mirror

    // the file as DataStorage writes it must decrypt with the backend's rules to the header and rows
    func testDataFileDecryptsWithBackendRules() throws {
        let rows = vectors.data_lines.map(\.plaintext).filter { !$0.contains("\n") }
        let key = Crypto.sharedInstance.newAesKey(128)
        let plain = try backendDecryptFile(dataFile(aesKey: key, lines: rows), privateKey: privateKey)
        AssertEqual(utf8(plain), rows.joined(separator: "\n"))
    }

    // BD10, locked as is: the backend joins decrypted lines with "\n", so a row holding "\n" becomes two rows
    func testRowWithNewlineBecomesTwoRowsAtTheBackend() throws {
        let file = dataFile(aesKey: Crypto.sharedInstance.newAesKey(128), lines: ["header", "row one\nrow two"])
        let plain = try backendDecryptFile(file, privateKey: privateKey)
        AssertEqual(utf8(plain).split(separator: "\n").count, 3)
    }

    // MARK: audio

    // the audio body is one CBC stream over the whole recording; must match openssl byte for byte
    func testAudioMatchesOpensslVector() {
        for v in vectors.audio {
            let (key, iv, audio) = (hex(v.aes_key_hex), hex(v.iv_hex), hex(v.plaintext_hex))
            let cryptor = Encryption.audio_stream_cryptor(aesKey: key, iv: iv)
            let body = Encryption.audio_encoded(Encryption.audio_encrypt(cryptor, audio as NSData, writeLen: audio.count))
            AssertEqual(utf8(Encryption.audio_iv_header(iv)), v.expected_iv_header)
            AssertEqual(utf8(body), v.expected_body)
        }
    }

    // an audio file is key line + `iv:data` with no trailing newline, and must decrypt with the backend's rules
    func testAudioFileDecryptsWithBackendRules() throws {
        let audio = Data((0..<5000).map { UInt8(truncatingIfNeeded: $0 * 31) })
        let file = audioFile(aesKey: Crypto.sharedInstance.newAesKey(128), iv: Crypto.sharedInstance.randomBytes(16),
                             audio: audio)
        AssertNotEqual(file.last, UInt8(ascii: "\n"))
        AssertEqual(file.filter { $0 == UInt8(ascii: "\n") }.count, 1)
        AssertEqual(try backendDecryptFile(file, privateKey: privateKey), audio)
    }

    // MARK: keys and password

    // a 128-bit request must give 16 random bytes; a short key makes the backend reject the whole file
    func testNewAesKeyIs16FreshBytes() {
        let a = Crypto.sharedInstance.newAesKey(128), b = Crypto.sharedInstance.newAesKey(128)
        AssertEqual(a.count, 16)
        AssertNotEqual(a, b)
        AssertEqual(Crypto.sharedInstance.randomBytes(16).count, 16)
    }

    // the server only ever sees this hash as the password; any change locks registered participants out
    func testPasswordHashMatchesSha256Vector() {
        for v in vectors.password_sha256 {
            AssertEqual(Crypto.sharedInstance.sha256Base64URL(v.password), v.expected)
        }
    }
}
