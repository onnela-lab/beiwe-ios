//
//  AudioQuestionViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/25/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import AVFoundation
import PKHUD
import PromiseKit


class AudioQuestionViewController: UIViewController, AVAudioRecorderDelegate, AVAudioPlayerDelegate {

    enum AudioState {
        case Initial
        case Recording
        case Recorded
        case Playing
    }
    var activeSurvey: ActiveSurvey!
    var maxLen: Int = 60;
    var recordingSession: AVAudioSession!
    var recorder: AVAudioRecorder?
    var player: AVAudioPlayer?
    var filename: NSURL!
    var state: AudioState = .Initial
    var timer: NSTimer?
    var currentLength: Double = 0
    var suffix = ".mp4"
    let OUTPUT_CHUNK_SIZE = 128 * 1024

    @IBOutlet weak var maxLengthLabel: UILabel!
    @IBOutlet weak var currentLengthLabel: UILabel!
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet weak var recordPlayButton: UIButton!
    @IBOutlet weak var reRecordButton: BWButton!
    @IBOutlet weak var saveButton: BWButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        promptLabel.text = activeSurvey.survey?.questions[0].prompt

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action:  #selector(cancelButton))

        reset()

        filename = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSUUID().UUIDString + ".mp4")

        recordingSession = AVAudioSession.sharedInstance()

        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] (allowed: Bool) -> Void in
                dispatch_async(dispatch_get_main_queue()) {
                    if !allowed {
                        self.fail()
                    }
                }
            }
        } catch {
            fail()
        }
        updateRecordButton()
        recorder = nil

        if let study = StudyManager.sharedInstance.currentStudy {
            // Just need to put any old answer in here...
            activeSurvey.bwAnswers["A"] = "A"
            Recline.shared.save(study).then {_ in
                print("Saved.");
                }.error {_ in
                    print("Error saving updated answers.");
            }
        }


    }

    func cleanupAndDismiss() {
        do {
            try NSFileManager.defaultManager().removeItemAtURL(filename)
        } catch { }
        recorder?.delegate = nil
        player?.delegate = nil
        recorder?.stop()
        player?.stop()
        player = nil;
        recorder = nil
        StudyManager.sharedInstance.surveysUpdatedEvent.emit();
        self.navigationController?.popViewControllerAnimated(true)
    }
    func cancelButton() {
        if (state != .Initial) {
            let alertController = UIAlertController(title: "Abandon recording?", message: "", preferredStyle: .ActionSheet)

            let leaveAction = UIAlertAction(title: "Abandon", style: .Destructive) { (action) in
                dispatch_async(dispatch_get_main_queue()) {
                    self.cleanupAndDismiss()
                }
            }
            alertController.addAction(leaveAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .Default) { (action) in
            }
            alertController.addAction(cancelAction)


            self.presentViewController(alertController, animated: true) {
                print("Ok");
            }

        } else {
            cleanupAndDismiss()
        }
    }

    func fail() {
        let alertController = UIAlertController(title: "Recording", message: "Unable to record.  You must allow access to the microphone to answer an audio question", preferredStyle: .Alert)

        let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in
            dispatch_async(dispatch_get_main_queue()) {
                self.cleanupAndDismiss()
            }
        }
        alertController.addAction(OKAction)

        self.presentViewController(alertController, animated: true) {
            print("Ok");
        }
    }

    func updateLengthLabel() {
        currentLengthLabel.text = "Length: \(currentLength) seconds"
    }

    func recordingTimer() {
        if let recorder = recorder {
            currentLength = round(recorder.currentTime * 10) / 10
            if (currentLength >= Double(maxLen)) {
                currentLength = Double(maxLen)
                if (recorder.recording) {
                    recorder.stop()
                }
            }

        }
        updateLengthLabel()
    }
    func startRecording() {
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVEncoderBitRateKey: 64 * 1024,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1 as NSNumber,
            AVEncoderAudioQualityKey: AVAudioQuality.High.rawValue
        ]

        do {
            // 5
            recorder = try AVAudioRecorder(URL: filename, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            state = .Recording
            updateLengthLabel()
            currentLengthLabel.hidden = false
            currentLength = 0;
            timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(recordingTimer), userInfo: nil, repeats: true)
        } catch  let error as NSError{
            print("Err: \(error)")
            fail()
        }
        updateRecordButton()
    }

    func stopRecording() {
        if let recorder = recorder {
            recorder.stop()
        }
    }

    func playRecording() {
        if let player = player {
            state = .Playing
            player.play()
            updateRecordButton()
        }
    }

    func stopPlaying() {
        if let player = player {
            state = .Recorded
            player.stop()
            player.currentTime = 0.0
            updateRecordButton()
        }
    }

    @IBAction func recordCancelPressed(sender: AnyObject) {
        switch(state) {
        case .Initial:
            startRecording()
        case .Recording:
            stopRecording()
        case .Recorded:
            playRecording()
        case .Playing:
            stopPlaying()
        }
    }

    func writeSomeData(handle: NSFileHandle, encFile: EncryptedStorage) -> Promise<Void> {
        return Promise().then(on: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND , 0)) {
            let data: NSData = handle.readDataOfLength(self.OUTPUT_CHUNK_SIZE)
            if (data.length > 0) {
                return encFile.write(data, writeLen: data.length).then {
                    return self.writeSomeData(handle, encFile: encFile)
                }
            }
            /* We're done... */
            return encFile.close()
        }

    }

    func saveEncryptedAudio() -> Promise<Void> {
        if let study = StudyManager.sharedInstance.currentStudy {
            var fileHandle: NSFileHandle
            do {
                fileHandle = try NSFileHandle(forReadingFromURL: filename)
            } catch {
                return Promise<Void>(error: BWErrors.IOError)
            }
            let encFile = EncryptedStorage(type: "voiceRecording", suffix: suffix, patientId: study.patientId!, publicKey: PersistentPasswordManager.sharedInstance.publicKeyName())
            return encFile.open().then {
                return self.writeSomeData(fileHandle, encFile: encFile)
            }.always {
                fileHandle.closeFile()
            }
        } else {
            return Promise<Void>(error: BWErrors.IOError)
        }
        /*
        return Promise<Void> { fulfill, reject in
            let is: NSInputStream? = NSInputStream(URL: self.filename)
            if (!)
        }
        */
    }
    @IBAction func saveButtonPressed(sender: AnyObject) {
        PKHUD.sharedHUD.dimsBackground = true;
        PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false;

        HUD.show(.LabeledProgress(title: "Saving", subtitle: ""))

        return saveEncryptedAudio().then { _ -> Void in
            HUD.flash(.Success, delay: 0.5)
            self.cleanupAndDismiss()
        }.onError { _ in
            HUD.flash(.LabeledError(title: "Error Saving", subtitle: "Audio answer not sent"), delay: 2.0) { finished in
                self.cleanupAndDismiss()
            }
        }

        //activeSurvey.isComplete = true;
        //StudyManager.sharedInstance.updateActiveSurveys(true);
    }

    func updateRecordButton() {
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
    }
    func reset() {
        if let timer = timer {
            timer.invalidate();
        }
        player = nil
        recorder = nil
        state = .Initial
        saveButton.enabled = false
        reRecordButton.hidden = true
        maxLen = StudyManager.sharedInstance.currentStudy?.studySettings?.voiceRecordingMaxLengthSeconds ?? 60
        maxLen = 5
        maxLengthLabel.text = "Maximum length \(maxLen) seconds"
        currentLengthLabel.hidden = true
        updateRecordButton()
    }
    @IBAction func reRecordButtonPressed(sender: AnyObject) {
        recorder?.deleteRecording()
        reset()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {
        if let timer = timer {
            timer.invalidate()
        }
        if (flag && currentLength > 0) {
            self.recorder = nil
            state = .Recorded
            saveButton.enabled = true
            reRecordButton.hidden = false
            do {
                player = try AVAudioPlayer(contentsOfURL: filename)
                player?.delegate = self
            } catch {
                reset()
            }
            updateRecordButton()
        } else {
            self.recorder?.deleteRecording()
            reset()
        }
    }

    func audioRecorderEncodeErrorDidOccur(recorder: AVAudioRecorder, error: NSError?) {
        self.recorder?.deleteRecording()
        reset()
    }

    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        if (state == .Playing) {
            state = .Recorded
            updateRecordButton()
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