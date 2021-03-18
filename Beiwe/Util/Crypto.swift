//
//  Crypto.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/25/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import IDZSwiftCommonCrypto

class Crypto {
    static let sharedInstance = Crypto();
    fileprivate static let defaultRSAPadding: SecPadding = .PKCS1


    func sha256Base64URL(_ str: String) -> String {
        let sha256: Digest = Digest(algorithm: .sha256);
        sha256.update(string: str);
        let digest = sha256.final();
        let data = Data(bytes: digest)
        let base64Str = data.base64EncodedString();
        return base64ToBase64URL(base64Str);
    }

    func base64ToBase64URL(_ base64str: String) -> String {
        //        //replaceAll('/', '_').replaceAll('+', '-');
        return base64str.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-");
    }

    func randomBytes(_ length: Int) -> Data? {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { [count=data.count]
            (mutableBytes: UnsafeMutablePointer<UInt8>) -> Int32 in
            SecRandomCopyBytes(kSecRandomDefault, count, mutableBytes)
        }

        if (result == errSecSuccess) {
            return data;
        } else {
            return nil;
        }

    }

    func newAesKey(_ keyLength: Int = 128) -> Data? {
        let length = (keyLength+7) / 8;
        let randoBytes = randomBytes(length);
        print(randoBytes!);
        print(randoBytes![0]);
        print(randoBytes!.base64EncodedString())
        if (randoBytes?[0] == 0) {
            print("First byte was zero.");
        }
        let zeroRepresentation: UInt8 = 0;
        print(zeroRepresentation);
        print("\n\n")
        return randoBytes;
    }


    func rsaEncryptString(_ str: String, publicKey: SecKey, padding: SecPadding = defaultRSAPadding) throws -> String {
        let blockSize = SecKeyGetBlockSize(publicKey)
        let plainTextData = [UInt8](str.utf8)
        let plainTextDataLength = Int(str.count)
        var encryptedData = [UInt8](repeating: 0, count: Int(blockSize))
        var encryptedDataLength = blockSize

        let status = SecKeyEncrypt(publicKey, padding, plainTextData, plainTextDataLength, &encryptedData, &encryptedDataLength)
        if status != noErr {
            throw NSError(domain: "beiwe.crypto", code: 1, userInfo: [:]);
        }

        let data = Data(bytes: UnsafePointer<UInt8>(encryptedData), count: encryptedDataLength)
        return base64ToBase64URL(data.base64EncodedString(options: []));
    }

    func aesEncrypt(_ iv: Data, key: Data, plainText: String) -> Data? {
        let arrayKey = Array(UnsafeBufferPointer(start: (key as NSData).bytes.bindMemory(to: UInt8.self, capacity: key.count), count: key.count));
        let arrayIv = Array(UnsafeBufferPointer(start: (iv as NSData).bytes.bindMemory(to: UInt8.self, capacity: iv.count), count: iv.count));

        let cryptor = Cryptor(operation:.encrypt, algorithm:.aes, options: .PKCS7Padding, key:arrayKey, iv: arrayIv)
        let cipherText = cryptor.update(string: plainText)?.final()
        if let cipherText = cipherText {
            return Data(cipherText);
        }
        return nil;
    }

}
