//
//  PeerListViewController.swift
//  MusicPlayerSonata
//
//  Created by Qinyu Tong on 4/26/15.
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class PeerListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MPCManagerDelegate {
    
    @IBOutlet weak var tblPeers: UITableView!
    
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
        
        
        tblPeers.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITableView related method implementation
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return appDelegate.mpcManager.viewPeers.count
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
            let peerID = appDelegate.mpcManager.viewPeers.allObjects[indexPath.row] as! MCPeerID
            
            cell.textLabel?.text = peerID.displayName
            if peerID == appDelegate.mpcManager.peer {
                cell.textLabel?.text = (cell.textLabel?.text ?? "") + " * My Device * "
            }
            
        } else {
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
        
    }
    
    
    // MARK: MPCManagerDelegate method implementation
    
    func foundPeer() {
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.tblPeers.reloadData()
        }
    }
    
    
    func lostPeer() {
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.tblPeers.reloadData()
        }
    }
    
    func connectedWithPeer() {
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.tblPeers.reloadData()
        }
    }
    
    func leaderChange() {
        dispatch_async(dispatch_get_main_queue()) {
            () -> Void in
            self.tblPeers.reloadData()
        }
    }
}
