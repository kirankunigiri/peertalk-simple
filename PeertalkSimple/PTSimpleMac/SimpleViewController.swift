//
//  SimpleViewController.swift
//  ptManagerManual
//
//  Created by Kiran Kunigiri on 1/16/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import Cocoa

class SimpleViewController: NSViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var statusLabel: NSTextField!
    
    // MARK: - Properties
    let ptManager = PTManager()
    var panel = NSOpenPanel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup the PTManager
        ptManager.delegate = self
        ptManager.connect(portNumber: PORT_NUMBER)
        
        // Setup file chooser
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = NSImage.imageTypes()
    }
    
    
    @IBAction func addButtonTapped(_ sender: Any) {
        if ptManager.isConnected {
            let num = Int(label.stringValue)! + 1
            self.label.stringValue = "\(num)"
            ptManager.sendObject(object: num, type: PTType.count.rawValue)
        }
    }
    
    
    @IBAction func imageButtonTapped(_ sender: Any) {
        if ptManager.isConnected {
            // Show the file chooser panel
            let opened = panel.runModal()
            
            // If the user selected an image, update the UI and send the image
            if opened == NSFileHandlingPanelOKButton {
                let url = panel.url!
                let image = NSImage(byReferencing: url)
                self.imageView.image = image
                
                let data = NSData(contentsOf: url)
                ptManager.sendData(data: data as Data!, type: PTType.image.rawValue)
            }
        }
    }
    
}



extension SimpleViewController: PTManagerDelegate {
    
    func shouldAcceptDataOfType(type: UInt32) -> Bool {
        return true
    }
    
    func didReceiveDataOfType(type: UInt32, data: Data) {
        if type == PTType.count.rawValue {
            let count = data.convert() as! Int
            self.label.stringValue = "\(count)"
        } else if type == PTType.image.rawValue {
            let image = NSImage(data: data)
            self.imageView.image = image
        }
    }
    
    func connectionDidChange(connected: Bool) {
        self.statusLabel.stringValue = connected ? "Connected" : "Disconnected"
    }
    
}
