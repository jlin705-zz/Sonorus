//
//  Clock.swift
//  Clock
//
//  Created by CHC on 4/11/15.
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//

import Foundation
import MultipeerConnectivity

protocol ClockDelegate {
    func displayTime(time: NSDate)
}

class Clock: NSObject {
    var delegate: ClockDelegate?
    
    var hostID: MCPeerID!
    
    var peerID: MCPeerID!
    
    var offset: NSTimeInterval!
    
    var clientTimer: NSTimer?
    
    var showTimer: NSTimer!
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    override init () {
        super.init()
    }
    
    func startClockService() {
        self.hostID = appDelegate.mpcManager.leader
        
        self.peerID = appDelegate.mpcManager.peer
        
        self.offset = 0
        
        // Sync time and create timer to query server
        if self.peerID != self.hostID {
            self.clientSendRequest()
            self.clientTimer = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: "clientSendRequest", userInfo: nil, repeats: true)
        }
        
        var time = self.getTimeInterval()
        var sleepTime = 1000 - time * 1000 % 1000
        usleep(useconds_t(sleepTime))
        // Create timer to show on screen
        self.showTimer = NSTimer.scheduledTimerWithTimeInterval(0.001, target: self, selector: "showTime", userInfo: nil, repeats: true)
        
        // Add observer
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleClockDataWithNotification:",
            name: "receivedClockDataNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleLeaderChangedWithNotification:",
            name: "leaderChangeNotification", object: nil)
    }
    
    func clientSendRequest() {
        // Get originate time stamp
        var message = ClockMessage()
        message.orgtime = NSDate.timeIntervalSinceReferenceDate()
        
        // Archived request message
        let data = NSKeyedArchiver.archivedDataWithRootObject(message)
        
        // Send request message
        if appDelegate.mpcManager.sendDataUnicastUnreliable(messagePayload: data, messageType: "clock", toPeer: hostID) {
            println("Send request to \(hostID.displayName)")
        }
    }
    
    func clientGetReply(message: ClockMessage) {
        // Add destination timestamp
        message.arvtime = NSDate.timeIntervalSinceReferenceDate()
        
        // Update local clock
        self.updateClock(message)
    }
    
    func serverGetRequest(message: ClockMessage, timestamp: NSTimeInterval, fromPeer: MCPeerID) {
        // Add receive timestamp
        message.rectime = timestamp
        
        // After process, add transmit timestamp
        message.xmttime = NSDate.timeIntervalSinceReferenceDate()
        
        // Send reply to client
        var data = NSKeyedArchiver.archivedDataWithRootObject(message)
        
        if appDelegate.mpcManager.sendDataUnicastUnreliable(messagePayload: data, messageType: "clock", toPeer: fromPeer){
            println("send reply to \(fromPeer.displayName)")
        }
    }
    
    func handleClockDataWithNotification(notification: NSNotification) {
        // Before process, get receive time stamp
        var rectime = NSDate.timeIntervalSinceReferenceDate()
        
        // Get the ClockMessage containing the time data and source peer
        let receivedDataDictionary = notification.object as! Dictionary<String, AnyObject>
        
        // "Extract" the data and the source peer from the received dictionary.
        var data = receivedDataDictionary["data"] as! NSData
        let fromPeer = receivedDataDictionary["fromPeer"] as! MCPeerID
        
        // Convert the data to clock message
        let message = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! ClockMessage
        
        if peerID == hostID { //server
            serverGetRequest(message, timestamp: rectime, fromPeer: fromPeer)
        } else { //client
            clientGetReply(message)
        }
    }
    
    func updateClock(message: ClockMessage) {
        var t1 = message.orgtime
        var t2 = message.rectime
        var t3 = message.xmttime
        var t4 = message.arvtime
        
        self.offset = ((t2 - t1) + (t3 - t4))/2
        println(offset)
        
        var time = self.getTimeInterval()
        var sleepTime = 1000 - time * 1000 % 1000
        usleep(useconds_t(sleepTime))
    }
    
    func getClock() -> NSDate {
        var timeInterval = NSDate.timeIntervalSinceReferenceDate()
        timeInterval += offset
        
        return NSDate(timeIntervalSinceReferenceDate: timeInterval)
    }
    
    func getTimeInterval() -> NSTimeInterval {
        return NSDate.timeIntervalSinceReferenceDate() + offset
    }
    
    func showTime() {
        
        
        delegate?.displayTime(self.getClock())
    }
    
    func handleLeaderChangedWithNotification(notification: NSNotification) {
        if self.peerID != self.hostID {
            self.clientTimer?.invalidate()
        } else {
            self.clientTimer = NSTimer.scheduledTimerWithTimeInterval(60, target: self, selector: "clientSendRequest", userInfo: nil, repeats: true)
        }
    }
}
