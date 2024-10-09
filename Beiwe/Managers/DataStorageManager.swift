import Foundation
import IDZSwiftCommonCrypto
import Security
import Sentry

var FILE_WRITE_FILE_EXISTS_COUNTER = 0

enum DataStorageErrors: Error {
    case cantCreateFile
    case notInitialized
}

/// all file paths in the scope of the app are of this form:
/// /var/mobile/Containers/Data/Application/49ECF24B-85A4-40C1-BC57-92B742C6ED64/Library/Caches/currentdat(a/patientid_accel_1698721703289.csv
/// the uuid is randomized per installation. We could remove it with a splice, but regex would be better. (not implemented)
func shortenPath(_ path_string: String) -> String {
    return shortenPathMore(path_string.replacingOccurrences(of: "/var/mobile/Containers/Data/Application/", with: ""))
}

func shortenPath(_ url: URL) -> String {
    return shortenPath(url.path)
}

// some file paths are also inside uuid/Library/, need to cut that too.
func shortenPathMore(_ path_string: String) -> String {
    if path_string.contains("Library/") {
        return path_string.components(separatedBy: "Library/")[1].description
    }
    // split at library, take the second half, and then remove the first character (a slash)
    return path_string
}

// file creation errors
enum DataStorageError: Error {
    case fileCreationError
}

// we can't resolve an error where it is not possible to move a file to the upload
// folder, but we can try again later. LEFT_BEHIND_FILES is our list of these files.
var LEFT_BEHIND_FILES = [String]()
let LEFT_BEHIND_FILES_LOCK = NSLock()


//////////////////////////////////////// DataStorage Manager ///////////////////////////////////////
//////////////////////////////////////// DataStorage Manager ///////////////////////////////////////
//////////////////////////////////////// DataStorage Manager ///////////////////////////////////////
class DataStorageManager {
    static let sharedInstance = DataStorageManager()
    static let dataFileSuffix = ".csv"

    var secKeyRef: SecKey?
    var initted = false

    ////////////////////////////////////////// Setup ///////////////////////////////////////////////
    
    /// instantiates your DataStorage object - called in every manager
    // All of these error cases are going to crash the app. If you hit these, you did something wrong.
    func createStore(_ type: String, headers: [String]) -> DataStorage {
        //! in order to avoid a race condition we cannot stash data on this object and then access it later, we need to access
        //! it through the StudyManager
        if !self.initted {
            // we tried accessing the keyRef variable on the study manager but that variable would be null.
            // No real understanding of why this code works, except that we always call the dataStorageManagerInit
            // externally to set it just before this runs in an external scope? that would be an Extremely
            // tight time window for a race condition...
            log.error("createStore called before the DataStorageManager received secKeyRef, app should crash now.")
        }
        
        if let study = StudyManager.sharedInstance.currentStudy {
            if let patientId = study.patientId {
                if let studySettings = study.studySettings {
                    if let publicKey = studySettings.clientPublicKey {
                        return DataStorage(
                            type: type, // the file name needs the data type
                            headers: headers, // the csv headers
                            patientId: patientId,
                            publicKey: publicKey,
                            keyRef: self.secKeyRef
                        )
                    } else {
                        fatalError("(createStore) No public key found!")
                    }
                } else {
                    fatalError("(createStore) No study settings found!")
                }
            } else {
                fatalError("(createStore) No patient id found!")
            }
        } else {
            fatalError("(createStore) No study found!")
        }
    }

    func dataStorageManagerInit(_ study: Study, secKeyRef: SecKey?) {
        self.initted = true
        self.secKeyRef = secKeyRef
        // this function used to be called in setCurrentStudy, but there was a looked-like-a-race-condition
        // in stashing these variables early on during app start, and then trying to access them later.
        // Fully removing the stashing of `self.secKeyRef` resulted in
        //   StudyManager().currentStudy?.keyRef
        // causing a null access (wrapped in an if-let statement so we know it was exactly .keyRef, not something else)
        // to occur.
        // Maybe the call to dataStorageManagerInit and passing the non-nullable study forces the compiler to block
        // until keyRef exists on StudyManager.currentStudy. Or somehow its the (optional tho?) secKeyRef that's passed in.
        
        // OLD CODE:
        // self.study = study
        // if let publicKey = study.studySettings?.clientPublicKey {
        //     self.publicKey = publicKey
        // }
    }

    /// see comment about race condition in createStore. We are using the same pattern here because we discovered a race condition
    /// in very similar code over there.
    func createEncryptedFile(type: String, suffix: String) -> EncryptedStorage {
        if !self.initted {
            // return
            fatalError("createEncryptedFile called before the DataStorageManager received secKeyRef, app should crash now.")
        }
        
        if let study = StudyManager.sharedInstance.currentStudy {
            if let patientId = study.patientId {
                if let studySettings = study.studySettings {
                    if let publicKey = studySettings.clientPublicKey {
                        return EncryptedStorage(
                            data_stream_type: type,
                            suffix: suffix,
                            patientId: patientId,
                            publicKey: PersistentPasswordManager.sharedInstance.publicKeyName(patientId),
                            keyRef: self.secKeyRef
                        )
                    } else {
                        fatalError("(createEncryptedFile) No public key found!")
                    }
                } else {
                    fatalError("(createEncryptedFile) No study settings found!")
                }
            } else {
                fatalError("(createEncryptedFile) No patient id found!")
            }
        } else {
            fatalError("(createEncryptedFile) No study found!")
        }
    }
    
    /// creates the currentData and upload directories. app crashes if this fails because that is a fundamental app failure.
    func ensureDirectoriesExist(recur: Int = Constants.RECUR_DEPTH) {
        do {
            try FileManager.default.createDirectory(
                atPath: DataStorageManager.currentDataDirectory().path,
                withIntermediateDirectories: true,
                attributes: [FileAttributeKey(rawValue: FileAttributeKey.protectionKey.rawValue): FileProtectionType.none]
            )
            try FileManager.default.createDirectory(
                atPath: DataStorageManager.uploadDataDirectory().path,
                withIntermediateDirectories: true,
                attributes: [FileAttributeKey(rawValue: FileAttributeKey.protectionKey.rawValue): FileProtectionType.none]
            )
        } catch {
            print("\(error)")
            if recur > 0 {
                log.error("create_directories recur at \(recur).")
                Thread.sleep(forTimeInterval: Constants.RECUR_SLEEP_DURATION)
                return self.ensureDirectoriesExist(recur: recur - 1)
            }
            log.error("Failed to create directories. \(error)")
            fatalError("Failed to create directories. \(error)")
        }
    }
    
    ////////////////////////////////////// Informational ///////////////////////////////////////////
    
    // for years we used the .cache directory. wtaf.
    static func currentDataDirectory() -> URL {
        let cacheDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: cacheDir).appendingPathComponent("currentdata")
    }

    static func uploadDataDirectory() -> URL {
        let cacheDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: cacheDir).appendingPathComponent("uploaddata")
    }
    
    static func oldCurrentDataDirectory() -> URL {
        let cacheDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: cacheDir).appendingPathComponent("currentdata")
    }

    static func oldUploadDataDirectory() -> URL {
        let cacheDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: cacheDir).appendingPathComponent("uploaddata")
    }
    
    func isUploadFile(_ filename: String) -> Bool {
        return filename.hasSuffix(DataStorageManager.dataFileSuffix) || filename.hasSuffix(".mp4") || filename.hasSuffix(".wav")
    }
    
    ///////////////////////////////////////////////// Upload ///////////////////////////////////////
    
    
    /// Moves any left behinde files in the data directory. Called just before upload.
    func moveLeftBehindFilesToUpload() {
        // safely get reference so that it can't be cleared or updated out from under us
        LEFT_BEHIND_FILES_LOCK.lock()
        let left_behind_files = LEFT_BEHIND_FILES
        LEFT_BEHIND_FILES = []
        LEFT_BEHIND_FILES_LOCK.unlock()
        
        var filesToMove: [String] = []
        if let enumerator = FileManager.default.enumerator(atPath: DataStorageManager.currentDataDirectory().path) {
            // for each file check its file type and add to list
            while let filename = enumerator.nextObject() as? String {
                if left_behind_files.contains(filename) {
                    filesToMove.append(filename)
                    print("found left behind file \(filename) to move to uploads.")
                }
            }
        }
        for filename in filesToMove {
            self.moveFile(DataStorageManager.currentDataDirectory().appendingPathComponent(filename),
                          dst: DataStorageManager.uploadDataDirectory().appendingPathComponent(filename))
            print("Moved left behind file \(shortenPath(filename)) to upload directory.")
        }
    }
    
    
    /// called at app start, moves any uploadable files that were never moved to upload to upload folder
    func moveUnknownJunkToUpload() {
        var filesToUpload: [String] = []
        if let enumerator = FileManager.default.enumerator(atPath: DataStorageManager.currentDataDirectory().path) {
            // for each file check its file type and add to list
            while let filename = enumerator.nextObject() as? String {
                if self.isUploadFile(filename) {
                    filesToUpload.append(filename)
                } else {
                    log.warning("Non upload file sitting in currentDataDirectory: \(filename)")
                }
            }
        }
        // move all data in the current data directory to the upload file directory.
        // active files are stored in a temp directory, then moved to the currentDataDirectory. this moves them to the upload directory.
        for filename in filesToUpload {
            self.moveFile(DataStorageManager.currentDataDirectory().appendingPathComponent(filename),
                          dst: DataStorageManager.uploadDataDirectory().appendingPathComponent(filename))
            print("Moved \(shortenPath(filename)) to upload directory.")
        }
    }
    
    // added to cover migration to new app version issue on 2024-2-20 when we updated the app
    // to no longer use the caches folder because that is just AWFUL WHY WAS IT DOING THAT AAUUGGUGU
    func moveOldUnknownJunkToUpload() {
        var filesToUpload: [String] = []
        let old_current_folder = DataStorageManager.oldCurrentDataDirectory()
        
        // check if this folder exists, if it does we need to move files to the new upload director
        if FileManager.default.fileExists(atPath: old_current_folder.path) {
            if let enumerator = FileManager.default.enumerator(atPath: old_current_folder.path) {
                // for each file check its file type and add to list
                while let filename = enumerator.nextObject() as? String {
                    if self.isUploadFile(filename) {
                        filesToUpload.append(filename)
                    } else {
                        print("Non upload file sitting in (old files) directory: \(shortenPath(filename))")
                    }
                }
            }
            for filename in filesToUpload {
                self.moveFile(old_current_folder.appendingPathComponent(filename),
                              dst: DataStorageManager.uploadDataDirectory().appendingPathComponent(filename))
            }
        }
        
        let old_upload_folder = DataStorageManager.oldUploadDataDirectory()
        // and then the same for the old upload files, if present.
        if FileManager.default.fileExists(atPath: old_upload_folder.path) {
            if let enumerator = FileManager.default.enumerator(atPath: old_upload_folder.path) {
                // for each file check its file type and add to list
                while let filename = enumerator.nextObject() as? String {
                    if self.isUploadFile(filename) {
                        filesToUpload.append(filename)
                    } else {
                        print("Non upload file sitting in (old uploads) directory: \(shortenPath(filename))")
                    }
                }
            }
            for filename in filesToUpload {
                self.moveFile(old_upload_folder.appendingPathComponent(filename),
                              dst: DataStorageManager.uploadDataDirectory().appendingPathComponent(filename))
            }
        }
    }
    
    // move file function with retry logic, fails silently but that is ok because it is
    // only used prepareForUpload_actual.
    private func moveFile(_ src: URL, dst: URL, recur: Int = Constants.RECUR_DEPTH) {
        do {
            try FileManager.default.moveItem(at: src, to: dst)
        } catch CocoaError.fileNoSuchFile {
            print("File not found (for moving)? \(shortenPath(src))")
            sentry_warning("File not found (for moving).", shortenPath(src), crash:false)
        } catch CocoaError.fileWriteFileExists {
            // print("File already exists (for moving) \(shortenPath(dst)), giving up for now because that's crazy?")
            // we are getting a huge number of these reported, so throttle by 10x?
            FILE_WRITE_FILE_EXISTS_COUNTER += 1
            if FILE_WRITE_FILE_EXISTS_COUNTER % 10 == 0 {
                sentry_warning("File already exists (for moving).", shortenPath(dst), crash:false)
            }
        } catch CocoaError.fileWriteOutOfSpace {
            // print("Out of space (for moving) \(shortenPath(dst))")
            // sentry_warning("Out of space (for moving).", shortenPath(dst)) // never report out of space like this.
        } catch {
            // known and not handling: fileWriteVolumeReadOnly, fileWriteInvalidFileName
            // print("moving file \(shortenPath(src)) to \(shortenPath(dst))")
            // fatalError("Error moving file \(error)")
            if recur > 0 {
                log.error("moveFile recur at \(recur).")
                Thread.sleep(forTimeInterval: Constants.RECUR_SLEEP_DURATION)
                return self.moveFile(src, dst: dst, recur: recur - 1)
            }
            log.error("Error moving(1) \(src) to \(dst)")
            print("\(error)")
            
//            if let sentry_client = Client.shared {
//                sentry_client.snapshotStacktrace {
//                    let event = Event(level: .error)
//                    event.message = "not a crash - Error moving file 1"
//                    event.environment = Constants.APP_INFO_TAG
//                    
//                    if event.extra == nil {
//                        event.extra = [:]
//                    }
//                    if var extras = event.extra {
//                        extras["from"] = shortenPath(src)
//                        extras["to"] = shortenPath(dst)
//                        extras["error"] = "\(error)"
//                        if let patient_id = StudyManager.sharedInstance.currentStudy?.patientId {
//                            extras["user_id"] = StudyManager.sharedInstance.currentStudy?.patientId
//                        }
//                    }
//                    sentry_client.appendStacktrace(to: event)
//                    sentry_client.send(event: event)
//                }
//            }
        }
    }
    
    // func _printFileInfo(_ file: URL) {
    //     // debugging function - unused
    //     let path = file.path
    //     var seekPos: UInt64 = 0
    //     var firstLine: String = ""
    //
    //     log.info("infoBeginForFile: \(path)")
    //     if let fileHandle = try? FileHandle(forReadingFrom: file) {
    //         defer {
    //             fileHandle.closeFile()
    //         }
    //         let dataString = String(data: fileHandle.readData(ofLength: 2048), encoding: String.Encoding.utf8)
    //         let dataArray = dataString?.split { $0 == "\n" }.map(String.init)
    //         if let dataArray = dataArray, dataArray.count > 0 {
    //             firstLine = dataArray[0]
    //         } else {
    //             log.warning("No first line found!!")
    //         }
    //         seekPos = fileHandle.seekToEndOfFile()
    //         fileHandle.closeFile()
    //     } else {
    //         log.error("Error opening file: \(path) for info")
    //     }
    //     log.info("infoForFile: len: \(seekPos), line: \(firstLine), filename: \(path)")
    // }
}

///////////////////////////////////////////// Data Storage /////////////////////////////////////////
///////////////////////////////////////////// Data Storage /////////////////////////////////////////
///////////////////////////////////////////// Data Storage /////////////////////////////////////////

class DataStorage {
    // participant info (to be factored out)
    var patientId: String // TODO: factor out
    var publicKey: String // string of the public key for local access. TODO: factor out
    var secKeyRef: SecKey? // TODO: make non-optional
    
    // file settings
    var headers: [String] // csv file header line
    var type: String // data stream type
    var name: String // name of this data storage object
    var sanitize: Bool // flag for the store function, replace commas with semicolons. TODO: factor out
    
    // file state
    var aesKey: Data // the current encryption key
    var filename: URL // the current file name
    
    // Locks to deal with critical code. We have at-upload-time threading conflicts, and tighter write conflicts.
    var op_queue: DispatchQueue
    
    // flag used to implement lazy file creation on at the first write operation.
    var file_exists = false
    var file_handle: FileHandle
    
    init(type: String, headers: [String], patientId: String, publicKey: String, keyRef: SecKey?) {
        self.type = type // the type of data stream
        self.patientId = patientId
        self.publicKey = publicKey
        self.headers = headers // the headers for the csv file
        self.secKeyRef = keyRef
        self.sanitize = false
        self.op_queue = DispatchQueue(label: "org.beiwe.\(self.type).write.queue")
        
        //!!! These values are correct but will be reset on first write over in lazy_new_file_setup.
        self.aesKey = Crypto.sharedInstance.newAesKey(Constants.KEYLENGTH)
        self.name = self.patientId + "_" + self.type + "_" + String(Int64(Date().timeIntervalSince1970 * 1000))
        self.filename = DataStorageManager.currentDataDirectory()
            .appendingPathComponent(self.name + DataStorageManager.dataFileSuffix)
        
        // the critical state-management
        self.file_handle = FileHandle()
        self.file_exists = false
    }
    
    ////////////////////////////////////// Informational Functions /////////////////////////////////////////
    
    /// Returns the entire raw string of the first line of a file containing an RSA-encoded decryption key.
    private func get_rsa_line() -> Data {
        // TODO: why are these two functions are not identical, the call to encryptString
        //   have different args, publicKey vs publicKeyId. And self.secKeyRef is sometimes not present?
        if let keyRef = self.secKeyRef {
            return try! Crypto.sharedInstance.base64ToBase64URL(
                (SwiftyRSA.encryptString(
                    Crypto.sharedInstance.base64ToBase64URL(self.aesKey.base64EncodedString()),
                    publicKey: keyRef,
                    padding: []
                )) + "\n").data(using: String.Encoding.utf8)!
        } else {
            return try! Crypto.sharedInstance.base64ToBase64URL(
                (SwiftyRSA.encryptString(
                    Crypto.sharedInstance.base64ToBase64URL(self.aesKey.base64EncodedString()),
                    publicKeyId: PersistentPasswordManager.sharedInstance.publicKeyName(self.patientId),
                    padding: []
                )) + "\n").data(using: String.Encoding.utf8)!
        }
    }
    
    /// Unless self's "type" (data stream) is the ios log, write a message to the ios log.
    private func conditionalApplog(event: String, msg: String = "", d1: String = "", d2: String = "", d3: String = "", d4: String = "") {
        if self.type != "ios_log" {
            AppEventManager.sharedInstance.logAppEvent(event: event, msg: msg, d1: d1, d2: d2, d3: d3)
        }
    }
    
    ////////////////////////////////////// Locking, public functions ///////////////////////////////
    
    /// The write function used for all data streams.
    /// Handles all encryption and file creation.
    public func store(_ data: [String]) {
        self.op_queue.sync {
            self.lazy_new_file_setup() // tests for whether lazy new file operations need to occur.
            self._store(data)
        }
    }
    
    /// The public reset (create new file / retire the old file) function.
    /// (technically file instantiation is lazy, due to this we can skip creating multiple files
    /// if there are multiple calls to reset before there are any calls to store(). )
    public func reset() {
        self.op_queue.sync {
            self.close_file()
        }
    }
    
    ///////////////////////////////// Private functions, file handling /////////////////////////////
    
    /// To reduce junk file creation we have implemented lazy initial file writes.
    /// Files are only created just before they are written to. The actual initial write
    /// contains the server-decryptable encryption key.
    /// This function is called only inside store(), which is the only external function
    /// that should be called for writes.
    private func lazy_new_file_setup(recur: Int = Constants.RECUR_DEPTH) {
        // do nothing if there is already a file
        if self.file_exists {
            return
        }
        
        // set new filename and real filename based on move on close
        self.name = self.patientId + "_" + self.type + "_" + String(Int64(Date().timeIntervalSince1970 * 1000))
        self.filename = DataStorageManager.currentDataDirectory()
            .appendingPathComponent(self.name + DataStorageManager.dataFileSuffix)
        
        // generate a new encryption key
        self.aesKey = Crypto.sharedInstance.newAesKey(Constants.KEYLENGTH)
        
        // Trying to make this safe is really really hard
        do {
            try self.instantiate_the_file() // inserts the RSA encoded AES key as first line
        } catch is DataStorageError {
            if recur == 0 {
                fatalError("Recursion depth hit in lazy_new_file_setup, file creation failed.")
            }
            // guarantee the file has a new name by waiting more than 1 millisecond
            Thread.sleep(forTimeInterval: Constants.RECUR_SLEEP_DURATION)
            return self.lazy_new_file_setup(recur: recur - 1)
        } catch {
            fatalError("Unknown error in lazy_new_file_setup: \(error)")
        }
        
        // writes the csv header as the first normal encrypted line of the file
        self.encrypted_write(self.headers.joined(separator: Constants.DELIMITER))
        
        // log creating new file (doesn't trigger for app log, that would crash).
        self.conditionalApplog(event: "file_init", msg: "Init new data file", d1: self.name)
        
        // new file creation done.
        self.file_exists = true
    }
    
    /// Generally resets file assets, creates the new filename.
    private func close_file() {
        // close the file handle. if it fails... we ignore it. if this happens at any time
        // other than app start then try_move_on_close will probably crash.
        do {
            try self.file_handle.close()
        } catch {
            // nope not even reporting it (it happens at app start for all data streams as nilerror)
            // io_error_report("file close error?", error: error)
        }
        
        // if no file has been creaed yet, e.g. if the last operation called was the reset function,
        // don't do the move file operation, we wait for lazy_new_file_setup to do that.
        if self.file_exists {
            self.try_move_on_close()
        }
        
        // set the file exists flag to false so that the file is created (and new encryption key
        // is generated etc.)
        self.file_exists = false
    }
    
    /// attempts to move a file to its upload location -- OH WAIT NO OF COURSE THIS CONCEPT WAS BUGGED
    private func try_move_on_close(recur: Int = Constants.RECUR_DEPTH) {
        // if move on close fails repeatedly we add it to LEFT_BEHIND_FILES_LOCK and try again
        // later. If THAT fails then it will be moved into the upload folder on app restart.
        
        let target_location = DataStorageManager.uploadDataDirectory()
            .appendingPathComponent(self.name + DataStorageManager.dataFileSuffix)
        // print("moving")
        // print(self.filename)
        // print(target_location)
        
        do {
            try FileManager.default.moveItem(at: self.filename, to: target_location)
            // print("moved temp data file \(shortenPath(self.filename)) to \(shortenPath(target_location))")
        } catch {
            print("Error moving temp data \(shortenPath(self.filename)) to \(shortenPath(target_location))")
            if recur > 0 {
                Thread.sleep(forTimeInterval: Constants.RECUR_SLEEP_DURATION)
                return self.try_move_on_close(recur: recur - 1)
            }
            self.io_error_report(
                "Error moving file on reset after \(Constants.RECUR_DEPTH) tries.",
                error: error,
                more: ["from": shortenPath(self.filename), "to": shortenPath(target_location)],
                crash: false
            )
            LEFT_BEHIND_FILES_LOCK.lock()
            LEFT_BEHIND_FILES.append(self.filename.path)
            LEFT_BEHIND_FILES_LOCK.unlock()
        }
    }
    
    /// Creates the file.
    private func instantiate_the_file() throws {
        // create the file, insert first line
        let created = FileManager.default.createFile(
            atPath: self.filename.path,
            contents: self.get_rsa_line(), // write the RSA encrypted key line
            attributes: [FileAttributeKey(rawValue: FileAttributeKey.protectionKey.rawValue): FileProtectionType.none]
        )
        
        var message = if created { "Create new data file" } else { "Could not create new data file" }
        if !created {
            // does not crash the app but it is a nasty problem
            self.io_error_report("file_creation_1", crash: false)
            throw DataStorageError.fileCreationError
        }
        
        do {
            self.file_handle = try FileHandle(forWritingTo: self.filename)
        } catch {
            // does not crash the app but it is a nasty problem too
            self.io_error_report("file_creation_2", error: error, crash: false)
            throw DataStorageError.fileCreationError
        }
        self.conditionalApplog(event: "file_create", msg: message, d1: self.name)
        print("created file '\(shortenPath(self.filename))'...")
    }
    
    // reports an io error to sentry, prints the error too.
    private func io_error_report(_ message: String, error: Error? = nil, more: [String: String]? = nil, crash: Bool) {
        // These print statements are not showing up reliably?
        if let error = error {
            print("io error: \(message) - error: \(error)")
        } else {
            print("io error: \(message)")
        }
        if let more = more {
            print("more: \(more)")
        }
        
//        if let sentry_client = Client.shared {
//            sentry_client.snapshotStacktrace {
//                let event = Event(level: .error)
//                // this is actually really important for error triage
//                if crash {
//                    event.message = message
//                } else {
//                    event.message = "not a crash - " + message
//                }
//                event.environment = Constants.APP_INFO_TAG
//            
//                //setup
//                if event.extra == nil {
//                    event.extra = [:]
//                }
//                // basics
//                if var extras = event.extra {
//                    extras["filename"] = shortenPath(self.filename)
//                    extras["user_id"] = self.patientId
//                    if let error = error {
//                        extras["error"] = "\(error)"
//                    }
//                }
//                // any extras
//                for (key, value) in more ?? [:] {
//                    event.extra?[key] = value
//                }
//                
//                sentry_client.appendStacktrace(to: event)
//                sentry_client.send(event: event)
//            }
//        }
    }
    
    ///////////////////////////////////////// Actual write logic ///////////////////////////////////////////
    
    /// outer write operation, handles encrypting data and passes it off to the write_raw_to_end_of_file
    private func encrypted_write(_ line: String) {
        let iv: Data = Crypto.sharedInstance.randomBytes(16)
        let encrypted = Crypto.sharedInstance.aesEncrypt(iv, key: self.aesKey, plainText: line)
        let base64_data = (
            Crypto.sharedInstance.base64ToBase64URL(iv.base64EncodedString(options: []))
                + ":"
                + Crypto.sharedInstance.base64ToBase64URL(encrypted.base64EncodedString(options: []))
                + "\n"
        ).data(using: String.Encoding.utf8)!
        self.write_raw_to_end_of_file(base64_data)
    }

    /// Writes a line of data to the end of the current file, has locks to handle single-line-level write contention.
    private func write_raw_to_end_of_file(_ data: Data) {
        self.file_handle.seekToEndOfFile()
        self.file_handle.write(data)
    }
    
    /// This is the main write function for all write operations from all data streams
    // This function is dumb, it should be replaced entirely by encrypted write once the stupid TODO below is addressed.
    private func _store(_ data: [String]) {
        var sanitizedData: [String]
        if self.sanitize {
            // TODO: survey answers and survey timings files have a (naive) comma replacement behavior.
            // This Should Be Moved out of datastorage before the write operation (this factoring is... horrible.
            // Its So Bad. I cannot even. Who with a brain in their head thought this was a good idea.)
            sanitizedData = []
            for line in data {
                sanitizedData.append(
                    line.replacingOccurrences(of: ",", with: ";")
                        .replacingOccurrences(of: "[\t\n\r]", with: " ", options: .regularExpression)
                )
            }
        } else {
            sanitizedData = data
        }
        self.encrypted_write(sanitizedData.joined(separator: Constants.DELIMITER))
    }
}

/////////////////////////////////////////////////////// EncryptedStorage /////////////////////////////////////////////////////
/////////////////////////////////////////////////////// EncryptedStorage /////////////////////////////////////////////////////
/////////////////////////////////////////////////////// EncryptedStorage /////////////////////////////////////////////////////

// EncryptedStorage Originally included a buffered write pattern in AudioQuestionViewController.
// orig comment: only write multiples of 3, since we are base64 encoding and would otherwise end up with padding
//    if (isFlush) // don't know what this variable is anymore....
//        evenLength = self.currentData.length
//    else
//        evenLength = (self.currentData.length / 3) * 3
//    self._write(new_data, len: new_data.length)
//    self.currentData.replaceBytes(in: NSRange(0..<self.currentData.length), withBytes: nil, length: 0)
class EncryptedStorage {
    // (Binary, mostly for audio files) Encrypted Storage
    // files
    var filename: URL
    var eventualFilename: URL
    var debug_shortname: String
    let fileManager = FileManager.default
    var file_handle: FileHandle?
    // encryption
    var publicKey: String
    var aesKey: Data
    var iv: Data
    var secKeyRef: SecKey
    // machinery
    let encryption_queue: DispatchQueue
    var stream_cryptor: StreamCryptor

    init(data_stream_type: String, suffix: String, patientId: String, publicKey: String, keyRef: SecKey?) {
        // queue name
        self.encryption_queue = DispatchQueue(label: "beiwe.dataqueue." + data_stream_type, qos: .userInteractive, attributes: [])
        // file names
        self.debug_shortname = patientId + "_" + data_stream_type + "_" + String(Int64(Date().timeIntervalSince1970 * 1000))
        self.eventualFilename = DataStorageManager.currentDataDirectory().appendingPathComponent(self.debug_shortname + suffix)
        self.filename = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(self.debug_shortname + suffix)
        
        // encryption setup
        self.aesKey = Crypto.sharedInstance.newAesKey(Constants.KEYLENGTH)
        self.iv = Crypto.sharedInstance.randomBytes(16)
        self.publicKey = publicKey
        self.secKeyRef = keyRef!
        let data_for_key = (aesKey as NSData).bytes.bindMemory(to: UInt8.self, capacity: self.aesKey.count)
        let data_for_iv = (iv as NSData).bytes.bindMemory(to: UInt8.self, capacity: self.iv.count)
        self.stream_cryptor = StreamCryptor(
            operation: .encrypt,
            algorithm: .aes,
            options: .PKCS7Padding,
            key: Array(UnsafeBufferPointer(start: data_for_key, count: self.aesKey.count)),
            iv: Array(UnsafeBufferPointer(start: data_for_iv, count: self.iv.count))
        )
    }

    func open() {
        self.encryption_queue.sync {
            self.open_actual()
        }
    }

    func close() {
        self.encryption_queue.sync {
            self.close_actual()
        }
    }

    func write(_ data: NSData?, writeLen: Int) {
        // This is called directly in audio file code
        // log.info("write called on \(self.debug_shortname)...")
        self.encryption_queue.sync {
            self.write_actual(data, writeLen: writeLen)
        }
    }

    private func open_actual(recur: Int = Constants.RECUR_DEPTH) {
        // open file
        if !self.fileManager.createFile(
            atPath: self.filename.path,
            contents: nil,
            attributes: [FileAttributeKey(rawValue: FileAttributeKey.protectionKey.rawValue): FileProtectionType.none])
        {
            if recur > 0 {
                log.error("open_actual recur at \(recur).")
                Thread.sleep(forTimeInterval: Constants.RECUR_SLEEP_DURATION)
                return self.open_actual(recur: recur - 1)
            }
            fatalError("could not create file?")
        }
        self.file_handle = try! FileHandle(forWritingTo: self.filename)

        // write the rsa line and iv immediately
        let rsaLine: String = try! Crypto.sharedInstance.base64ToBase64URL(
            SwiftyRSA.encryptString(
                Crypto.sharedInstance.base64ToBase64URL(self.aesKey.base64EncodedString()),
                publicKey: self.secKeyRef,
                padding: []
            )
        ) + "\n"
        let ivHeader = Crypto.sharedInstance.base64ToBase64URL(self.iv.base64EncodedString()) + ":"
        self.file_handle?.write(rsaLine.data(using: String.Encoding.utf8)!)
        self.file_handle?.write(ivHeader.data(using: String.Encoding.utf8)!)
    }

    private func close_actual() {
        self.file_handle?.closeFile()
        self.file_handle = nil
        print("(closing and) moving temp data file \(shortenPath(self.filename)) to \(shortenPath(self.eventualFilename))")
        do {
            try FileManager.default.moveItem(at: self.filename, to: self.eventualFilename)
        } catch CocoaError.fileNoSuchFile {
            print("close_actual - File not found? \(shortenPath(self.filename))")
        } catch CocoaError.fileWriteFileExists {
            print("close_actual - File already exists \(shortenPath(self.eventualFilename)) - wtf?")
        } catch {
            // print("Error moving file: \(error)")
            fatalError("An Unknown Error occurred moving file \(shortenPath(self.filename)) to \(shortenPath(self.eventualFilename)): \(error)")
        }
    }

    private func write_actual(_ data: NSData?, writeLen: Int) -> Int {
        // core write function, as much as anything here can be said to "write"
        // log.info("write_actual called on \(self.eventualFilename)...")
        let new_data: NSMutableData = NSMutableData()

        // setup to write - this case should be impossible
        if data != nil && writeLen != 0 {
            // log.info("write_actual case 1")
            // Need to encrypt data
            let encryptLen = self.stream_cryptor.getOutputLength(inputByteCount: writeLen)
            let bufferOut = UnsafeMutablePointer<Void>.allocate(capacity: encryptLen)
            var byteCount: Int = 0
            let bufferIn = UnsafeMutableRawPointer(mutating: data!.bytes)
            self.stream_cryptor.update(
                bufferIn: bufferIn,
                byteCountIn: writeLen,
                bufferOut: bufferOut,
                byteCapacityOut: encryptLen,
                byteCountOut: &byteCount
            )
            new_data.append(NSData(bytesNoCopy: bufferOut, length: byteCount) as Data)
        }

        // again, this case should be impossible
        let encryptLen = self.stream_cryptor.getOutputLength(inputByteCount: 0, isFinal: true)
        if encryptLen > 0 {
            // log.info("write_actual case 2")
            // mostly setup of these obscure pointers to an array of data (there must be a better way to do this...)
            let bufferOut = UnsafeMutablePointer<Void>.allocate(capacity: encryptLen)
            var byteCount: Int = 0
            self.stream_cryptor.final(bufferOut: bufferOut, byteCapacityOut: encryptLen, byteCountOut: &byteCount)
            // setup to write an array of appropriate length
            let finalData = NSData(bytesNoCopy: bufferOut, length: byteCount)
            var array = [UInt8](repeating: 0, count: finalData.length / MemoryLayout<UInt8>.size)
            // copy bytes into array (its an array of bytes, length is just length), append to new_data
            finalData.getBytes(&array, length: finalData.length)
            new_data.append(finalData as Data)
        }

        // this was formerly the _write function
        if new_data.length != 0 {
            // log.info("write_actual case 3")
            let dataToWriteBuffer = UnsafeMutableRawPointer(mutating: new_data.bytes)
            let dataToWrite = NSData(bytesNoCopy: dataToWriteBuffer, length: new_data.length, freeWhenDone: false)
            let encodedData: String = Crypto.sharedInstance.base64ToBase64URL(dataToWrite.base64EncodedString(options: []))
            self.file_handle?.write(encodedData.data(using: String.Encoding.utf8)!)
        }
        // log.info("write_actual finished")
        return new_data.length
    }

    deinit {
        if self.file_handle != nil {
            self.file_handle?.closeFile()
            self.file_handle = nil
        }
    }
}
