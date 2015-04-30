//
//  MPCManager.swift
//  MPCRevisited
//
//  Created by Advaya Krishna on 4/13/15.
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//

import UIKit
import MultipeerConnectivity


protocol MPCManagerDelegate {
    func foundPeer()
    
    func lostPeer()
    
    func connectedWithPeer()
    
    func leaderChange()
}


class MPCManager: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {

    var delegate: MPCManagerDelegate?
    
    var session: MCSession!
    
    var peer: MCPeerID!
    
    var leader: MCPeerID?
    
    var browser: MCNearbyServiceBrowser!
    
    var advertiser: MCNearbyServiceAdvertiser!
    
    var connectedPeers = NSMutableSet() //for broadcast, not include self
    
    var viewPeers = NSMutableSet() //for display, include self

    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    let fileManager = NSFileManager.defaultManager()
    
    var initPlaylist = NSMutableArray()
    
    var initPLcount = 0
    
    var initState = true

    //var lock: NSObject!
    
    override init() {
        super.init()
        
        var deviceName = UIDevice.currentDevice().name

        if deviceName == "iPhone Simulator" {
            peer = MCPeerID(displayName: "Sonorus \(arc4random())")
        } else {
            peer = MCPeerID(displayName: deviceName)
        }

        viewPeers.addObject(peer)
        
        session = MCSession(peer: peer)
        session.delegate = self
        
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: "sonorus")
        browser.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: "sonorus")
        advertiser.delegate = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "leaderChange",
            name: "leaderChangeNotification", object: nil)
    }
    
    func quit() {
        println("quit, disconnect")
        session.disconnect()
    }
    
    
    // MARK: MCNearbyServiceBrowserDelegate method implementation
    
    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        println("Found peer: \(peerID.displayName)")
        if leader != nil && leader == peer {
            println("Inviting peer")
            self.browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 20)
        }
        //println(self.connectedPeers)
    }
    
    
    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {
        println("Lost peer: \(peerID.displayName)")
    }
    
    
    func browser(browser: MCNearbyServiceBrowser!, didNotStartBrowsingForPeers error: NSError!) {
        println(error.localizedDescription)
    }
    
    
    // MARK: MCNearbyServiceAdvertiserDelegate method implementation
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
        
        leader = peerID
        delegate?.leaderChange()
        invitationHandler(true, self.session)
        
        NSNotificationCenter.defaultCenter().postNotificationName("getLeaderNotification", object: nil)
    }
    
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didNotStartAdvertisingPeer error: NSError!) {
        println(error.localizedDescription)
    }
    
    
    // MARK: MCSessionDelegate method implementation
    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        switch state{
            case MCSessionState.Connected:
                //println("Connected to session: \(session)")
                println("Connected to session")
                println("Connected with a new peer: \(peerID.displayName)")
                
                connectedPeers.addObject(peerID)
                viewPeers.addObject(peerID)
                
                delegate?.connectedWithPeer()
            
                if leader != nil && leader == peer {
                    sendPlaylist(peerID: peerID)
                }
            
            case MCSessionState.Connecting:
                //println("Connecting to session: \(session)")
                println("Connecting to session \(peerID.displayName)")
            
            case MCSessionState.NotConnected:
                println("Session lost \(peerID.displayName)")
            
                // Update connected peers list
                connectedPeers.removeObject(peerID)
                viewPeers.removeObject(peerID)

                //post notification to to start a new election
                //objc_sync_enter(lock)
                if peerID == leader {
                    leader = nil
                    println("send lost leader notification")
                    NSNotificationCenter.defaultCenter().postNotificationName("lostLeaderNotification", object: nil)
                }
                //objc_sync_exit(lock)
            
                delegate?.lostPeer()

            default:
                println("Unknown state \(state)")
        }
    }
    
    
    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
        
        let message = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! Message
        
        switch message.type {
            case "clock":
                let dictionary: [String: AnyObject] = ["data": message.msg, "fromPeer": peerID]
                NSNotificationCenter.defaultCenter().postNotificationName("receivedClockDataNotification", object: dictionary)
            
            case "leaderElection":
                let dictionary: [String: AnyObject] = ["data": message.msg, "fromPeer": peerID]
                NSNotificationCenter.defaultCenter().postNotificationName("receivedElectionNotification", object: dictionary)
            
            case "sync":
                if (!initState){ //if in init playlist state, ignore all sync message, or didnot finish receiving the file
                    let dictionary: [String: AnyObject] = ["data": message.msg, "fromPeer": peerID]
                    NSNotificationCenter.defaultCenter().postNotificationName("receivedSyncNotification", object: dictionary)
                }
            
            case "ready":
                let dictionary: [String: AnyObject] = ["data": message.msg, "fromPeer": peerID]
                NSNotificationCenter.defaultCenter().postNotificationName("receivedGuestReadyNotification", object: dictionary)
            
            case "songLookup":
                self.handleSongLookup(message, fromPeer: peerID)
            
            case "songRequest":
                //let dict: [String:AnyObject] = NSKeyedUnarchiver.unarchiveObjectWithData(message.msg)! as! [String:AnyObject]
                let song = NSKeyedUnarchiver.unarchiveObjectWithData(message.msg)! as! Song //dict["song"] as! Song
                sendFile(song, withPeer: peerID)
            
            case "playlist":
                println("case playlist")
                self.handlePlaylist(message, fromPeer: peerID)
            
            default:
                println("Error message type \(message.type)")
                break
        }
    }
    
    
    func session(session: MCSession!, didStartReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!) {
        println("start receving file \(resourceName)")
    }
    
    func session(session: MCSession!, didFinishReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, atURL localURL: NSURL!, withError error: NSError!) {
        println("finished receving file \(resourceName)")
        
       let paths:NSArray = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        
        let basePath: AnyObject! = (paths.count > 0) ? paths.objectAtIndex(0) : nil
        
        let s = basePath as! String
        let dstURL = NSURL(fileURLWithPath: s + "/" + resourceName + ".mp3")
        
        fileManager.moveItemAtURL(localURL, toURL: dstURL!, error: nil)
        
        if (self.initState){
            //change url of the song
            for var i = 0; i < initPlaylist.count; i++ {
                var song = initPlaylist[i] as! Song
                println("============\nsong path\(song.AudioPath)\n")
                if (song.Title == resourceName){
                    song.AudioPath = dstURL!
                    let tmp = initPlaylist[i] as! Song
                    println("changed path\(tmp.AudioPath)\n===========")
                    break
                }
            }
            
            self.initPLcount += 1
            
            if (self.initPLcount == initPlaylist.count){ //all songs are received
                self.initState = false
                //TODO: post all notifications
                for var i = 0; i < initPlaylist.count; i++ {
                    var song = initPlaylist[i] as! Song
                    let dictionary: [String: AnyObject] = ["songPath": song.AudioPath]
                    NSNotificationCenter.defaultCenter().postNotificationName("receivedSongNotification", object: dictionary)
                }
                sendReadyMessage(peerID)
                println("send ready message")
            }
            
        }
        else{
            let dictionary: [String: AnyObject] = ["songPath": dstURL!]
            NSNotificationCenter.defaultCenter().postNotificationName("receivedSongNotification", object: dictionary)
            sendReadyMessage(peerID)
            println("send ready message")
        }
    }
    
    func session(session: MCSession!, didReceiveStream stream: NSInputStream!, withName streamName: String!, fromPeer peerID: MCPeerID!) { }
    
    
    
    // MARK: Custom method implementation
    func sendDataUnicastReliable(messagePayload payload: NSData, messageType type: String, toPeer targetPeer: MCPeerID) -> Bool{
        
        let peersArray = NSArray(object: targetPeer)
        var error: NSError?
        
        // Pack type and data into message and convert to sendData
        let message = Message(typeTmp: type, msgTmp: payload)
        let data = NSKeyedArchiver.archivedDataWithRootObject(message)
        
        if !session.sendData(data, toPeers: peersArray as [AnyObject], withMode: MCSessionSendDataMode.Reliable, error: &error) {
            println(error?.localizedDescription)
            return false
        }
        
        return true
    }
    
    func sendDataBroadcastReliable(messagePayload payload: NSData, messageType type: String) -> Bool {
        var error: NSError?
        
        // Pack type and data into message and convert to sendData
        let message = Message(typeTmp: type, msgTmp: payload)
        let data = NSKeyedArchiver.archivedDataWithRootObject(message)
        
        println("boradcast \(type) to:")
        
        if self.connectedPeers.count > 0 {
            if !session.sendData(data, toPeers: self.connectedPeers.allObjects, withMode: MCSessionSendDataMode.Reliable, error: &error) {
                println(error?.localizedDescription)
                return false
            }
        }
        
        return true
    }
    
    func sendDataUnicastUnreliable(messagePayload payload: NSData, messageType type: String, toPeer targetPeer: MCPeerID) -> Bool{
        
        let peersArray = NSArray(object: targetPeer)
        var error: NSError?
        
        // Pack type and data into message and convert to sendData
        let message = Message(typeTmp: type, msgTmp: payload)
        let data = NSKeyedArchiver.archivedDataWithRootObject(message) 
        
        if !session.sendData(data, toPeers: peersArray as [AnyObject], withMode: MCSessionSendDataMode.Unreliable, error: &error) {
            println(error?.localizedDescription)
            return false
        }
        
        return true
    }
    
    func sendDataBroadcastUnreliable(messagePayload payload: NSData, messageType type: String) -> Bool {
        var error: NSError?
        
        // Pack type and data into message and convert to sendData
        let message = Message(typeTmp: type, msgTmp: payload)
        let data = NSKeyedArchiver.archivedDataWithRootObject(message)
        
        if self.connectedPeers.count > 0 {
            if !session.sendData(data, toPeers: self.connectedPeers.allObjects, withMode: MCSessionSendDataMode.Unreliable, error: &error) {
                println(error?.localizedDescription)
                return false
            }
        }
        
        return true
    }
    
    func leaderChange () {
        delegate?.leaderChange()
    }
    
    func sendPlaylist(#peerID: MCPeerID) {
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        dispatch_async(backgroundQueue, {
            var tempList = NSMutableArray()
            for item in self.appDelegate.sharedAudioList {
                tempList.addObject(item)
            }
            let data = NSKeyedArchiver.archivedDataWithRootObject(tempList)
            //let data = NSKeyedArchiver.archivedDataWithRootObject(self.appDelegate.sharedAudioList!)
            let result = self.sendDataUnicastReliable(messagePayload: data, messageType: "playlist", toPeer: peerID)
            println("Sent playlist")
        })
    }
    
    //qinyu added
    func sendFileRequest(#song: Song, targetPeer: MCPeerID) {
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        dispatch_async(backgroundQueue, {
            let data = NSKeyedArchiver.archivedDataWithRootObject(song)
            let result = self.sendDataUnicastReliable(messagePayload: data, messageType: "songRequest", toPeer: targetPeer)
            println("Sent song request: " + (song.Title as String))
        })
    }
    
    func sendFileLookup(#song: Song) {
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        dispatch_async(backgroundQueue, {
            let data = NSKeyedArchiver.archivedDataWithRootObject(song)
            let result = self.sendDataBroadcastReliable(messagePayload: data, messageType: "songLookup")
            println("Sent song lookup: " + (song.Title as String))
        })
    }
    
    func sendFile(song: Song, withPeer peerID: MCPeerID) {
        session.sendResourceAtURL(song.AudioPath, withName: song.Title as String, toPeer: peerID, withCompletionHandler: sendFileHandler)
        
    }
    
    func sendFileHandler(error: NSError!) -> Void {
        println("file send complete")
    }
    
    //qinyu added
    func sendReadyMessage(targetPeer: MCPeerID) {
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        dispatch_async(backgroundQueue, {
            let result = self.sendDataUnicastReliable(messagePayload: NSData(), messageType: "ready", toPeer: targetPeer)
            println("Sent ready message")
        })
    }
    
    func handleSongLookup(message: Message, fromPeer peerID: MCPeerID!) {
        //let dict: [String:AnyObject] = NSKeyedUnarchiver.unarchiveObjectWithData(message.msg)! as! [String:AnyObject]
        let song = NSKeyedUnarchiver.unarchiveObjectWithData(message.msg)! as! Song//dict["song"] as! Song
        println("lookup: " + (song.Title as String) + (song.Artist as String))
        println(appDelegate.audioList.count)
        for localSong in appDelegate.audioList as NSArray{
            let s = localSong as! Song
            println("local: " + (s.Title as String) + (s.Artist as String))
            if (s.Title as String) == (song.Title as String) &&
                (s.Artist as String) == (song.Artist as String) {
                    println("Song already on disk: " + (s.Title as String))
                    
                    if (self.initState){
                        //change url of the song
                        for var i = 0; i < initPlaylist.count; i++ {
                            var song = initPlaylist[i] as! Song
                            println("============\nsong path\(song.AudioPath)\n")
                            if (song.Title as String == localSong.Title as String){
                                song.AudioPath = localSong.AudioPath
                                let tmp = initPlaylist[i] as! Song
                                println("changed path\(tmp.AudioPath)\n===========")
                                break
                            }
                        }
                        
                        self.initPLcount += 1
                        
                        if (self.initPLcount == initPlaylist.count){ //all songs are received
                            self.initState = false
                            //post all notifications
                            for var i = 0; i < initPlaylist.count; i++ {
                                var song = initPlaylist[i] as! Song
                                let dictionary: [String: AnyObject] = ["songPath": song.AudioPath]
                                NSNotificationCenter.defaultCenter().postNotificationName("receivedSongNotification", object: dictionary)
                            }
                            sendReadyMessage(peerID)
                            println("send ready message")
                        }
                    }
                    else{ //normal add song
                        let dictionary: [String: AnyObject] = ["songPath": s.AudioPath]
                        NSNotificationCenter.defaultCenter().postNotificationName("receivedSongNotification", object: dictionary)
                    }
                    return
            }
        }
        println((song.Title as String) + " not found, sending file request")
        sendFileRequest(song: song, targetPeer: peerID)
    }
    
    func handlePlaylist(message: Message, fromPeer peerID: MCPeerID!) {
        println("receive playlist");
        //let dict: [String:AnyObject] = NSKeyedUnarchiver.unarchiveObjectWithData(message.msg)! as! [String:AnyObject]
        initPlaylist = NSKeyedUnarchiver.unarchiveObjectWithData(message.msg)! as! NSMutableArray//dict["playlist"] as!NSMutableArray
        if(initPlaylist.count == 0){ //empty share playlist, out initstate
            println("empty share playlist! out init state")
            self.initState = false
        }
        else{
            for (var i = 0; i < initPlaylist.count; i++){
                let inSong = initPlaylist[i] as! Song
                var isLocal = false
                for (var j = 0; j < appDelegate.audioList.count; j++){
                    let localSong = appDelegate.audioList[j] as! Song
                    if (inSong.Title as String == localSong.Title as String){
                        self.initPLcount++
                        inSong.AudioPath = localSong.AudioPath
                        let tmp = initPlaylist[i] as! Song
                        println("============\nchanged path\(tmp.AudioPath)\n===========")
                        isLocal = true
                        break
                    }
                }
                if (!isLocal){ //not in local, request song
                    sendFileRequest(song: inSong, targetPeer: peerID)
                }
            }
            if (self.initPLcount == initPlaylist.count){ //all songs in local, init Playlist done
                self.initState = false
                //post notifications
                for var i = 0; i < initPlaylist.count; i++ {
                    var song = initPlaylist[i] as! Song
                    let dictionary: [String: AnyObject] = ["songPath": song.AudioPath]
                    NSNotificationCenter.defaultCenter().postNotificationName("receivedSongNotification", object: dictionary)
                }
                
                sendReadyMessage(peerID)
                println("send ready message")
            }
        }
    }
}
