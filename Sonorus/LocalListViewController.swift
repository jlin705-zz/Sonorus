//
//  NewViewController.swift
//  MusicPlayerSonata
//
//  Created by jialiang lin on 4/26/15.
//  Copyright (c) 2015 DS-Team15. All rights reserved.
//

import UIKit

class LocalListViewController: UIViewController ,UITableViewDataSource, UITableViewDelegate{
    @IBOutlet weak var tableView: UITableView!
    
    var tableData:NSMutableArray=NSMutableArray()
    var viewContorller:ViewController=ViewController()
    var sharedList:NSMutableArray = NSMutableArray()
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()        
        
    }
    
    
    // MARK: - Table View
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tableData.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
        
        let song:Song=self.tableData[indexPath.row] as! Song
        
        cell.titleLable.text = song.Title as String
        
        cell.addButton.tag = indexPath.row
        cell.addButton.addTarget(self, action: "addAction:", forControlEvents: .TouchUpInside)
        
        return cell
        
    }
    
    @IBAction func addAction(sender: UIButton){
        sharedList.addObject(tableData[sender.tag])
        println("add song to shared playlist, broadcasting file to peers")
        //read file from the disk
        var song = tableData[sender.tag] as! Song
        appDelegate.mpcManager.sendFileLookup(song: song)
        self.performSegueWithIdentifier("updateList", sender: self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if (segue.identifier == "updateList"){
            var upcoming: ViewController = segue.destinationViewController as! ViewController
            upcoming.sharedAudioList = self.sharedList
        }
    }

}
