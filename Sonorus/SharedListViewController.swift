//
//  SharedListViewController
//  MusicPlayerSonata
//
//  Created by jialiang lin on 4/26/15.
//  Copyright (c) 2015 Team15. All rights reserved.
//

import UIKit

class SharedListViewController: UIViewController ,UITableViewDataSource, UITableViewDelegate{
    @IBOutlet weak var tableView: UITableView!
    
    var tableData:NSMutableArray=NSMutableArray()
    var viewContorller:ViewController=ViewController()

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
        println("AAAAAAADDDDDDDDDDDDD")
        self.performSegueWithIdentifier("updateList", sender: self)
    }
    //
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
