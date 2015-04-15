//
//  LeaderElection.swift
//  MPCRevisited
//
//  Created by Qinyu Tong on 4/10/15.
//  Copyright (c) 2015 Appcoda. All rights reserved.
//
import MultipeerConnectivity

class LeaderElection: NSObject{
    var me: MCPeerID!
    var leader : MCPeerID!
    var receivedAnswer: Bool!
    var receiveVictory: Bool!
    
    var waitResponseTimer: NSTimer?
    var waitVictoryTimer: NSTimer?
    
    var isInElection: Bool!
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    override init(){
    }
    
    
    func setup(){
        leader = appDelegate.mpcManager.leader
        me = appDelegate.mpcManager.peer
        
        self.receivedAnswer = false //did not receive answer
        self.receiveVictory = false
        self.isInElection = false
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleLostLeader", name: "lostLeaderNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleElectionMessage:", name: "receivedElectionNotification", object: nil)
    }
    
    func getLeader() ->MCPeerID!{
        return leader
    }
    
    func handleLostLeader(){
        println("Lost leader, start new election")
        if !self.isInElection {
            self.isInElection = true
            startElection()
        }
    }
    
    func startElection(){
        println("start election!!!!!!")
        
        let msgData = NSKeyedArchiver.archivedDataWithRootObject(LeaderElectMessage(kindTmp: "election"))
        
        // Initialize state
        self.receivedAnswer = false //did not receive answer
        self.receiveVictory = false
        
        // Stop previous timer
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.waitResponseTimer?.invalidate()
            self.waitVictoryTimer?.invalidate()
        }
        
        //broadcast message and wait 2 second for answer
        appDelegate.mpcManager.sendDataBroadcastReliable(messagePayload: msgData, messageType: "leaderElection")
        
        println("before timer")
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.waitResponseTimer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: "afterWait", userInfo: nil, repeats: false)
        }
    }
    
    func afterWait(){
        println("after wait \(receivedAnswer)")
        
        if (!receivedAnswer){ //did not receive answer, this process is leader broadcast victory
            let victMsg = NSKeyedArchiver.archivedDataWithRootObject(LeaderElectMessage(kindTmp: "victory"))
            
            appDelegate.mpcManager.sendDataBroadcastReliable(messagePayload: victMsg, messageType: "leaderElection")
            
            leader = me //set leader to self
            appDelegate.mpcManager.leader = me
            self.isInElection = false
            
            println("change leader to \(me.displayName)")
            
            //notify leader changed
            NSNotificationCenter.defaultCenter().postNotificationName("leaderChangeNotification", object: nil)
        }
        //else keep silent
    }
    
    
    //communication layer receive a election msg, use this method to respond
    func handleElectionMessage(notification: NSNotification){
        let receivedDataDictionary = notification.object as! Dictionary<String, AnyObject>
        
        // "Extract" the data and the source peer from the received dictionary.
        let data = receivedDataDictionary["data"] as? NSData
        let fromPeer = receivedDataDictionary["fromPeer"] as! MCPeerID

        let electMsg = NSKeyedUnarchiver.unarchiveObjectWithData(data!) as! LeaderElectMessage
        
        println("electMsg: \(electMsg.kind), \(fromPeer)")
        
        switch electMsg.kind{
            case "election":
                self.isInElection = true
                println("me \(me.hashValue) fromPeer \(fromPeer.hashValue)")
                if me.hashValue > fromPeer.hashValue {    //bigger than the sender
                    let answerData = NSKeyedArchiver.archivedDataWithRootObject(LeaderElectMessage(kindTmp: "answer"))
                    appDelegate.mpcManager.sendDataUnicastReliable(messagePayload: answerData, messageType: "leaderElection", toPeer: fromPeer)
                    
                    println("send answer to \(fromPeer)")
                    startElection() //start a new election
                }
                //else keep silent
            
                //wait for victory, how long should we wait ? test to see
                self.waitVictoryTimer?.invalidate()
                dispatch_async(dispatch_get_main_queue()) {
                    () -> Void in
                    self.waitVictoryTimer = NSTimer.scheduledTimerWithTimeInterval(10.0, target: self, selector: "afterWaitVictory", userInfo: nil, repeats: false)
                }

            case "answer": //??????
                self.receivedAnswer = true
                println("receive Answer from \(fromPeer)")
                //wait for victory, how long should we wait ? test to see
                self.waitVictoryTimer?.invalidate()
                dispatch_async(dispatch_get_main_queue()) {
                    () -> Void in
                    self.waitVictoryTimer = NSTimer.scheduledTimerWithTimeInterval(10.0, target: self, selector: "afterWaitVictory", userInfo: nil, repeats: false)
                }
            
            case "victory":
                self.receiveVictory = true
                self.leader = fromPeer //save leader
                self.isInElection = false
                
                appDelegate.mpcManager.leader = fromPeer
                println("change leader to \(fromPeer.displayName)")
                NSNotificationCenter.defaultCenter().postNotificationName("leaderChangeNotification", object: nil)
            
            default:
                println("illegel election msg kind")
        }
    }
    
    func afterWaitVictory(){
        if !receiveVictory {    //if did not receive victory msg, start new election
            println("received answer but no victory message received, start new election")
            startElection()
        }
    }
}