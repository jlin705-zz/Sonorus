import UIKit

class ShareListView: UIView,UITableViewDataSource,UITableViewDelegate {
    
    @IBOutlet weak var viewBackground: UIView!
    
    @IBOutlet weak var viewContent: UIView!
    
    @IBOutlet weak var tableView: UITableView!
    
    var tableData:NSArray=NSArray()
    var viewController:ViewController=ViewController()
    
    func showShareListView(){
        UIApplication.sharedApplication().keyWindow?.addSubview(self)
        
        var vbFrame:CGRect = self.viewBackground.frame
        vbFrame.origin.y=vbFrame.origin.y+vbFrame.size.height
        
        self.viewBackground.frame=vbFrame
        UIView.animateWithDuration(0.15, animations: { () -> Void in
            var vbFrame:CGRect = self.viewBackground.frame
            vbFrame.origin.y=vbFrame.origin.y-vbFrame.size.height
            self.viewBackground.frame=vbFrame
            let blurEffect=UIBlurEffect(style: UIBlurEffectStyle.Dark)
            let blureView=UIVisualEffectView(effect: blurEffect)
            blureView.frame = self.viewBackground.frame;
            self.viewBackground=blureView
        });
    }
    
    @IBAction func closeShareListView(sender: AnyObject) {
        self.removeFromSuperview()
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        return tableData.count;
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell{
        let cell=UITableViewCell(style: UITableViewCellStyle.Value1, reuseIdentifier: "id")
        cell.backgroundColor=UIColor.clearColor()
        
        let song:Song=self.tableData[indexPath.row] as! Song
        
        cell.textLabel?.text=song.Title as String
        cell.textLabel?.font=UIFont(name: "Arial", size: 14.0)
        cell.textLabel?.textColor=UIColor.whiteColor()
        cell.detailTextLabel?.text=song.Artist as String
        cell.detailTextLabel?.font=UIFont(name:"Arial", size: 8.0)
        return cell;
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let rowSong:Song=self.tableData[indexPath.row] as! Song
        
        viewController.currentAudioIndex = indexPath.row
        viewController.prepareAudio()
        viewController.updatePrepareAudioUI()
        viewController.rotationAnimation()
        
        viewController.sendSyncMessage("switch", relativeTime: 0, songIndex: viewController.currentAudioIndex)
        
        viewController.playAudio()
        viewController.updatePlayAudioUI()
        viewController.playButton.setImage(UIImage(named: "player_btn_pause_normal@2x.png"), forState: UIControlState.Normal)
        
        self.removeFromSuperview()
    }
}