import AVFoundation
import PKHUD
import UIKit

class AudioQuestionViewController: UIViewController, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    enum AudioState {
        case initial
        case recording
        case recorded
        case playing
    }

    var activeSurvey: ActiveSurvey!
    var maxLen: Int = 60
    var recordingSession: AVAudioSession!
    var recorder: AVAudioRecorder?
    var player: AVAudioPlayer?
    var filename: URL?
    var state: AudioState = .initial
    var timer: Timer?
    var currentLength: Double = 0
    var suffix = ".mp4"

    @IBOutlet weak var maxLengthLabel: UILabel!
    @IBOutlet weak var currentLengthLabel: UILabel!
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet weak var recordPlayButton: UIButton!
    @IBOutlet weak var reRecordButton: BWButton!
    @IBOutlet weak var saveButton: BWButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.promptLabel.text = self.activeSurvey.survey?.questions[0].prompt ?? ""
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(self.cancelButton))
        self.reset()
        self.recordingSession = AVAudioSession.sharedInstance()

        do {
            try self.recordingSession.setCategory(AVAudioSession.Category.playAndRecord)
            try self.recordingSession.setActive(true)
            self.recordingSession.requestRecordPermission { [unowned self] (allowed: Bool) in
                DispatchQueue.main.async {
                    if !allowed {
                        self.fail()
                    }
                }
            }
        } catch {
            self.fail()
        }
        self.updateRecordButton()
        self.recorder = nil

        if let study = StudyManager.sharedInstance.currentStudy {
            // Just need to put any old answer in here...
            self.activeSurvey.bwAnswers["A"] = "A"
            Recline.shared.save(study)
            log.info("Saved.")
        }
    }

    func cleanupAndDismiss() {
        if let filename = filename {
            do {
                try FileManager.default.removeItem(at: filename)
            } catch { }
            self.filename = nil
        }
        self.recorder?.delegate = nil
        self.player?.delegate = nil
        self.recorder?.stop()
        self.player?.stop()
        self.player = nil
        self.recorder = nil
        StudyManager.sharedInstance.surveysUpdatedEvent.emit(0)
        self.navigationController?.popViewController(animated: true)
    }

    @objc func cancelButton() {
        if self.state != .initial {
            let alertController = UIAlertController(title: NSLocalizedString("audio_survey_abandon_recording_alert", comment: ""), message: "", preferredStyle: .actionSheet)

            let leaveAction = UIAlertAction(title: NSLocalizedString("audio_survey_abandon_recording_alert_confirm_button", comment: ""), style: .destructive) { action in
                DispatchQueue.main.async {
                    self.cleanupAndDismiss()
                }
            }
            alertController.addAction(leaveAction)
            let cancelAction = UIAlertAction(title: NSLocalizedString("cancel_button_text", comment: ""), style: .default) { action in
            }
            alertController.addAction(cancelAction)

            self.present(alertController, animated: true) {
            }

        } else {
            self.cleanupAndDismiss()
        }
    }

    func fail() {
        let alertController = UIAlertController(title: NSLocalizedString("recording_alert_title", comment: ""), message: NSLocalizedString("microphone_permission_error", comment: ""), preferredStyle: .alert)

        let OKAction = UIAlertAction(title: NSLocalizedString("ok_button_text", comment: ""), style: .default) { action in
            DispatchQueue.main.async {
                self.cleanupAndDismiss()
            }
        }
        alertController.addAction(OKAction)

        self.present(alertController, animated: true) {
        }
    }

    func updateLengthLabel() {
        self.currentLengthLabel.text = "Length: \(self.currentLength) seconds"
    }

    @objc func recordingTimer() {
        if let recorder = recorder, recorder.currentTime > 0 {
            self.currentLength = round(recorder.currentTime * 10) / 10
            if self.currentLength >= Double(self.maxLen) {
                self.currentLength = Double(self.maxLen)
                if recorder.isRecording {
                    self.resetTimer()
                    recorder.stop()
                }
            }
        }
        self.updateLengthLabel()
    }

    func startRecording() {
        var settings: [String: AnyObject]
        let format = self.activeSurvey.survey?.audioSurveyType ?? "compressed"
        let bitrate = self.activeSurvey.survey?.audioBitrate ?? 64000
        let samplerate = self.activeSurvey.survey?.audioSampleRate ?? 44100

        if format == "compressed" {
            self.suffix = ".mp4"
            settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC) as AnyObject,
                // AVEncoderBitRateKey: bitrate,
                AVEncoderBitRatePerChannelKey: bitrate as AnyObject,
                AVSampleRateKey: Double(samplerate) as AnyObject,
                AVNumberOfChannelsKey: 1 as NSNumber,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue as AnyObject,
            ]
        } else if format == "raw" {
            self.suffix = ".wav"
            settings = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM) as AnyObject,
                // AVEncoderBitRateKey: bitrate * 1024,
                AVSampleRateKey: Double(samplerate) as AnyObject,
                AVNumberOfChannelsKey: 1 as NSNumber,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue as AnyObject,
            ]
        } else {
            return self.fail()
        }

        self.filename = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + self.suffix)

        do {
            // 5
            log.info("Beginning recording")
            self.recorder = try AVAudioRecorder(url: self.filename!, settings: settings)
            self.recorder?.delegate = self
            self.currentLength = 0
            self.state = .recording
            self.updateLengthLabel()
            self.currentLengthLabel.isHidden = false
            self.recorder?.record()
            self.resetTimer()
            self.disableIdleTimer()
            self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.recordingTimer), userInfo: nil, repeats: true)
        } catch let error as NSError {
            log.error("Err: \(error)")
            fail()
        }
        self.updateRecordButton()
    }

    func stopRecording() {
        if let recorder = recorder {
            self.resetTimer()
            recorder.stop()
        }
    }

    func playRecording() {
        if let player = player {
            self.state = .playing
            player.play()
            self.updateRecordButton()
        }
    }

    func stopPlaying() {
        if let player = player {
            self.state = .recorded
            player.stop()
            player.currentTime = 0.0
            self.updateRecordButton()
        }
    }

    @IBAction func recordCancelPressed(_ sender: AnyObject) {
        switch self.state {
        case .initial:
            self.startRecording()
        case .recording:
            self.stopRecording()
        case .recorded:
            self.playRecording()
        case .playing:
            self.stopPlaying()
        }
    }

    func saveEncryptedAudio() {
        let study = StudyManager.sharedInstance.currentStudy!  // There's a study. excellent use of optionals here, really. 🙄
        
        // deal with file, name the file.
        var fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forReadingFrom: self.filename!)
        } catch {
            fatalError("Could not open file for reading?? \(error)")
        }
        let surveyId = self.activeSurvey.survey?.surveyId
        let name = "voiceRecording" + "_" + surveyId!
        let encFile = DataStorageManager.sharedInstance.createEncryptedFile(type: name, suffix: self.suffix)
        
        // open the file, write the file, close the file, close the file but different
        encFile.open()
        self.writeEncryptedData(fileHandle, encFile: encFile)
        encFile.close()
        fileHandle.closeFile()
    }
    
    func writeEncryptedData(_ handle: FileHandle, encFile: EncryptedStorage) {
        var data: Data = handle.readDataToEndOfFile()
        while data.count > 0 {
            encFile.write(data as NSData, writeLen: data.count)
            data = handle.readDataToEndOfFile()
        }
        /* We're done... */
        AppEventManager.sharedInstance.logAppEvent(event: "audio_save_closing", msg: "Closing audio file", d1: encFile.eventualFilename.lastPathComponent)
    }

    @IBAction func saveButtonPressed(_ sender: AnyObject) {
        PKHUD.sharedHUD.dimsBackground = true
        PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false

        HUD.show(.labeledProgress(title: "Saving", subtitle: ""))
        AppEventManager.sharedInstance.logAppEvent(event: "audio_save", msg: "Save audio pressed")
        
        // this used to be in a promise structure with a catch clause, now it is syncronous code and doesn't actually have throw clauses
        do {
            self.saveEncryptedAudio()
            self.activeSurvey.isComplete = true
            StudyManager.sharedInstance.updateActiveSurveys(true)
            HUD.flash(.success, delay: 0.5)
            self.cleanupAndDismiss()
        } catch {
            // IDE should say that this is unreachable.
            AppEventManager.sharedInstance.logAppEvent(event: "audio_save_fail", msg: "Save audio failed", d1: String(describing: error))
            HUD.flash(.labeledError(title: NSLocalizedString("audio_survey_error_saving_title", comment: ""), subtitle: NSLocalizedString("audio_survey_error_saving_text", comment: "")), delay: 2.0) { finished in
                self.cleanupAndDismiss()
            }
        }
    }

    func updateRecordButton() {
        /*
         var imageName: String;
         switch(state) {
         case .Initial:
             imageName = "record"
         case .Playing, .Recording:
             imageName = "stop"
         case .Recorded:
             imageName = "play"
         }

         let image = UIImage(named: imageName)
         recordPlayButton.setImage(image, forState: .Highlighted)
         recordPlayButton.setImage(image, forState: .Normal)
         recordPlayButton.setImage(image, forState: .Disabled)
         */
        var text: String
        switch self.state {
        case .initial:
            text = NSLocalizedString("audio_survey_record_button", comment: "")
        case .playing, .recording:
            text = NSLocalizedString("audio_survey_stop_button", comment: "")
        case .recorded:
            text = NSLocalizedString("audio_survey_play_button", comment: "")
        }
        self.recordPlayButton.setTitle(text, for: .highlighted)
        self.recordPlayButton.setTitle(text, for: UIControl.State())
        self.recordPlayButton.setTitle(text, for: .disabled)
    }

    func resetTimer() {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
    }

    func reset() {
        self.resetTimer()
        self.filename = nil
        self.player = nil
        self.recorder = nil
        self.state = .initial
        // saveButton.enabled = false
        self.saveButton.isHidden = true
        self.reRecordButton.isHidden = true
        self.maxLen = StudyManager.sharedInstance.currentStudy?.studySettings?.voiceRecordingMaxLengthSeconds ?? 60
        // maxLen = 5
        self.maxLengthLabel.text = "Maximum length \(self.maxLen) seconds"
        self.currentLengthLabel.isHidden = true
        self.updateRecordButton()
    }

    @IBAction func reRecordButtonPressed(_ sender: AnyObject) {
        self.recorder?.deleteRecording()
        self.reset()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func enableIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func disableIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        log.debug("recording finished, success: \(flag), len: \(self.currentLength)")
        self.resetTimer()
        self.enableIdleTimer()
        if flag && self.currentLength > 0.0 {
            self.recorder = nil
            self.state = .recorded
            // saveButton.enabled = true
            self.saveButton.isHidden = false
            self.reRecordButton.isHidden = false
            do {
                self.player = try AVAudioPlayer(contentsOf: self.filename!)
                self.player?.delegate = self
            } catch {
                self.reset()
            }
            self.updateRecordButton()
        } else {
            self.recorder?.deleteRecording()
            self.reset()
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        log.error("Error received in audio recorded: \(error)")
        self.enableIdleTimer()
        self.recorder?.deleteRecording()
        self.reset()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if self.state == .playing {
            self.state = .recorded
            self.updateRecordButton()
        }
    }
    
    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
         // Get the new view controller using segue.destinationViewController.
         // Pass the selected object to the new view controller.
     }
     */
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
    return input.rawValue
}
