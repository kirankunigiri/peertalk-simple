//
//  ViewController.swift
//  PeertalkManual-Mac
//
//  Created by Kiran Kunigiri on 1/7/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import Cocoa
import Quartz

// MARK: - Main Class
class ManualViewController: NSViewController {

    // MARK: Outlets
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var statusLabel: NSTextField!
    var panel = NSOpenPanel()
    
    // MARK: Constants
    
    /** The interval for rechecking whether or not an iOS device is connected */
    let PTAppReconnectDelay: TimeInterval = 1.0
    
    // MARK: Properties
    var connectingToDeviceID: NSNumber!
    var connectedDeviceID: NSNumber!
    var connectedDeviceProperties: NSDictionary?
    
    var notConnectedQueue = DispatchQueue(label: "PTExample.notConnectedQueue")
    var notConnectedQueueSuspended: Bool = false
    
    var connectedChannel: PTChannel? {
        didSet {
            
            // Toggle the notConnectedQueue depending on if we are connected or not
            if connectedChannel == nil && notConnectedQueueSuspended {
                notConnectedQueue.resume()
                notConnectedQueueSuspended = false
            } else if connectedChannel != nil && !notConnectedQueueSuspended {
                notConnectedQueue.suspend()
                notConnectedQueueSuspended = true
            }
            
            // Reconnect to the device if we were originally connecting to one
            if connectedChannel == nil && connectingToDeviceID != nil {
                self.enqueueConnectToUSBDevice()
            }
        }
    }
    
    
    // MARK: Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start the peertalk service
        self.startListeningForDevices()
        self.enqueueConnectToLocalIPv4Port()
        
        // Setup file chooser
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = NSImage.imageTypes
    }

    // Add 1 to our counter label and send the data if the device is connected
    @IBAction func addButtonPressed(_ sender: NSButton) {
        if isConnected() {
            let num = Int(label.stringValue)! + 1
            self.label.stringValue = "\(num)"
            
            let data = NSKeyedArchiver.archivedData(withRootObject: num) as NSData
            self.sendData(data: data.createReferencingDispatchData(), type: PTType.number)
        }
    }
    
    // Present the image picker if the device is connected
    @IBAction func imageButtonPressed(_ sender: NSButton) {
        if isConnected() {
            // Show the file chooser panel
            let opened = panel.runModal()
            
            // If the user selected an image, update the UI and send the image
            if opened.rawValue == NSFileHandlingPanelOKButton {
                let url = panel.url!
                let image = NSImage(byReferencing: url)
                self.imageView.image = image
                
                let data = NSData(contentsOf: url)!
                self.sendData(data: data.createReferencingDispatchData(), type: PTType.image)
            }
        }
    }
    
    /** Whether or not the device is connected */
    func isConnected() -> Bool {
        return connectedChannel != nil
    }
    
    /** Sends data to the connected device */
    func sendData(data: __DispatchData, type: PTType) {
        connectedChannel?.sendFrame(ofType: type.rawValue, tag: PTFrameNoTag, withPayload: data as __DispatchData!, callback: { (error) in
            print(error ?? "Sent")
        })
    }

}



// MARK: - PTChannel Delegate
extension ManualViewController: PTChannelDelegate {
    
    // Decide whether or not to accept the frame
    func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        // Optional: Check the frame type and reject specific ones it
        return true
    }
    
    // Receive the frame data
    func ioFrameChannel(_ channel: PTChannel, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData) {
        
        // Creates the data
        let dispatchData = payload.dispatchData as DispatchData
        let data = NSData(contentsOfDispatchData: dispatchData as __DispatchData) as Data
        
        // Check frame type and get the corresponding data
        if type == PTType.number.rawValue {
            let count = NSKeyedUnarchiver.unarchiveObject(with: data) as! Int
            self.label.stringValue = "\(count)"
        } else if type == PTType.image.rawValue {
            let image = NSImage(data: data)
            self.imageView.image = image
        }
        
        
    }
    
    // Connection was ended
    func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error!) {
        
        // Check that the disconnected device is the current device
        if connectedDeviceID != nil && connectedDeviceID.isEqual(to: channel.userInfo) {
            self.didDisconnect(fromDevice: connectedDeviceID)
        }
        
        // Check that the disconnected channel is the current one
        if connectedChannel == channel {
            print("Disconnected from \(channel.userInfo)")
            self.connectedChannel = nil
        }
        
    }
    
}






// MARK: - Helper methods
extension ManualViewController {
    
    func startListeningForDevices() {
        
        // Grab the notification center instance
        let nc = NotificationCenter.default
        
        // Add an observer for when the device attaches
        nc.addObserver(forName: NSNotification.Name.PTUSBDeviceDidAttach, object: PTUSBHub.shared(), queue: nil) { (note) in
            
            // Grab the device ID from the user info
            let deviceID = note.userInfo!["DeviceID"] as! NSNumber
            print("Attached to device: \(deviceID)")
            
            // Update our properties on our thread
            self.notConnectedQueue.async(execute: {() -> Void in
                if self.connectingToDeviceID == nil || !deviceID.isEqual(to: self.connectingToDeviceID) {
                    self.disconnectFromCurrentChannel()
                    self.connectingToDeviceID = deviceID
                    self.connectedDeviceProperties = (note.userInfo?["Properties"] as? NSDictionary)
                    self.enqueueConnectToUSBDevice()
                }
            })
        }
        
        // Add an observer for when the device detaches
        nc.addObserver(forName: NSNotification.Name.PTUSBDeviceDidDetach, object: PTUSBHub.shared(), queue: nil) { (note) in
            
            // Grab the device ID from the user info
            let deviceID = note.userInfo!["DeviceID"] as! NSNumber
            print("Detached from device: \(deviceID)")
            
            // Update our properties on our thread
            if self.connectingToDeviceID.isEqual(to: deviceID) {
                self.connectedDeviceProperties = nil
                self.connectingToDeviceID = nil
                if self.connectedChannel != nil {
                    self.connectedChannel?.close()
                }
            }
            
        }
        
    }
    
    // Runs when the device disconnects
    func didDisconnect(fromDevice deviceID: NSNumber) {
        print("Disconnected from device")
        self.statusLabel.stringValue = "Status: Disconnected"
        
        // Notify the class that the device has changed
        if connectedDeviceID.isEqual(to: deviceID) {
            self.willChangeValue(forKey: "connectedDeviceID")
            connectedDeviceID = nil
            self.didChangeValue(forKey: "connectedDeviceID")
        }
    }
    
    /** Disconnects from the connected channel */
    func disconnectFromCurrentChannel() {
        if connectedDeviceID != nil && connectedChannel != nil {
            connectedChannel?.close()
            self.connectedChannel = nil
        }
    }
    
    @objc func enqueueConnectToLocalIPv4Port() {
        notConnectedQueue.async(execute: {() -> Void in
            DispatchQueue.main.async(execute: {() -> Void in
                self.connectToLocalIPv4Port()
            })
        })
    }
    
    func connectToLocalIPv4Port() {
        let channel = PTChannel(delegate: self)
        channel?.userInfo = "127.0.0.1:\(PORT_NUMBER)"
        
        channel?.connect(toPort: in_port_t(PORT_NUMBER), iPv4Address: INADDR_LOOPBACK, callback: { (error, address) in
            if error == nil {
                // Update to new channel
                self.disconnectFromCurrentChannel()
                self.connectedChannel = channel
                channel?.userInfo = address!
            } else {
                print(error!)
            }
            
            self.perform(#selector(self.enqueueConnectToLocalIPv4Port), with: nil, afterDelay: self.PTAppReconnectDelay)
        })
    }
    
    @objc func enqueueConnectToUSBDevice() {
        notConnectedQueue.async(execute: {() -> Void in
            DispatchQueue.main.async(execute: {() -> Void in
                self.connectToUSBDevice()
            })
        })
    }
    
    func connectToUSBDevice() {
        
        // Create the new channel
        let channel = PTChannel(delegate: self)
        channel?.userInfo = connectingToDeviceID
        channel?.delegate = self
        
        // Connect to the device
        channel?.connect(toPort: Int32(PORT_NUMBER), overUSBHub: PTUSBHub.shared(), deviceID: connectingToDeviceID, callback: { (error) in
            if error != nil {
                print(error!)
                // Reconnet to the device
                if (channel?.userInfo != nil && (channel?.userInfo as! NSNumber).isEqual(to: self.connectingToDeviceID)) {
                    self.perform(#selector(self.enqueueConnectToUSBDevice), with: nil, afterDelay: self.PTAppReconnectDelay)
                }
            } else {
                // Update connected device properties
                self.connectedDeviceID = self.connectingToDeviceID
                self.connectedChannel = channel
                self.statusLabel.stringValue = "Status: Connected"
                // Check the device properties
                print(self.connectedDeviceProperties!)
            }
        })
    }
    
}





