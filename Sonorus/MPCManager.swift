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
    
    func invitationWasReceived(fromPeer: String)
    
    func connectedWithPeer(peerID: MCPeerID)
}


class MPCManager: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {

    var delegate: MPCManagerDelegate?
    
    var session: MCSession!
    
    var peer: MCPeerID!
    
    var leader: MCPeerID?
    
    var browser: MCNearbyServiceBrowser!
    
    var advertiser: MCNearbyServiceAdvertiser!
    
    var foundPeers = [MCPeerID]()
    var connectedPeers = [MCPeerID]()
    
    var invitationHandler: ((Bool, MCSession!)->Void)!
    
    
    override init() {
        super.init()
        
        //peer = MCPeerID(displayName: "Advaya")//UIDevice.currentDevice().name)
        peer = MCPeerID(displayName: "Huacong \(arc4random())")
        //leader = peer
        connectedPeers.append(peer)
        
        session = MCSession(peer: peer)
        session.delegate = self
        
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: "appcoda-mpc")
        browser.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: "appcoda-mpc")
        advertiser.delegate = self
    }
    
    
    // MARK: MCNearbyServiceBrowserDelegate method implementation
    
    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        //foundPeers.append(peerID)
        println("Found a new peer:")
        println(peerID)
        if leader != nil && peer == leader {
            println("Inviting peer")
            self.browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 20)
        }
        println(self.connectedPeers)
    }
    
    
    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {
        for (index, aPeer) in enumerate(connectedPeers){
            if aPeer == peerID {
                connectedPeers.removeAtIndex(index)
                break
            }
        }
        
        //post notification to to start a new election
        println("lost peer \(peerID)")
        NSNotificationCenter.defaultCenter().postNotificationName("lostPeerNotification", object: nil)
        delegate?.lostPeer()
    }
    
    
    func browser(browser: MCNearbyServiceBrowser!, didNotStartBrowsingForPeers error: NSError!) {
        println(error.localizedDescription)
    }
    
    
    // MARK: MCNearbyServiceAdvertiserDelegate method implementation
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
        //self.invitationHandler = invitationHandler
        
        //delegate?.invitationWasReceived(peerID.displayName)
        if leader == nil {
            leader = peerID
            NSNotificationCenter.defaultCenter().postNotificationName("getLeaderNotification", object: nil)
        }
        invitationHandler(true, self.session)
    }
    
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didNotStartAdvertisingPeer error: NSError!) {
        println(error.localizedDescription)
    }
    
    
    // MARK: MCSessionDelegate method implementation
    
    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        /* switch state{
        case MCSessionState.Connected:
            println("Connected to session: \(session)")
            delegate?.connectedWithPeer(peerID)
            
        case MCSessionState.Connecting:
            println("Connecting to session: \(session)")
            
        default:
            println("Did not connect to session: \(session)")
        } */
        if state == MCSessionState.Connected {
            delegate?.connectedWithPeer(peerID)
        }
        delegate?.foundPeer()
    }
    
    
    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
        let message = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! Message
        if message.type == "clock" {
            let dictionary: [String: AnyObject] = ["data": message.msg, "fromPeer": peerID]
            NSNotificationCenter.defaultCenter().postNotificationName("receivedClockDataNotification", object: dictionary)
        }
        else if message.type == "leaderElection" {
            let dictionary: [String: AnyObject] = ["data": message.msg, "fromPeer": peerID]
            NSNotificationCenter.defaultCenter().postNotificationName("receivedElectionNotification", object: dictionary)
        }
        
        
    }
    
    
    func session(session: MCSession!, didStartReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!) { }
    
    func session(session: MCSession!, didFinishReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, atURL localURL: NSURL!, withError error: NSError!) { }
    
    func session(session: MCSession!, didReceiveStream stream: NSInputStream!, withName streamName: String!, fromPeer peerID: MCPeerID!) { }
    
    
    
    // MARK: Custom method implementation
    
    func sendData(dictionaryWithData dictionary: Dictionary<String, String>, toPeer targetPeer: MCPeerID) -> Bool {
        let dataToSend = NSKeyedArchiver.archivedDataWithRootObject(dictionary)
        let peersArray = NSArray(object: targetPeer)
        var error: NSError?
        
        if !session.sendData(dataToSend, toPeers: peersArray as [AnyObject], withMode: MCSessionSendDataMode.Reliable, error: &error) {
            println(error?.localizedDescription)
            return false
        }
        
        return true
    }
    
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
        
        if !session.sendData(data, toPeers: connectedPeers as [AnyObject], withMode: MCSessionSendDataMode.Reliable, error: &error) {
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
        
        if !session.sendData(data, toPeers: connectedPeers as [AnyObject], withMode: MCSessionSendDataMode.Unreliable, error: &error) {
            println(error?.localizedDescription)
            return false
        }
        
        return true
    }
}
