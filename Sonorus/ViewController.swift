//
//  ViewController.swift
//  MusicPlayerSonorus
//
//  Created by jialiang lin on 4/13/15.
//  Modified by Qinyu Tong on 4/26/15
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//

// ToDo: block ui until list finish

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
    
    var currentAudioIndex = 0
    var timer:NSTimer?
    var audioLength = 0.0
    var totalLengthOfAudio = ""
    var rotation: CABasicAnimation!
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    var isAdvertising: Bool!
    
    let playImage = UIImage(named: "player_btn_play_normal@2x.png")
    let pauseImage = UIImage(named: "player_btn_pause_normal@2x.png")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /**
        Qinyu added
        */
        self.appDelegate.mpcManager.advertiser.startAdvertisingPeer()
        
        var timer = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: Selector("startBrowsing"), userInfo: nil, repeats: false)
        self.isAdvertising = true
        
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "setupService",
            name: "getLeaderNotification", object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleReceiveSongNotification:",
            name: "receivedSongNotification", object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleSyncMessageNotification:",
            name: "receivedSyncNotification", object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleGuestReadyNotification:",
            name: "receivedGuestReadyNotification", object: nil)

        //new added section end
        
        self.photo.layer.cornerRadius = self.photo.frame.size.width/2.0
        self.photo.clipsToBounds = true
        self.photoBorderView.layer.cornerRadius = self.photoBorderView.frame.size.width/2.0
        self.photoBorderView.clipsToBounds = true
        
        //blurr
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        let blureView = UIVisualEffectView(effect: blurEffect)
        blureView.frame = self.view.frame
        self.backgroundImageView.addSubview(blureView)
        
        //set slider icon
        self.progressSlider.setMinimumTrackImage(UIImage(named: "player_slider_playback_left.png"), forState: UIControlState.Normal)
        self.progressSlider.setMaximumTrackImage(UIImage(named: "player_slider_playback_right.png"), forState: UIControlState.Normal)
        self.progressSlider.setThumbImage(UIImage(named: "player_slider_playback_thumb.png"), forState: UIControlState.Normal)
        self.progressSlider.userInteractionEnabled = false
        
        // timer for progress bar
        self.startTimer()
        
        self.setAudioList()
        
        // rotation
        self.rotationAnimation()
        println("LOaddddddd")
        self.pauseLayer(self.photo.layer)
    }
    
    func startBrowsing() {
        if self.appDelegate.mpcManager.leader == nil {
            self.appDelegate.mpcManager.leader = self.appDelegate.mpcManager.peer
            NSNotificationCenter.defaultCenter().postNotificationName("getLeaderNotification", object: nil)
            
            appDelegate.mpcManager.initState = false
        }

        self.appDelegate.mpcManager.browser.startBrowsingForPeers()
    }
    
    
    func setupService() {
        self.appDelegate.clockService.setup()
        self.appDelegate.leaderElection_service.setup()
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
        
        playList.tableData = self.appDelegate.sharedAudioList
        playList.viewController = self
        playList.showShareListView()
    }
    
    @IBAction func play(sender : UIButton) {
        if (self.appDelegate.sharedAudioList.count != 0) {
            if self.audioPlayer!.playing {
                self.sendSyncMessageBroadcast("pause", relativeTime: nil, songIndex: nil)
                self.pauseAudioPlayer()
                
                self.playButton.setImage(playImage, forState: UIControlState.Normal)
                
                self.pauseLayer(self.photo.layer)
            } else {
                self.sendSyncMessageBroadcast("play", relativeTime: self.audioPlayer!.currentTime, songIndex: self.currentAudioIndex)
                self.playAudio()
                
                self.playButton.setImage(self.pauseImage, forState: UIControlState.Normal)
                
                self.resumeLayer(self.photo.layer)
//                self.rotationAnimation()
            }
        }
    }
    
    @IBAction func next(sender : AnyObject) {
        if (self.appDelegate.sharedAudioList.count != 0) {
            self.playNextAudio()
        }
    }
    
    @IBAction func previous(sender : AnyObject) {
        if (self.appDelegate.sharedAudioList.count != 0) {
            self.playPreviousAudio()
        }
    }
    
    @IBAction func changeAudioLocationSlider(sender : UISlider) {
//        self.sendSyncMessage("playAt", relativeTime: sender.value, songIndex: nil)
        self.audioPlayer?.currentTime = NSTimeInterval(sender.value)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "showView") {
            var upcoming: LocalListViewController = segue.destinationViewController as! LocalListViewController
            upcoming.tableData = self.appDelegate.audioList
            upcoming.viewContorller = self
            //upcoming.sharedList = self.appDelegate.sharedAudioList
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
        self.rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        
        self.rotation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        self.rotation.toValue = 2*M_PI
        self.rotation.duration = 16
        self.rotation.repeatCount = HUGE
        self.rotation.autoreverses = false
        
        self.photo.layer.addAnimation(self.rotation, forKey: "rotationAnimation")
        println("start: \(self.photo.layer)")
    }
    
    func pauseLayer(layer: CALayer){
        //println("pause \(layer)")
        if (layer.speed != 0.0){
            var pausedTime:CFTimeInterval = layer.convertTime(CACurrentMediaTime(), fromLayer: self.photo.layer)
            
            layer.timeOffset = pausedTime
            layer.speed = 0.0
            //println("pause: \(pausedTime)")
        }
    }
    
    func resumeLayer(layer:CALayer){
        if (layer.speed == 0.0){
            //println("resume \(layer) \(self.photo.layer)")

            var pausedTime:CFTimeInterval = layer.timeOffset
            layer.timeOffset = 0.0
            layer.beginTime = 0.0
            var timeSincePause:CFTimeInterval = layer.convertTime(CACurrentMediaTime(), fromLayer: self.photo.layer) - pausedTime
            //var timeSincePause:CFTimeInterval = NSDate.timeIntervalSinceReferenceDate() - pausedTime
            //println("current: \(layer.convertTime(CACurrentMediaTime(), fromLayer: self.photo.layer))")
            //println("absolute: \(mach_absolute_time())")
        
        
            layer.beginTime = timeSincePause
            layer.speed = 1.0
            //println(layer.beginTime)
        }
    }
    
    func setPlayButton() {
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.playButton.setImage(self.playImage, forState: UIControlState.Normal)
        }
    }
    
    func setPauseButton() {
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.playButton.setImage(self.pauseImage, forState: UIControlState.Normal)
        }
    }
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
        if flag {
            self.currentAudioIndex++
            
            if self.currentAudioIndex > self.appDelegate.sharedAudioList.count - 1 {
                self.currentAudioIndex = 0
            }
            
            self.prepareAudio()
            
            self.playAudio()
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
    
    func prepareAudio() {
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error: nil)
        AVAudioSession.sharedInstance().setActive(true, error: nil)
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        var currentSong: Song = self.appDelegate.sharedAudioList[currentAudioIndex] as! Song
        //println("Prepare Audio: Current Index: \(currentAudioIndex) \nsong: \(currentSong.Title)")
        
        self.audioPlayer = AVAudioPlayer(contentsOfURL: currentSong.AudioPath, error: nil)
        self.audioPlayer!.delegate = self
        
        self.audioLength = self.audioPlayer!.duration
        
        self.progressSlider.maximumValue = CFloat(self.audioPlayer!.duration)
        self.progressSlider.minimumValue = 0.0
        self.progressSlider.value = 0.0
        
        self.audioPlayer!.prepareToPlay()
        
        self.updateLabels()
        self.showTotalSurahLength()
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.playTimeLabel.text = "00:00"
        }
    }
    
    func playAudio() {
        self.audioPlayer!.play()
    }
    
    func playNextAudio(){
        self.currentAudioIndex++
        
        if self.currentAudioIndex > self.appDelegate.sharedAudioList.count - 1 { //go to the first song
            self.currentAudioIndex = 0
        }
        prepareAudio()
        
        // send sync message
        self.sendSyncMessageBroadcast("switch", relativeTime: 0, songIndex: currentAudioIndex)
        
        playAudio()
        self.playButton.setImage(self.pauseImage, forState: UIControlState.Normal)
        self.resumeLayer(self.photo.layer)
//        self.rotationAnimation()
    }
    
    func playPreviousAudio() {
        self.currentAudioIndex--
        
        if self.currentAudioIndex < 0 { //go to the last song
            self.currentAudioIndex = appDelegate.sharedAudioList.count - 1
        }
        
        self.prepareAudio()
        
        // send sync message
        self.sendSyncMessageBroadcast("switch", relativeTime: 0, songIndex: currentAudioIndex)
        
        self.playAudio()
        self.playButton.setImage(self.pauseImage, forState: UIControlState.Normal)
        self.resumeLayer(self.photo.layer)

//        self.rotationAnimation()
    }
    
    func stopAudiplayer() {
        self.audioPlayer!.stop();
    }
    
    func pauseAudioPlayer() {
        self.audioPlayer!.pause()
    }
    
    func startTimer() {
        if self.timer == nil {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("update"), userInfo: nil,repeats: true)
        }
    }
    
    func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    func update() {
        if self.audioPlayer == nil {
            return
        }
        
        if !self.audioPlayer!.playing{
            return
        }
        
        var minute_ = abs(Int((self.audioPlayer!.currentTime/60) % 60))
        var second_ = abs(Int(self.audioPlayer!.currentTime  % 60))
        
        var minute = minute_ > 9 ? "\(minute_)" : "0\(minute_)"
        var second = second_ > 9 ? "\(second_)" : "0\(second_)"
        
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.playTimeLabel.text  = "\(minute):\(second)"
            self.progressSlider.value = CFloat(self.audioPlayer!.currentTime)
        }
    }
    
    func showTotalSurahLength() {
        self.calculateSurahLength()
        
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.allTimeLabel.text = self.totalLengthOfAudio
        }
    }
    
    func calculateSurahLength() {
        var minute_ = abs(Int((audioLength/60) % 60))
        var second_ = abs(Int(audioLength % 60))
        
        var minute = minute_ > 9 ? "\(minute_)" : "0\(minute_)"
        var second = second_ > 9 ? "\(second_)" : "0\(second_)"
        self.totalLengthOfAudio = "\(minute):\(second)"
    }
    
    func setAudioList() {
        let filemanager:NSFileManager = NSFileManager()
        
        let paths:NSArray = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        
        let basePath: AnyObject! = (paths.count > 0) ? paths.objectAtIndex(0) : nil
        
        let files = filemanager.enumeratorAtPath(basePath as! String)

        self.appDelegate.audioList = NSMutableArray()
        
        while let file: AnyObject = files?.nextObject() {
            if (file as! NSString).containsString(".mp3") {
                self.appDelegate.audioList.addObject(getMusicInfo(setAudioPath(file as! String)))
            }
        }
    }
    
    func updateLabels() {
        var currentSong:Song = appDelegate.sharedAudioList[currentAudioIndex] as! Song
        
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.titleLabel.text = currentSong.Title as String
            self.artistLabel.text = currentSong.Artist as String
            self.photo.image = currentSong.Image
            self.backgroundImageView.image = self.photo.image
        }
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
                if syncMessage.songIndex > self.appDelegate.sharedAudioList.count - 1 {
                    return
                }
                
                self.currentAudioIndex = syncMessage.songIndex!
                prepareAudio()
                
                let relativeTime = syncMessage.relativeTime
                let absoluteTime = syncMessage.absoluteTime
                let diff = appDelegate.clockService.getTimeInterval() - absoluteTime!
                
                self.audioPlayer!.currentTime = relativeTime! + diff
                
                self.playAudio()
                self.setPauseButton()
                dispatch_async(dispatch_get_main_queue()) {
                    () -> Void in
                    self.resumeLayer(self.photo.layer)
                }
            
            case "playAt":
                let relativeTime = syncMessage.relativeTime
                let absoluteTime = syncMessage.absoluteTime
                let diff = appDelegate.clockService.getTimeInterval() - absoluteTime!
                
                self.audioPlayer!.currentTime = relativeTime! + diff
                self.playAudio()
                
            case "pause":
                self.pauseAudioPlayer()
                self.setPlayButton()
                dispatch_async(dispatch_get_main_queue()) {
                    () -> Void in
                    self.pauseLayer(self.photo.layer)
                }
            
            case "switch":
                // prepare song
                if syncMessage.songIndex > self.appDelegate.sharedAudioList.count - 1 {
                    return
                }
                
                self.currentAudioIndex = syncMessage.songIndex!
                prepareAudio()
                
                let relativeTime = syncMessage.relativeTime
                let absoluteTime = syncMessage.absoluteTime
                let diff = self.appDelegate.clockService.getTimeInterval() - absoluteTime!
                
                self.audioPlayer!.currentTime = relativeTime! + diff
                
                self.playAudio()
                self.setPauseButton()
                dispatch_async(dispatch_get_main_queue()) {
                    () -> Void in
                    self.resumeLayer(self.photo.layer)
                }
            
            default:
                println("illegal play message kind")
        }
    }
    
    func handleGuestReadyNotification(notification: NSNotification) {
        // Get the ClockMessage containing the time data and source peer
        let receivedDataDictionary = notification.object as! Dictionary<String, AnyObject>
        
        // "Extract" the data and the source peer from the received dictionary.
        var data = receivedDataDictionary["data"] as! NSData
        let fromPeer = receivedDataDictionary["fromPeer"] as! MCPeerID
        
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            var tempTimer: NSTimer = NSTimer.scheduledTimerWithTimeInterval(5.0, target: self, selector: "sendStartPlayToGuest:", userInfo: fromPeer, repeats: false)
        }
    }
    
    func sendStartPlayToGuest(tempTimer: NSTimer!) {
        if self.audioPlayer?.playing != nil && self.audioPlayer!.playing {
            self.sendSyncMessageUnicast("play", relativeTime: audioPlayer!.currentTime, songIndex: currentAudioIndex, peer: tempTimer.userInfo as! MCPeerID)
        }
    }
    
    func sendSyncMessageBroadcast(type: String, relativeTime: NSTimeInterval?, songIndex: Int?) {
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
        self.appDelegate.mpcManager.sendDataBroadcastReliable(messagePayload: data, messageType: "sync")
    }
    
    func sendSyncMessageUnicast(type: String, relativeTime: NSTimeInterval?, songIndex: Int?, peer: MCPeerID) {
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
        self.appDelegate.mpcManager.sendDataUnicastReliable(messagePayload: data, messageType: "sync", toPeer: peer)
    }
    
    //handle notification posted by mpcmanager
    //when receiving a song from other peers
    func handleReceiveSongNotification(notification: NSNotification){
        let receivedDataDictionary = notification.object as! Dictionary<String, AnyObject>
        
        // "Extract" the song's path from received dictionary.
        let songPath = receivedDataDictionary["songPath"] as! NSURL
        
        //reload the audio list
        self.setAudioList()
        self.appDelegate.sharedAudioList.addObject(getMusicInfo(songPath)) //add song to shared playlist
        
        println("\nhandle received song, add song \(getMusicInfo(songPath).Title)")
        
        if (self.appDelegate.sharedAudioList.count == 1){
            println("first song prepare audio!!!!!!")
            self.prepareAudio()
        }
    }
}

