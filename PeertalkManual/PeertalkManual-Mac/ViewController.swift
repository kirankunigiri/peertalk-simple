//
//  ViewController.swift
//  PeertalkManual-Mac
//
//  Created by Kiran Kunigiri on 1/7/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    // Outlets
    @IBOutlet weak var label: NSTextField!
    
    // Constants
    let PTAppReconnectDelay: TimeInterval = 1.0
    
    // Properties
    var debugMode = false
    
    var connectingToDeviceID: NSNumber!
    var connectedDeviceID: NSNumber!
    var connectedDeviceProperties: NSDictionary?
    
    var notConnectedQueue = DispatchQueue(label: "PTExample.notConnectedQueue")
    var notConnectedQueueSuspended: Bool = false
    
    var connectedChannel: PTChannel? {
        didSet {
            
            // Toggle the notConnectedQueue depending on if we are connected or not
            if !(connectedChannel != nil) && notConnectedQueueSuspended {
                notConnectedQueue.resume()
                notConnectedQueueSuspended = false
            }
            else if (connectedChannel != nil) && !notConnectedQueueSuspended {
                notConnectedQueue.suspend()
                notConnectedQueueSuspended = true
            }
            
            if !(connectedChannel != nil) && (connectingToDeviceID != nil) {
                self.enqueueConnectToUSBDevice()
            }
        }
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.startListeningForDevices()
        self.enqueueConnectToLocalIPv4Port()
    }

    @IBAction func sendButtonPressed(_ sender: NSButton) {
        if connectedChannel != nil {
            let num = "\(Int(label.stringValue)! + 1)"
            self.label.stringValue = num
            self.sendData(data: "\(num)".dispatchData)
        }
    }
    
    func sendData(data: DispatchData) {
        connectedChannel?.sendFrame(ofType: PTFrame.message.rawValue, tag: PTFrameNoTag, withPayload: data as __DispatchData, callback: { (error) in
            print(error ?? "Sent")
        })
    }

}




extension ViewController: PTChannelDelegate {
    
    // Decide whether or not to accept the frame
    func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        print("Will accept frame type")
        // Check if it is of the frame type we want. Otherwise close the channel
        if type != PTFrame.message.rawValue {
            channel.close()
            return false
        }
        return true
    }
    
    // Receive the frame data
    func ioFrameChannel(_ channel: PTChannel, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData) {
        
        if type == PTFrame.deviceInfo.rawValue {
            
            // If it is of type device info, then convert the data to a dictionary
            var deviceInfo = NSDictionary(contentsOfDispatchData: payload.dispatchData)
            
        } else if type == PTFrame.message.rawValue {
            
            // If it is a message, convert the data to a string
            let data = payload.dispatchData as DispatchData
            let message = String(bytes: data, encoding: .utf8)!
            
            // Update the UI
            self.label.stringValue = message
        }
        
    }
    
    // Connection was ended
    func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error!) {
        
        // Check that the disconnected device is the current device
        if connectedDeviceID != nil && (connectedDeviceID.isEqual(to: channel.userInfo)) {
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
extension ViewController {
    
    func startListeningForDevices() {
        
        // Grab the notification center instance
        let nc = NotificationCenter.default
        
        // Add an observer for when the device attaches
        nc.addObserver(forName: NSNotification.Name.PTUSBDeviceDidAttach, object: PTUSBHub.shared(), queue: nil) { (note) in
            
            let deviceID = note.userInfo!["DeviceID"] as! NSNumber
            print("PTUSBDeviceDidAttachNotification: \(deviceID)")
            
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
            
            let deviceID = note.userInfo!["DeviceID"] as! NSNumber
            print("PTUSBDeviceDidDetachNotification: \(deviceID)")
            
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
        
        if connectedDeviceID.isEqual(to: deviceID) {
            self.willChangeValue(forKey: "connectedDeviceID")
            connectedDeviceID = nil
            self.didChangeValue(forKey: "connectedDeviceID")
        }
    }
    
    func disconnectFromCurrentChannel() {
        if connectedDeviceID != nil && connectedChannel != nil {
            connectedChannel?.close()
            self.connectedChannel = nil
        }
    }
    
    func enqueueConnectToLocalIPv4Port() {
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
    
    func enqueueConnectToUSBDevice() {
        notConnectedQueue.async(execute: {() -> Void in
            DispatchQueue.main.async(execute: {() -> Void in
                self.connectToUSBDevice()
            })
        })
    }
    
    func connectToUSBDevice() {
        let channel = PTChannel(delegate: self)
        channel?.userInfo = connectingToDeviceID
        channel?.delegate = self
        
        channel?.connect(toPort: PTExampleProtocolIPv4PortNumber, overUSBHub: PTUSBHub.shared(), deviceID: connectingToDeviceID, callback: { (error) in
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
                // TODO: Check connected device vs connecting device
                print(self.connectedDeviceID)
                print(self.connectedDeviceProperties!)
            }
        })
    }
    
}





