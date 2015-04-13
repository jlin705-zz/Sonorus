//
//  LeaderElectMessage.swift
//  MPCRevisited
//
//  Created by Qinyu Tong on 4/11/15.
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//
//

import MultipeerConnectivity

class LeaderElectMessage: NSObject, NSCoding {
    var kind: String!
    //var sender: MCPeerID!
    
    override init(){}
    
    init(kindTmp: String!){
        self.kind = kindTmp
        //self.sender = senderTmp
    }
    
    // MARK: NSCoding
    
    required convenience init(coder decoder: NSCoder) {
        self.init()
        self.kind = decoder.decodeObjectForKey("kind") as! String?
        //self.sender = decoder.decodeObjectForKey("sender") as! MCPeerID?
        
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(self.kind, forKey: "kind")
        //coder.encodeObject(self.sender, forKey: "sender")
    }
}
