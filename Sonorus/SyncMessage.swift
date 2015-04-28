//
//  SyncMessage.swift
//  Sonorus
//
//  Created by Qinyu Tong on 4/26/15.
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//

import Foundation

class SyncMessage: NSObject, NSCoding {
    var kind: String!
    var absoluteTime: NSTimeInterval?
    var relativeTime: NSTimeInterval?
    var songIndex: Int?
    
    override init() {}
    
    // MARK: NSCoding
    
    required convenience init(coder decoder: NSCoder) {
        self.init()
        self.kind = decoder.decodeObjectForKey("kind") as! String!
        
        switch self.kind {
            case "play":
                self.absoluteTime = decoder.decodeDoubleForKey("absoluteTime")
                self.relativeTime = decoder.decodeDoubleForKey("relativeTime")
                self.songIndex = decoder.decodeIntegerForKey("songIndex")
            
            case "pause":
                break
            
            case "playAt":
                self.absoluteTime = decoder.decodeDoubleForKey("absoluteTime")
                self.relativeTime = decoder.decodeDoubleForKey("relativeTime")
            
            case "switch":
                self.absoluteTime = decoder.decodeDoubleForKey("absoluteTime")
                self.relativeTime = decoder.decodeDoubleForKey("relativeTime")
                self.songIndex = decoder.decodeIntegerForKey("songIndex")
            
            default:
                break
        }
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(self.kind, forKey: "kind")
        
        switch self.kind {
            case "play":
                coder.encodeDouble(self.absoluteTime!, forKey: "absoluteTime")
                coder.encodeDouble(self.relativeTime!, forKey: "relativeTime")
                coder.encodeInteger(self.songIndex!, forKey: "songIndex")
            
            case "pause":
                break
            
            case "playAt":
                coder.encodeDouble(self.absoluteTime!, forKey: "absoluteTime")
                coder.encodeDouble(self.relativeTime!, forKey: "relativeTime")
                
            case "switch":
                coder.encodeDouble(self.absoluteTime!, forKey: "absoluteTime")
                coder.encodeDouble(self.relativeTime!, forKey: "relativeTime")
                coder.encodeInteger(self.songIndex!, forKey: "songIndex")
                
            default:
                break
            
        }
    }
}