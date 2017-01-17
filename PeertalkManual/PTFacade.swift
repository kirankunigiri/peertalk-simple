//
//  PeertalkSimple.swift
//  PeertalkManual
//
//  Created by Kiran Kunigiri on 1/16/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import Foundation


#if os(iOS)
// MARK: - iOS
    
    protocol PTFacadeDelegate {
        
        /** Return whether or not you want to accept the specified data type */
        func shouldAcceptDataOfType(type: UInt32) -> Bool
        
        /** Runs when the device has received data */
        func didReceiveDataOfType(type: UInt32, data: Data)
        
        /** Runs when the connection has changed */
        func connectionDidChange(connected: Bool)
        
    }
    
    class PTFacade: NSObject {
        
        // Properties
        var delegate: PTFacadeDelegate?
        
        weak var serverChannel: PTChannel?
        weak var peerChannel: PTChannel?
        
        /** Begins to look for a device and connects when it finds one */
        func connect() {
            let channel = PTChannel(delegate: self)
            channel?.listen(onPort: in_port_t(PORT_NUMBER), iPv4Address: INADDR_LOOPBACK, callback: { (error) in
                if error == nil {
                    self.serverChannel = channel
                }
            })
        }
        
        /** Whether or not the device is connected */
        var isConnected: Bool {
            return peerChannel != nil
        }
        
        /** Closes the USB connectin */
        func closeConnection() {
            self.serverChannel?.close()
        }
        
        /** Sends data to the connected device */
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
    extension PTFacade: PTChannelDelegate {
        
        func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
            // Check if the channel is our connected channel; otherwise ignore it
            if channel != peerChannel {
                return false
            } else {
                return delegate!.shouldAcceptDataOfType(type: type)
            }
        }
        
        
        func ioFrameChannel(_ channel: PTChannel!, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData!) {
            // Creates the data
            let dispatchData = payload.dispatchData as DispatchData
            let data = NSData(contentsOfDispatchData: dispatchData as __DispatchData) as Data
            delegate?.didReceiveDataOfType(type: type, data: data)
        }
        
        func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error?) {
            print("ERROR (Connection ended): \(error?.localizedDescription)")
            delegate?.connectionDidChange(connected: false)
        }
        
        func ioFrameChannel(_ channel: PTChannel!, didAcceptConnection otherChannel: PTChannel!, from address: PTAddress!) {
            
            // Cancel any existing connections
            if (peerChannel != nil) {
                peerChannel?.cancel()
            }
            
            // Update the peer channel and information
            peerChannel = otherChannel
            peerChannel?.userInfo = address
            print("SUCCESS (Connected to channel)")
            delegate?.connectionDidChange(connected: true)
        }
    }
    
    
    
    
    
    
    
    
    
#elseif os(OSX)
// MARK: - OS X
    
    protocol PTFacadeDelegate {
        
        /** Return whether or not you want to accept the specified data type */
        func shouldAcceptDataOfType(type: UInt32) -> Bool
        
        /** Runs when the device has received data */
        func didReceiveDataOfType(type: UInt32, data: Data)
        
        /** Runs when the connection has changed */
        func connectionDidChange(connected: Bool)
        
    }
    
    class PTFacade: NSObject {
        
        // MARK: Properties
        var delegate: PTFacadeDelegate?
        
        var connectingToDeviceID: NSNumber!
        var connectedDeviceID: NSNumber!
        var connectedDeviceProperties: NSDictionary?
        
        /** The interval for rechecking whether or not an iOS device is connected */
        let PTAppReconnectDelay: TimeInterval = 1.0
        
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
        
        /** Begins to look for a device and connects when it finds one */
        func connect() {
            self.startListeningForDevices()
            self.enqueueConnectToLocalIPv4Port()
        }
        
        /** Whether or not the device is connected */
        var isConnected: Bool {
            return connectedChannel != nil
        }
        
        /** Closes the USB connectin */
        func closeConnection() {
            self.connectedChannel?.close()
        }
        
        /** Sends data to the connected device */
        func sendObject(object: Any, type: UInt32, completion: ((_ success: Bool) -> Void)? = nil) {
            let data = Data.toData(object: object)
            if connectedChannel != nil {
                connectedChannel?.sendFrame(ofType: type, tag: PTFrameNoTag, withPayload: (data as NSData).createReferencingDispatchData(), callback: { (error) in
                    completion?(true)
                })
            } else {
                completion?(false)
            }
        }
        
        /** Sends data to the connected device */
        func sendData(data: Data, type: UInt32, completion: ((_ success: Bool) -> Void)? = nil) {
            if connectedChannel != nil {
                connectedChannel?.sendFrame(ofType: type, tag: PTFrameNoTag, withPayload: (data as NSData).createReferencingDispatchData(), callback: { (error) in
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
    
        
        
        
        
        
        // MARK: - PTChannel Delegate
        extension PTFacade: PTChannelDelegate {
            
            // Decide whether or not to accept the frame
            func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
                return delegate!.shouldAcceptDataOfType(type: type)
            }
            
            // Receive the frame data
            func ioFrameChannel(_ channel: PTChannel, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData) {
                // Creates the data
                let dispatchData = payload.dispatchData as DispatchData
                let data = NSData(contentsOfDispatchData: dispatchData as __DispatchData) as Data
                self.delegate?.didReceiveDataOfType(type: type, data: data)
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
        extension PTFacade {
            
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
                self.delegate?.connectionDidChange(connected: false)
                
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
                        self.delegate?.connectionDidChange(connected: true)
                        // Check the device properties
                        print(self.connectedDeviceProperties!)
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
    
    static func toData(object: Any) -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: object)
    }
    
}


