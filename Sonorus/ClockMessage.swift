//
//  ClockMessage.swift
//  Clock
//
//  Created by CHC on 4/11/15.
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//

import Foundation

class ClockMessage: NSObject, NSCoding {
    var orgtime: NSTimeInterval!
    var rectime: NSTimeInterval!
    var xmttime: NSTimeInterval!
    var arvtime: NSTimeInterval!
    
    override init() {
        self.orgtime = 0
        self.rectime = 0
        self.xmttime = 0
        self.arvtime = 0
    }
    
    // MARK: NSCoding
    
    required convenience init(coder decoder: NSCoder) {
        self.init()
        self.orgtime = decoder.decodeDoubleForKey("orgtime")
        self.rectime = decoder.decodeDoubleForKey("rectime")
        self.xmttime = decoder.decodeDoubleForKey("xmttime")
        self.arvtime = decoder.decodeDoubleForKey("arvtime")
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeDouble(self.orgtime, forKey: "orgtime")
        coder.encodeDouble(self.rectime, forKey: "rectime")
        coder.encodeDouble(self.xmttime, forKey: "xmttime")
        coder.encodeDouble(self.arvtime, forKey: "arvtime")
    }
}