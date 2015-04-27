//
//  Song.swift
//  Sonorus
//
//  Created by jialiang lin on 4/14/15.
//  Copyright (c) 2015 Team15. All rights reserved.
//

import Foundation
import UIKit

class Song: NSObject, NSCoding {
    var Image:UIImage = UIImage()
    var Title:NSString = ""
    var Artist:NSString = ""
    var AudioPath:NSURL = NSURL()
    
    // MARK: NSCoding
    
    required convenience init(coder decoder: NSCoder) {
        self.init()
        self.Image = decoder.decodeObjectForKey("Image") as! UIImage
        self.Title = decoder.decodeObjectForKey("Title") as! NSString
        self.Artist = decoder.decodeObjectForKey("Artist") as! NSString
        self.AudioPath = decoder.decodeObjectForKey("AudioPath") as! NSURL
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(self.Image, forKey: "Image")
        coder.encodeObject(self.Title, forKey: "Title")
        coder.encodeObject(self.Artist, forKey: "Artist")
        coder.encodeObject(self.AudioPath, forKey: "AudioPath")
    }
}
