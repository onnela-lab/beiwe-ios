//
//  DataStorageManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/29/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import Security
import PromiseKit
import IDZSwiftCommonCrypto

enum DataStorageErrors : Error {
    case cantCreateFile
    case notInitialized

}
class EncryptedStorage {

    static let delimiter = ",";

    let keyLength = 128;

    var type: String;
    var aesKey: Data?;
    var iv: Data?
    var publicKey: String;
    var filename: URL;
    var realFilename: URL
    var patientId: String;
    let queue: DispatchQueue
    var currentData: NSMutableData = NSMutableData()
    var hasData = false
    var handle: FileHandle?
    let fileManager = FileManager.default;
    var sc: StreamCryptor
    var secKeyRef: SecKey?


    init(type: String, suffix: String, patientId: String, publicKey: String, keyRef: SecKey?) {
        self.patientId = patientId;
        self.publicKey = publicKey;
        self.type = type;
        self.secKeyRef = keyRef

        queue = DispatchQueue(label: "com.rocketfarm.beiwe.dataqueue." + type, attributes: [])

        let name = patientId + "_" + type + "_" + String(Int64(Date().timeIntervalSince1970 * 1000));
        realFilename = DataStorageManager.currentDataDirectory().appendingPathComponent(name + suffix)
        filename = URL(fileURLWithPath:  NSTemporaryDirectory()).appendingPathComponent(name + suffix)
        aesKey = Crypto.sharedInstance.newAesKey(keyLength);
        iv = Crypto.sharedInstance.randomBytes(16)
        let arrayKey = Array(UnsafeBufferPointer(start: (aesKey! as NSData).bytes.bindMemory(to: UInt8.self, capacity: aesKey!.count), count: aesKey!.count));
        let arrayIv = Array(UnsafeBufferPointer(start: (iv! as NSData).bytes.bindMemory(to: UInt8.self, capacity: iv!.count), count: iv!.count));
        sc = StreamCryptor(operation: .encrypt, algorithm: .aes, options: .PKCS7Padding, key: arrayKey, iv: arrayIv)

    }

    func open() -> Promise<Void> {
        guard let aesKey = aesKey, let iv = iv else {
            return Promise(error: DataStorageErrors.notInitialized)
        }
        return Promise().then(on: queue) {
            if (!self.fileManager.createFile(atPath: self.filename.path, contents: nil, attributes: [FileAttributeKey(rawValue: FileAttributeKey.protectionKey.rawValue): FileProtectionType.none])) {
                return Promise(error: DataStorageErrors.cantCreateFile)
            } else {
                log.info("Create new enc file: \(self.filename)");
            }
            self.handle = try? FileHandle(forWritingTo: self.filename)
            var rsaLine: String?
            if let keyRef = self.secKeyRef {
                rsaLine = try Crypto.sharedInstance.base64ToBase64URL(SwiftyRSA.encryptString(Crypto.sharedInstance.base64ToBase64URL(aesKey.base64EncodedString()), publicKey: keyRef, padding: [])) + "\n";
            } else {
                rsaLine = try Crypto.sharedInstance.base64ToBase64URL(SwiftyRSA.encryptString(Crypto.sharedInstance.base64ToBase64URL(aesKey.base64EncodedString()), publicKeyId: PersistentPasswordManager.sharedInstance.publicKeyName(self.patientId), padding: [])) + "\n";
            }
            self.handle?.write(rsaLine!.data(using: String.Encoding.utf8)!)
            let ivHeader = Crypto.sharedInstance.base64ToBase64URL(iv.base64EncodedString()) + ":"
            self.handle?.write(ivHeader.data(using: String.Encoding.utf8)!)
            return Promise()
        }


    }

    func close() -> Promise<Void> {
        return write(nil, writeLen: 0, isFlush: true).then(on: queue) {
            if let handle = self.handle {
                handle.closeFile()
                self.handle = nil
                try FileManager.default.moveItem(at: self.filename, to: self.realFilename)
                log.info("moved temp data file \(self.filename) to \(self.realFilename)");
            }
            return Promise()
        }
    }

    func _write(_ data: NSData, len: Int) -> Promise<Int> {
        if (len == 0) {
            return Promise(value: 0);
        }
        return Promise().then(on: queue) {
            self.hasData = true
            let dataToWriteBuffer = UnsafeMutableRawPointer(mutating: data.bytes)
            let dataToWrite = NSData(bytesNoCopy: dataToWriteBuffer, length: len, freeWhenDone: false)
            let encodedData: String = Crypto.sharedInstance.base64ToBase64URL(dataToWrite.base64EncodedString(options: []))
            self.handle?.write(encodedData.data(using: String.Encoding.utf8)!)
            return Promise(value: len)
        }

    }

    func write(_ data: NSData?, writeLen: Int, isFlush: Bool = false) -> Promise<Void> {
        return Promise().then(on: queue) {
            if (data != nil && writeLen != 0) {
                // Need to encrypt data
                let encryptLen = self.sc.getOutputLength(inputByteCount: writeLen)
                let bufferOut = UnsafeMutablePointer<Void>.allocate(capacity: encryptLen)
                var byteCount: Int = 0
                let bufferIn = UnsafeMutableRawPointer(mutating: data!.bytes)
                self.sc.update(bufferIn: bufferIn, byteCountIn: writeLen, bufferOut: bufferOut, byteCapacityOut: encryptLen, byteCountOut: &byteCount)
                self.currentData.append(NSData(bytesNoCopy: bufferOut, length: byteCount) as Data)
            }
            if (isFlush) {
                let encryptLen = self.sc.getOutputLength(inputByteCount: 0, isFinal: true)
                if (encryptLen > 0) {
                    let bufferOut = UnsafeMutablePointer<Void>.allocate(capacity: encryptLen)
                    var byteCount: Int = 0
                    self.sc.final(bufferOut: bufferOut, byteCapacityOut: encryptLen, byteCountOut: &byteCount)
                    let finalData = NSData(bytesNoCopy: bufferOut, length: byteCount);

                    let count = finalData.length / MemoryLayout<UInt8>.size

                    // create array of appropriate length:
                    var array = [UInt8](repeating: 0, count: count)

                    // copy bytes into array
                    finalData.getBytes(&array, length:count * MemoryLayout<UInt8>.size)
                    self.currentData.append(finalData as Data)
                }
            }
            // Only write multiples of 3, since we are base64 encoding and would otherwise end up with padding
            var evenLength: Int
            if (isFlush) {
                evenLength = self.currentData.length
            } else {
                evenLength = (self.currentData.length / 3) * 3
            }
            return self._write(self.currentData, len: evenLength)
            }.then(on: queue) { evenLength in
                self.currentData.replaceBytes(in: NSRange(0..<evenLength), withBytes: nil, length: 0)
        }
    }

    deinit {
        if (handle != nil) {
            handle?.closeFile()
            handle = nil
        }
    }
}

class DataStorage {

    static let delimiter = ",";

    let flushLines = 100;
    let keyLength = 128;

    var headers: [String];
    var type: String;
    var lines: [String] = [ ];
    var aesKey: Data?;
    var publicKey: String;
    var hasData: Bool = false;
    var filename: URL?;
    var realFilename: URL?
    var dataPoints = 0;
    var patientId: String;
    var bytesWritten = 0;
    var hasError = false;
    var errMsg: String = "";
    var noBuffer = false;
    var sanitize = false;
    let moveOnClose: Bool
    let queue: DispatchQueue
    var name = ""
    var logClosures:[()->()] = [ ]
    var secKeyRef: SecKey?


    init(type: String, headers: [String], patientId: String, publicKey: String, moveOnClose: Bool = false, keyRef: SecKey?) {
        self.patientId = patientId;
        self.publicKey = publicKey;
        self.type = type;
        self.headers = headers;
        self.moveOnClose = moveOnClose
        self.secKeyRef = keyRef

        queue = DispatchQueue(label: "com.rocketfarm.beiwe.dataqueue." + type, attributes: [])
        logClosures = [ ]
        reset();
        outputLogClosures();
    }

    fileprivate func outputLogClosures() {
        let tmpLogClosures: [()->()] = logClosures
        logClosures = []
        for c in tmpLogClosures {
            c();
        }
    }

    fileprivate func reset() {
        if let filename = filename, let realFilename = realFilename, moveOnClose == true && hasData == true {
            do {
                try FileManager.default.moveItem(at: filename, to: realFilename)
                log.info("moved temp data file \(filename) to \(realFilename)");
            } catch {
                log.error("Error moving temp data \(filename) to \(realFilename)");
            }
        }
        let name = patientId + "_" + type + "_" + String(Int64(Date().timeIntervalSince1970 * 1000));
        self.name = name
        errMsg = ""
        hasError = false;

        realFilename = DataStorageManager.currentDataDirectory().appendingPathComponent(name + DataStorageManager.dataFileSuffix)
        if (moveOnClose) {
            filename = URL(fileURLWithPath:  NSTemporaryDirectory()).appendingPathComponent(name + DataStorageManager.dataFileSuffix) ;
        } else {
            filename = realFilename
        }
        lines = [ ];
        dataPoints = 0;
        bytesWritten = 0;
        hasData = false;
        aesKey = Crypto.sharedInstance.newAesKey(keyLength);
        if let aesKey = aesKey {
            do {
                var rsaLine: String?
                if let keyRef = self.secKeyRef {
                    rsaLine = try Crypto.sharedInstance.base64ToBase64URL(SwiftyRSA.encryptString(Crypto.sharedInstance.base64ToBase64URL(aesKey.base64EncodedString()), publicKey: keyRef, padding: [])) + "\n";
                } else {
                    rsaLine = try Crypto.sharedInstance.base64ToBase64URL(SwiftyRSA.encryptString(Crypto.sharedInstance.base64ToBase64URL(aesKey.base64EncodedString()), publicKeyId: PersistentPasswordManager.sharedInstance.publicKeyName(self.patientId), padding: [])) + "\n";
                }
                lines = [ rsaLine! ];
                _writeLine(headers.joined(separator: DataStorage.delimiter))
            } catch let unkErr {
                errMsg = "RSAEncErr: " + String(describing: unkErr)
                lines = [ errMsg + "\n" ];
                log.error(errMsg)
                hasError = true;
            }
        } else {
            errMsg = "Failed to generate AES key"
            lines = [ errMsg + "\n" ];
            log.error(errMsg)
            hasError = true;
        }

        if (type != "ios_log") {
            self.logClosures.append() {
                AppEventManager.sharedInstance.logAppEvent(event: "file_init", msg: "Init new data file", d1: name, d2: String(self.hasError), d3: self.errMsg)
            }
        }

    }


    fileprivate func _writeLine(_ line: String) {
        let iv: Data? = Crypto.sharedInstance.randomBytes(16);
        if let iv = iv, let aesKey = aesKey {
            let encrypted = Crypto.sharedInstance.aesEncrypt(iv, key: aesKey, plainText: line);
            if let encrypted = encrypted  {
                lines.append(Crypto.sharedInstance.base64ToBase64URL(iv.base64EncodedString(options: [])) + ":" + Crypto.sharedInstance.base64ToBase64URL(encrypted.base64EncodedString(options: [])) + "\n")
                if (lines.count >= flushLines) {
                    flush(false);
                }
            }
        } else {
            self.errMsg = "Can't generate IV, skipping data"
            log.error(self.errMsg);
            hasError = true;
        }
    }

    fileprivate func writeLine(_ line: String) {
        hasData = true;
        dataPoints = dataPoints + 1;
        _writeLine(line);
        if (noBuffer) {
            flush(false);
        }
    }

    func store(_ data: [String]) -> Promise<Void> {
        return Promise().then(on: queue) {
            var sanitizedData: [String];
            if (self.sanitize) {
                sanitizedData = [];
                for str in data {
                    sanitizedData.append(str.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "[\t\n\r]", with: " ", options: .regularExpression))
                }
            } else {
                sanitizedData = data;
            }
            let csv = sanitizedData.joined(separator: DataStorage.delimiter);
            self.writeLine(csv)
            return Promise()
        }
    }

    func flush(_ reset: Bool = false) -> Promise<Void> {
        return Promise().then(on: queue) {
            self.logClosures = [ ];
            if (!self.hasData || self.lines.count == 0) {
                if (reset) {
                    self.reset()
                }
                return Promise();
            }
            let data = self.lines.joined(separator: "").data(using: String.Encoding.utf8);
            let lineCount = self.lines.count
            self.lines = [ ];
            if (self.type != "ios_log") {
                self.logClosures.append() {
                    AppEventManager.sharedInstance.logAppEvent(event: "file_flush", msg: "Flushing lines to file", d1: self.name, d2: String(lineCount))
                }
            }
            if let filename = self.filename, let data = data  {
                let fileManager = FileManager.default;
                if (!fileManager.fileExists(atPath: filename.path)) {
                    if (!fileManager.createFile(atPath: filename.path, contents: data, attributes: [FileAttributeKey(rawValue: FileAttributeKey.protectionKey.rawValue): FileProtectionType.none])) {
                        self.hasError = true;
                        self.errMsg = "Failed to create file."
                        log.error(self.errMsg);
                    } else {
                        log.info("Create new data file: \(filename)");
                    }
                    if (self.type != "ios_log") {
                        self.logClosures.append() {
                            AppEventManager.sharedInstance.logAppEvent(event: "file_create", msg: "Create new data file", d1: self.name, d2: String(self.hasError), d3: self.errMsg)
                        }
                    }
                } else {
                    if let fileHandle = try? FileHandle(forWritingTo: filename) {
                        defer {
                            fileHandle.closeFile()
                        }
                        let seekPos = fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                        self.bytesWritten = self.bytesWritten + data.count;
                        log.info("Appended data to file: \(filename), size: \(seekPos)");
                        if (self.bytesWritten > DataStorageManager.MAX_DATAFILE_SIZE) {
                            log.info("Rolling data file: \(filename)")
                            self.reset();
                        }
                    } else {
                        self.hasError = true;
                        self.errMsg = "Error opening file for writing"
                        log.error(self.errMsg);
                        if (self.type != "ios_log") {
                            self.logClosures.append() {
                                AppEventManager.sharedInstance.logAppEvent(event: "file_err", msg: "Error writing to file", d1: self.name, d2: String(self.hasError), d3: self.errMsg)
                            }
                        }
                    }
                }
            } else {
                self.errMsg = "No filename.  NO data??"
                print(self.errMsg);
                self.hasError = true;
                if (self.type != "ios_log") {
                    self.logClosures.append() {
                        AppEventManager.sharedInstance.logAppEvent(event: "file_err", msg: "Error writing to file", d1: self.name, d2: String(self.hasError), d3: self.errMsg)
                    }
                }
                self.reset();
            }
            if (reset) {
                self.reset()
            }
            self.outputLogClosures()
            return Promise()
        }
    }

    func closeAndReset() -> Promise<Void> {
        return flush(true)
    }
}

class DataStorageManager {
    static let sharedInstance = DataStorageManager();
    static let dataFileSuffix = ".csv";
    static let MAX_DATAFILE_SIZE = (1024 * 1024) * 10; // 10Meg

    var publicKey: String?;
    var storageTypes: [String: DataStorage] = [:];
    var study: Study?;
    var secKeyRef: SecKey?;

    static func currentDataDirectory() -> URL {
        let dirPaths = NSSearchPathForDirectoriesInDomains(.cachesDirectory,
                                                           .userDomainMask, true)

        let cacheDir = dirPaths[0]
        return URL(fileURLWithPath: cacheDir).appendingPathComponent("currentdata");
    }

    static func uploadDataDirectory() -> URL {
        let dirPaths = NSSearchPathForDirectoriesInDomains(.cachesDirectory,
                                                           .userDomainMask, true)

        let cacheDir = dirPaths[0]
        return URL(fileURLWithPath: cacheDir).appendingPathComponent("uploaddata");
    }

    func createDirectories() {


        do {
            try FileManager.default.createDirectory(atPath: DataStorageManager.currentDataDirectory().path,
                                                                     withIntermediateDirectories: true,
                                                                     attributes: [FileAttributeKey(rawValue: FileAttributeKey.protectionKey.rawValue): FileProtectionType.none]);
            try FileManager.default.createDirectory(atPath: DataStorageManager.uploadDataDirectory().path,
                                                                     withIntermediateDirectories: true,
                                                                     attributes: [FileAttributeKey(rawValue: FileAttributeKey.protectionKey.rawValue): FileProtectionType.none])
        } catch {
            log.error("Failed to create directories.");
        }
    }

    func setCurrentStudy(_ study: Study, secKeyRef: SecKey?) {
        self.study = study;
        self.secKeyRef = secKeyRef
        if let publicKey = study.studySettings?.clientPublicKey {
            self.publicKey = publicKey
        }

    }

    func createStore(_ type: String, headers: [String]) -> DataStorage? {
        if (storageTypes[type] == nil) {
            if let publicKey = publicKey, let patientId = study?.patientId {
                storageTypes[type] = DataStorage(type: type, headers: headers, patientId: patientId, publicKey: publicKey, keyRef: secKeyRef);
            } else {
                log.error("No public key found! Can't store data");
                return nil;
            }
        }
        return storageTypes[type]!;
    }

    func closeStore(_ type: String) -> Promise<Void> {
        if let storage = storageTypes[type] {
            self.storageTypes.removeValue(forKey: type);
            return storage.flush(false);
        }
        return Promise();
    }


    func _flushAll() -> Promise<Void> {
        var promises: [Promise<Void>] = []
        for (_, storage) in storageTypes {
            promises.append(storage.closeAndReset());
        }
        return when(fulfilled: promises)
    }

    

    func isUploadFile(_ filename: String) -> Bool {
        return filename.hasSuffix(DataStorageManager.dataFileSuffix) || filename.hasSuffix(".mp4") || filename.hasSuffix(".wav")
    }

    func _printFileInfo(_ file: URL) {
        let path = file.path
        var seekPos: UInt64 = 0
        var firstLine: String = ""
        log.info("infoBeginForFile: \(path)")
        if let fileHandle = try? FileHandle(forReadingFrom: file) {
            defer {
                fileHandle.closeFile()
            }
            let dataString = String(data: fileHandle.readData(ofLength: 2048), encoding: String.Encoding.utf8)
            let dataArray = dataString?.characters.split{$0 == "\n"}.map(String.init)
            if let dataArray = dataArray, dataArray.count > 0 {
                firstLine = dataArray[0]
            } else {
                log.warning("No first line found!!")
            }
            seekPos = fileHandle.seekToEndOfFile()
            fileHandle.closeFile()
        } else {
            log.error("Error opening file: \(path) for info");
        }

        log.info("infoForFile: len: \(seekPos), line: \(firstLine), filename: \(path)")


    }
    func _moveFile(_ src: URL, dst: URL) {
        let fileManager = FileManager.default
        do {
            //_printFileInfo(src)
            try fileManager.moveItem(at: src, to: dst)
            //_printFileInfo(dst)
            log.info("moved \(src) to \(dst)");
        } catch {
            log.error("Error moving \(src) to \(dst)");
        }
    }
    func prepareForUpload() -> Promise<Void> {
        // self._flushAll()
        let prepQ = DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default)
        var filesToUpload: [String] = [ ]
        /* Flush once to get all of the files currently processing */
        return self._flushAll().then(on: prepQ) {
            /* And record there names */
            let fileManager = FileManager.default

                let enumerator = fileManager.enumerator(atPath: DataStorageManager.currentDataDirectory().path);

                if let enumerator = enumerator {
                    while let filename = enumerator.nextObject() as? String {
                        if (self.isUploadFile(filename)) {
                            filesToUpload.append(filename)
                        } else {
                            log.warning("Non upload file sitting in directory: \(filename)")
                        }
                    }
                }
                /* Need to flush again, because there is (very slim) one of those files was created after the flush */
                return self._flushAll()
            }.then(on: prepQ) {
                for filename in filesToUpload {
                    let src = DataStorageManager.currentDataDirectory().appendingPathComponent(filename);
                    let dst = DataStorageManager.uploadDataDirectory().appendingPathComponent(filename);
                    self._moveFile(src, dst: dst)
                }
                return Promise()
        }
    }

    func createEncryptedFile(type: String, suffix: String) -> EncryptedStorage {
        return EncryptedStorage(type: type, suffix: suffix, patientId: study!.patientId!, publicKey: PersistentPasswordManager.sharedInstance.publicKeyName(study!.patientId!), keyRef: secKeyRef)
    }
}
