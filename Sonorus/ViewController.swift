//
//  ViewController.swift
//  MusicPlayerSonorus
//
//  Created by jialiang lin on 4/13/15.
//  Modified by Qinyu Tong on 4/26/15
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//

import UIKit
import AVFoundation
import MultipeerConnectivity

class ViewController: UIViewController, UITableViewDelegate,AVAudioPlayerDelegate {
    
    @IBOutlet weak var photoBorderView: UIView!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var photo: UIImageView!
    @IBOutlet weak var playButton:UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel:UILabel!
    @IBOutlet weak var playTimeLabel:UILabel!
    @IBOutlet weak var allTimeLabel:UILabel!
    
    
    var audioPlayer: AVAudioPlayer?
    var currentAudio = "";
    //var audioList:NSMutableArray! = NSMutableArray()
    var currentAudioIndex = 0
    var timer:NSTimer!
    var audioLength = 0.0
    var toggle = true
    var effectToggle = true
    var totalLengthOfAudio = ""
    var finalImage:UIImage!
    var isTableViewOnscreen = false
    var sharedAudioList:NSMutableArray! = NSMutableArray()
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    var isAdvertising: Bool!
    
    let playImage = UIImage(named: "player_btn_play_normal@2x.png")
    let pauseImage = UIImage(named: "player_btn_pause_normal@2x.png")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /**
        Qinyu added
        */
        appDelegate.mpcManager.advertiser.startAdvertisingPeer()
        
        var timer = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: Selector("startBrowsing"), userInfo: nil, repeats: false)
        isAdvertising = true
        
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "startClockAndLeaderElectionService",
            name: "getLeaderNotification", object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleReceiveSongNotification:",
            name: "receiveSongNotification", object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleSyncMessageNotification:",
            name: "receiveSyncNotification", object: nil)

        //new added section end
        
        photo.layer.cornerRadius = self.photo.frame.size.width/2.0
        photo.clipsToBounds = true
        photoBorderView.layer.cornerRadius = self.photoBorderView.frame.size.width/2.0
        photoBorderView.clipsToBounds = true
        
        //blurr
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        let blureView = UIVisualEffectView(effect: blurEffect)
        blureView.frame = self.view.frame
        backgroundImageView.addSubview(blureView)
        
        //set slider icon
        progressSlider.setMinimumTrackImage(UIImage(named: "player_slider_playback_left.png"), forState: UIControlState.Normal)
        progressSlider.setMaximumTrackImage(UIImage(named: "player_slider_playback_right.png"), forState: UIControlState.Normal)
        progressSlider.setThumbImage(UIImage(named: "player_slider_playback_thumb.png"), forState: UIControlState.Normal)
        
        setAudioList()
        
        // rotation
        rotationAnimation()
        pauseLayer(photo.layer)
        
        if (sharedAudioList.count != 0){
            prepareAudio()
            self.updatePrepareAudioUI()
        }
    }
    
    func startBrowsing() {
        if appDelegate.mpcManager.leader == nil {
            appDelegate.mpcManager.leader = appDelegate.mpcManager.peer
            NSNotificationCenter.defaultCenter().postNotificationName("getLeaderNotification", object: nil)
        }
        //tblPeers.reloadData()
        appDelegate.mpcManager.browser.startBrowsingForPeers()
    }
    
    
    func startClockAndLeaderElectionService() {
        appDelegate.clockService.setup()
        appDelegate.leaderElection_service.setup()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func showPeerList() {
        self.performSegueWithIdentifier("showPeer", sender: self)
    }
    
    @IBAction func showLocalList() {
        self.performSegueWithIdentifier("showView", sender: self)
    }
    
    @IBAction func showPlayList(sender: UIButton) {
        var playList:ShareListView = NSBundle.mainBundle().loadNibNamed("ShareListView", owner: self, options: nil).last as! ShareListView
        
        playList.tableData = self.sharedAudioList
        playList.viewController = self
        playList.showShareListView()
    }
    
    @IBAction func play(sender : UIButton) {
        if (sharedAudioList.count != 0) {
            if audioPlayer!.playing {
                self.sendSyncMessage("pause", relativeTime: nil, songIndex: nil)
                self.pauseAudioPlayer()
                
                self.playButton.setImage(playImage, forState: UIControlState.Normal)
                
                self.pauseLayer(photo.layer)
            } else {
                self.sendSyncMessage("play", relativeTime: audioPlayer!.currentTime, songIndex: currentAudioIndex)
                self.playAudio()
                self.updatePlayAudioUI()
                
                self.playButton.setImage(pauseImage, forState: UIControlState.Normal)
                
                self.resumeLayer(photo.layer)
            }
        }
    }
    
    @IBAction func next(sender : AnyObject) {
        if (sharedAudioList.count != 0) {
            self.playNextAudio()
        }
    }
    
    @IBAction func previous(sender : AnyObject) {
        if (sharedAudioList.count != 0) {
            self.playPreviousAudio()
        }
    }
    
    @IBAction func changeAudioLocationSlider(sender : UISlider) {
//        self.sendSyncMessage("playAt", relativeTime: sender.value, songIndex: nil)
        audioPlayer?.currentTime = NSTimeInterval(sender.value)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "showView") {
            var upcoming: LocalListViewController = segue.destinationViewController as! LocalListViewController
            upcoming.tableData = self.appDelegate.audioList
            upcoming.sharedList = self.sharedAudioList
        }
        
        if (segue.identifier == "showPeer") {
            var upcoming: PeerListViewController = segue.destinationViewController as! PeerListViewController
            ///////// add what variable you wanna pass into the new view
            
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1;
    }
    
    func rotationAnimation() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        
        rotation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        rotation.toValue = 2*M_PI
        rotation.duration = 16
        rotation.repeatCount = HUGE
        rotation.autoreverses = false
        
        photo.layer.addAnimation(rotation, forKey: "rotationAnimation")
    }
    
    func pauseLayer(layer:CALayer){
        var pausedTime:CFTimeInterval = layer.convertTime(CACurrentMediaTime(), fromLayer: nil)
        layer.speed = 0.0
        layer.timeOffset = pausedTime
    }
    
    func resumeLayer(layer:CALayer){
        var pausedTime:CFTimeInterval = layer.timeOffset
        
        layer.speed = 1.0
        layer.timeOffset = 0.0
        layer.beginTime = 0.0
        
        var timeSincePause:CFTimeInterval = layer.convertTime(CACurrentMediaTime(), fromLayer: nil) - pausedTime
        
        layer.beginTime = timeSincePause
    }
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
        if flag {
            currentAudioIndex++
            
            if currentAudioIndex > sharedAudioList.count - 1 {
                currentAudioIndex = 0
            }
            
            self.prepareAudio()
            self.updatePrepareAudioUI()
            
            self.playAudio()
            self.updatePlayAudioUI()
        }
    }
    
    func setAudioPath(audioName: String) -> NSURL {
        let paths:NSArray = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        
        let basePath: AnyObject! = (paths.count > 0) ? paths.objectAtIndex(0) : nil
        var s = basePath as! String
        
        return NSURL(fileURLWithPath: s + "/" + audioName)!
    }
    
    func getMusicInfo(musicpath: NSURL) -> Song {
        var result = Song()
        let assetUrl = musicpath
        let asset = AVAsset.assetWithURL(assetUrl) as! AVAsset
        
        for metaDataItems:AVMutableMetadataItem in asset.commonMetadata as! [AVMutableMetadataItem] {
            //getting the title of the song
            if metaDataItems.commonKey == "title" {
                let titleData = metaDataItems.value as! NSString
                //println("title ---> \(titleData)")
                result.Title = titleData
            }
            
            //getting the "Artist of the mp3 file"
            if metaDataItems.commonKey == "artist" {
                let artistData = metaDataItems.value as! NSString
                //println("artist ---> \(artistData)")
                result.Artist = artistData
            }
            
            //getting the thumbnail image associated with file
            if metaDataItems.commonKey == "artwork" {
                let imageData = metaDataItems.value as! NSData
                var image2: UIImage = UIImage(data: imageData)!
                //imageView1.image = image2
                result.Image = image2
            }
        }
        
        result.AudioPath = musicpath
        return result
    }
    
    func saveCurrentTrackNumber() {
        NSUserDefaults.standardUserDefaults().setObject(currentAudioIndex, forKey:"currentAudioIndex")
        NSUserDefaults.standardUserDefaults().synchronize()
        
    }
    
    func retrieveSavedTrackNumber() {
        if let currentAudioIndex_ = NSUserDefaults.standardUserDefaults().objectForKey("currentAudioIndex") as? Int{
            currentAudioIndex = currentAudioIndex_
        } else {
            currentAudioIndex = 0
        }
    }
    
    func prepareAudio() {
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error: nil)
        AVAudioSession.sharedInstance().setActive(true, error: nil)
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        println("Current Audio Index: \(currentAudioIndex)")
        
        var currentSong: Song = sharedAudioList[currentAudioIndex] as! Song
        
        println(currentSong.AudioPath)
        
        audioPlayer = AVAudioPlayer(contentsOfURL: currentSong.AudioPath, error: nil)
        audioPlayer!.delegate = self
        
        audioLength = audioPlayer!.duration
        
        progressSlider.maximumValue = CFloat(audioPlayer!.duration)
        progressSlider.minimumValue = 0.0
        progressSlider.value = 0.0
        
        audioPlayer!.prepareToPlay()
        
        
    }
    
    func updatePrepareAudioUI() {
        updateLabels()
        
        showTotalSurahLength()
        
        playTimeLabel.text = "00:00"
    }
    
    func playAudio() {
        audioPlayer!.play()
    }
    
    func updatePlayAudioUI() {
        startTimer()
        updateLabels()
        //saveCurrentTrackNumber()
    }
    
    func playNextAudio(){
        currentAudioIndex++
        
        if currentAudioIndex > sharedAudioList.count - 1 { //go to the first song
            currentAudioIndex = 0
        }
        prepareAudio()
        self.updatePrepareAudioUI()
        
        // send sync message
        self.sendSyncMessage("switch", relativeTime: 0, songIndex: currentAudioIndex)
        
        let playingBefore: Bool? = audioPlayer?.playing
        
        playAudio()
        self.updatePlayAudioUI()
        self.playButton.setImage(self.pauseImage, forState: UIControlState.Normal)
        
        if playingBefore != nil && playingBefore == false {
            self.resumeLayer(self.photo.layer)
        }
    }
    
    func playPreviousAudio() {
        currentAudioIndex--
        
        if currentAudioIndex < 0 { //go to the last song
            currentAudioIndex = sharedAudioList.count - 1
        }
        
        prepareAudio()
        self.updatePrepareAudioUI()
        
        // send sync message
        self.sendSyncMessage("switch", relativeTime: 0, songIndex: currentAudioIndex)
        
        let playingBefore: Bool? = audioPlayer?.playing
        
        playAudio()
        self.updatePlayAudioUI()
        self.playButton.setImage(self.pauseImage, forState: UIControlState.Normal)
        
        if playingBefore != nil && playingBefore == false {
            self.resumeLayer(self.photo.layer)
        }
    }
    
    func stopAudiplayer() {
        audioPlayer!.stop();
    }
    
    func pauseAudioPlayer() {
        audioPlayer!.pause()
    }
    
    func startTimer() {
        if timer == nil {
            timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("update:"), userInfo: nil,repeats: true)
        }
    }
    
    func stopTimer() {
        timer.invalidate()
    }
    
    func update(timer: NSTimer) {
        if !audioPlayer!.playing{
            return
        }
        
        var minute_ = abs(Int((audioPlayer!.currentTime/60) % 60))
        var second_ = abs(Int(audioPlayer!.currentTime  % 60))
        
        var minute = minute_ > 9 ? "\(minute_)" : "0\(minute_)"
        var second = second_ > 9 ? "\(second_)" : "0\(second_)"
        
        playTimeLabel.text  = "\(minute):\(second)"
        progressSlider.value = CFloat(audioPlayer!.currentTime)
    }
    
    func showTotalSurahLength() {
        calculateSurahLength()
        allTimeLabel.text = totalLengthOfAudio
    }
    
    func calculateSurahLength() {
        var minute_ = abs(Int((audioLength/60) % 60))
        var second_ = abs(Int(audioLength % 60))
        
        var minute = minute_ > 9 ? "\(minute_)" : "0\(minute_)"
        var second = second_ > 9 ? "\(second_)" : "0\(second_)"
        totalLengthOfAudio = "\(minute):\(second)"
    }
    
    func setAudioList() {
        let filemanager:NSFileManager = NSFileManager()
        
        let paths:NSArray = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        
        let basePath: AnyObject! = (paths.count > 0) ? paths.objectAtIndex(0) : nil
        println(basePath)
        
        let files = filemanager.enumeratorAtPath(basePath as! String)

        appDelegate.audioList = NSMutableArray()
        
        while let file: AnyObject = files?.nextObject() {
            appDelegate.audioList.addObject(getMusicInfo(setAudioPath(file as! String)))
        }
    }
    
    func updateLabels() {
        var currentSong:Song = sharedAudioList[currentAudioIndex] as! Song
        
        titleLabel.text = currentSong.Title as String
        artistLabel.text = currentSong.Artist as String
        photo.image = currentSong.Image
        backgroundImageView.image = photo.image
    }
    
    func handleSyncMessageNotification(notification: NSNotification) {
        // Get the ClockMessage containing the time data and source peer
        let receivedDataDictionary = notification.object as! Dictionary<String, AnyObject>
        
        // "Extract" the data and the source peer from the received dictionary.
        var data = receivedDataDictionary["data"] as! NSData
        let fromPeer = receivedDataDictionary["fromPeer"] as! MCPeerID
        
        // Convert the data to clock message
        let syncMessage = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! SyncMessage
        
        println("Receive Sync Message \(syncMessage.kind)")
        
        switch syncMessage.kind {
            case "play":
                // prepare song
                currentAudioIndex = syncMessage.songIndex!
                prepareAudio()
                dispatch_async(dispatch_get_main_queue()) {
                    () -> Void in
                    self.updatePrepareAudioUI()
                }
                
                let relativeTime = syncMessage.relativeTime
                let absoluteTime = syncMessage.absoluteTime
                let diff = appDelegate.clockService.getTimeInterval() - absoluteTime!
                
                audioPlayer!.currentTime = relativeTime! + diff
                
                self.playAudio()
                
                dispatch_async(dispatch_get_main_queue()) {
                    () -> Void in
                    self.updatePlayAudioUI()
                    self.playButton.setImage(self.pauseImage, forState: UIControlState.Normal)
                    self.resumeLayer(self.photo.layer)
                }
                
                
                
            case "playAt":
                let relativeTime = syncMessage.relativeTime
                let absoluteTime = syncMessage.absoluteTime
                let diff = appDelegate.clockService.getTimeInterval() - absoluteTime!
                
                audioPlayer!.currentTime = relativeTime! + diff
                playAudio()
                
            case "pause":
                self.pauseAudioPlayer()
                
                dispatch_async(dispatch_get_main_queue()) {
                    () -> Void in
                    self.playButton.setImage(self.playImage, forState: UIControlState.Normal)
                    self.pauseLayer(self.photo.layer)
                }
            
            case "switch":
                // prepare song
                currentAudioIndex = syncMessage.songIndex!
                prepareAudio()
                dispatch_async(dispatch_get_main_queue()) {
                    () -> Void in
                    self.updatePrepareAudioUI()
                }
                
                let relativeTime = syncMessage.relativeTime
                let absoluteTime = syncMessage.absoluteTime
                let diff = appDelegate.clockService.getTimeInterval() - absoluteTime!
                
                audioPlayer!.currentTime = relativeTime! + diff
                
                let playingBefore: Bool? = audioPlayer?.playing
                
                self.playAudio()
                dispatch_async(dispatch_get_main_queue()) {
                    () -> Void in
                    self.updatePlayAudioUI()
                    self.playButton.setImage(self.pauseImage, forState: UIControlState.Normal)
                    self.resumeLayer(self.photo.layer)
                }
            
                if playingBefore != nil && playingBefore == false {
                    dispatch_async(dispatch_get_main_queue()) {
                        () -> Void in
                        self.resumeLayer(self.photo.layer)
                    }
                }
            
            default:
                println("illegal play message kind")
        }
    }
    
    func sendSyncMessage(type: String, relativeTime: NSTimeInterval?, songIndex: Int?) {
        // Generate sync message
        var syncMessage = SyncMessage()
        syncMessage.kind = type
        
        switch type {
            case "play":
                syncMessage.relativeTime = relativeTime
                syncMessage.absoluteTime = appDelegate.clockService.getTimeInterval()
                syncMessage.songIndex = songIndex
                println("Send Sync Message \(syncMessage.kind) \(syncMessage.relativeTime) \(syncMessage.absoluteTime) \(syncMessage.songIndex)")
            
            case "pause":
                println("Send Sync Message \(syncMessage.kind)")
                break
                
            case "playAt":
                syncMessage.relativeTime = relativeTime
                syncMessage.absoluteTime = appDelegate.clockService.getTimeInterval()
                
            case "switch":
                syncMessage.relativeTime = relativeTime
                syncMessage.absoluteTime = appDelegate.clockService.getTimeInterval()
                syncMessage.songIndex = songIndex
                
            default:
                break
        }
        
        // Archived sync message
        let data = NSKeyedArchiver.archivedDataWithRootObject(syncMessage)
        
        // Send sync message
        appDelegate.mpcManager.sendDataBroadcastReliable(messagePayload: data, messageType: "sync")
    }
    
    //handle notification posted by mpcmanager
    //when receiving a song from other peers
    func handleReceiveSongNotification(notification: NSNotification){
        let receivedDataDictionary = notification.object as! Dictionary<String, AnyObject>
        
        // "Extract" the song's path from received dictionary.
        let songPath = receivedDataDictionary["songPath"] as! NSURL
        
        //reload the audio list
        setAudioList()
        sharedAudioList.addObject(getMusicInfo(songPath)) //add song to shared playlist
        
        println("\n handle received song, add song \(songPath)")
        
        self.prepareAudio()
        
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            if (self.sharedAudioList.count != 0){
                self.updatePrepareAudioUI()
            }
        }
    }
}

