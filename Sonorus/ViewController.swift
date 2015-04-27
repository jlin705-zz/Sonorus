//
//  ViewController.swift
//  MusicPlayerSonata
//
//  Created by jialiang lin on 4/13/15.
//  Copyright (c) 2015 Team15. All rights reserved.
//

import UIKit
import AVFoundation

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
    
    //@IBOutlet var imageView1: UIImageView!
    
    var audioPlayer = AVAudioPlayer()
    var currentAudio = "";
    var audioList:NSMutableArray!
    var currentAudioIndex = 0
    var timer:NSTimer!
    var audioLength = 0.0
    var toggle = true
    var effectToggle = true
    var totalLengthOfAudio = ""
    var finalImage:UIImage!
    var isTableViewOnscreen = false
    var sharedAudioList:NSMutableArray!
    
    
    @IBAction func showPeerList(){
        self.performSegueWithIdentifier("showPeer", sender: self)
    }
    
    
    @IBAction func showLocalList(){
        self.performSegueWithIdentifier("showView", sender: self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        println("hahhahahahah")
        if (segue.identifier == "showView"){
            var upcoming: SharedListViewController = segue.destinationViewController as! SharedListViewController
            upcoming.tableData = self.audioList 
        }
        
        if (segue.identifier == "showPeer"){
            var upcoming: PeerListViewController = segue.destinationViewController as! PeerListViewController
            ///////// add what variable you wanna pass into the new view
            
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1;
    }
    
    func rotationAnimation(){
        let rotation=CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.timingFunction=CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        rotation.toValue=2*M_PI
        rotation.duration=16
        rotation.repeatCount=HUGE
        rotation.autoreverses=false
        photo.layer.addAnimation(rotation, forKey: "rotationAnimation")
    }
    
    func pauseLayer(layer:CALayer){
        var pausedTime:CFTimeInterval=layer.convertTime(CACurrentMediaTime(), fromLayer: nil)
        layer.speed=0.0
        layer.timeOffset=pausedTime
    }
    
    func resumeLayer(layer:CALayer){
        var pausedTime:CFTimeInterval = layer.timeOffset
        layer.speed=1.0
        layer.timeOffset=0.0
        layer.beginTime=0.0
        var timeSincePause:CFTimeInterval=layer.convertTime(CACurrentMediaTime(), fromLayer: nil)-pausedTime
        layer.beginTime=timeSincePause
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        photo.layer.cornerRadius=self.photo.frame.size.width/2.0
        photo.clipsToBounds=true
        photoBorderView.layer.cornerRadius=self.photoBorderView.frame.size.width/2.0
        photoBorderView.clipsToBounds=true
        //blurr
        let blurEffect=UIBlurEffect(style: UIBlurEffectStyle.Dark)
        let blureView=UIVisualEffectView(effect: blurEffect)
        blureView.frame=self.view.frame
        backgroundImageView.addSubview(blureView)

        //set slider icon
        progressSlider.setMinimumTrackImage(UIImage(named: "player_slider_playback_left.png"), forState: UIControlState.Normal)
        progressSlider.setMaximumTrackImage(UIImage(named: "player_slider_playback_right.png"), forState: UIControlState.Normal)
        progressSlider.setThumbImage(UIImage(named: "player_slider_playback_thumb.png"), forState: UIControlState.Normal)
        
        let filemanager:NSFileManager = NSFileManager()
        
        let paths:NSArray = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        
        let basePath: AnyObject! = (paths.count > 0) ? paths.objectAtIndex(0) : nil
        println(basePath)
        
        let files = filemanager.enumeratorAtPath(basePath as! String)
        
        while true {
            if( filemanager.enumeratorAtPath(basePath as! String)?.nextObject() != nil){
                break
            }
        }
        prepareAudio()
        updateLabels()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func showPlayList(sender: UIButton) {
        var playList:MusicListView=NSBundle.mainBundle().loadNibNamed("MusicListView", owner: self, options: nil).last as! MusicListView
        playList.tableData=self.audioList
        playList.viewContorller=self
        playList.showPlayListView()
    }
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool){
        if flag{
            currentAudioIndex++
            if currentAudioIndex>audioList.count-1{
                currentAudioIndex--
                return
            }
            prepareAudio()
            playAudio()
        }
    }
    
    func setAudioPath(audioName: String)->NSURL{
        let paths:NSArray = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        
        let basePath: AnyObject! = (paths.count > 0) ? paths.objectAtIndex(0) : nil
        var s = basePath as! String
        return NSURL(fileURLWithPath: s+"/"+audioName)!
    }
    
    
    func getMusicInfo(musicpath: NSURL)->Song{
        var result = Song()
        let assetUrl = musicpath
        let asset = AVAsset.assetWithURL(assetUrl) as! AVAsset
        
        for metaDataItems:AVMutableMetadataItem in asset.commonMetadata as! [AVMutableMetadataItem] {
            //getting the title of the song
            if metaDataItems.commonKey == "title" {
                let titleData = metaDataItems.value as! NSString
                println("title ---> \(titleData)")
                result.Title = titleData
            }
            //getting the "Artist of the mp3 file"
            if metaDataItems.commonKey == "artist" {
                let artistData = metaDataItems.value as! NSString
                println("artist ---> \(artistData)")
                result.Artist = artistData
            }
            //getting the thumbnail image associated with file
            if metaDataItems.commonKey == "artwork" {
                let imageData = metaDataItems.value as! NSData
                var image2: UIImage = UIImage(data: imageData)!
                //                imageView1.image = image2
                result.Image = image2
            }
        }
        result.AudioPath = musicpath
        return result
    }
    
    func saveCurrentTrackNumber(){
        NSUserDefaults.standardUserDefaults().setObject(currentAudioIndex, forKey:"currentAudioIndex")
        NSUserDefaults.standardUserDefaults().synchronize()
        
    }
    
    func retrieveSavedTrackNumber(){
        
        if let currentAudioIndex_ = NSUserDefaults.standardUserDefaults().objectForKey("currentAudioIndex") as? Int{
            currentAudioIndex = currentAudioIndex_
        }else{
            currentAudioIndex = 0
        }
        
    }
    
    func prepareAudio(){
        setAudioList()
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error: nil)
        AVAudioSession.sharedInstance().setActive(true, error: nil)
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        // TODO: Change to shared list
        var currentSong: Song = audioList[currentAudioIndex] as! Song
        audioPlayer = AVAudioPlayer(contentsOfURL: currentSong.AudioPath, error: nil)
        audioPlayer.delegate = self
        audioLength = audioPlayer.duration
        progressSlider.maximumValue = CFloat(audioPlayer.duration)
        progressSlider.minimumValue = 0.0
        progressSlider.value = 0.0
        audioPlayer.prepareToPlay()
        showTotalSurahLength()
        updateLabels()
        playTimeLabel.text = "00:00"
    }
    
    func  playAudio(){
        audioPlayer.play()
        startTimer()
        updateLabels()
        saveCurrentTrackNumber()
    }
    
    func playNextAudio(){
        currentAudioIndex++
        if currentAudioIndex>audioList.count-1{
            currentAudioIndex--
            
            return
        }
        if audioPlayer.playing{
            prepareAudio()
            playAudio()
        }else{
            prepareAudio()
        }
    }
    
    
    func playPreviousAudio(){
        currentAudioIndex--
        if currentAudioIndex<0{
            currentAudioIndex++
            return
        }
        if audioPlayer.playing{
            prepareAudio()
            playAudio()
        }else{
            prepareAudio()
        }
        
    }
    
    
    func stopAudiplayer(){
        audioPlayer.stop();
        
    }
    
    func pauseAudioPlayer(){
        audioPlayer.pause()
        
    }
    
    func startTimer(){
        if timer == nil {
            timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("update:"), userInfo: nil,repeats: true)
            timer.fire()
        }
    }
    
    func stopTimer(){
        timer.invalidate()
        
    }
    
    
    func update(timer: NSTimer){
        if !audioPlayer.playing{
            return
        }
        
        var minute_ = abs(Int((audioPlayer.currentTime/60) % 60))
        var second_ = abs(Int(audioPlayer.currentTime  % 60))
        
        var minute = minute_ > 9 ? "\(minute_)" : "0\(minute_)"
        var second = second_ > 9 ? "\(second_)" : "0\(second_)"
        
        playTimeLabel.text  = "\(minute):\(second)"
        progressSlider.value = CFloat(audioPlayer.currentTime)
        
    }
    
    
    
    
    func showTotalSurahLength(){
        calculateSurahLength()
        allTimeLabel.text = totalLengthOfAudio
    }
    
    
    func calculateSurahLength(){
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

        audioList = NSMutableArray()
        
        while let file: AnyObject = files?.nextObject() {
                audioList.addObject(getMusicInfo(setAudioPath(file as! String)))
        }
    }
    
    func updateLabels(){
        var currentSong:Song = audioList[currentAudioIndex] as! Song
        titleLabel.text = currentSong.Title as String
        artistLabel.text = currentSong.Artist as String
        photo.image = currentSong.Image
        backgroundImageView.image = photo.image
    }
    
    @IBAction func play(sender : UIButton) {
        let play = UIImage(named: "player_btn_play_normal@2x.png")
        let pause = UIImage(named: "player_btn_pause_normal@2x.png")
        if audioPlayer.playing{
            pauseAudioPlayer()
            audioPlayer.playing ? "\(playButton.setImage( pause, forState: UIControlState.Normal))" : "\(playButton.setImage(play , forState: UIControlState.Normal))"
            pauseLayer(photo.layer)
        }else{
            rotationAnimation()
            playAudio()
            audioPlayer.playing ? "\(playButton.setImage( pause, forState: UIControlState.Normal))" : "\(playButton.setImage(play , forState: UIControlState.Normal))"
            resumeLayer(photo.layer)
        }
    }
    
    
    
    @IBAction func next(sender : AnyObject) {
        playNextAudio()
    }
    
    
    @IBAction func previous(sender : AnyObject) {
        playPreviousAudio()
    }
    
    
    
    
    @IBAction func changeAudioLocationSlider(sender : UISlider) {
        audioPlayer.currentTime = NSTimeInterval(sender.value)
        
    }
    
}

