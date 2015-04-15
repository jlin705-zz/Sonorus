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

    //var lock: NSObject!
    
    override init() {
        super.init()
        
        //self.lock = NSObject()
        
        peer = MCPeerID(displayName: "Sonorus \(arc4random())")

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
//        connectedPeers.removeObject(peerID)
//        viewPeers.removeObject(peerID)
        
        println("Lost peer: \(peerID.displayName)")
//        delegate?.lostPeer()
        
        //post notification to to start a new election
//        if peerID == leader {
//            leader = nil
//            NSNotificationCenter.defaultCenter().postNotificationName("lostLeaderNotification", object: nil)
//        }
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
        // add peer back to connectedPeers in case that framework lostPeer accidently
//        if !self.connectedPeers.containsObject(peerID) {
//            self.connectedPeers.addObject(peerID)
//            self.viewPeers.addObject(peerID)
//            
//            self.delegate?.foundPeer()
//        }
        
        let message = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! Message
        
        if message.type == "clock" {
            let dictionary: [String: AnyObject] = ["data": message.msg, "fromPeer": peerID]
            NSNotificationCenter.defaultCenter().postNotificationName("receivedClockDataNotification", object: dictionary)
            
        } else if message.type == "leaderElection" {
            let dictionary: [String: AnyObject] = ["data": message.msg, "fromPeer": peerID]
            NSNotificationCenter.defaultCenter().postNotificationName("receivedElectionNotification", object: dictionary)
        }
    }
    
    
    func session(session: MCSession!, didStartReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!) { }
    
    func session(session: MCSession!, didFinishReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, atURL localURL: NSURL!, withError error: NSError!) { }
    
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
        
        if !session.sendData(data, toPeers: self.connectedPeers.allObjects, withMode: MCSessionSendDataMode.Reliable, error: &error) {
            println(error?.localizedDescription)
            return false
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
        
        if !session.sendData(data, toPeers: self.connectedPeers.allObjects, withMode: MCSessionSendDataMode.Unreliable, error: &error) {
            println(error?.localizedDescription)
            return false
        }
        
        return true
    }
    
    func leaderChange () {
        delegate?.leaderChange()
    }
}
