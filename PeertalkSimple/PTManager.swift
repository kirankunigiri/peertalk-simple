//
//  PeertalkSimple.swift
//  PeertalkManual
//
//  Created by Kiran Kunigiri on 1/16/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import Foundation

// MARK: - Delegate
protocol PTManagerDelegate {
    
    /** Return whether or not you want to accept the specified data type */
    func peertalk(shouldAcceptDataOfType type: UInt32) -> Bool
    
    /** Runs when the device has received data */
    func peertalk(didReceiveData data: Data, ofType type: UInt32)
    
    /** Runs when the connection has changed */
    func peertalk(didChangeConnection connected: Bool)
    
}

#if os(iOS)
// MARK: - iOS
    
    class PTManager: NSObject {
        
        static let instance = PTManager()
        
        // MARK: Properties
        var delegate: PTManagerDelegate?
        var portNumber: Int?
        weak var serverChannel: PTChannel?
        weak var peerChannel: PTChannel?
        
        /** Prints out all errors and status updates */
        var debugMode = false
        
        
        
        // MARK: Methods
        
        /** Prints only if in debug mode */
        fileprivate func printDebug(_ string: String) {
            if debugMode {
                print(string)
            }
        }
        
        /** Begins to look for a device and connects when it finds one */
        func connect(portNumber: Int) {
            if !isConnected {
                self.portNumber = portNumber
                let channel = PTChannel(delegate: self)
                channel?.listen(onPort: in_port_t(portNumber), iPv4Address: INADDR_LOOPBACK, callback: { (error) in
                    if error == nil {
                        self.serverChannel = channel
                    }
                })
            }
        }
        
        /** Whether or not the device is connected */
        var isConnected: Bool {
            return peerChannel != nil
        }
        
        /** Closes the USB connectin */
        func disconnect() {
            self.serverChannel?.close()
            self.peerChannel?.close()
            peerChannel = nil
            serverChannel = nil
        }
        
        /** Sends data to the connected device 
         * Uses NSKeyedArchiver to convert the object to data
         */
        func sendObject(object: Any, type: UInt32, completion: ((_ success: Bool) -> Void)? = nil) {
            let data = Data.toData(object: object)
            if peerChannel != nil {
                peerChannel?.sendFrame(ofType: type, tag: PTFrameNoTag, withPayload: (data as NSData).createReferencingDispatchData(), callback: { (error) in
                    completion?(true)
                })
            } else {
                completion?(false)
            }
        }
        
        /** Sends data to the connected device */
        func sendData(data: Data, type: UInt32, completion: ((_ success: Bool) -> Void)? = nil) {
            if peerChannel != nil {
                peerChannel?.sendFrame(ofType: type, tag: PTFrameNoTag, withPayload: (data as NSData).createReferencingDispatchData(), callback: { (error) in
                    completion?(true)
                })
            } else {
                completion?(false)
            }
        }
        
        /** Sends data to the connected device */
        func sendDispatchData(dispatchData: DispatchData, type: UInt32, completion: ((_ success: Bool) -> Void)? = nil) {
            if peerChannel != nil {
                peerChannel?.sendFrame(ofType: type, tag: PTFrameNoTag, withPayload: dispatchData as __DispatchData, callback: { (error) in
                    completion?(true)
                })
            } else {
                completion?(false)
            }
        }
        
    }
    
    
    
    // MARK: - Channel Delegate
    extension PTManager: PTChannelDelegate {
        
        func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
            // Check if the channel is our connected channel; otherwise ignore it
            if channel != peerChannel {
                return false
            } else {
                return delegate!.peertalk(shouldAcceptDataOfType: type)
            }
        }
        
        
        func ioFrameChannel(_ channel: PTChannel!, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData!) {
            // Creates the data
            let dispatchData = payload.dispatchData as DispatchData
            let data = NSData(contentsOfDispatchData: dispatchData as __DispatchData) as Data
            delegate?.peertalk(didReceiveData: data, ofType: type)
        }
        
        func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error?) {
            printDebug("ERROR (Connection ended): \(String(describing: error?.localizedDescription))")
            peerChannel = nil
            serverChannel = nil
            delegate?.peertalk(didChangeConnection: false)
        }
        
        func ioFrameChannel(_ channel: PTChannel!, didAcceptConnection otherChannel: PTChannel!, from address: PTAddress!) {
            
            // Cancel any existing connections
            if (peerChannel != nil) {
                peerChannel?.cancel()
            }
            
            // Update the peer channel and information
            peerChannel = otherChannel
            peerChannel?.userInfo = address
            printDebug("SUCCESS (Connected to channel)")
            delegate?.peertalk(didChangeConnection: true)
        }
    }
    
    
    
    
    
    
    
    
    
#elseif os(OSX)
// MARK: - OS X
    
    class PTManager: NSObject {
        
        static var instance = PTManager()
        
        // MARK: Properties
        var delegate: PTManagerDelegate?
        fileprivate var portNumber: Int?
        var connectingToDeviceID: NSNumber?
        var connectedDeviceID: NSNumber?
        var connectedDeviceProperties: NSDictionary?
        
        fileprivate var notConnectedQueue = DispatchQueue(label: "PTExample.notConnectedQueue")
        fileprivate var notConnectedQueueSuspended: Bool = false
        
        /** Prints out all errors and status updates */
        var debugMode = false
        
        /** The interval for rechecking whether or not an iOS device is connected */
        let reconnectDelay: TimeInterval = 1.0
        
        fileprivate var connectedChannel: PTChannel? {
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
        
        /** Prints only if in debug mode */
        fileprivate func printDebug(_ string: String) {
            if debugMode {
                print(string)
            }
        }
        
        /** Begins to look for a device and connects when it finds one */
        func connect(portNumber: Int) {
            self.portNumber = portNumber
            self.startListeningForDevices()
            self.enqueueConnectToLocalIPv4Port()
        }
        
        /** Whether or not the device is connected */
        var isConnected: Bool {
            return connectedChannel != nil
        }
        
        /** Closes the USB connection */
        fileprivate func disconnect() {
            if connectedDeviceID != nil && connectedChannel != nil {
                connectedChannel?.close()
                self.connectedChannel = nil
            }
        }
        
        /** Sends data to the connected device */
        func sendObject(object: Any, type: UInt32, completion: ((_ success: Bool) -> Void)? = nil) {
            let data = Data.toData(object: object) as NSData
            if connectedChannel != nil {
                connectedChannel?.sendFrame(ofType: type, tag: PTFrameNoTag, withPayload: data.createReferencingDispatchData(), callback: { (error) in
                    completion?(true)
                })
            } else {
                completion?(false)
            }
        }
        
        /** Sends data to the connected device */
        func sendData(data: Data, type: UInt32, completion: ((_ success: Bool) -> Void)? = nil) {
            let data = data as NSData
            if connectedChannel != nil {
                connectedChannel?.sendFrame(ofType: type, tag: PTFrameNoTag, withPayload: data.createReferencingDispatchData(), callback: { (error) in
                    completion?(true)
                })
            } else {
                completion?(false)
            }
        }
        
        /** Sends data to the connected device */
        func sendDispatchData(dispatchData: DispatchData, type: UInt32, completion: ((_ success: Bool) -> Void)? = nil) {
            if connectedChannel != nil {
                connectedChannel?.sendFrame(ofType: type, tag: PTFrameNoTag, withPayload: dispatchData as __DispatchData, callback: { (error) in
                    completion?(true)
                })
            } else {
                completion?(false)
            }
        }
    }
    
        
        
        
        
        
        // MARK: - Channel Delegate
        extension PTManager: PTChannelDelegate {
            
            // Decide whether or not to accept the frame
            func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
                return delegate!.peertalk(shouldAcceptDataOfType: type)
            }
            
            // Receive the frame data
            func ioFrameChannel(_ channel: PTChannel, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData) {
                // Creates the data
                let dispatchData = payload.dispatchData as DispatchData
                let data = NSData(contentsOfDispatchData: dispatchData as __DispatchData) as Data
                delegate?.peertalk(didReceiveData: data, ofType: type)
            }
            
            // Connection was ended
            func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error!) {
                
                // Check that the disconnected device is the current device
                if connectedDeviceID != nil && connectedDeviceID!.isEqual(to: channel.userInfo) {
                    self.didDisconnect(fromDevice: connectedDeviceID!)
                }
                
                // Check that the disconnected channel is the current one
                if connectedChannel == channel {
                    printDebug("Disconnected from \(channel.userInfo)")
                    self.connectedChannel = nil
                }
                
            }
            
        }
    
        
        
        // MARK: - Helper methods
        extension PTManager {
            
            fileprivate func startListeningForDevices() {
                
                // Grab the notification center instance
                let nc = NotificationCenter.default
                
                // Add an observer for when the device attaches
                nc.addObserver(forName: NSNotification.Name.PTUSBDeviceDidAttach, object: PTUSBHub.shared(), queue: nil) { (note) in
                    
                    // Grab the device ID from the user info
                    let deviceID = note.userInfo!["DeviceID"] as! NSNumber
                    self.printDebug("Attached to device: \(deviceID)")
                    
                    // Update our properties on our thread
                    self.notConnectedQueue.async(execute: {() -> Void in
                        if self.connectingToDeviceID == nil || !deviceID.isEqual(to: self.connectingToDeviceID) {
                            self.disconnect()
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
                    self.printDebug("Detached from device: \(deviceID)")
                    
                    // Update our properties on our thread
                    if self.connectingToDeviceID!.isEqual(to: deviceID) {
                        self.connectedDeviceProperties = nil
                        self.connectingToDeviceID = nil
                        if self.connectedChannel != nil {
                            self.connectedChannel?.close()
                        }
                    }
                    
                }
                
            }
            
            // Runs when the device disconnects
            fileprivate func didDisconnect(fromDevice deviceID: NSNumber) {
                printDebug("Disconnected from device")
                delegate?.peertalk(didChangeConnection: false)
                
                // Notify the class that the device has changed
                if connectedDeviceID!.isEqual(to: deviceID) {
                    self.willChangeValue(forKey: "connectedDeviceID")
                    connectedDeviceID = nil
                    self.didChangeValue(forKey: "connectedDeviceID")
                }
            }
            
            @objc fileprivate func enqueueConnectToLocalIPv4Port() {
                notConnectedQueue.async(execute: {() -> Void in
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.connectToLocalIPv4Port()
                    })
                })
            }
            
            fileprivate func connectToLocalIPv4Port() {
                let channel = PTChannel(delegate: self)
                channel?.userInfo = "127.0.0.1:\(portNumber ?? -1)"
                
                channel?.connect(toPort: in_port_t(portNumber!), iPv4Address: INADDR_LOOPBACK, callback: { (error, address) in
                    if error == nil {
                        // Update to new channel
                        self.disconnect()
                        self.connectedChannel = channel
                        channel?.userInfo = address!
                    } else {
                        self.printDebug(error!.localizedDescription)
                    }
                    
                    self.perform(#selector(self.enqueueConnectToLocalIPv4Port), with: nil, afterDelay: self.reconnectDelay)
                })
            }
            
            @objc fileprivate func enqueueConnectToUSBDevice() {
                notConnectedQueue.async(execute: {() -> Void in
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.connectToUSBDevice()
                    })
                })
            }
            
            fileprivate func connectToUSBDevice() {
                
                // Create the new channel
                let channel = PTChannel(delegate: self)
                channel?.userInfo = connectingToDeviceID
                channel?.delegate = self
                
                // Connect to the device
                channel?.connect(toPort: Int32(portNumber!), overUSBHub: PTUSBHub.shared(), deviceID: connectingToDeviceID, callback: { (error) in
                    if error != nil {
                        self.printDebug(error!.localizedDescription)
                        // Reconnet to the device
                        if (channel?.userInfo != nil && (channel?.userInfo as! NSNumber).isEqual(to: self.connectingToDeviceID)) {
                            self.perform(#selector(self.enqueueConnectToUSBDevice), with: nil, afterDelay: self.reconnectDelay)
                        }
                    } else {
                        // Update connected device properties
                        self.connectedDeviceID = self.connectingToDeviceID
                        self.connectedChannel = channel
                        self.delegate?.peertalk(didChangeConnection: true)
                        // Check the device properties
                        self.printDebug("\(self.connectedDeviceProperties!)")
                    }
                })
            }
            
        }
    
    
#endif





// MARK: - Data extension for conversion
extension Data {
    
    /** Unarchive data into an object. It will be returned as type `Any` but you can cast it into the correct type. */
    func convert() -> Any {
        return NSKeyedUnarchiver.unarchiveObject(with: self)!
    }
    
    /** Converts an object into Data using the NSKeyedArchiver */
    static func toData(object: Any) -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: object)
    }
    
}




