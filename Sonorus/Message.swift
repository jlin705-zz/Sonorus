//
//  Message.swift
//  MPCRevisited
//
//  Created by Qinyu Tong on 4/11/15.
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//
//

import Foundation

class Message: NSObject, NSCoding {
    var type: String!
    var msg: NSData!
    
    override init(){
    }
    
    init(typeTmp: String!, msgTmp: NSData!) {
        self.type = typeTmp
        self.msg = msgTmp
    }
    
    // MARK: NSCoding
    
    required convenience init(coder decoder: NSCoder) {
        self.init()
        self.type = decoder.decodeObjectForKey("type") as! String?
        self.msg = decoder.decodeObjectForKey("msg") as! NSData?
        
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(self.type, forKey: "type")
        coder.encodeObject(self.msg, forKey: "msg")
    }
}
