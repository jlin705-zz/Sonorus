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
    
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    override init(){
    }
    
    
    func setup(){
        leader = appDelegate.mpcManager.leader
        me = appDelegate.mpcManager.peer
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleLostPeer", name: "lostPeerNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleElectionMessage:", name: "receivedElectionNotification", object: nil)
    }
    
    func getLeader() ->MCPeerID!{
        return leader
    }
    
    func handleLostPeer(){
        println("lose peer, start new election")
        startElection()
    }
    
    func startElection(){
        let msgData = NSKeyedArchiver.archivedDataWithRootObject(LeaderElectMessage(kindTmp: "election"))
        receivedAnswer = false //did not receive answer
        
        //broadcast message and wait 1 second for answer
        appDelegate.mpcManager.sendDataBroadcastReliable(messagePayload: msgData, messageType: "leaderElection")

        var waitResponseTimer = NSTimer.scheduledTimerWithTimeInterval(2.0, target: self, selector: Selector("afterWait"), userInfo: nil, repeats: false)
        
    }
    
    func afterWait(){
        if (!receivedAnswer){ //did not receive answer, this process is leader broadcast victory
            let victMsg = NSKeyedArchiver.archivedDataWithRootObject(LeaderElectMessage(kindTmp: "victory"))
            appDelegate.mpcManager.sendDataBroadcastReliable(messagePayload: victMsg, messageType: "leaderElection")
            leader = me //set leader to self
            appDelegate.mpcManager.leader = me
            //notify leader changed
            NSNotificationCenter.defaultCenter().postNotificationName("leaderChangeNotification", object: nil)
        }
        //else keep silent
    }
    
    //leaderChangeNotification
    
    
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
                if me.hashValue > fromPeer.hashValue {    //bigger than the sender
                    let answerData = NSKeyedArchiver.archivedDataWithRootObject(LeaderElectMessage(kindTmp: "answer"))
                    appDelegate.mpcManager.sendDataUnicastReliable(messagePayload: answerData, messageType: "leaderElection", toPeer: fromPeer)
                    
                    startElection() //start a new election
                }
                //else keep silent
            case "answer": //??????
                self.receivedAnswer = true
                self.receiveVictory = false
                //wait for victory, how long should we wait ? test to see
                let waitVictoryTimer = NSTimer.scheduledTimerWithTimeInterval(2.0, target: self, selector: Selector("afterWaitVictory"), userInfo: nil, repeats: false)
            
            case "victory":
                self.receiveVictory = true
                self.leader = fromPeer //save leader
                appDelegate.mpcManager.leader = fromPeer
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