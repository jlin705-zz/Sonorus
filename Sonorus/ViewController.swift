//
//  ViewController.swift
//  Sonorus
//
//  Created by Qinyu Tong on 4/13/15.
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MPCManagerDelegate, ClockDelegate {
    
    @IBOutlet weak var tblPeers: UITableView!
    
    @IBOutlet var clockTime: UILabel!
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    var isAdvertising: Bool!
    
    var clock: Clock!
    
    var leaderElection: LeaderElection!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        tblPeers.delegate = self
        tblPeers.dataSource = self
        
        appDelegate.mpcManager.delegate = self
        
        appDelegate.mpcManager.advertiser.startAdvertisingPeer()
        
        tblPeers.reloadData()
        
        var timer = NSTimer.scheduledTimerWithTimeInterval(5.0, target: self, selector: Selector("startBrowsing"), userInfo: nil, repeats: false)
        isAdvertising = true
        
        clockTime.text = "Clock Time"
        
        clock = Clock()
        clock.delegate = self
        
        leaderElection = LeaderElection()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "startClockAndLeaderElectionService",
            name: "getLeaderNotification", object: nil)
        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func startBrowsing() {
        if appDelegate.mpcManager.leader == nil {
            appDelegate.mpcManager.leader = appDelegate.mpcManager.peer
            leaderElection.leader = appDelegate.mpcManager.peer
            NSNotificationCenter.defaultCenter().postNotificationName("getLeaderNotification", object: nil)
        }
        tblPeers.reloadData()
        appDelegate.mpcManager.browser.startBrowsingForPeers()
    }
    
    func startClockAndLeaderElectionService() {
        clock.startClockService()
        leaderElection.setup()
    }
    
    
    
    // MARK: UITableView related method implementation
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //return appDelegate.mpcManager.foundPeers.count
        if section == 0 {
            return 1
        }
        else {
            return appDelegate.mpcManager.connectedPeers.count
        }
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Leader"
        }
        else {
            return "Devices"
        }
    }
    
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("idCellPeer") as! UITableViewCell
        
        if indexPath.section != 0 {
            let peerID = appDelegate.mpcManager.connectedPeers[indexPath.row]
            cell.textLabel?.text = peerID.displayName
            if peerID == appDelegate.mpcManager.peer {
                cell.textLabel?.text = (cell.textLabel?.text ?? "") + " * My Device * "
            }
            
        }
        else {
            let leader = appDelegate.mpcManager.leader
            if leader != nil{
                if leader == appDelegate.mpcManager.peer {
                    cell.textLabel?.text = appDelegate.mpcManager.leader!.displayName + " * My Device * "
                } else {
                    cell.textLabel?.text = appDelegate.mpcManager.leader!.displayName
                }
            } else {
                cell.textLabel?.text = "Initializing..."
            }
        }
        return cell
    }
    
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 60.0
    }
    
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        //let selectedPeer = appDelegate.mpcManager.foundPeers[indexPath.row] as MCPeerID
        
        //appDelegate.mpcManager.browser.invitePeer(selectedPeer, toSession: appDelegate.mpcManager.session, withContext: nil, timeout: 20)
    }
    
    
    // MARK: MPCManagerDelegate method implementation
    
    func foundPeer() {
        tblPeers.reloadData()
    }
    
    
    func lostPeer() {
        tblPeers.reloadData()
    }
    
    func invitationWasReceived(fromPeer: String) {
        let alert = UIAlertController(title: "", message: "\(fromPeer) wants to chat with you.", preferredStyle: UIAlertControllerStyle.Alert)
        
        let acceptAction: UIAlertAction = UIAlertAction(title: "Accept", style: UIAlertActionStyle.Default) { (alertAction) -> Void in
            self.appDelegate.mpcManager.invitationHandler(true, self.appDelegate.mpcManager.session)
        }
        
        let declineAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel) { (alertAction) -> Void in
            self.appDelegate.mpcManager.invitationHandler(false, nil)
        }
        
        alert.addAction(acceptAction)
        alert.addAction(declineAction)
        
        NSOperationQueue.mainQueue().addOperationWithBlock { () -> Void in
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    
    func connectedWithPeer(peerID: MCPeerID) {
        /* NSOperationQueue.mainQueue().addOperationWithBlock { () -> Void in
        self.performSegueWithIdentifier("idSegueChat", sender: self)
        } */
        appDelegate.mpcManager.connectedPeers.append(peerID)
        println("Connected with a new peer:")
        println(peerID)
        for p in appDelegate.mpcManager.connectedPeers {
            println(p, p.hashValue)
        }
        if appDelegate.mpcManager.leader == nil {
            appDelegate.mpcManager.leader = peerID
        }
        tblPeers.reloadData()
    }
    
    func displayTime(time: NSDate) {
        var dateFormatter = NSDateFormatter()
        //dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        
        let timeStr = dateFormatter.stringFromDate(time)
        
        clockTime.text = timeStr
    }
}



