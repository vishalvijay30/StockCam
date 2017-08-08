//
//  ViewController.swift
//  StockCam
//
//  Created by Vishal  on 8/7/17.
//
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var V1 : View1 = View1(nibName: "View1", bundle: nil)
        var V2 : View2 = View2(nibName: "View2", bundle: nil)
        
        self.addChildViewController(V1)
        self.scrollView.addSubview(V1.view)
        V1.didMove(toParentViewController: self)
        
        self.addChildViewController(V2)
        self.scrollView.addSubview(V2.view)
        V2.didMove(toParentViewController: self)
        
        var V2Frame : CGRect = V2.view.frame
        V2Frame.origin.x = self.view.frame.width
        V2.view.frame = V2Frame
        
        self.scrollView.contentSize = CGSize(width: self.view.frame.width * 2, height: self.view.frame.size.height)
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

